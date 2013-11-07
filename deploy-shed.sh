#!/bin/bash
# deploy-shed.sh
# Deploys the shed server to an instance of
# Caché, Ensemble or HealthShare
#
usage()
{
    cat << 'end-of-usage'
usage: deploy-shed.sh [help] user:password@install_dir
       help    - displays this usage
Installs the shed.Server.cls on the target instance
installed at install_dir. 
Example:
   $./deploy-shed.sh _system:SYS@/usr/cachesys
end-of-usage
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
namespace="%SYS"
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
expect "%SYS>" {
        send "set loader=\"$tmp\"\r"
        expect "%SYS>"
        send "open loader:\"R\"\r"
        expect "$namespace>"
        send "use loader zl\r"
        expect "$namespace>"
        send "zs shed.loader\r"
        expect "$namespace>"
        send "do load^shed.loader(\"$shedServer\")\r"
        expect "$namespace>"
        send "do ##class(\%RoutineMgr).Delete(\"shed.loader\")\r"
        expect "$namespace>"
        send "halt\r"
}
End-Of-Expect

rm $tmp
}
set -f
arg="$1"
echo arg=$arg
if [ "$arg" = "help" ]; then
    usage
    exit
fi

credentials=${arg%@*}
install_dir=${arg#*@}
echo credentials=$credentials
user=${credentials%:*}
passwd=${credentials#*:}
echo install_dir=$install_dir
echo user=$user
echo passwd=$passwd

echo instanceName=$(instanceName $install_dir )

shedLoader $install_dir $user $passwd
