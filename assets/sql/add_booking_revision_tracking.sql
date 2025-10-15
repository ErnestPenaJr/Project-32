-- ========================================
-- Booking Revision Tracking Migration
-- Date: 2025-10-14
-- Purpose: Add columns to track booking edits and revisions
-- ========================================

-- Add revision tracking columns to BOOKINGS table
ALTER TABLE BOOKINGS ADD (
    ORIGINAL_BOOKING_ID NUMBER NULL,
    REVISION_NUMBER NUMBER DEFAULT 0 NOT NULL,
    IS_MODIFIED CHAR(1) DEFAULT 'N' CHECK (IS_MODIFIED IN ('Y', 'N')),
    REVISION_DATE TIMESTAMP NULL,
    MODIFIED_BY NUMBER NULL
);

-- Add foreign key constraint for ORIGINAL_BOOKING_ID (self-referencing)
ALTER TABLE BOOKINGS ADD CONSTRAINT FK_BOOKINGS_ORIGINAL
    FOREIGN KEY (ORIGINAL_BOOKING_ID) REFERENCES BOOKINGS(BOOKING_ID);

-- Add foreign key constraint for MODIFIED_BY
ALTER TABLE BOOKINGS ADD CONSTRAINT FK_BOOKINGS_MODIFIED_BY
    FOREIGN KEY (MODIFIED_BY) REFERENCES USERS(USER_ID);

-- Create index for faster revision queries
CREATE INDEX IDX_BOOKINGS_ORIGINAL_ID ON BOOKINGS(ORIGINAL_BOOKING_ID);
CREATE INDEX IDX_BOOKINGS_REVISION_NUM ON BOOKINGS(REVISION_NUMBER);
CREATE INDEX IDX_BOOKINGS_IS_MODIFIED ON BOOKINGS(IS_MODIFIED);

-- Add comments to document the new columns
COMMENT ON COLUMN BOOKINGS.ORIGINAL_BOOKING_ID IS 'References the first booking in a revision chain. NULL for original bookings, points to parent for revised bookings';
COMMENT ON COLUMN BOOKINGS.REVISION_NUMBER IS 'Tracks the revision count. 0 for original bookings, increments with each edit';
COMMENT ON COLUMN BOOKINGS.IS_MODIFIED IS 'Y if booking has been edited, N if original or unmodified';
COMMENT ON COLUMN BOOKINGS.REVISION_DATE IS 'Timestamp of when the booking was last revised';
COMMENT ON COLUMN BOOKINGS.MODIFIED_BY IS 'User ID of the person who last modified the booking';

-- ========================================
-- Rollback Script (if needed)
-- ========================================
-- To rollback this migration, run:
-- ALTER TABLE BOOKINGS DROP CONSTRAINT FK_BOOKINGS_ORIGINAL;
-- ALTER TABLE BOOKINGS DROP CONSTRAINT FK_BOOKINGS_MODIFIED_BY;
-- DROP INDEX IDX_BOOKINGS_ORIGINAL_ID;
-- DROP INDEX IDX_BOOKINGS_REVISION_NUM;
-- DROP INDEX IDX_BOOKINGS_IS_MODIFIED;
-- ALTER TABLE BOOKINGS DROP COLUMN ORIGINAL_BOOKING_ID;
-- ALTER TABLE BOOKINGS DROP COLUMN REVISION_NUMBER;
-- ALTER TABLE BOOKINGS DROP COLUMN IS_MODIFIED;
-- ALTER TABLE BOOKINGS DROP COLUMN REVISION_DATE;
-- ALTER TABLE BOOKINGS DROP COLUMN MODIFIED_BY;
