Include %occSAX

Class shed.Server Extends %CSP.REST
{

ClassMethod exception(msg...) As %Exception.General
{
	set message=""
	for i=1:1:msg {
		set message=message_" "_msg(i)
	}
	return ##class(%Exception.GeneralException).%New("shed","shed",message)
}

ClassMethod gitHTTPGet(namespace, gituser, repo, url) As %Net.HttpResponse
{
	set req=##class(%Net.HttpRequest).%New()
	do ##class(%Net.URLParser).Parse(url,.uc)
	if ( '$data(uc("host")) ) {
		throw ..exception("gitHTTPGet: no host found in url",url)
	}
	set req.Server=uc("host")
	
	set req.Port=$select($get(uc("port"))'="":uc("port"),1:80)
	if ( uc("scheme") = "https" ) {
		set req.Https=1
		set req.SSLConfiguration="DefaultClient"
		set req.Port="443"
	}
	if ( '$data(^[namespace]%git(gituser,repo,"credentials")) ) {
		throw ##class(%Exception.General).%New("git","NoCredentials",,"No git credentials found for repo="_repo)
	} else {
		set creds=^[namespace]%git(gituser,repo,"credentials")
		set req.Username=$list(creds,1)
		set req.Password=$list(creds,2)
	}
	do ..debug("Git HTTP Request to",uc("path")_"?"_uc("query"))
	set sc=req.Get(uc("path")_"?"_uc("query"))
	do ..debug("Git HTTP Response size=",req.HttpResponse.ContentLength)
	return req.HttpResponse
}

/// Pulls artifacts from github into Cache.
/// You can specify a full respository or the path
/// to a file or folder within the respository.
/// Note that only artifacts with the ".cls" or ".mac" extenstion
/// are pulled in.
ClassMethod GitPull(namespace, gituser, repo, path = "") As %Status
{
	do ..ProcessCustomHeaders()
	do ..debug("GitPull",gituser,repo,namespace,path)
	#dim error as %Exception.AbstractException
	if ('##class(%SYS.Namespace).Exists(namespace) ) {
 		return $$$ERROR("Namespace '"_namespace_"' does not exist. Did you try /namespaces?")
 	}
	try {
		do ..git(gituser,repo,namespace,path)
		return $$$OK
	} catch error {
		do error.Log()
		return error.AsStatus()
	}
}

/// Endpoint to store github credentials on the system
/// Maps (gituser,repo) to and set of user/pass credentials.
/// Stores information per namespace in the ^%git global
ClassMethod GitPasswd(namespace, gituser, repo, gitusername, gitpassword) As %Status
{
	do ..ProcessCustomHeaders()
	do ..debug("GitPasswd",namespace,gituser,repo,gituser,gitpassword)
	if ('##class(%SYS.Namespace).Exists(namespace) ) {
 		return $$$ERROR("Namespace '"_namespace_"' does not exist. Try /namespaces")
 	}
	set ^[namespace]%git(gituser,repo,"credentials")=$listbuild(gitusername,gitpassword)
	return $$$OK
}

/// Provides connectivity to github to pull repositories 
/// or files into the system
ClassMethod git(gituser, repo, namespace = {$namespace}, path = "/")
{
	
	#dim resp as %Net.HttpResponse
	set url="https://api.github.com/repos/"
	set gitUser = gituser
	if ( $e(path,1) '= "/" ) { set path="/"_path }
	set rr=url_gitUser_"/"_repo_"/contents"_path
	//write "git("""_rr_""")",!
	set resp=..gitHTTPGet(namespace,gituser,repo,url_gitUser_"/"_repo_"/contents"_path)
	set raw=""
	while ( 'resp.Data.AtEnd ) {
		set raw=raw_resp.Data.Read()
	}
	set sc=##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(raw,,.obj)
	
	if ( obj.%Extends("%ZEN.proxyObject") ) {

			write obj.name
			if ( obj.type="file" ) {
				set contentStream=##class(%Stream.TmpCharacter).%New()
				set contentStream.LineTerminator=$C(10)
				set content = $system.Encryption.Base64Decode( obj.content)
				//zzdump content
				//break
				do contentStream.Write( content  )
				set ext=$zconvert($p(obj.name,".",$l(obj.name,".")),"U")
				if ( ext="CLS" ) {
					
					do ..PostClassFromStream(namespace,obj.name,contentStream)
				} 
				if ( ext="MAC" ) {
					do ..PostMacFromStream(namespace,obj.name,contentStream)
				}
					write " ",contentStream.Size,!
			}
			if ( obj.type="dir" ) {
				do ..git(gituser,repo,namespace,path_obj.name_"/")
				
			}

	} 
	if ( obj.%Extends("%ListOfObjects") ) {
		for i=1:1:obj.Count() {
			set t1=obj.GetAt(i)
			//do obj.GetAt(i).%CopyToArray(.oa)
			//zw oa
			set:t1.type="dir" t1.name=t1.name_"/"
			do ..git(gituser,repo,namespace,path_t1.name)
			
			
			
		}
	}
}

ClassMethod LoadClass(ClassFileName, namespace As %String = "")
{
	if ( namespace="" ) { set namespace=$namespace }
	if (##class(%SYS.Namespace).Exists(namespace) ) {
 			set $namespace=namespace
 	}
	set fs=##class(%Stream.FileCharacter).%New()
	set fs.Filename=ClassFileName
	set classname=$piece(ClassFileName,##class(%File).GetDirectory(ClassFileName),2)
	set sc=##class(%Compiler.UDL.TextServices).SetTextFromStream(namespace,classname,fs)
	if $$$ISERR(sc) {
		write "Compiler Error",!
		do $system.Status.DisplayError(sc)
		$$$ThrowStatus(sc)
	}
}

ClassMethod GetXMLClass(namespace, classname) As %Status
{
	if ( namespace="" ) { set namespace=$namespace }
	if (##class(%SYS.Namespace).Exists(namespace) ) {
 			new $namespace
 			set $namespace=namespace
 	}
 	set classname=..StripExt(classname,"XML")
 	set sc=$system.OBJ.ExportToStream(classname,.stream)
 	if ( $$$ISERR(sc) ) {
	 	do $system.Status.DisplayError(sc)
	 	return $$$OK
 	}
 	if ( $isobject(stream) ) {
 		do stream.OutputToDevice()
 	}
 	return $$$OK
}

/// <p>GET a class or macro routine from the system
/// By default this will return the raw source code.
/// 	</p>
/// <p>You must specify the correct extentsion for the artifact you want
/// in the :path parameter.</p>
/// <p>For example - 
/// Sample.Person.cls
/// Foo.mac</p>
/// <p>If you want the default xml export of an resource 
/// 	append '.xml' to the resource
/// name</p>
/// <p>If :path is emtpy or contins a "*" wildcard, then a list of the 
/// classes in that namespace is returned.</p>
/// For example,
/// <pre>
/// curl -X GET http://server/shed/samples/cls/Sample.*.cls
/// </pre>
/// <p>You can get JSON back by specifing the Http-Accept header
/// as 'application/json' in your request</p>
ClassMethod Get(namespace, artifact) As %Status
{
	do ..ProcessCustomHeaders()
	do ..debug("Get",namespace,artifact)

	set type=..GetExtUpper(artifact)
	if ( type="CLS" ) {
		
		return ..GetClass(namespace,artifact)
	}
	if ( type="MAC" ) {
		return ..GetMac(namespace,artifact)
	}
	if ( type="XML" ) {
		return ..GetXMLClass(namespace,artifact)
	}
	return $$$ERROR("Unkown extenstion '"_type_"'")
}

ClassMethod jsonout() As %Boolean [ CodeMode = expression ]
{
$get(^||shed.http.accept)="application/json"
}

ClassMethod xmlout() As %Boolean [ CodeMode = expression ]
{
$get(^||shed.http.accept)="application/xml"
}

ClassMethod debugon() As %Boolean [ CodeMode = expression ]
{
$get(^||shed.debug)
}

ClassMethod debug(msg...)
{
	quit:'..debugon()
	for i=1:1:msg {
		write msg(i)," "
	}
	write !
}

ClassMethod Post(namespace, artifact) As %Status
{
	do ..ProcessCustomHeaders()
	do ..debug("Post",namespace,artifact)

	set type=..GetExtUpper(artifact)
	if ( type="CLS" ) {
		return ..PostClass(namespace,artifact)
	}
	if ( type="MAC" ) {
		
		return ..PostMac(namespace,artifact)
	}
	return $$$ERROR("Unkown extenstion '"_type_"'")
}

/// Check for any custom headers
/// And sent process-private flags
/// This can turn on debugging, request json content, etc
ClassMethod ProcessCustomHeaders()
{
  
	set ^||shed.http.accept=$Get(%request.CgiEnvs("HTTP_ACCEPT"))
	set ^||shed.debug=$Get(%request.CgiEnvs("HTTP_X_SHED_DEBUG"),0)
	if ( ^||shed.debug  ) {
		write "shed			debug on",!
		zw ^||shed.http.accept
	}
}

XData UrlMap
{
<Routes>
<Route Url="/man" Method="GET" Call="Man"/>

<Route Url="/:namespace/:path" Method="GET" Call="Get" />
<Route Url="/:namespace/:path" Method="POST" Call="Post" />
<Route Url="/:namespace/git/pull/:gituser/:repo/" Method="GET" Call="GitPull" />
<Route Url="/:namespace/git/pull/:gituser/:repo/:path" Method="GET" Call="GitPull" />
<Route Url="/:namespace/git/passwd/:gituser/:repo/:gitusername/:gitpassword" Method="GET" Call="GitPasswd"/>
<!--
<Route Url="/:namespace/cls" Method="GET" Call="GetClass"/>
<Route Url="/:namespace/cls/:classname" Method="GET" Call="GetClass"/>
<Route Url="/:namespace/xmlcls/:classname" Method="GET" Call="GetXMLClass"/>
<Route Url="/:namespace/mac" Method="GET" Call="GetMac"/>
<Route Url="/:namespace/mac/:routine" Method="GET" Call="GetMac"/>
-->

<!--
<Route Url="/:namespace/cls/:classname" Method="POST" Call="PostClass"/>
<Route Url="/:namespace/mac/:routine" Method="POST" Call="PostMac"/>
-->
<Route Url="/namespaces" Method="GET" Call="GetNamespaces"/>
<Route Url="/upgrade" Method="GET" Call="Upgrade"/>

</Routes>
}

Parameter VERSION = "0.0.2";

ClassMethod Logo() As %String
{
	/*
 set logo="             _ .-') _     ('-.   "_$C(10)
 set logo=logo_"            ( (  OO) )  _(  OO)  "_$C(10)
 set logo=logo_" .-'),-----. \     .'_ (,------. "_$C(10)
 set logo=logo_" ( OO'  .-.  ',`'--..._) |  .---' "_$C(10)
 set logo=logo_" /   |  | |  ||  |  \  ' |  |     "_$C(10)
 set logo=logo_" \_) |  |\|  ||  |   ' |(|  '--.  "_$C(10)
 set logo=logo_"   \ |  | |  ||  |   / : |  .--'  "_$C(10)
 set logo=logo_"    `'  '-'  '|  '--'  / |  `---. "_$C(10)
 set logo=logo_"      `-----' `-------'  `------'"_$C(10)
 return logo
 	*/
 set $list(logo,1)=" _|_  _  _|"
 set $list(logo,2)="_\| |(/_(_|"
 return $listtostring(logo,$C(10))_$C(10)
}

/// Returns version info and API documentation
ClassMethod Man() As %Status
{
	
    if ( $data(%request) ) {
	 	
	 	if %request.UserAgent["curl" {
		 	set plain=1
		 	set LF=$C(10)
		 	set:$data(%response) %response.ContentType="text/text"
	 	} else {
		 	set plain=0
	 		set %response.ContentType="text/html"
	 		set LF="<br/>"
	 		&html<
	 		<!DOCTYPE html>
			<html lang="en">
			<head>
				<title>shed</title>
				<link href="http://developer.github.com/shared/css/documentation.css" media="screen" rel="stylesheet" type="text/css">
	 		</head>
	 		<body class="api">
	 		<div id="wrapper">
      		<div class="content">
	 		>
	 	}   
    }
    w:'plain "<pre>"
	Write ..Logo(),LF
	w:'plain "</pre>"
	w:'plain "<h2>" 
	Write "/shed",LF
	w:'plain "</h2>" 
	w "Version:",..#VERSION,LF
	set uu="http://github.com/"_..#SHEDGITUSER_"/"_..#SHEDGITREPO
	w:'plain "<a href="""_uu_""">",uu,"</a>",LF
	w:plain uu,LF
	
	w:'plain "<p>"
	Write "shed is a REST based interface for managing InterSystems code artifacts.",LF
	Write "It currently supports Cache classes, .mac code and integration with github.",LF
	Write "Responses from shed come in only 2 flavors: source code or errors.",LF
	Write "Client driver developers should refer to the following API reference.",LF
	w:'plain "</p>"
	Write LF,"API Reference",LF
	Write:plain "-------------",LF
	write:'plain "<hr/>"
	// Load up the UrlMap and write out the comments for each method that is mapped
	set tClassName=..%ClassName(1)
	Set tCompiledClass=##class(%Dictionary.CompiledClass).%OpenId(tClassName,,.tSC)
    Set tIndex = tCompiledClass.XDatas.FindObjectId(tClassName_"||UrlMap")
    If tIndex="" {
	    Write "ERROR! Cannot find UrlMap XData to generate documention",!
		Write "Try the /upgrade endpoint!",!
	    return $$$ERROR($$$XDataBlockMissing,tClassName,"UrlMap") 
    }
    #; Get XDATA as stream
    Set tStream = tCompiledClass.XDatas.GetAt(tIndex).Data
    Do tStream.Rewind()
            
    #; Create an XML import handler ( use the internal handler )
    Set tHandler=##class(%XML.ImportHandler).%New("CacheTemp",$$$IntHandler) 
        
    #; Create the Entity Resolver
    Set tResolver=##class(%XML.SAX.XDataEntityResolver).%New(tClassName)
        
    #; Parse the XML data in the specfied stream
    Set tSC=##Class(%XML.SAX.Parser).ParseStream(tStream,tHandler,tResolver,,,"Schema")
    If $$$ISERR(tSC) Quit       
        
    #; Copy tree because handler will delete it's copy when it goes out of scope
    Merge tMap=^CacheTemp(tHandler.Tree)
    //zw tMap
    //break
    If $Data(tMap("error"))||$Data(tMap("warning")) {
         Write "ERROR! Invalid UrlMap XData found unable to generate documention",!
		Write "Try the /upgrade endpoint!",!
    	return $$$ERROR($$$InvalidDispatchMap)
    }
            
    #; Walk the xml and generate the routing map
    Set tChild="",tCounter=0 For {
    	Set tChild=$Order(tMap(1,"c",tChild)) If tChild="" Quit
        Set tArgCount=0,tUrl=tMap(tChild,"a","Url")
        /*
        For tI=2:1:$Length(tUrl,"/") {
        	Set tPiece=$Piece(tUrl,"/",tI)
            If $Extract(tPiece)=":" {
            	Set tPattern=tPattern_"/([^/]+)"
            } else {
            	Set tPattern=tPattern_"/"_tPiece
            }
        }
         */     
        Set tCounter=$Increment(tCounter),tMethod=tMap(tChild,"a","Method"),tDispatch=tMap(tChild,"a","Call")
        w:'plain "<pre>"
        write tMethod," ",tUrl,LF
        w:'plain "</pre>"
        
        set methodi=tCompiledClass.Methods.FindObjectId(tClassName_"||"_tDispatch)
        set method=tCompiledClass.Methods.GetAt(methodi)
        w:'plain "<p>"
        write " ",method.Description,LF
        w:'plain "</p>"
        write LF
        //$$$GENERATE(" If pIndex="_tCounter_" Quit $ListBuild("""_tPattern_""","""_tMethod_""","""_tDispatch_""")")
   }
      Write "$ZV=",$ZV,LF      
	if ( 'plain ) {
		
	&html<
	</div></div>
		</body>
		</html>
	>	
		
	}
	Quit $$$OK
}

/// Upgrades the version of shed on this system
/// Pulls update from github
ClassMethod Upgrade() As %Status
{
	return ..GitPull($namespace,..#SHEDGITUSER,..#SHEDGITREPO,..#SHEDSERVERCLS)
}

Parameter SHEDCSPAPP = "/shed";

Parameter SHEDGITUSER = "jasonmimick";

Parameter SHEDGITREPO = "shed";

Parameter SHEDSERVERCLS = "shed.Server.cls";

/// Setup a csp app for the Ordinary Development Environment
/// This class should be loaded into %SYS
/// CSP app is /shed
ClassMethod Bootstrap() As %Status [ CodeMode = objectgenerator, ServerOnly = 1 ]
{
	Write !,"shed bootstraping",!
	if ( $namespace'="%SYS" ) {
		return $$$ERROR("shed is only supported in the %SYS namespace!")
	}
	
	Set cspapp=..#SHEDCSPAPP
	Set appExists = ##class(Security.Applications).Exists(cspapp,.app,.status)
	if ( appExists ) {
		Write "shed bootstrap nothing to do "_cspapp_" exists.",!
		goto BootDone
	}
	//return:$$$ISERR(status) status
	set properties("AutheEnabled")=8224
	set properties("DispatchClass")=%class.Name
	set properties("Description")="REST endpoint for shed see: http://github.com/jasonmimick/shed"
	set properties("NameSpace")="%SYS"
	set properties("Name")=cspapp
	set status=##class(Security.Applications).Create(cspapp,.properties)
	return:$$$ISERR(status) status
	
BootDone
	Do %code.WriteLine(" // This is a dummy - used for compile-time side-effects")
	
	Do %code.WriteLine(" Quit")
    Quit $$$OK
}

/// Returns raw source code for a .mac macro routine
ClassMethod GetMac(namespace As %String, routine As %String = "") As %Status
{
		if (##class(%SYS.Namespace).Exists(namespace) ) {
			new $namespace
 			set $namespace=namespace
 		}
 		if ( ##class(%RoutineMgr).Exists(routine ) ) {
 			set rm=##class(%RoutineMgr).%New(routine)
 			do rm.Code.OutputToDevice()
 		} else {		// dump matching routines
 			// ^rINDEX("routine","MAC")=$lb(timestamp....)
 			if ( routine'="" ) {
 				set rp=$listfromstring(routine,".")
 				set routine=..StripExt(routine,"MAC")
 		
 			}
 			set rou=$order(^rINDEX(routine)),done=0
 			while ( 'done ) {
	 			if ( $data(^rINDEX(rou,"MAC")) ) {
		 			write rou," ",$list(^rINDEX(rou,"MAC"),1),!
	 			}
	 			set rou=$order(^rINDEX(rou))
 				set:rou'[routine done=1
 				set:rou="" done=1
 			}
 		}
 		quit $$$OK
}

ClassMethod PostMac(namespace As %String, routine As %String) As %Status
{
	return ..PostMacFromStream(namespace,routine,%request.Content)
}

ClassMethod PostMacFromStream(namespace, routine, stream) As %Status
{
	    // Detection for line end - either (13,10) or $c(10)!!!!
	    if ( $length(stream.ReadLine())=stream.Size ) {
	    	set stream.LineTerminator=$C(10)
	    }
	    do stream.Rewind()

		//write "routine=",routine,!,!
		
 		if (##class(%SYS.Namespace).Exists(namespace) ) {
 			new $namespace
 			set $namespace=namespace
 		}
 		
 		
 		set rm=##class(%RoutineMgr).%New(routine)
 		while ( 'stream.AtEnd ) {
 			do rm.Code.WriteLine( stream.ReadLine() )
 		}
		do rm.%Save()
    	do rm.Compile("k-d")
 		
 		quit $$$OK
}

/// Pushes a class into the system.
/// For example,
/// <pre class="headers">
/// $ curl -X POST \
/// > --data-binary @Hello.World.cls \
/// > --header "Content-Type:text/plain" \
/// > http://_system:SYS@sandbox.healthshare.us:57772/shed/user/cls/Hello.World
/// </pre>
ClassMethod PostClass(namespace As %String, classname As %String) As %Status
{
	return ..PostClassFromStream(namespace,classname,%request.Content)
}

ClassMethod PostClassFromStream(namespace As %String, classname As %String, stream As %Stream.Object) As %Status
{
	
	 #dim tStream As %Stream.Character
    
    Try {
	    
	    // Detection for line end - either (13,10) or $c(10)!!!!
	   	set firstLine=stream.ReadLine()
	   	do stream.Rewind()
	    if ( $length(firstLine)=stream.Size ) {
	    	set stream.LineTerminator=$C(10)
	    }
		if ( $ascii($extract(firstLine,$length(firstLine)))=13 ) {
			set stream.LineTerminator=$C(13,10)
		}
	    set sc=##class(%Compiler.UDL.TextServices).SetTextFromStream(namespace,classname,stream)
		if $$$ISERR(sc) {
			write "Compiler Error",!
			do $system.Status.DisplayError(sc)
			$$$ThrowStatus(sc)
		}
		
		do {
			new $namespace
			set $namespace=namespace
			if (..debugon()) {
				set flags="ckd"
			} else {
				set flags="ck-d"
			}
			do $system.OBJ.Compile(..StripExt(classname,"CLS"),flags)
		} while (0)
		
	} Catch (e) {
        Set tSC=e.AsStatus()
        Write e.DisplayString()
        return tSC
    }
    return $$$OK
}

ClassMethod GetExtUpper(name) As %String
{
	set ap=$listfromstring(name,".")
	return $zconvert($list(ap,$listlength(ap)),"U")
}

ClassMethod StripExt(name, ext) As %String
{
	set nl=$listfromstring(name,".")
	set e=$zconvert( $list(nl,$listlength(nl)),"U")
	if ( e=ext ) {
		set nll=$list(nl,1,$ll(nl)-1)
	 	return $listtostring(nll,".")
	}
	return name
}

/// This method returns the source code for the named cache class
/// Or, if no classname is passed in, then returns a list of the 
/// classes in that namespace, wildcard (*) searches are supported
/// For example,
/// <pre>
/// curl -X GET http://server/shed/samples/cls/Sample.*
/// </pre>
/// 
ClassMethod GetClass(pNamespace As %String, pClassname As %String = "*") As %Status
{
    #dim tSC As %Status = $$$OK
    #dim e As %Exception.AbstractException
    
    #dim tStream As %Stream.Character
    
    Try {
	     set pClassname=..StripExt(pClassname,"CLS")
	    // Check if valid classname - 
	    // if not, treat as a query to return classnames which match
	    // along with last update timestamp
	    //if ( '##class(%Dictionary.CacheClassname).IsValid(pClassname) ) {
	
		if ( pClassname["*" ) {
			if (##class(%SYS.Namespace).Exists(pNamespace) ) {
 				set $namespace=pNamespace
 			}
			set pClassname=$replace(pClassname,"*","%")
			 set stmt=##class(%SQL.Statement).%New()
			 // TODO - filter out % classes!
		 	set sc=stmt.%Prepare("select Name,TimeChanged from %Dictionary.ClassDefinition where Name Like ?")
		 	//write "pClassname=",pClassname,!
		 	set result=stmt.%Execute(pClassname)
		 	//do result.%Display()
		 	If ..jsonout() {
        		Set %response.ContentType="application/json"
				set list=##class(%ListOfObjects).%New()
			}
		 	while ( result.%Next() ) {
			 	
			 	If ..jsonout() {
        			set po=##class(%ZEN.proxyObject).%New()
        			set po.name=result.%Get("Name")
        			set po.timeChanged=$zdt(result.%Get("TimeChanged"),3)
        			do list.Insert(po)	
        	 	} else {
				 	write result.%Get("Name")," ",$zdt(result.%Get("TimeChanged")),!
			 	}
		 	}
			If ..jsonout() {
				do ##class(%ZEN.Auxiliary.jsonProvider).%ObjectToJSON(list)
			}
		 	return $$$OK   
	    }
	   
	    if ( ..xmlout() ) {
					    
			return ..GetXMLClass(pNamespace,pClassname_".cls")   
	    }
	    
        Set tSC=##class(%Compiler.UDL.TextServices).GetTextAsStream(pNamespace,pClassname,.tStream)
        If $$$ISERR(tSC) Quit
        
        #; Looks good
        if ( '..jsonout() ) {
	        Do tStream.OutputToDevice()
        } else {
	        set code=""
	        while ( 'tStream.AtEnd ) {
		        set code=code_tStream.Read()
	        }
	        set base64source=$system.Encryption.Base64Encode(code)
	     	set po=##class(%ZEN.proxyObject).%New()
	     	set po.name=pClassname
	     	set po.content=base64source
	     	do po.%ToJSON() 
        }    
    } Catch (e) {
        Set tSC=e.AsStatus()
    }
    
    Quit tSC
}

/// This method returns a list of namespaces for this server
ClassMethod GetNamespaces() As %Status
{
	do ..ProcessCustomHeaders()
    #dim tSC As %Status = $$$OK
    #dim tList,tNS,tFilteredList,tValue As %String
    
    #; Get the list of namespaces
    Do List^%SYS.NAMESPACE(.tList)
    Set tNS="" For  {
    
        Set tNS=$Order(tList(tNS),1,tValue) If tNS="" Quit
    
        #; Only want namespaces which are enabled and are not remote
        If $List(tValue,1)=1&&$List(tValue,2)=0 {
            Set tFilteredList(tNS)=""
        }
    }
    
    #; If we have been asked for json
    //If $Get(%request.CgiEnvs("HTTP_ACCEPT"))="application/json" {
	If ..jsonout() {
        
        #; Set the response header to JSON
        Set %response.ContentType="application/json"
        
        #; Create a JSON proxy
        Set tProxy = ##class(%ZEN.proxyObject).%New()
        
        #; And a list to hold the namespaces
        Set tList=##class(%Library.ListOfDataTypes).%New()
        
        #; Add the namespaces to the list
        Set tNS="" For  {
            Set tNS=$Order(tFilteredList(tNS)) If tNS="" Quit
            Do tList.Insert(tNS)
        }
        
        #; Set the namespace property
        Set tProxy.namespaces=tList
        
        #; Output the JSON
        Do tProxy.%ToJSON()
        
    } else {
        
        Set tNS="" For  {
            Set tNS=$Order(tFilteredList(tNS)) If tNS="" Quit
            Write tNS,!
        }
    }
    Quit tSC
}

}

