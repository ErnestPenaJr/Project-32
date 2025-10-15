<cfoutput>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Booking Approval Required</title>
    <style>
        body {
            font-family: 'Segoe UI', Arial, sans-serif;
            background-color: ##f4f6f9;
            color: ##1f2933;
            margin: 0;
            padding: 0;
        }
        .container {
            max-width: 640px;
            margin: 0 auto;
            padding: 32px 24px;
            background-color: ##ffffff;
            border-radius: 12px;
            box-shadow: 0 12px 32px rgba(15, 23, 42, 0.08);
        }
        .header {
            text-align: center;
            margin-bottom: 28px;
        }
        .badge {
            display: inline-block;
            padding: 6px 14px;
            border-radius: 999px;
            font-size: 12px;
            font-weight: 600;
            letter-spacing: 0.04em;
            text-transform: uppercase;
            background: linear-gradient(135deg, ##0d6efd, ##60a5fa);
            color: ##ffffff;
        }
        h1 {
            margin: 16px 0 8px;
            font-size: 24px;
            color: ##0b1d51;
        }
        .intro {
            font-size: 15px;
            line-height: 1.7;
            margin-bottom: 24px;
        }
        .details {
            background-color: ##f8fbff;
            border-radius: 12px;
            padding: 24px;
            margin-bottom: 28px;
            border: 1px solid rgba(13, 110, 253, 0.12);
        }
        .details h2 {
            margin: 0 0 16px;
            font-size: 18px;
            color: ##0d47a1;
        }
        .details-list {
            list-style: none;
            padding: 0;
            margin: 0;
        }
        .details-list li {
            margin-bottom: 10px;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        .details-list span.label {
            min-width: 120px;
            font-weight: 600;
            color: ##1f2937;
        }
        .details-list span.value {
            color: ##334155;
        }
        .actions {
            text-align: center;
            margin-bottom: 28px;
        }
        .button {
            display: inline-block;
            padding: 12px 20px;
            margin: 6px;
            border-radius: 8px;
            font-weight: 600;
            text-decoration: none;
            color: ##ffffff;
            transition: transform 0.2s ease, box-shadow 0.2s ease;
        }
        .button:hover {
            transform: translateY(-2px);
            box-shadow: 0 12px 24px rgba(59, 130, 246, 0.18);
        }
        .button-approve {
            background: linear-gradient(135deg, ##2563eb, ##1d4ed8);
        }
        .button-reject {
            background: linear-gradient(135deg, ##dc2626, ##b91c1c);
        }
        .secondary-link {
            display: inline-block;
            margin-top: 16px;
            color: ##2563eb;
            font-weight: 600;
            text-decoration: none;
        }
        .footer {
            margin-top: 32px;
            text-align: center;
            font-size: 13px;
            color: ##6b7280;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <span class="badge">Pending Approval</span>
            <h1>Action Required: Review Booking Request</h1>
        </div>

        <p class="intro">
            Hello #HTMLEditFormat(args.admin.FIRST_NAME)#,#chr(10)#<br>
            You have a new booking request awaiting your review. Please evaluate the details below and choose an action.
        </p>

        <div class="details">
            <h2>Booking Summary</h2>
            <ul class="details-list">
                <li>
                    <span class="label">Requester</span>
                    <span class="value">#HTMLEditFormat(args.booking.requesterName)# (#HTMLEditFormat(args.booking.requesterEmail)#)</span>
                </li>
                <li>
                    <span class="label">Room</span>
                    <span class="value">#HTMLEditFormat(args.booking.roomName)# (#HTMLEditFormat(args.booking.location)#)</span>
                </li>
                <li>
                    <span class="label">Starts</span>
                    <span class="value">#DateFormat(args.booking.startTime, "mmmm dd, yyyy")# at #TimeFormat(args.booking.startTime, "h:mm tt")#</span>
                </li>
                <li>
                    <span class="label">Ends</span>
                    <span class="value">#DateFormat(args.booking.endTime, "mmmm dd, yyyy")# at #TimeFormat(args.booking.endTime, "h:mm tt")#</span>
                </li>
                <cfif structKeyExists(args.booking, "meetingTitle") AND len(trim(args.booking.meetingTitle))>
                    <li>
                        <span class="label">Meeting Title</span>
                        <span class="value">#HTMLEditFormat(args.booking.meetingTitle)#</span>
                    </li>
                </cfif>
                <li>
                    <span class="label">Booking ID</span>
                    <span class="value">#args.booking.bookingId#</span>
                </li>
            </ul>
        </div>

        <div class="actions">
            <a href="#args.approveUrl#" class="button button-approve" target="_blank">Approve Request</a>
            <a href="#args.rejectUrl#" class="button button-reject" target="_blank">Reject Request</a>
            <div>
                <a href="#args.detailUrl#" class="secondary-link" target="_blank">View full booking details</a>
            </div>
        </div>

        <p class="intro" style="margin-bottom: 0;">
            Thank you for helping us keep the DoCM room schedule accurate and responsive.
        </p>

        <div class="footer">
            <p>This message was sent by the DoCM Room Reservation System.</p>
            <p>If you no longer wish to receive immediate approval notifications, update your preferences in the admin portal.</p>
        </div>
    </div>
</body>
</html>
</cfoutput>
