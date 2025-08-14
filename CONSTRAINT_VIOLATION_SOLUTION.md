# Oracle SQL Constraint Violation Fix - ORA-02290

## Problem Summary
The error `ORA-02290: check constraint (CONFROOM.SYS_C00308309) violated` occurs when inserting records into `SYSTEM_NOTIFICATION_SETTINGS` table due to:

1. **Missing CHECK constraint values**: The table doesn't allow `SETTING_TYPE = 'TIME'` and `CATEGORY = 'USER_EXPERIENCE'`
2. **Incorrect user role reference**: Using `ROLE_ID = 1` in WHERE clause instead of proper JOIN with ROLES table

## Root Cause Analysis

### Issue 1: CHECK Constraint Mismatch
**Current table definition:**
```sql
SETTING_TYPE VARCHAR2(20) CHECK (SETTING_TYPE IN ('STRING', 'NUMBER', 'BOOLEAN', 'JSON'))
CATEGORY VARCHAR2(50) DEFAULT 'GENERAL'
```

**Required values in failing INSERT:**
- `SETTING_TYPE = 'TIME'` ❌ Not allowed
- `CATEGORY = 'USER_EXPERIENCE'` ❌ Not constrained properly

### Issue 2: User Role Query Problem
**Failing INSERT pattern:**
```sql
FROM USERS WHERE ROLE_ID = 1 AND ROWNUM = 1
```

**Database structure shows:**
- USERS table has `ROLE_ID` (foreign key to ROLES.ROLE_ID)
- ROLES table has `ROLE_NAME` field
- Need proper JOIN to find Site Admin users

## Solution

### Step 1: Update Table Constraints
Execute this SQL to fix the constraint issues:

```sql
-- Update SETTING_TYPE constraint to include missing values
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

-- Add proper CATEGORY constraint
ALTER TABLE SYSTEM_NOTIFICATION_SETTINGS 
ADD CONSTRAINT CHK_CATEGORY 
CHECK (CATEGORY IN ('GENERAL', 'SYSTEM', 'EMAIL', 'IN_APP', 'USER_EXPERIENCE', 'ANALYTICS', 'SECURITY', 'LIMITS', 'PERFORMANCE', 'RELIABILITY'));
```

### Step 2: Execute Corrected INSERT Statements
```sql
-- Delete any existing conflicting records first
DELETE FROM SYSTEM_NOTIFICATION_SETTINGS 
WHERE SETTING_NAME IN ('QUIET_HOURS_START', 'QUIET_HOURS_END');

-- Corrected INSERT statements using proper JOIN
INSERT INTO SYSTEM_NOTIFICATION_SETTINGS (SETTING_NAME, SETTING_VALUE, SETTING_TYPE, DESCRIPTION, CATEGORY, CREATED_BY) 
SELECT 'QUIET_HOURS_START', '22:00', 'TIME', 'Start time for quiet hours (no non-critical notifications)', 'USER_EXPERIENCE', u.USER_ID 
FROM USERS u 
JOIN ROLES r ON u.ROLE_ID = r.ROLE_ID 
WHERE r.ROLE_NAME = 'Site Admin' AND ROWNUM = 1;

INSERT INTO SYSTEM_NOTIFICATION_SETTINGS (SETTING_NAME, SETTING_VALUE, SETTING_TYPE, DESCRIPTION, CATEGORY, CREATED_BY) 
SELECT 'QUIET_HOURS_END', '08:00', 'TIME', 'End time for quiet hours', 'USER_EXPERIENCE', u.USER_ID 
FROM USERS u 
JOIN ROLES r ON u.ROLE_ID = r.ROLE_ID 
WHERE r.ROLE_NAME = 'Site Admin' AND ROWNUM = 1;

COMMIT;
```

### Step 3: Verification Queries
```sql
-- Verify the records were inserted successfully
SELECT SETTING_NAME, SETTING_VALUE, SETTING_TYPE, CATEGORY, CREATED_BY
FROM SYSTEM_NOTIFICATION_SETTINGS 
WHERE SETTING_NAME IN ('QUIET_HOURS_START', 'QUIET_HOURS_END');

-- Check constraint definitions
SELECT constraint_name, search_condition 
FROM user_constraints 
WHERE table_name = 'SYSTEM_NOTIFICATION_SETTINGS' 
AND constraint_type = 'C'
AND search_condition IS NOT NULL;

-- Verify Site Admin user exists
SELECT u.USER_ID, u.FIRST_NAME, u.LAST_NAME, u.EMAIL, r.ROLE_NAME
FROM USERS u
JOIN ROLES r ON u.ROLE_ID = r.ROLE_ID
WHERE r.ROLE_NAME = 'Site Admin';
```

## Files Updated
1. **`/Users/epena1/ColdFusion_2021/ColdFusion/cfusion/wwwroot/DoCMRoomReservation/assets/sql/system_notification_controls.sql`**
   - Fixed SETTING_TYPE constraint to include 'TIME' and 'INTEGER'
   - Added proper CATEGORY constraint
   - Fixed all INSERT statements to use proper JOIN syntax

2. **`/Users/epena1/ColdFusion_2021/ColdFusion/cfusion/wwwroot/DoCMRoomReservation/fix_notification_settings.sql`**
   - Complete fix script with constraint updates and corrected INSERTs
   - Verification queries included

## Prevention for Future Issues
1. Always verify CHECK constraint values before INSERT operations
2. Use proper JOINs when referencing related tables (USERS → ROLES)
3. Test INSERT statements against actual table constraints
4. Keep table definition documentation synchronized with actual schema

## Database Schema Notes
- USERS table uses `ROLE_ID` (NUMBER) foreign key
- ROLES table contains `ROLE_NAME` values like 'Site Admin', 'Admin', 'User'
- Site Admin role should have `ROLE_ID = 1` based on INSERT order in tables.sql