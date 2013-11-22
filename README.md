# /shed

A REST service for managing InterSystems source code resources.
It currently supports Cache classes, .mac code and integration with github.
Responses from shed come in only 2 flavors: source code or errors.

## What's it do?

* Provides an HTTP endpoint to GET and POST Caché classes and macro routines.
* Command-line script which wraps curl to invoke shed
* github integration - push and pull your repos between a Caché instance and github

### Getting started

Clone this repo and then install. To installed the client-side tool:

`$make install`

This will put shed.sh into /usr/local/bin by default.

Then, running
`shed install user@passwd:/usr/local/cache`
Would shed-enable the Caché instance installed in /usr/local/cache
on the local machine.

To interact with your Caché server, shed relies on some configuration
which is stored within your local .git/config.
If the user/password and server/port of the Caché instance are not found 
in your git config, then shed will prompt you.
You can see and set these settings like this

<pre>
$shed config 
user=
password=
server=
$git config --local --add shed.user jimmy
$git config --local --add shed.server cache.jimmy.com:57772
$shed config
user=jimmy
password=
server=cache.jimmmy.com:57772
</pre>

Note, you can pre-configure a subset of these, and then shed will propmt you.

Other commands are 'get' and 'post', just like the raw HTTP API.
For example,
<pre>
$shed get foo.test.cls
$shed get -ns SAMPLES Sample.Person.cls
$shed post foo.test.cls
$shed post -ns SAMPLES Sample.Car.cls
</pre>

## Dependencies

* Caché 2014.1 or higher, specifically the shed.Server relies on the %Compile.URL.TextServices classes and %CSP.REST
* Client-side: git, curl, expect, and make - these are all easy to `sudo apt-get install`

##API Reference
`GET /man`
 Returns version info and API documentation

`GET /:namespace/:path`
GET a class or macro routine from the system
By default this will return the raw source code.
You must specify the correct extentsion for the artifact you want
in the :path parameter.</p>
For example - 
*Sample.Person.cl
*Foo.mac
If you want the default xml export of an resource append '.xml' to the resource name or use the `--format` option on shed.sh

If :path is emtpy or contins a "*" wildcard, then a list of the 
classes in that namespace is returned.</p>
For example,
`curl -X GET http://server/shed/samples/cls/Sample.*.cls`
<p>You can get JSON back by specifing the Http-Accept header
as 'application/json' in your request</p>

`POST /:namespace/:path`
 
Loads a file into Caché. Requires Content-Type=application/text HTTP header.
For example:
`curl -X POST --header "Content-Type:application/text" --data-binary @some.class.cls http://jim:secret@cache.server.com:57772/shed/user/some.class.cls`

`GET /:namespace/git/pull/:gituser/:repo/`
 Pulls artifacts from github into Cache.
You can specify a full respository or the path
to a file or folder within the respository.
Note that only artifacts with the ".cls" or ".mac" extenstion
are pulled in.

`GET /:namespace/git/pull/:gituser/:repo/:path`
 Pulls artifacts from github into Cache.
You can specify a full respository or the path
to a file or folder within the respository.
Note that only artifacts with the ".cls" or ".mac" extenstion
are pulled in. Rather that storing your git credentials on the Caché system
you can pass in the X-Shed-Git- HTTP header's like this:

`--header "X-Shed-Git-User:<gituser>" --header "X-Shed-Git-Password:<gitpasswd>"

`GET /:namespace/git/passwd/:gituser/:repo/:gitusername/:gitpassword`
Endpoint to store github credentials on the system
Maps (gituser,repo) to and set of user/pass credentials.
Stores information per namespace in the ^%git global

`GET /namespaces`

Lists the namespace on the Caché instance.

