component {
    property name="dsn" type="string";

    property name="dbUser" type="string";
    property name="dbPass" type="string";

    // Explicit credentials are mandatory here. The datasource authenticates as
    // WEBSCHEDULE_USER, not CONFROOM, so a queryExecute given only
    // {datasource=...} cannot see any CONFROOM table -- every statement in this
    // component failed with "ORA-00942: table or view does not exist".
    // cfcs/*.cfc and assets/cfc/*.cfc already pass credentials on every query;
    // this component did not.
    private void function resolveCredentials() {
        if (listFirst(CGI.SERVER_NAME, '.') EQ 'cmapps') {
            variables.dbUser = "CONFROOM_USER";
            variables.dbPass = "1DOCMAU4CNFRM6";
        } else {
            variables.dbUser = "CONFROOM";
            variables.dbPass = "1DOCMOA4CNFRM3";
        }
    }

    // Single source of query options, so no call site can omit the credentials.
    private struct function dbOptions(struct extra = {}) {
        var opts = { datasource = variables.dsn, username = variables.dbUser, password = variables.dbPass };
        for (var k in arguments.extra) { opts[k] = arguments.extra[k]; }
        return opts;
    }

    
    public function init(required string dsn) {
        resolveCredentials();
        variables.dsn = arguments.dsn;
        return this;
    }
    
    public function getUserById(required numeric userId) {
        var qUser = queryExecute(
            "SELECT USER_ID, FIRST_NAME, LAST_NAME, EMAIL, ROLE, DEPARTMENT_ID, STATUS, 
                    NOTIFICATION_PREFERENCES, CREATED_AT, UPDATED_AT 
             FROM USERS 
             WHERE USER_ID = :userId",
            {userId = {value=arguments.userId, cfsqltype="cf_sql_numeric"}},
            dbOptions()
        );
        return qUser;
    }
    
    public function authenticate(required string email, required string password) {
        var passwordHash = hash(arguments.password, "SHA-512");
        var qUser = queryExecute(
            "SELECT USER_ID, FIRST_NAME, LAST_NAME, EMAIL, ROLE 
             FROM USERS 
             WHERE EMAIL = :email AND PASSWORD_HASH = :passwordHash AND STATUS = 'Active'",
            {
                email = {value=arguments.email, cfsqltype="cf_sql_varchar"},
                passwordHash = {value=passwordHash, cfsqltype="cf_sql_varchar"}
            },
            dbOptions()
        );
        return qUser;
    }
    
    public function createUser(required struct userData) {
        var passwordHash = hash(arguments.userData.password, "SHA-512");
        var qCreate = queryExecute(
            "INSERT INTO USERS (FIRST_NAME, LAST_NAME, EMAIL, PASSWORD_HASH, ROLE, DEPARTMENT_ID, STATUS) 
             VALUES (:firstName, :lastName, :email, :passwordHash, :role, :departmentId, :status)
             RETURNING USER_ID INTO :generatedId",
            {
                firstName = {value=arguments.userData.firstName, cfsqltype="cf_sql_varchar"},
                lastName = {value=arguments.userData.lastName, cfsqltype="cf_sql_varchar"},
                email = {value=arguments.userData.email, cfsqltype="cf_sql_varchar"},
                passwordHash = {value=passwordHash, cfsqltype="cf_sql_varchar"},
                role = {value=arguments.userData.role, cfsqltype="cf_sql_varchar"},
                departmentId = {value=arguments.userData.departmentId, cfsqltype="cf_sql_numeric"},
                status = {value='Active', cfsqltype="cf_sql_varchar"},
                generatedId = {type="out", variable="newUserId", cfsqltype="cf_sql_numeric"}
            },
            dbOptions({result="result"})
        );
        return result.generatedKey;
    }
    
    public function updateUser(required numeric userId, required struct userData) {
        var updateSQL = "UPDATE USERS SET 
                        FIRST_NAME = :firstName,
                        LAST_NAME = :lastName,
                        EMAIL = :email,
                        ROLE = :role,
                        DEPARTMENT_ID = :departmentId,
                        STATUS = :status,
                        NOTIFICATION_PREFERENCES = :notificationPrefs
                        WHERE USER_ID = :userId";
        
        queryExecute(
            updateSQL,
            {
                firstName = {value=arguments.userData.firstName, cfsqltype="cf_sql_varchar"},
                lastName = {value=arguments.userData.lastName, cfsqltype="cf_sql_varchar"},
                email = {value=arguments.userData.email, cfsqltype="cf_sql_varchar"},
                role = {value=arguments.userData.role, cfsqltype="cf_sql_varchar"},
                departmentId = {value=arguments.userData.departmentId, cfsqltype="cf_sql_numeric"},
                status = {value=arguments.userData.status, cfsqltype="cf_sql_varchar"},
                notificationPrefs = {value=arguments.userData.notificationPreferences, cfsqltype="cf_sql_clob"},
                userId = {value=arguments.userId, cfsqltype="cf_sql_numeric"}
            },
            dbOptions()
        );
        return true;
    }
}
