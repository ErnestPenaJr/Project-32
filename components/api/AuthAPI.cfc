component {
    // Handle login
    remote struct function login() returnformat="json" {
        var response = {
            success = false,
            message = "",
            redirect = "/"
        };
        
        try {
            // Get form data
            var email = form.email ?: "";
            var password = form.password ?: "";
            var remember = structKeyExists(form, "remember");
            
            // Validate credentials
            var user = queryExecute("
                SELECT USER_ID, EMAIL, PASSWORD_HASH, IS_ADMIN, FIRST_NAME, LAST_NAME
                FROM USERS
                WHERE EMAIL = :email
                AND IS_ACTIVE = 1
            ", {email = {value=email, cfsqltype="CF_SQL_VARCHAR"}}, {datasource=application.dsn});
            
            if (user.recordCount == 1 && application.bcrypt.checkPassword(password, user.PASSWORD_HASH)) {
                // Set session variables
                session.loggedin = true;
                session.userid = user.USER_ID;
                session.email = user.EMAIL;
                session.isAdmin = user.IS_ADMIN;
                session.fullName = user.FIRST_NAME & " " & user.LAST_NAME;
                
                // Handle remember me
                if (remember) {
                    var token = createUUID();
                    var expiry = dateAdd("d", 30, now());
                    
                    // Store remember me token
                    queryExecute("
                        INSERT INTO USER_TOKENS (USER_ID, TOKEN, EXPIRY_DATE)
                        VALUES (:userid, :token, :expiry)
                    ", {
                        userid = {value=user.USER_ID, cfsqltype="CF_SQL_INTEGER"},
                        token = {value=token, cfsqltype="CF_SQL_VARCHAR"},
                        expiry = {value=expiry, cfsqltype="CF_SQL_TIMESTAMP"}
                    }, {datasource=application.dsn});
                    
                    // Set remember me cookie
                    cfcookie(name="remember_token", value=token, expires=expiry, httpOnly=true, secure=true);
                }
                
                response.success = true;
                response.message = "Login successful";
                
                // Redirect admin users to admin dashboard
                if (user.IS_ADMIN) {
                    response.redirect = "/admin/";
                }
            } else {
                response.message = "Invalid email or password";
            }
        } catch (any e) {
            response.message = "An error occurred during login";
            writeLog(type="error", text="Login error: #e.message# #e.detail#");
        }
        
        return response;
    }
    
    // Handle logout
    remote void function logout() {
        // Clear session
        structClear(session);
        
        // Clear remember me cookie if exists
        if (structKeyExists(cookie, "remember_token")) {
            // Delete token from database
            queryExecute("
                DELETE FROM USER_TOKENS
                WHERE TOKEN = :token
            ", {
                token = {value=cookie.remember_token, cfsqltype="CF_SQL_VARCHAR"}
            }, {datasource=application.dsn});
            
            // Delete cookie
            cfcookie(name="remember_token", value="", expires="now");
        }
        
        // Redirect to login page
        location(url="/login.html", addToken=false);
    }
    
    // Check if user is logged in
    remote struct function checkAuth() returnformat="json" {
        return {
            loggedin = session.loggedin ?: false,
            userid = session.userid ?: 0,
            isAdmin = session.isAdmin ?: false,
            fullName = session.fullName ?: ""
        };
    }
}
