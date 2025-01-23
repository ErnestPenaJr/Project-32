<cfoutput>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Password Reset Request</title>
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
        .reset-button {
            display: inline-block;
            background-color: ##006BA6;
            color: white;
            padding: 12px 24px;
            text-decoration: none;
            border-radius: 5px;
            margin: 20px 0;
        }
        .reset-button:hover {
            background-color: ##005885;
        }
        .footer {
            text-align: center;
            margin-top: 30px;
            padding-top: 20px;
            border-top: 1px solid ##ddd;
            font-size: 12px;
            color: ##666;
        }
        .note {
            background-color: ##f8f9fa;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
            font-size: 14px;
        }
    </style>
</head>
<body>
    <div class="header">
        <img src="#application.config.baseUrl#/assets/images/mdacc-logo.png" alt="MD Anderson Logo" class="logo">
        <h1>Password Reset Request</h1>
    </div>

    <p>Hello,</p>

    <p>We received a request to reset your password for the MD Anderson Room Reservation System. Click the button below to reset your password:</p>

    <div style="text-align: center;">
        <a href="#args.resetUrl#" class="reset-button">Reset Password</a>
    </div>

    <div class="note">
        <p><strong>Note:</strong> This password reset link will expire in 1 hour for security reasons.</p>
        <p>If you did not request a password reset, please ignore this email or contact support if you have concerns.</p>
    </div>

    <div class="footer">
        <p>This is an automated message. Please do not reply to this email.</p>
        <p>MD Anderson Cancer Center - Room Reservation System</p>
    </div>
</body>
</html>
</cfoutput>
