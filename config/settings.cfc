component {
    // Initialize application settings
    public any function init() {
        // Application settings
        this.settings = {
            // General settings
            appName: "Hotel Management System",
            version: "1.0.0",
            environment: "development", // Can be 'development', 'staging', or 'production'
            
            // Email settings
            emailSettings: {
                smtpServer: "smtp.yourserver.com",
                smtpPort: 587,
                smtpUsername: "your_email@domain.com",
                smtpPassword: "your_password",
                fromEmail: "noreply@yourhotel.com",
                fromName: "Hotel Management System"
            },
            
            // File upload settings
            uploadSettings: {
                allowedExtensions: "jpg,jpeg,png,gif,pdf",
                maxFileSize: 5242880, // 5MB in bytes
                uploadPath: expandPath("../assets/uploads/")
            },
            
            // Security settings
            security: {
                passwordMinLength: 8,
                passwordRequirements: {
                    uppercase: true,
                    lowercase: true,
                    numbers: true,
                    special: true
                },
                sessionTimeout: 20, // minutes
                maxLoginAttempts: 5,
                lockoutDuration: 15 // minutes
            },
            
            // Pagination settings
            pagination: {
                defaultPageSize: 10,
                maxPageSize: 100
            },
            
            // API settings
            api: {
                enabled: true,
                requireAuthentication: true,
                allowedOrigins: "*",
                rateLimiting: {
                    enabled: true,
                    maxRequests: 100,
                    timeWindow: 60 // seconds
                }
            },
            
            // Logging settings
            logging: {
                enabled: true,
                level: "ERROR", // DEBUG, INFO, WARN, ERROR, FATAL
                logFile: "hotel_management.log",
                maxFileSize: 10485760, // 10MB in bytes
                maxFiles: 5
            }
        };
        
        return this;
    }

    // Get a specific setting
    public any function getSetting(required string key) {
        return this.settings[arguments.key];
    }

    // Update a specific setting
    public void function updateSetting(required string key, required any value) {
        this.settings[arguments.key] = arguments.value;
    }

    // Get all settings
    public struct function getAllSettings() {
        return this.settings;
    }

    // Validate if a setting exists
    public boolean function settingExists(required string key) {
        return structKeyExists(this.settings, arguments.key);
    }
}
