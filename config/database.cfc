component {
    // Initialize the database configuration
    public any function init() {
        // Database connection settings
        this.datasource = {
            class: "com.mysql.cj.jdbc.Driver",
            connectionString: "jdbc:mysql://localhost:3306/hotel_management",
            username: "your_username",
            password: "your_password"
        };
        
        return this;
    }

    // Get database connection
    public any function getConnection() {
        try {
            return new Query(datasource = this.datasource.connectionString).execute();
        } catch (any e) {
            writeLog(
                file = "databaseError",
                type = "error",
                text = "Database connection error: " & e.message
            );
            throw(
                type = "Database",
                message = "Failed to connect to database",
                detail = e.message
            );
        }
    }

    // Execute a query
    public any function executeQuery(required string sql, struct params = {}) {
        try {
            var qry = new Query();
            qry.setDatasource(this.datasource.connectionString);
            qry.setSQL(arguments.sql);
            
            // Add parameters if they exist
            for (var param in arguments.params) {
                qry.addParam(
                    name = param,
                    value = arguments.params[param],
                    cfsqltype = determineType(arguments.params[param])
                );
            }
            
            return qry.execute().getResult();
        } catch (any e) {
            writeLog(
                file = "databaseError",
                type = "error",
                text = "Query execution error: " & e.message & " - SQL: " & arguments.sql
            );
            throw(
                type = "Database",
                message = "Failed to execute query",
                detail = e.message
            );
        }
    }

    // Helper function to determine SQL type
    private string function determineType(any value) {
        switch(getMetadata(arguments.value).getName()) {
            case "java.lang.String":
                return "CF_SQL_VARCHAR";
            case "java.lang.Integer":
            case "java.lang.Long":
                return "CF_SQL_INTEGER";
            case "java.lang.Double":
            case "java.lang.Float":
                return "CF_SQL_DOUBLE";
            case "java.lang.Boolean":
                return "CF_SQL_BIT";
            case "java.util.Date":
                return "CF_SQL_TIMESTAMP";
            default:
                return "CF_SQL_VARCHAR";
        }
    }
}
