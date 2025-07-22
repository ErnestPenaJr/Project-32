-- Notification Preferences System
-- Database schema for granular notification management

-- Create NOTIFICATION_TYPES table to define all available notification types
CREATE TABLE NOTIFICATION_TYPES (
    TYPE_CODE VARCHAR2(50) PRIMARY KEY,
    DISPLAY_NAME VARCHAR2(100) NOT NULL,
    DESCRIPTION VARCHAR2(500),
    CATEGORY VARCHAR2(50) NOT NULL,
    DEFAULT_EMAIL_ENABLED NUMBER(1) DEFAULT 1 CHECK (DEFAULT_EMAIL_ENABLED IN (0,1)),
    DEFAULT_IN_APP_ENABLED NUMBER(1) DEFAULT 1 CHECK (DEFAULT_IN_APP_ENABLED IN (0,1)),
    ADMIN_ONLY NUMBER(1) DEFAULT 0 CHECK (ADMIN_ONLY IN (0,1)),
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create NOTIFICATION_PREFERENCES table to store user-specific preferences
CREATE TABLE NOTIFICATION_PREFERENCES (
    NOTIFICATION_ID NUMBER PRIMARY KEY,
    USER_ID NUMBER NOT NULL,
    NOTIFICATION_TYPE VARCHAR2(50) NOT NULL,
    EMAIL_ENABLED NUMBER(1) DEFAULT 1 CHECK (EMAIL_ENABLED IN (0,1)),
    IN_APP_ENABLED NUMBER(1) DEFAULT 1 CHECK (IN_APP_ENABLED IN (0,1)),
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UPDATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT FK_NOTIF_PREF_USER FOREIGN KEY (USER_ID) REFERENCES USERS(USER_ID) ON DELETE CASCADE,
    CONSTRAINT FK_NOTIF_PREF_TYPE FOREIGN KEY (NOTIFICATION_TYPE) REFERENCES NOTIFICATION_TYPES(TYPE_CODE) ON DELETE CASCADE,
    CONSTRAINT UQ_USER_NOTIF_TYPE UNIQUE (USER_ID, NOTIFICATION_TYPE)
);

-- Create sequence for NOTIFICATION_PREFERENCES
CREATE SEQUENCE NOTIFICATION_PREFERENCES_SEQ
    START WITH 1
    INCREMENT BY 1
    NOCACHE;

-- Create trigger for auto-incrementing NOTIFICATION_ID
CREATE OR REPLACE TRIGGER TRG_NOTIFICATION_PREFERENCES_ID
    BEFORE INSERT ON NOTIFICATION_PREFERENCES
    FOR EACH ROW
BEGIN
    IF :NEW.NOTIFICATION_ID IS NULL THEN
        SELECT NOTIFICATION_PREFERENCES_SEQ.NEXTVAL INTO :NEW.NOTIFICATION_ID FROM DUAL;
    END IF;
END;
/

-- Create trigger for updating UPDATED_AT timestamp
CREATE OR REPLACE TRIGGER TRG_NOTIFICATION_PREF_UPDATE
    BEFORE UPDATE ON NOTIFICATION_PREFERENCES
    FOR EACH ROW
BEGIN
    :NEW.UPDATED_AT := CURRENT_TIMESTAMP;
END;
/

CREATE OR REPLACE TRIGGER TRG_NOTIFICATION_TYPES_UPDATE
    BEFORE UPDATE ON NOTIFICATION_TYPES
    FOR EACH ROW
BEGIN
    :NEW.UPDATED_AT := CURRENT_TIMESTAMP;
END;
/

-- Insert default notification types based on the email analysis
INSERT INTO NOTIFICATION_TYPES (TYPE_CODE, DISPLAY_NAME, DESCRIPTION, CATEGORY, DEFAULT_EMAIL_ENABLED, DEFAULT_IN_APP_ENABLED, ADMIN_ONLY) VALUES
-- Booking Lifecycle Notifications
('BOOKING_CONFIRMATION', 'Booking Confirmation', 'Email sent when a new booking is created', 'Booking Lifecycle', 1, 1, 0),
('BOOKING_CANCELLATION', 'Booking Cancellation', 'Email sent when a booking is cancelled', 'Booking Lifecycle', 1, 1, 0),
('BOOKING_REMINDER', 'Booking Reminder', 'Reminder email sent before booking start time', 'Booking Lifecycle', 1, 1, 0),
('BOOKING_END_REMINDER', 'Booking End Reminder', 'Reminder email sent before booking end time', 'Booking Lifecycle', 1, 1, 0),

-- Approval Workflow Notifications
('BOOKING_APPROVAL_CONFIRMED', 'Booking Approval Confirmed', 'Email sent when admin approves a booking', 'Approval Workflow', 1, 1, 0),
('BOOKING_REJECTION', 'Booking Rejection', 'Email sent when admin rejects a booking', 'Approval Workflow', 1, 1, 0),

-- User Management Notifications
('NEW_USER_CREATED', 'New User Account Created', 'Welcome email sent to new users', 'User Management', 1, 1, 0),
('USER_ACCOUNT_UPDATED', 'User Account Updated', 'Email sent when user account is modified', 'User Management', 1, 1, 0),
('USER_ACCOUNT_DEACTIVATED', 'User Account Deactivated', 'Email sent when user account is deactivated', 'User Management', 1, 1, 0),
('NEW_USER_ACCESS_REQUEST', 'New User Access Request', 'Email sent to admins when new user requests access', 'User Management', 1, 1, 1),

-- System Notifications
('PASSWORD_RESET', 'Password Reset', 'Email sent for password reset requests', 'System', 1, 0, 0),
('HELP_REQUEST', 'Help Request', 'Email sent when user submits help request', 'System', 1, 1, 1),

-- Administrative Notifications
('BULK_NOTIFICATION', 'Bulk Notification', 'Custom notifications sent by administrators', 'Administrative', 1, 1, 0),
('SYSTEM_MAINTENANCE', 'System Maintenance', 'System maintenance and update notifications', 'Administrative', 1, 1, 0);

-- Create indexes for better performance
CREATE INDEX IDX_NOTIF_PREF_USER ON NOTIFICATION_PREFERENCES(USER_ID);
CREATE INDEX IDX_NOTIF_PREF_TYPE ON NOTIFICATION_PREFERENCES(NOTIFICATION_TYPE);
CREATE INDEX IDX_NOTIF_TYPES_CATEGORY ON NOTIFICATION_TYPES(CATEGORY);

-- Insert default admin preferences for existing admin users
-- This ensures admins receive new booking notifications by default
INSERT INTO NOTIFICATION_PREFERENCES (USER_ID, NOTIFICATION_TYPE, EMAIL_ENABLED, IN_APP_ENABLED)
SELECT u.USER_ID, 'NEW_USER_ACCESS_REQUEST', 1, 1
FROM USERS u 
WHERE u.ROLE IN ('Admin', 'Site Admin')
AND u.STATUS = 'Active'
AND NOT EXISTS (
    SELECT 1 FROM NOTIFICATION_PREFERENCES np 
    WHERE np.USER_ID = u.USER_ID 
    AND np.NOTIFICATION_TYPE = 'NEW_USER_ACCESS_REQUEST'
);

-- Grant necessary permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON NOTIFICATION_TYPES TO CONFROOM_USER;
GRANT SELECT, INSERT, UPDATE, DELETE ON NOTIFICATION_PREFERENCES TO CONFROOM_USER;
GRANT SELECT ON NOTIFICATION_PREFERENCES_SEQ TO CONFROOM_USER;

COMMIT;