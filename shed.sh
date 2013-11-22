#!/bin/bash

usage()
{
    cat << 'end-of-usage'
usage: shed [-h|--help] [-ns|--namespace <namespace>] [-v|--verbose] [-f|--format <xml|json>] <command> [<args>]

Available options:
  --namespace   Sets the namespace to connect to on the Caché server
  --format      Format to return resource, default is plain test, also accepts 'json' or 'xml'

Available commands are:
  install     Will install the shed.Server to a Caché instance
  config      Will output the current shed config stored in git
  man         Outputs the /man from the current shed server
  get         GETs a resource from a Caché instance
  post        POSTs a resource to Caché
  git-pull    Pull a repo from github and load it into Caché


To configure user/password/server run:
$git config --local shed.user <username>
$git config --local shed.password <password>
$git config --local shed.server <server:port>

Examples:
Install shed to /var/isc/healthshare
#shed install _system:SYS@/var/isc/healthshare

Grab a copy of the Sample.Person class
#shed -ns SAMPLES get Sample.Person.cls

Fetch a json formated list of all the classes in the EnsLib.HL7 package
#shed -ns ENSDEMO --format json get EnsLib.HL7.*.cls

Update a class to the USER namespace
#shed -ns USER post Acme.Widgets.RocketLauncher.cls

Pull a fresh copy of all the resource in the acme/widget repo on github into Caché
This command takes 3 arguments, git user, git password, and path of repository.
#shed -ns USER git-pull joe@acme.com secret123 acme/widgets
end-of-usage
}
# helper routines start
config()
{
  git config --get-regexp shed
}

# parse ccontrol qlist info
# from install_dir/bin/ccontrol
# and extract the instance name for 
# this install_dir
instanceName() {
    install_dir=$1
    ccontrol=$install_dir/bin/ccontrol
    list=`$ccontrol qlist | awk -F\^ '{ print $1"^"$2 }'`
    for config in `echo "$list" | sort`
        do
            instance=`echo $config | cut -d'^' -f1`
            dir=`echo $config | cut -d'^' -f2`
            if [ "$dir" = "$install_dir" ]; then
                echo $instance
                return 1
            fi
        done
    return 0
}

shedLoader()
{
    install_dir=$1
    user=$2
    passwd=$3
    shedServer="$(pwd)/shed.Server.cls"
    tmp="$(pwd)/shed.loader.mac"
    cat << 'end-of-shed.loader.mac' >> "$tmp"
 #;shed.loader.mac
load(filename)  public  {
 set fs=##class(%Stream.FileCharacter).%New()
 set fs.Filename=filename
 set firstLine=fs.ReadLine()
 do fs.Rewind()
 if ( $length(firstLine)=fs.Size ) {
  set fs.LineTerminator=$C(10)
 }
 if ( $ascii($extract(firstLine,$length(firstLine)))=13 ) {
  set fs.LineTerminator=$C(13,10)
 }
 set classname=$piece(filename,##class(%File).GetDirectory(filename),2)
 set sc=##class(%Compiler.UDL.TextServices).SetTextFromStream($zu(5),classname,fs)
 if ('sc) {
  write "Compiler Error",!
  do $system.Status.DisplayError(sc)
 }
}


end-of-shed.loader.mac

instance=$( instanceName $install_dir )
csession="$install_dir/bin/csession"
namespace="USER"  #"%SYS"
#namespace="`echo $namespace | tr '[:lower:]' '[:upper:']`"
system="\\\$system"
echo namespace=$namespace
/usr/bin/expect <<End-Of-Expect
spawn $csession $instance -U $namespace
expect "Username: " {
        send "$user\r"
}
expect "Password: " {
        send "$passwd\r"
}
expect "$namespace>" {
        send "set loader=\"$tmp\"\r"
        expect "$namespace>"
        send "open loader:\"R\"\r"
        expect "$namespace>"
        send "use loader zl\r"
        expect "$namespace>"
        send "zs shed.loader\r"
        expect "$namespace>"
        send "do load^shed.loader(\"$shedServer\")\r"
        expect "$namespace>"
       send "halt\r"
}
End-Of-Expect
#        send "do ##class(\%RoutineMgr).Delete(\"shed.loader\")\r"
#        expect "$namespace>"
 

rm $tmp
}


#end of helper routines
# main script
options=$@
arguments=($options)
index=0
command=0
command_arg=0
namespace=0
debug=0
format=0
for arg in $options
do
  index=`expr $index + 1`
  case $arg in
    -v|--verbose) debug=1;;
    -h|--help) usage 
               exit;;
    -f|--format) format=${arguments[index]};;
    -ns|--namespace)  namespace=${arguments[index]};; 
    config) config
            exit;;
  install) command="install" 
           command_arg=${arguments[index]};;
      get)  command="get"
           command_arg=${arguments[index]};;
      post) command="post"
           command_arg=${arguments[index]};;
      man)  command="man";;
    git-pull) command="git-pull"
            ii=`expr $index+1`
            iii=`expr $index+2`
            command_arg=("${arguments[index]}" "${arguments[ii]}" "${arguments[iii]}")
            echo "command_arg.length=${#command_arg[@]}"
            echo "command_arg=$command_arg";;
  esac
done

if [ $command = 0 ]; then 
  echo "no command found"
  usage
  exit
fi

user=`git config --get shed.user`
password=`git config --get shed.password`
server=`git config --get shed.server`


if [ -z $user ]; then echo "user not found in git config, run shed --help"; fi
if [ -z $server ]; then echo "server not found in git config, run shed --help"; fi
if [ -z $password ]; then
  echo -n "Caché password for user='$user':" 
  read password
fi
if [ -z $password ]; then echo "password not found, run shed --help"; fi
verbose="--silent"
if [ $debug = 1 ]; then
  debug_header="-H X-Shed-Debug:1"
  verbose="-v"
fi

if [ $format = 'json' ]; then
  json_header="--header Accept:application/json"
fi
if [ $format = 'xml' ]; then
  json_header="--header Accept:application/xml"
fi
if [ $command = 'git-pull' ]; then
  gituser=${command_arg[0]}
  gitpasswd=${command_arg[1]}
  git_header="-H X-Shed-Git-User:$gituser -H X-Shed-Git-Password:$gitpasswd"
fi
headers="$debug_header $json_header"

#set -x
case $command in 
  man)
    curl $verbose -X GET $headers http://$user:$password@$server/shed/man ;;
  get)
    curl $verbose -X GET $headers http://$user:$password@$server/shed/$namespace/$command_arg ;;
  post)
    curl $verbose -X POST $headers --header "Content-Type:text.plain" --data-binary @$command_arg http://$user:$password@$server/shed/$namespace/$command_arg ;;
  install)
    shedLoader $command_arg $user $password;;
  git-pull)
    curl $verbose -X GET $git_header http://$user:$password@$server/shed/$namespace/git/pull/${command_arg[2]}/ ;;
  esac
