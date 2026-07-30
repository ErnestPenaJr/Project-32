-- Migration: add the pending-approval notification types
--
-- Why this is needed
-- ------------------
-- components/ApprovalNotification.cfc resolves its recipients with an INNER JOIN
-- against NOTIFICATION_TYPES:
--
--     JOIN NOTIFICATION_TYPES t ON t.TYPE_CODE = :typeCode
--
-- It passes the type codes BOOKING_PENDING_APPROVAL (immediate alert sent when a
-- request is submitted) and BOOKING_PENDING_APPROVAL_DIGEST (the scheduled
-- digest). Neither code was ever seeded by assets/sql/notification_preferences.sql,
-- so the join matched nothing, the recipient list came back empty, and no
-- approver was ever notified that a request needed action.
--
-- These are administrative types, so ADMIN_ONLY = 1 and both delivery channels
-- default to enabled.
--
-- Apply
-- -----
--   sqlplus CONFROOM/<password>@<tns> @add_pending_approval_notification_types.sql

INSERT INTO NOTIFICATION_TYPES (
    TYPE_CODE, DISPLAY_NAME, DESCRIPTION, CATEGORY,
    DEFAULT_EMAIL_ENABLED, DEFAULT_IN_APP_ENABLED, ADMIN_ONLY
)
SELECT
    'BOOKING_PENDING_APPROVAL',
    'Booking Pending Approval',
    'Immediate alert sent to approvers when a reservation request is submitted',
    'Approval Workflow',
    1, 1, 1
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1 FROM NOTIFICATION_TYPES WHERE TYPE_CODE = 'BOOKING_PENDING_APPROVAL'
);

INSERT INTO NOTIFICATION_TYPES (
    TYPE_CODE, DISPLAY_NAME, DESCRIPTION, CATEGORY,
    DEFAULT_EMAIL_ENABLED, DEFAULT_IN_APP_ENABLED, ADMIN_ONLY
)
SELECT
    'BOOKING_PENDING_APPROVAL_DIGEST',
    'Booking Pending Approval Digest',
    'Recurring summary of reservation requests still awaiting a decision',
    'Approval Workflow',
    1, 0, 1
FROM DUAL
WHERE NOT EXISTS (
    SELECT 1 FROM NOTIFICATION_TYPES WHERE TYPE_CODE = 'BOOKING_PENDING_APPROVAL_DIGEST'
);

COMMIT;

-- Verify
--   SELECT TYPE_CODE, ADMIN_ONLY FROM NOTIFICATION_TYPES
--   WHERE TYPE_CODE LIKE 'BOOKING_PENDING_APPROVAL%';
-- Expect two rows.


-- Rollback
-- --------
-- Delete the dependent preference rows first: NOTIFICATION_PREFERENCES has
-- FK_NOTIF_PREF_TYPE ON DELETE CASCADE, so removing the type also removes any
-- per-user override an approver has saved. That is the intended rollback
-- behaviour, but it does discard those overrides -- export them first if they
-- need to be preserved.
--
--   DELETE FROM NOTIFICATION_TYPES
--   WHERE TYPE_CODE IN ('BOOKING_PENDING_APPROVAL', 'BOOKING_PENDING_APPROVAL_DIGEST');
--   COMMIT;
