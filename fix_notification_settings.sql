-- =============================================================================
-- FIX FOR ORACLE SQL CONSTRAINT VIOLATION ERROR
-- ORA-02290: check constraint (CONFROOM.SYS_C00308309) violated
-- =============================================================================

-- ISSUE ANALYSIS:
-- 1. The SETTING_TYPE values 'TIME' and 'INTEGER' are not allowed in current table definition
-- 2. The CATEGORY value 'USER_EXPERIENCE' is not allowed in current table definition  
-- 3. The INSERT queries reference ROLE_ID but existing queries use ROLE field

-- SOLUTION 1: Update the table constraints to match requirements
-- Add missing values to CHECK constraints

-- First, let's check current constraints
SELECT constraint_name, constraint_type, search_condition 
FROM user_constraints 
WHERE table_name = 'SYSTEM_NOTIFICATION_SETTINGS' 
AND constraint_type = 'C';

-- Update SETTING_TYPE constraint to include 'TIME' and 'INTEGER'
ALTER TABLE SYSTEM_NOTIFICATION_SETTINGS 
DROP CONSTRAINT (
    SELECT constraint_name 
    FROM user_constraints 
    WHERE table_name = 'SYSTEM_NOTIFICATION_SETTINGS' 
    AND search_condition LIKE '%SETTING_TYPE%'
);

ALTER TABLE SYSTEM_NOTIFICATION_SETTINGS 
ADD CONSTRAINT CHK_SETTING_TYPE 
CHECK (SETTING_TYPE IN ('STRING', 'NUMBER', 'BOOLEAN', 'JSON', 'TIME', 'INTEGER'));

-- Update CATEGORY constraint to include 'USER_EXPERIENCE' and other missing values
-- First drop existing category constraint if it exists
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE SYSTEM_NOTIFICATION_SETTINGS DROP CONSTRAINT CHK_CATEGORY';
EXCEPTION
    WHEN OTHERS THEN
        NULL; -- Ignore if constraint doesn't exist
END;
/

-- Add comprehensive CATEGORY constraint
ALTER TABLE SYSTEM_NOTIFICATION_SETTINGS 
ADD CONSTRAINT CHK_CATEGORY 
CHECK (CATEGORY IN ('GENERAL', 'SYSTEM', 'EMAIL', 'IN_APP', 'USER_EXPERIENCE', 'ANALYTICS', 'SECURITY', 'LIMITS', 'PERFORMANCE', 'RELIABILITY'));

-- SOLUTION 2: Corrected INSERT statements
-- These statements use ROLE_ID = 1 (Site Admin) instead of ROLE = 'Site Admin'

-- Delete any existing conflicting records first
DELETE FROM SYSTEM_NOTIFICATION_SETTINGS 
WHERE SETTING_NAME IN ('QUIET_HOURS_START', 'QUIET_HOURS_END');

-- Insert corrected records
INSERT INTO SYSTEM_NOTIFICATION_SETTINGS (SETTING_NAME, SETTING_VALUE, SETTING_TYPE, DESCRIPTION, CATEGORY, CREATED_BY) 
SELECT 'QUIET_HOURS_START', '22:00', 'TIME', 'Start time for quiet hours (no non-critical notifications)', 'USER_EXPERIENCE', USER_ID 
FROM USERS WHERE ROLE_ID = 1 AND ROWNUM = 1;

INSERT INTO SYSTEM_NOTIFICATION_SETTINGS (SETTING_NAME, SETTING_VALUE, SETTING_TYPE, DESCRIPTION, CATEGORY, CREATED_BY) 
SELECT 'QUIET_HOURS_END', '08:00', 'TIME', 'End time for quiet hours', 'USER_EXPERIENCE', USER_ID 
FROM USERS WHERE ROLE_ID = 1 AND ROWNUM = 1;

-- VERIFICATION QUERIES
-- Check if the inserts were successful
SELECT SETTING_NAME, SETTING_VALUE, SETTING_TYPE, CATEGORY, CREATED_BY
FROM SYSTEM_NOTIFICATION_SETTINGS 
WHERE SETTING_NAME IN ('QUIET_HOURS_START', 'QUIET_HOURS_END');

-- Verify constraint definitions
SELECT constraint_name, search_condition 
FROM user_constraints 
WHERE table_name = 'SYSTEM_NOTIFICATION_SETTINGS' 
AND constraint_type = 'C'
AND search_condition IS NOT NULL;

-- Check if Site Admin user exists
SELECT USER_ID, FIRST_NAME, LAST_NAME, EMAIL, ROLE_ID
FROM USERS u
JOIN ROLES r ON u.ROLE_ID = r.ROLE_ID
WHERE r.ROLE_NAME = 'Site Admin';

COMMIT;