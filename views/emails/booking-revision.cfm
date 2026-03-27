<cfoutput>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Booking Revision Notice</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            color: ##333;
            max-width: 600px;
            margin: 0 auto;
            padding: 20px;
        }
        .header {
            text-align: center;
            margin-bottom: 30px;
        }
        .logo {
            max-width: 200px;
            margin-bottom: 20px;
        }
        .alert-info {
            background-color: ##d1ecf1;
            border: 1px solid ##bee5eb;
            color: ##0c5460;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .booking-details {
            background-color: ##f8f9fa;
            padding: 20px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .comparison-table {
            width: 100%;
            margin: 20px 0;
            border-collapse: collapse;
        }
        .comparison-table th {
            background-color: ##003C7F;
            color: white;
            padding: 10px;
            text-align: left;
        }
        .comparison-table td {
            padding: 10px;
            border: 1px solid ##ddd;
        }
        .comparison-table tr:nth-child(even) {
            background-color: ##f2f2f2;
        }
        .original-value {
            color: ##666;
            text-decoration: line-through;
        }
        .revised-value {
            color: ##28a745;
            font-weight: bold;
        }
        .revision-badge {
            background-color: ##ffc107;
            color: ##000;
            padding: 5px 10px;
            border-radius: 3px;
            font-size: 12px;
            font-weight: bold;
            display: inline-block;
            margin-bottom: 10px;
        }
        .action-buttons {
            text-align: center;
            margin: 30px 0;
        }
        .btn {
            display: inline-block;
            padding: 12px 24px;
            margin: 5px;
            text-decoration: none;
            border-radius: 5px;
            font-weight: bold;
        }
        .btn-primary {
            background-color: ##003C7F;
            color: white;
        }
        .btn-danger {
            background-color: ##dc3545;
            color: white;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid ##ddd;
            font-size: 12px;
            color: ##666;
        }
    </style>
</head>
<body>
    <div class="header">
        <img src="#application.config.baseUrl#/assets/images/mda-logo-black.png" alt="MD Anderson Logo" class="logo">
        <h1>Booking Revision Notice</h1>
    </div>

    <p>Dear #args.user.firstName# #args.user.lastName#,</p>

    <div class="alert-info">
        <strong>Important:</strong> Your room booking has been revised by #args.modifiedBy.firstName# #args.modifiedBy.lastName#.
        <div class="revision-badge">Revision ###args.booking.revisionNumber#</div>
    </div>

    <p>The following changes have been made to your booking:</p>

    <table class="comparison-table">
        <thead>
            <tr>
                <th>Field</th>
                <th>Original Value</th>
                <th>New Value</th>
            </tr>
        </thead>
        <tbody>
            <cfif args.original.roomId NEQ args.booking.roomId>
            <tr>
                <td><strong>Room</strong></td>
                <td class="original-value">#args.original.roomName#</td>
                <td class="revised-value">#args.booking.roomName#</td>
            </tr>
            </cfif>

            <cfif dateCompare(args.original.startTime, args.booking.startTime) NEQ 0>
            <tr>
                <td><strong>Start Time</strong></td>
                <td class="original-value">#dateFormat(args.original.startTime, "mmmm d, yyyy")# at #timeFormat(args.original.startTime, "h:mm tt")#</td>
                <td class="revised-value">#dateFormat(args.booking.startTime, "mmmm d, yyyy")# at #timeFormat(args.booking.startTime, "h:mm tt")#</td>
            </tr>
            </cfif>

            <cfif dateCompare(args.original.endTime, args.booking.endTime) NEQ 0>
            <tr>
                <td><strong>End Time</strong></td>
                <td class="original-value">#dateFormat(args.original.endTime, "mmmm d, yyyy")# at #timeFormat(args.original.endTime, "h:mm tt")#</td>
                <td class="revised-value">#dateFormat(args.booking.endTime, "mmmm d, yyyy")# at #timeFormat(args.booking.endTime, "h:mm tt")#</td>
            </tr>
            </cfif>

            <cfif (args.original.comments ?: "") NEQ (args.booking.comments ?: "")>
            <tr>
                <td><strong>Meeting Title</strong></td>
                <td class="original-value"><cfif len(trim(args.original.comments ?: ""))>#args.original.comments#<cfelse><em>No title</em></cfif></td>
                <td class="revised-value"><cfif len(trim(args.booking.comments ?: ""))>#args.booking.comments#<cfelse><em>No title</em></cfif></td>
            </tr>
            </cfif>
        </tbody>
    </table>

    <div class="booking-details">
        <h3>Current Booking Details:</h3>
        <p><strong>Booking ID:</strong> #args.booking.bookingId#</p>
        <p><strong>Room:</strong> #args.booking.roomName#</p>
        <p><strong>Location:</strong> #args.booking.building# - Room #args.booking.roomNumber#</p>
        <p><strong>Date:</strong> #dateFormat(args.booking.startTime, "mmmm d, yyyy")#</p>
        <p><strong>Time:</strong> #timeFormat(args.booking.startTime, "h:mm tt")# - #timeFormat(args.booking.endTime, "h:mm tt")#</p>
        <cfif len(trim(args.booking.comments ?: ""))>
        <p><strong>Meeting Title:</strong> #args.booking.comments#</p>
        </cfif>
        <p><strong>Status:</strong> #args.booking.status#</p>
        <p><strong>Revision ##:</strong> #args.booking.revisionNumber#</p>
        <p><strong>Last Modified:</strong> #dateFormat(args.booking.revisionDate, "mmmm d, yyyy")# at #timeFormat(args.booking.revisionDate, "h:mm tt")#</p>
        <p><strong>Modified By:</strong> #args.modifiedBy.firstName# #args.modifiedBy.lastName#</p>
    </div>

    <div class="action-buttons">
        <a href="#application.config.baseUrl#/index.html" class="btn btn-primary">View Booking</a>
        <a href="#application.config.baseUrl#/index.html?cancel=#args.booking.bookingId#" class="btn btn-danger">Cancel Booking</a>
    </div>

    <p><strong>Note:</strong> If you have any questions about this revision or did not authorize this change, please contact the person who made the revision or the Room Reservation administrator.</p>

    <p>You can view your complete booking history and revision timeline by logging into your account at <a href="#application.config.baseUrl#">#application.config.baseUrl#</a></p>

    <div class="footer">
        <p>This is an automated message. Please do not reply to this email.</p>
        <p>MD Anderson Cancer Center - Room Reservation System</p>
        <p>For support, please contact the IT Help Desk.</p>
    </div>
</body>
</html>
</cfoutput>
