<cfoutput>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Booking Confirmation</title>
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
        .booking-details {
            background-color: ##f8f9fa;
            padding: 20px;
            border-radius: 5px;
            margin: 20px 0;
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
        <img src="#application.config.baseUrl#/assets/images/mdacc-logo.png" alt="MD Anderson Logo" class="logo">
        <h1>Booking Confirmation</h1>
    </div>

    <p>Dear #args.user.firstName# #args.user.lastName#,</p>

    <p>Your room booking has been confirmed. Here are the details:</p>

    <div class="booking-details">
        <p><strong>Room:</strong> #args.booking.roomName#</p>
        <p><strong>Date:</strong> #dateFormat(args.booking.bookingDate, "mmmm d, yyyy")#</p>
        <p><strong>Time:</strong> #timeFormat(args.booking.startTime, "h:mm tt")# - #timeFormat(args.booking.endTime, "h:mm tt")#</p>
        <p><strong>Duration:</strong> #args.booking.duration# minutes</p>
        <p><strong>Building:</strong> #args.booking.building#</p>
        <p><strong>Floor:</strong> #args.booking.floor#</p>
    </div>

    <p>You can manage your booking by logging into your account at <a href="#application.config.baseUrl#">#application.config.baseUrl#</a></p>

    <p>If you need to cancel or modify your booking, please do so at least 24 hours in advance.</p>

    <div class="footer">
        <p>This is an automated message. Please do not reply to this email.</p>
        <p>MD Anderson Cancer Center - Room Reservation System</p>
    </div>
</body>
</html>
</cfoutput>
