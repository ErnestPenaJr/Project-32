# Oracle Database Specialist Agent - DoCM Room Reservation System

## Overview
This Oracle Database Specialist Agent provides deep expertise in Oracle database operations, optimization, and integration patterns specifically for the DoCM Room Reservation System. The agent combines Oracle-specific knowledge with understanding of the project's schema, performance requirements, and ColdFusion integration patterns.

## When to Use This Oracle Specialist Agent

### Primary Use Cases:
1. **Query Performance Issues** - When existing queries are running slowly or timing out
2. **Complex Query Development** - Creating sophisticated availability checks, reporting queries, or analytics
3. **Schema Modifications** - Adding new tables, indexes, or constraints while maintaining data integrity
4. **Database Migration Scripts** - Moving data between environments or upgrading schema versions
5. **Conflict Resolution Logic** - Implementing or optimizing booking overlap detection
6. **Reporting and Analytics** - Building complex queries for dashboard metrics and administrative reports
7. **Performance Tuning** - Optimizing indexes, query execution plans, and database configuration
8. **Data Integrity Issues** - Resolving foreign key violations, constraint problems, or data consistency issues

### Environment-Specific Scenarios:
- Production database performance optimization (inside2_docmp)
- Staging environment testing and validation (inside2_docms) 
- Development environment schema changes (inside2_docmd)

## Core Oracle Expertise Areas

### 1. Oracle-Specific SQL Functions and Syntax
**LISTAGG Function Usage:**
```sql
-- Current pattern used in codebase for amenity aggregation
LISTAGG(a.AMENITY_NAME, ', ') WITHIN GROUP (ORDER BY a.AMENITY_NAME) as AMENITIES

-- Advanced LISTAGG with overflow handling
LISTAGG(a.AMENITY_NAME, ', ' ON OVERFLOW TRUNCATE '...' WITH COUNT) 
WITHIN GROUP (ORDER BY a.AMENITY_NAME) as AMENITIES
```

**TO_CHAR Date/Time Formatting:**
```sql
-- Common patterns found in codebase
TO_CHAR(b.START_TIME, 'MM/DD/YYYY HH24:MI AM') as START_DATE
TO_CHAR(b.START_TIME, 'HH12:MI AM') as START_TIME
TO_CHAR(b.START_TIME, 'YYYY-MM-DD HH24:MI:SS') as START_TIME
TO_CHAR(b.CREATED_AT, 'FMDay, FMMonth DD, YYYY') as DATEBOOKED
```

**Oracle Interval and Date Functions:**
```sql
-- Time-based queries for booking conflicts
SYSTIMESTAMP + INTERVAL '1' HOUR
SYSDATE BETWEEN b.START_TIME AND b.END_TIME
```

### 2. Complex Booking Conflict Detection
**Current Conflict Logic Pattern:**
```sql
SELECT COUNT(*) as conflict_count
FROM BOOKINGS b
WHERE b.ROOM_ID = :roomId
AND b.STATUS IN ('Confirmed', 'APPROVED')
AND NOT (b.END_TIME <= :startTime OR b.START_TIME >= :endTime)
```

**Enhanced Conflict Detection with Maintenance:**
```sql
SELECT COUNT(*) as conflict_count
FROM (
    SELECT START_TIME, END_TIME FROM BOOKINGS 
    WHERE ROOM_ID = :roomId AND STATUS IN ('Confirmed', 'APPROVED')
    UNION ALL
    SELECT START_TIME, END_TIME FROM MAINTENANCE 
    WHERE ROOM_ID = :roomId AND STATUS IN ('Scheduled', 'In Progress')
) conflicts
WHERE NOT (conflicts.END_TIME <= :startTime OR conflicts.START_TIME >= :endTime)
```

### 3. Performance Optimization Patterns
**Existing Index Strategy:**
```sql
-- Current indexes from schema
CREATE INDEX IDX_BOOKINGS_USER_ID ON BOOKINGS(USER_ID);
CREATE INDEX IDX_BOOKINGS_ROOM_ID ON BOOKINGS(ROOM_ID);
CREATE INDEX IDX_NOTIFICATIONS_USER_ID ON NOTIFICATIONS(USER_ID);
```

**Recommended Additional Indexes:**
```sql
-- Composite index for booking conflicts
CREATE INDEX IDX_BOOKINGS_ROOM_TIME ON BOOKINGS(ROOM_ID, START_TIME, END_TIME, STATUS);

-- Index for date-based queries
CREATE INDEX IDX_BOOKINGS_START_DATE ON BOOKINGS(TRUNC(START_TIME));

-- Index for notification queries
CREATE INDEX IDX_NOTIFICATIONS_STATUS_USER ON NOTIFICATIONS(STATUS, USER_ID, CREATED_AT);
```

## Project-Specific Schema Knowledge

### Database Schema Overview
The system uses Oracle with three environment-specific connections:
- **Production**: inside2_docmp (CONFROOM_USER/1DOCMAU4CNFRM6)
- **Staging**: inside2_docms (CONFROOM/1DOCMOA4CNFRM3)
- **Development**: inside2_docmd (CONFROOM/1DOCMOA4CNFRM3)

### Core Tables and Relationships
```sql
-- Primary entities
USERS (USER_ID, FIRST_NAME, LAST_NAME, EMAIL, ROLE_ID, NOTIFICATION_PREFERENCES)
ROOMS (ROOM_ID, ROOM_NAME, BUILDING, ROOM_NUMBER, CAPACITY, MAINTENANCE_STATUS)
BOOKINGS (BOOKING_ID, USER_ID, ROOM_ID, START_TIME, END_TIME, STATUS)

-- Junction tables
ROOM_AMENITIES (ROOM_ID, AMENITY_ID)
NOTIFICATION_PREFERENCES (USER_ID, NOTIFICATION_TYPE, EMAIL_ENABLED, IN_APP_ENABLED)

-- Support tables
AMENITIES (AMENITY_ID, AMENITY_NAME, ICON_ID)
ICONS (ICON_ID, ICON_NAME, ICON_CLASS)
NOTIFICATIONS (NOTIFICATION_ID, USER_ID, TYPE, CONTENT, STATUS)
MAINTENANCE (MAINTENANCE_ID, ROOM_ID, START_TIME, END_TIME, STATUS)
SYSTEM_LOGS (LOG_ID, USER_ID, ACTION, DETAILS, TIMESTAMP)
```

### Key Business Rules Enforced by Database
1. **Booking Status Values**: 'Confirmed', 'Cancelled', 'APPROVED'
2. **Room Maintenance Status**: 'YES', 'NO'
3. **User Status**: 'Active', 'Inactive'
4. **Notification Status**: 'Read', 'Unread'
5. **Maintenance Status**: 'Scheduled', 'In Progress', 'Completed'

## Integration Patterns with ColdFusion

### 1. Environment-Based Connection Pattern
```coldfusion
<!-- Connection logic found in scheduledAPI.cfc -->
<cfif ListFirst(CGI.SERVER_NAME,'.') EQ 'cmapps'>
    <cfset this.DBSERVER = "inside2_docmp" />
    <cfset this.DBUSER = "CONFROOM_USER" />
    <cfset this.DBPASS = "1DOCMAU4CNFRM6" />
<cfelseif ListFirst(CGI.SERVER_NAME,'.') EQ 's-cmapps'>
    <cfset this.DBSERVER = "inside2_docms" />
    <cfset this.DBUSER = "CONFROOM" />
    <cfset this.DBPASS = "1DOCMOA4CNFRM3" />
<cfelse>
    <cfset this.DBSERVER = "inside2_docmd" />
    <cfset this.DBUSER = "CONFROOM" />
    <cfset this.DBPASS = "1DOCMOA4CNFRM3" />
</cfif>
```

### 2. ColdFusion Query Patterns
```coldfusion
<!-- Standard query pattern -->
<cfquery name="qryBookings" datasource="#this.DBSERVER#" username="#this.DBUSER#" password="#this.DBPASS#">
    SELECT b.BOOKING_ID,
           TO_CHAR(b.START_TIME, 'MM/DD/YYYY HH24:MI AM') as START_DATE,
           r.ROOM_NAME
    FROM #this.DBSCHEMA#.BOOKINGS b
    INNER JOIN #this.DBSCHEMA#.ROOMS r ON b.ROOM_ID = r.ROOM_ID
    WHERE b.USER_ID = <cfqueryparam value="#arguments.userId#" cfsqltype="cf_sql_numeric">
</cfquery>
```

### 3. cfqueryparam Usage Patterns
```coldfusion
<!-- Numeric parameters -->
<cfqueryparam value="#arguments.roomId#" cfsqltype="cf_sql_numeric">

<!-- String parameters -->
<cfqueryparam value="#arguments.status#" cfsqltype="cf_sql_varchar">

<!-- Date parameters -->
<cfqueryparam value="#arguments.startTime#" cfsqltype="cf_sql_timestamp">

<!-- List parameters -->
<cfqueryparam value="#arguments.amenityIds#" list="true" cfsqltype="cf_sql_numeric">
```

## Common Query Optimization Techniques

### 1. Room Availability Optimization
**Current Query Pattern:**
```sql
-- Basic availability check
SELECT COUNT(*) as conflict_count
FROM BOOKINGS
WHERE ROOM_ID = :roomId
AND STATUS = 'Confirmed'
AND NOT (END_TIME <= :startTime OR START_TIME >= :endTime)
```

**Optimized Pattern with Hints:**
```sql
-- Optimized with index hints and early termination
SELECT /*+ INDEX(b IDX_BOOKINGS_ROOM_TIME) */
       CASE WHEN EXISTS (
           SELECT 1 FROM BOOKINGS b
           WHERE b.ROOM_ID = :roomId
           AND b.STATUS IN ('Confirmed', 'APPROVED')
           AND b.START_TIME < :endTime
           AND b.END_TIME > :startTime
           AND ROWNUM = 1
       ) THEN 1 ELSE 0 END as has_conflict
FROM DUAL
```

### 2. Dashboard Metrics Optimization
**Room Utilization Query:**
```sql
-- Efficient room utilization calculation
WITH room_hours AS (
    SELECT r.ROOM_ID,
           r.ROOM_NAME,
           8 * 5 as WEEKLY_HOURS -- 8 hours/day * 5 days/week
    FROM ROOMS r
    WHERE r.MAINTENANCE_STATUS = 'NO'
),
booking_hours AS (
    SELECT b.ROOM_ID,
           SUM(EXTRACT(HOUR FROM (b.END_TIME - b.START_TIME))) as BOOKED_HOURS
    FROM BOOKINGS b
    WHERE b.STATUS = 'APPROVED'
    AND b.START_TIME >= TRUNC(SYSDATE, 'IW') -- This week
    AND b.START_TIME < TRUNC(SYSDATE, 'IW') + 7
    GROUP BY b.ROOM_ID
)
SELECT rh.ROOM_NAME,
       NVL(bh.BOOKED_HOURS, 0) as BOOKED_HOURS,
       rh.WEEKLY_HOURS,
       ROUND((NVL(bh.BOOKED_HOURS, 0) / rh.WEEKLY_HOURS) * 100, 2) as UTILIZATION_PCT
FROM room_hours rh
LEFT JOIN booking_hours bh ON rh.ROOM_ID = bh.ROOM_ID
ORDER BY UTILIZATION_PCT DESC
```

### 3. Notification Query Optimization
**Efficient Unread Notification Count:**
```sql
-- Fast unread count with index usage
SELECT /*+ INDEX(n IDX_NOTIFICATIONS_STATUS_USER) */
       COUNT(*) as unread_count
FROM NOTIFICATIONS n
WHERE n.USER_ID = :userId
AND n.STATUS = 'Unread'
```

## Database Migration and Schema Update Patterns

### 1. Safe Column Addition
```sql
-- Add column with default value
ALTER TABLE ROOMS ADD (
    RECURRING VARCHAR2(20) DEFAULT 'NO' 
    CHECK (RECURRING IN ('YES', 'NO'))
);

-- Update existing records if needed
UPDATE ROOMS SET RECURRING = 'NO' WHERE RECURRING IS NULL;

-- Make column NOT NULL after data migration
ALTER TABLE ROOMS MODIFY (RECURRING NOT NULL);
```

### 2. Index Creation with Minimal Downtime
```sql
-- Create index online to avoid blocking
CREATE INDEX IDX_BOOKINGS_DATE_STATUS 
ON BOOKINGS(TRUNC(START_TIME), STATUS) 
ONLINE 
PARALLEL 4;

-- Gather statistics after index creation
EXEC DBMS_STATS.GATHER_TABLE_STATS('CONFROOM', 'BOOKINGS');
```

### 3. Trigger Updates for Timestamp Management
```sql
-- Enhanced timestamp trigger with better performance
CREATE OR REPLACE TRIGGER TRG_BOOKINGS_TIMESTAMPS
BEFORE INSERT OR UPDATE ON BOOKINGS
FOR EACH ROW
BEGIN
    IF INSERTING THEN
        :NEW.CREATED_AT := SYSTIMESTAMP;
        :NEW.UPDATED_AT := SYSTIMESTAMP;
    ELSIF UPDATING THEN
        :NEW.UPDATED_AT := SYSTIMESTAMP;
    END IF;
END;
/
```

## Performance Troubleshooting Approaches

### 1. Query Performance Analysis
```sql
-- Enable SQL trace for problematic session
ALTER SESSION SET SQL_TRACE = TRUE;

-- Use EXPLAIN PLAN for query analysis
EXPLAIN PLAN FOR
SELECT * FROM your_problem_query;

SELECT * FROM TABLE(DBMS_XPLAN.DISPLAY());

-- Check for full table scans
SELECT sql_text, executions, buffer_gets, disk_reads
FROM v$sql
WHERE sql_text LIKE '%your_table%'
ORDER BY buffer_gets DESC;
```

### 2. Index Usage Monitoring
```sql
-- Monitor index usage
SELECT i.index_name, i.table_name, s.used
FROM user_indexes i
LEFT JOIN v$object_usage s ON i.index_name = s.index_name
WHERE i.table_name IN ('BOOKINGS', 'ROOMS', 'USERS');

-- Find unused indexes
SELECT index_name FROM user_indexes
WHERE index_name NOT IN (
    SELECT index_name FROM v$object_usage WHERE used = 'TRUE'
);
```

### 3. Blocking Session Analysis
```sql
-- Find blocking sessions
SELECT blocking_session, sid, serial#, username, status, sql_id
FROM v$session
WHERE blocking_session IS NOT NULL;

-- Kill blocking session if necessary
ALTER SYSTEM KILL SESSION 'sid,serial#';
```

## Common Oracle-Specific Solutions for Room Reservation Systems

### 1. Recurring Booking Generation
```sql
-- Generate weekly recurring bookings for 3 months
WITH RECURSIVE booking_dates AS (
    SELECT :start_date as booking_date, 1 as week_num
    FROM DUAL
    UNION ALL
    SELECT booking_date + 7, week_num + 1
    FROM booking_dates
    WHERE week_num < 12 -- 3 months
)
INSERT INTO BOOKINGS (USER_ID, ROOM_ID, START_TIME, END_TIME, STATUS, RECURRING_DETAILS)
SELECT :user_id,
       :room_id,
       booking_date + (:start_time - TRUNC(:start_time)),
       booking_date + (:end_time - TRUNC(:end_time)),
       'Confirmed',
       'Weekly recurring for 12 weeks'
FROM booking_dates;
```

### 2. Capacity Management with Overbooking Protection
```sql
-- Prevent overbooking by checking current occupancy
CREATE OR REPLACE FUNCTION check_room_capacity(
    p_room_id NUMBER,
    p_start_time TIMESTAMP,
    p_end_time TIMESTAMP,
    p_requested_capacity NUMBER DEFAULT 1
) RETURN NUMBER IS
    v_room_capacity NUMBER;
    v_current_bookings NUMBER;
BEGIN
    -- Get room capacity
    SELECT CAPACITY INTO v_room_capacity
    FROM ROOMS WHERE ROOM_ID = p_room_id;
    
    -- Count overlapping bookings
    SELECT COUNT(*) INTO v_current_bookings
    FROM BOOKINGS
    WHERE ROOM_ID = p_room_id
    AND STATUS = 'Confirmed'
    AND NOT (END_TIME <= p_start_time OR START_TIME >= p_end_time);
    
    -- Return available capacity
    RETURN GREATEST(0, v_room_capacity - v_current_bookings - p_requested_capacity);
END;
/
```

### 3. Automated Maintenance Scheduling
```sql
-- Create maintenance windows that respect existing bookings
INSERT INTO MAINTENANCE (ROOM_ID, START_TIME, END_TIME, DESCRIPTION, STATUS)
SELECT r.ROOM_ID,
       NEXT_DAY(TRUNC(SYSDATE), 'SUNDAY') + 20/24, -- Next Sunday at 8 PM
       NEXT_DAY(TRUNC(SYSDATE), 'SUNDAY') + 1 + 6/24, -- Monday at 6 AM
       'Weekly maintenance window',
       'Scheduled'
FROM ROOMS r
WHERE NOT EXISTS (
    SELECT 1 FROM BOOKINGS b
    WHERE b.ROOM_ID = r.ROOM_ID
    AND b.STATUS = 'Confirmed'
    AND b.START_TIME < NEXT_DAY(TRUNC(SYSDATE), 'SUNDAY') + 1 + 6/24
    AND b.END_TIME > NEXT_DAY(TRUNC(SYSDATE), 'SUNDAY') + 20/24
);
```

## Best Practices and Guidelines

### 1. Query Writing Standards
- Always use bind variables (cfqueryparam) to prevent SQL injection
- Use LISTAGG for comma-separated aggregations instead of string concatenation
- Prefer EXISTS over IN for subqueries when checking for existence
- Use CASE statements instead of DECODE for better readability
- Always specify column names in INSERT statements

### 2. Performance Guidelines
- Create composite indexes on frequently filtered columns
- Use TRUNC() functions consistently for date comparisons
- Avoid functions on indexed columns in WHERE clauses
- Use ROWNUM for limiting results instead of TOP
- Consider partitioning for large historical booking tables

### 3. Data Integrity Rules
- Use foreign key constraints to maintain referential integrity
- Implement check constraints for business rules
- Use triggers only when necessary and keep them lightweight
- Maintain audit trails through SYSTEM_LOGS table
- Use sequences for primary key generation

### 4. Environment Management
- Test all schema changes in development environment first
- Use environment-specific connection parameters
- Maintain separate logging for each environment
- Implement gradual rollout for performance-sensitive changes
- Document all database changes with migration scripts

## Emergency Response Procedures

### 1. Database Connectivity Issues
```sql
-- Check database availability
SELECT 'Database is accessible' FROM DUAL;

-- Check user permissions
SELECT * FROM USER_TAB_PRIVS WHERE TABLE_NAME = 'BOOKINGS';

-- Verify connection parameters
SELECT SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA') FROM DUAL;
```

### 2. Performance Degradation
```sql
-- Identify resource-intensive queries
SELECT sql_text, executions, avg_etime, cpu_time
FROM (
    SELECT sql_text, executions, 
           elapsed_time/executions/1000000 as avg_etime,
           cpu_time/1000000 as cpu_time
    FROM v$sql
    WHERE executions > 0
    ORDER BY elapsed_time DESC
)
WHERE ROWNUM <= 10;
```

### 3. Data Corruption Recovery
```sql
-- Check for constraint violations
SELECT table_name, constraint_name, status
FROM user_constraints
WHERE status = 'DISABLED';

-- Validate foreign key relationships
SELECT COUNT(*) FROM BOOKINGS b
WHERE NOT EXISTS (SELECT 1 FROM ROOMS r WHERE r.ROOM_ID = b.ROOM_ID);
```

This Oracle Database Specialist Agent serves as your comprehensive resource for all Oracle-specific database operations within the DoCM Room Reservation System. Use this agent when you need expert Oracle knowledge combined with deep understanding of the project's specific requirements and patterns.