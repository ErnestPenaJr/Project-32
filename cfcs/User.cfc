component {
    property name="userID" type="string";
    property name="username" type="string";
    property name="email" type="string";
    property name="password" type="string";
    property name="firstName" type="string";
    property name="lastName" type="string";
    property name="role" type="string";
    property name="status" type="string";
    property name="lastLogin" type="date";
    property name="created" type="date";
    property name="modified" type="date";

    // Constructor
    public function init() {
        variables.dbService = application.dbService;
        return this;
    }

    // Create new user
    public boolean function create(required struct userData) {
        try {
            // Hash password
            arguments.userData.password = hash(arguments.userData.password, "SHA-512");
            
            // Set timestamps
            arguments.userData.created = now();
            arguments.userData.modified = now();
            
            // Insert user data
            var sql = "
                INSERT INTO users (
                    username, email, password, firstName, lastName,
                    role, status, created, modified
                ) VALUES (
                    :username, :email, :password, :firstName, :lastName,
                    :role, :status, :created, :modified
                )
            ";
            
            variables.dbService.executeQuery(sql, arguments.userData);
            return true;
        } catch (any e) {
            writeLog(
                file = "userError",
                type = "error",
                text = "Error creating user: " & e.message
            );
            return false;
        }
    }

    // Get user by ID
    public struct function getUserByID(required string userID) {
        var sql = "SELECT * FROM users WHERE userID = :userID";
        var params = {userID = arguments.userID};
        return variables.dbService.executeQuery(sql, params);
    }

    // Get user by username
    public struct function getUserByUsername(required string username) {
        var sql = "SELECT * FROM users WHERE username = :username";
        var params = {username = arguments.username};
        return variables.dbService.executeQuery(sql, params);
    }

    // Update user
    public boolean function update(required struct userData) {
        try {
            arguments.userData.modified = now();
            
            var sql = "
                UPDATE users
                SET username = :username,
                    email = :email,
                    firstName = :firstName,
                    lastName = :lastName,
                    role = :role,
                    status = :status,
                    modified = :modified
                WHERE userID = :userID
            ";
            
            variables.dbService.executeQuery(sql, arguments.userData);
            return true;
        } catch (any e) {
            writeLog(
                file = "userError",
                type = "error",
                text = "Error updating user: " & e.message
            );
            return false;
        }
    }

    // Change password
    public boolean function changePassword(required string userID, required string newPassword) {
        try {
            var hashedPassword = hash(arguments.newPassword, "SHA-512");
            var sql = "UPDATE users SET password = :password WHERE userID = :userID";
            var params = {
                password = hashedPassword,
                userID = arguments.userID
            };
            
            variables.dbService.executeQuery(sql, params);
            return true;
        } catch (any e) {
            writeLog(
                file = "userError",
                type = "error",
                text = "Error changing password: " & e.message
            );
            return false;
        }
    }

    // Authenticate user
    public boolean function authenticate(required string username, required string password) {
        try {
            var user = getUserByUsername(arguments.username);
            if (structIsEmpty(user)) {
                return false;
            }
            
            var hashedPassword = hash(arguments.password, "SHA-512");
            return (hashedPassword == user.password);
        } catch (any e) {
            writeLog(
                file = "userError",
                type = "error",
                text = "Error authenticating user: " & e.message
            );
            return false;
        }
    }

    // Delete user
    public boolean function delete(required string userID) {
        try {
            var sql = "DELETE FROM users WHERE userID = :userID";
            var params = {userID = arguments.userID};
            
            variables.dbService.executeQuery(sql, params);
            return true;
        } catch (any e) {
            writeLog(
                file = "userError",
                type = "error",
                text = "Error deleting user: " & e.message
            );
            return false;
        }
    }

    // List users with pagination
    public array function listUsers(numeric page = 1, numeric pageSize = 10) {
        try {
            var offset = (arguments.page - 1) * arguments.pageSize;
            var sql = "
                SELECT *
                FROM users
                ORDER BY created DESC
                LIMIT :pageSize
                OFFSET :offset
            ";
            var params = {
                pageSize = arguments.pageSize,
                offset = offset
            };
            
            return variables.dbService.executeQuery(sql, params);
        } catch (any e) {
            writeLog(
                file = "userError",
                type = "error",
                text = "Error listing users: " & e.message
            );
            return [];
        }
    }

    // Count total users
    public numeric function countUsers() {
        try {
            var sql = "SELECT COUNT(*) as total FROM users";
            var result = variables.dbService.executeQuery(sql);
            return result.total;
        } catch (any e) {
            writeLog(
                file = "userError",
                type = "error",
                text = "Error counting users: " & e.message
            );
            return 0;
        }
    }
}
