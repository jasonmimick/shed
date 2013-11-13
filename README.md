 _|_  _  _|
_\| |(/_(_|

/shed
Version:0.0.2
http://github.com/jasonmimick/shed
shed is a REST based interface for managing InterSystems code artifacts.
It currently supports Cache classes, .mac code and integration with github.
Responses from shed come in only 2 flavors: source code or errors.
Client driver developers should refer to the following API reference.

API Reference
-------------
GET /man
 Returns version info and API documentation

GET /:namespace/:path
 <p>GET a class or macro routine from the system
By default this will return the raw source code.
	</p>
<p>You must specify the correct extentsion for the artifact you want
in the :path parameter.</p>
<p>For example - 
Sample.Person.cls
Foo.mac</p>
<p>If you want the default xml export of an resource 
	append '.xml' to the resource
name</p>
<p>If :path is emtpy or contins a "*" wildcard, then a list of the 
classes in that namespace is returned.</p>
For example,
<pre>
curl -X GET http://server/shed/samples/cls/Sample.*.cls
</pre>
<p>You can get JSON back by specifing the Http-Accept header
as 'application/json' in your request</p>

POST /:namespace/:path
 

GET /:namespace/git/pull/:gituser/:repo/
 Pulls artifacts from github into Cache.
You can specify a full respository or the path
to a file or folder within the respository.
Note that only artifacts with the ".cls" or ".mac" extenstion
are pulled in.

GET /:namespace/git/pull/:gituser/:repo/:path
 Pulls artifacts from github into Cache.
You can specify a full respository or the path
to a file or folder within the respository.
Note that only artifacts with the ".cls" or ".mac" extenstion
are pulled in.

GET /:namespace/git/passwd/:gituser/:repo/:gitusername/:gitpassword
 <Route Url="/:namespace/git/passwd/:gituser/:repo/:gitusername/:gitpassword" Method="GET" Call="GitPasswd"/>
Endpoint to store github credentials on the system
Maps (gituser,repo) to and set of user/pass credentials.
Stores information per namespace in the ^%git global

GET /namespaces
 This method returns a list of namespaces for this server

GET /upgrade
 Upgrades the version of shed on this system
Pulls update from github

$ZV=Cache for Windows (x86-64) 2013.2 (Build 454U) Wed Sep 11 2013 19:11:13 EDT
