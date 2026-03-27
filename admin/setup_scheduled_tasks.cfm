<!--- setup_scheduled_tasks.cfm - Run once to register scheduled tasks --->
<cfset baseURL  = "https://#CGI.SERVER_NAME#">
<cfset taskURL  = "#baseURL#/DoCMRoomReservation/cfcs/scheduledAPI.cfc?method=sendPendingRequestReminder">
<cfset adminURL = "#baseURL#/CFIDE/administrator/scheduler/scheduledtasks.cfm">

<cfschedule
    action="update"
    task="PendingRequestReminderHourly"
    operation="HTTPRequest"
    url="#taskURL#"
    startDate="03/26/2026"
    startTime="04:00 PM"
    interval="3600"
    requestTimeOut="120"
    resolveURL="true"
    publish="false"
>

<cfoutput>
    <h2>Scheduled Task Registered</h2>
    <p><strong>Task:</strong> PendingRequestReminderHourly</p>
    <p><strong>Runs:</strong> Every 1 hour (3600 seconds)</p>
    <p><strong>URL:</strong> #taskURL#</p>
    <p><strong>Start Date/Time:</strong> 03/26/2026 at 4:00 PM</p>
    <p style="color:green;"><strong>&##10003; Task successfully scheduled.</strong></p>
    <p>You can verify it in the <a href="#adminURL#" target="_blank">ColdFusion Administrator &rarr; Scheduled Tasks</a>.</p>
</cfoutput>
