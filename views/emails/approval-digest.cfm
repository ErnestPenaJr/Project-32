<cfoutput>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Pending Approval Digest</title>
    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            background-color: ##f5f7fa;
            color: ##1f2937;
            margin: 0;
            padding: 0;
        }
        .container {
            max-width: 720px;
            margin: 0 auto;
            padding: 32px 24px;
            background-color: ##ffffff;
            border-radius: 14px;
            box-shadow: 0 20px 48px rgba(15, 23, 42, 0.12);
        }
        .header {
            text-align: center;
            margin-bottom: 28px;
        }
        .badge {
            display: inline-block;
            padding: 6px 16px;
            border-radius: 999px;
            background: linear-gradient(135deg, ##0891b2, ##2563eb);
            color: ##ffffff;
            font-size: 12px;
            font-weight: 600;
            letter-spacing: 0.05em;
            text-transform: uppercase;
        }
        h1 {
            margin: 18px 0 10px;
            font-size: 24px;
            color: ##0f172a;
        }
        .subheading {
            color: ##475569;
            font-size: 14px;
            margin-bottom: 32px;
        }
        .card {
            border-radius: 12px;
            border: 1px solid rgba(15, 118, 110, 0.16);
            padding: 20px 24px;
            margin-bottom: 20px;
            background: linear-gradient(145deg, ##f8fffe 0%, ##ffffff 100%);
        }
        .card h2 {
            margin: 0 0 16px;
            font-size: 18px;
            color: ##0f766e;
        }
        .meta {
            margin-bottom: 12px;
            font-size: 13px;
            color: ##475569;
        }
        .meta span {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            margin-right: 12px;
        }
        .list {
            list-style: none;
            padding: 0;
            margin: 0;
        }
        .list li {
            display: flex;
            justify-content: space-between;
            gap: 12px;
            padding: 12px 0;
            border-bottom: 1px dashed rgba(14, 116, 144, 0.18);
        }
        .list li:last-child {
            border-bottom: none;
        }
        .label {
            font-weight: 600;
            color: ##0f172a;
            min-width: 130px;
        }
        .value {
            color: ##1f2937;
            flex: 1;
        }
        .cta {
            margin-top: 16px;
            text-align: right;
        }
        .button {
            display: inline-block;
            padding: 10px 18px;
            border-radius: 8px;
            background: linear-gradient(135deg, ##0f766e, ##0d9488);
            color: ##ffffff;
            font-weight: 600;
            text-decoration: none;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        .button:hover {
            transform: translateY(-2px);
            box-shadow: 0 18px 36px rgba(13, 148, 136, 0.22);
        }
        .footer {
            margin-top: 36px;
            text-align: center;
            font-size: 13px;
            color: ##64748b;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <span class="badge">Daily Digest</span>
            <h1>Pending Booking Approvals</h1>
            <div class="subheading">
                Summary generated on #DateFormat(args.runDate, "mmmm dd, yyyy")# at #TimeFormat(args.runDate, "h:mm tt")#
            </div>
        </div>

        <cfif arrayLen(args.pendingApprovals) EQ 0>
            <p>There are currently no pending approvals. Great job staying on top of requests!</p>
        <cfelse>
            <cfloop array="#args.pendingApprovals#" index="item">
                <div class="card">
                    <h2>#HTMLEditFormat(item.roomName)#</h2>
                    <div class="meta">
                        <span>Requester: <strong>#HTMLEditFormat(item.requesterName)#</strong></span>
                        <span>Submitted: <strong>#DateFormat(item.submittedAt, "mmm dd")#</strong></span>
                    </div>
                    <ul class="list">
                        <li>
                            <span class="label">Schedule</span>
                            <span class="value">#DateFormat(item.startTime, "mmm dd, yyyy")# · #TimeFormat(item.startTime, "h:mm tt")# – #TimeFormat(item.endTime, "h:mm tt")#</span>
                        </li>
                        <li>
                            <span class="label">Location</span>
                            <span class="value">#HTMLEditFormat(item.location)#</span>
                        </li>
                        <cfif structKeyExists(item, "meetingTitle") AND len(trim(item.meetingTitle))>
                            <li>
                                <span class="label">Meeting Title</span>
                                <span class="value">#HTMLEditFormat(item.meetingTitle)#</span>
                            </li>
                        </cfif>
                        <li>
                            <span class="label">Booking ID</span>
                            <span class="value">#item.bookingId#</span>
                        </li>
                        <cfif structKeyExists(item, "ageHours")>
                            <li>
                                <span class="label">Age</span>
                                <span class="value">#NumberFormat(item.ageHours, "9.9")# hours pending</span>
                            </li>
                        </cfif>
                    </ul>
                    <div class="cta">
                        <a href="#args.detailBaseUrl#?bookingId=#item.bookingId#" class="button" target="_blank">Review Request</a>
                    </div>
                </div>
            </cfloop>
        </cfif>

        <div class="footer">
            <p>You are receiving this digest because daily approval summaries are enabled in your notification preferences.</p>
            <p>Adjust timing or disable digests in the admin notification settings page.</p>
        </div>
    </div>
</body>
</html>
</cfoutput>
