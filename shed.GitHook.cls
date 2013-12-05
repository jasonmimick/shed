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
	write "GitHook namespace=",namespace,!
    //kill ^gitdata
    write "%request.Content=",%request.Content,!
    set i=$i(^gitdata)
    set ^gitdata(i,"ContentType")=%request.ContentType
    merge ^gitdata(i,"Data")=%request.Data
    merge ^gitdata(i,"CgiEnvs")=%request.CgiEnvs
    
	set event = %request.CgiEnvs("HTTP_X_GITHUB_EVENT")
	set delivery = %request.CgiEnvs("HTTP_X_GITHUB_DELIVERY")
	set payload = %request.Get("payload")  
	set sysEvent = "github"_event
	set created = $system.Event.Create(sysEvent)
	if ( 'created ) {
		do LOG^%ETN("Unable to create $system.Event with resource name ='"_sysEvent_"'")
		quit '$$$OK
	}
	set $$$gitHookGlobal(delivery)=$lb(event,$ZTS,payload)
	set $$$gitHookGlobal(event,delivery)=""	// index on event
	set sig=$system.Event.Signal(sysEvent,delivery)
    return $$$OK
}

}

