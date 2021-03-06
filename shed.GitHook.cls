Class shed.GitHook Extends %CSP.REST
{

XData UrlMap
{
<Routes>
	<Route Url="/hook/:namespace" Method="POST" Call="Hook" />
	</Routes>
}

ClassMethod Hook(namespace As %String = {$namespace}) As %Status
{
	#define gitHookGlobal	^github.hook
    //kill ^gitdata
    set i=$i(^gitdata)
    set ^gitdata(i,"ContentType")=%request.ContentType
    merge ^gitdata(i,"Data")=%request.Data
    merge ^gitdata(i,"CgiEnvs")=%request.CgiEnvs
    
	set event = %request.CgiEnvs("HTTP_X_GITHUB_EVENT")
	set delivery = %request.CgiEnvs("HTTP_X_GITHUB_DELIVERY")
	set payload = %request.Get("payload")  
	set sysEvent = "github"_event
	set created = $system.Event.Create(sysEvent)
	// if it was 'created, then it already exists
	set $$$gitHookGlobal(delivery)=$lb(event,$ZTS,payload)
	set $$$gitHookGlobal(event,delivery)=""	// index on event
	set sig=$system.Event.Signal(sysEvent,delivery)
    return $$$OK
}

ClassMethod pull(ns as %String,payload as %String)
{
	set sc=##class(%ZEN.Auxiliary.jsonProvider).%ConvertJSONToObject(payload,,.obj)
	zw obj
	set repo=obj.repository.name
	zw repo
	set owner=obj.repository.owner.name
	zw owner
	try {
		//set sc=##class(shed.Server).GitPull(ns,user,repo)
	} catch (error) {
		break
	}
}
}

