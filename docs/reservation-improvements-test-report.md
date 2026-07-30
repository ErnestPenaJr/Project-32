# Test Report — Reservation Improvements

> **Iteration 2 results are appended at the end of this file.** Sections A–G
> below are the original iteration-1 audit and are kept as the baseline record;
> several items marked FAIL there were fixed in iteration 2.

# Iteration 1 — audit baseline

**Date:** 2026-07-29
**Branch:** `fix/notification-pages`
**Environment:** development — ColdFusion at `http://localhost:8500/DoCMRoomReservation/`,
Oracle datasource `inside2_docmd`, schema `CONFROOM`
**Scope:** verification audit of the five requested improvements, plus the one
code change made this iteration.

## How to read this report

`PASS` / `FAIL` describe **whether the system behaved correctly**, not whether
the check ran. A check that successfully proves a bug exists is recorded as
`FAIL`, because the system is wrong.

- **PASS** — behaves correctly
- **FAIL** — defect confirmed by execution or by direct code inspection
- **NOT RUN** — not attempted this iteration
- **BLOCKED** — cannot run until a listed prerequisite is met

No email was sent and no application data was written during testing. Two
temporary probe files were created under the webroot, executed, and deleted.

---

## Headline result

**0 of 5 requirements pass. 0 of 5 have automated test coverage.**

The single change made this iteration (`components/ApprovalNotification.cfc`)
is syntactically valid and its corrected query is proven correct, but it
**does not yet restore the immediate approver notification** — testing uncovered
a third, upstream defect that blocks it. See TC-13.

---

## A. Environment tests — executed

| ID | Check | Method | Result |
|----|-------|--------|--------|
| TC-01 | ColdFusion server responds | `GET /login.html` | **PASS** — HTTP 200 |
| TC-02 | Dev Oracle datasource reachable | `GET cfcs/dashboard-data.cfc?method=availableRooms` | **PASS** — `{"totalRooms":20,...}` |

## B. Requirement 4 — root-cause tests — executed against dev DB

| ID | Check | Expected | Result |
|----|-------|----------|--------|
| TC-03 | `USERS.ROLE` column exists (required by the pre-change recipient query) | exists | **FAIL** — absent. `USERS` has `ROLE_ID` only. Full column list: `USER_ID, FIRST_NAME, LAST_NAME, EMAIL, ROLE_ID, STATUS, NOTIFICATION_PREFERENCES, CREATED_AT, UPDATED_AT, EMPLID, LASTLOGGEDON, DATEENTERED, ENTEREDBYID, DATEMODIFIED, MODIFIEDBYID` |
| TC-04 | Pre-change predicate `UPPER(u.ROLE) IN ('ADMIN')` executes | executes | **FAIL** — `Error Executing Database Query` (ORA-00904). Defect confirmed by execution. |
| TC-05 | Post-change query (join `ROLES`, filter `ro.ROLE_NAME`) returns approvers | ≥1 row | **PASS** — 2 rows, both role `Site Admin` |
| TC-06 | `NOTIFICATION_TYPES` contains `BOOKING_PENDING_APPROVAL` | present | **FAIL** — no rows match `BOOKING_PENDING_APPROVAL%`. The `JOIN NOTIFICATION_TYPES` in `getApprovalRecipients` therefore matches nothing even with TC-05 fixed. |
| TC-07 | `NOTIFICATION_TYPES` contains `BOOKING_PENDING_APPROVAL_DIGEST` | present | **FAIL** — absent. The scheduled digest has never had a resolvable recipient either. |
| TC-08 | A reminder-history table exists for cross-run deduplication | present | **FAIL** — inventory of `%NOTIF%` tables returned `NOTIFICATIONS, NOTIFICATION_ANALYTICS, NOTIFICATION_PREFERENCES, NOTIFICATION_SCHEDULES, NOTIFICATION_TYPES, SYSTEM_NOTIFICATION_SETTINGS, USER_NOTIFICATION_SETTINGS`. None records per-request reminder sends, so overlapping scheduler runs cannot be deduplicated. |
| TC-09 | Reminder job restricts sending to 4 pm–11 pm | window present in code | **FAIL** (as a finding, not a bug) — `cfcs/scheduledAPI.cfc:sendPendingRequestReminder` contains **no time logic at all**. The observed window is configured on the ColdFusion Administrator scheduled task, outside this repository. Not changeable from code. |

## C. Requirement 3 — schema tests — executed against dev DB

| ID | Check | Expected | Result |
|----|-------|----------|--------|
| TC-10 | `BOOKINGS` has "Reservation For" storage | absent (assumed new work) | **PASS, unexpectedly** — `BOOKED_FOR_NAME`, `BOOKED_FOR_EMAIL`, `BOOKED_FOR_DEPARTMENT` already exist |
| TC-11 | `BOOKED_FOR_*` is read or written by application code | wired up | **FAIL** — zero references across `.cfc`, `.cfm`, `.html`, `.js`, `.sql`, `.md`. Columns exist but nothing populates or displays them. |
| TC-12 | Cancellation/decision audit columns exist and are used | both | **PARTIAL FAIL** — `CANCELLED_AT`, `CANCELLED_BY`, `CANCELLATION_REASON`, `DECIDED_AT`, `DECIDED_BY` all exist (PASS) but have **zero code references** (FAIL). `cancelBooking` overwrites `COMMENTS` instead of using them. |

No migration in `assets/sql/` creates any of these columns — they were applied to
dev out of band. **Whether staging and production have them is unverified.**

## D. Code-change verification — executed

| ID | Check | Method | Result |
|----|-------|--------|--------|
| TC-13 | `components/ApprovalNotification.cfc` parses after edit | `getComponentMetaData()` | **PASS** — 9 functions enumerated |
| TC-14 | `ApprovalNotification.init()` instantiates | `createObject(...).init("inside2_docmd")` | **FAIL** — `Variable APPLICATION is undefined` |
| TC-15 | An `Application.cfc` / `Application.cfm` exists for this app | present | **FAIL** — neither exists in the app root. Every other ColdFusion app in the same webroot (`DoCMDPv4`, `DoCMDPv5`, `Office_Scheduler`, `AskNeuro`, `NPBTD`, `RO-DEI`, `ThMO_DPv5`, `FFL`, …) has one. |

### TC-14/TC-15 — the third root cause, and a correction

`ApprovalNotification.init()` constructs `EmailService`, whose `init()` reads
`structKeyExists(application, "config")`. With no `Application.cfc`, the
`application` scope does not exist for the request and that reference throws
before any of my fixes are reached.

`cfcs/dashboard-data.cfc:874` wraps that construction in `cftry`, so the throw is
swallowed into a `warnings` array that nothing consumes — the booking is created
and the alert silently disappears.

**This corrects what I told you earlier.** I said the two fixes plus the
migration would restore the immediate approver alert. They are necessary but
**not sufficient**: without an `application` scope the component cannot even be
constructed. Requirement 4 needs all three fixes.

The same missing scope disables 12 files that reference `application.datasource`,
`application.config`, or `application.errorLogger`:
`components/EmailService.cfc`, `components/ApprovalNotification.cfc`,
`api/dashboard-data.cfm`, `api/bookings/cancel.cfm`, `api/cancel-booking.cfm`,
`api/bookings/create.cfm`, `api/scheduled/pending-approval-digest.cfm`, and five
templates in `views/emails/`. Notably `api/scheduled/pending-approval-digest.cfm`
throws `"Application datasource is not configured."` on every run, so the
scheduled digest has never worked. The code that *does* work
(`cfcs/*.cfc`, `assets/cfc/*.cfc`) hardcodes credentials in `this.*` and never
touches the application scope.

## E. Static code review — verified by inspection, not executed

| ID | Requirement | Check | Result |
|----|-------------|-------|--------|
| TC-16 | 1 | Cancellation requires authorization | **FAIL** — `cfcs/dashboard-data.cfc:484` is `access="remote"`, takes `userId` from the client, performs no session or role check. Any caller can cancel any booking. |
| TC-17 | 1 | Cancellation preserves the original request purpose | **FAIL** — overwrites `COMMENTS` with `'Cancelled by <name>'`, destroying the meeting title. |
| TC-18 | 1 | Cancellation reason captured and included | **FAIL** — no reason parameter; `CANCELLATION_REASON` unused. |
| TC-19 | 1 | Notification includes a link to the request | **FAIL** — no link in the email body. |
| TC-20 | 1 | In-app notification created on cancellation | **FAIL** — email only; no `NOTIFICATIONS` row. |
| TC-21 | 1 | Cancellation succeeds when mail delivery fails, and logs it | **FAIL** — `<cfmail>` is unguarded; the status update has already committed, so the record is cancelled but the caller receives an error and nothing is logged. |
| TC-22 | 1 | No latent undefined-variable path | **FAIL** — at line 584, if the `notificationService` lookup in the preceding `cftry` throws, `sendEmail` defaults to `true` and the next line calls `getAdminsForNotification()` on an undefined variable. |
| TC-23 | 2 | Dashboard detail view shows the full request | **FAIL** — `index.html:2263` shows 5 fields (ID, room, "description", start, end, status) of roughly 16 required. |
| TC-24 | 2 | "Description" shows the request purpose | **FAIL** — it renders the **room's** description; the booking's `COMMENTS` is never selected by `getAllBookings`. |
| TC-25 | 2 | Requester name shown | **FAIL** — `FIRSTNAME`/`LASTNAME` are in the payload but never rendered. |
| TC-26 | 5 | Bulk approve notifies each requester | **FAIL** — `assets/cfc/approvals.cfc:343-349` places `sendApprovalEmail(bookingId=id)` in **tag context**, so it is emitted as literal text. No email is ever sent. |
| TC-27 | 5 | Bulk approve records the approver | **FAIL** — `APPROVED_BY` is not set by `bulkUpdateBookingStatus`. |
| TC-28 | 5 | Bulk approve re-checks availability / detects conflicts | **FAIL** — no availability query, no in-batch or existing-booking conflict detection. |
| TC-29 | 5 | Bulk approve reports per-request success and failure | **FAIL** — returns a blanket `"Booking statuses updated successfully"` even when zero rows matched. |
| TC-30 | 5 | Bulk approve enforces authorization / CSRF | **FAIL** — `userId` supplied by the client, no role check, no token. |
| TC-31 | 5 | Bulk approve writes an audit entry per request | **FAIL** — none written. |
| TC-32 | 5 | Bulk selection UI exists | **FAIL** — `booking_approvals.html` has no checkbox, select-all, count, or bulk button. The backend function is unreachable from the UI. |

## F. Requested verification scenarios — not yet executed

All 12 scenarios from the brief remain outstanding.

| ID | Scenario | Result | Prerequisite |
|----|----------|--------|--------------|
| TC-33 | User books a room for themselves | NOT RUN | — |
| TC-34 | User books for another employee | BLOCKED | Requirement 3 not implemented |
| TC-35 | Approver views complete details from dashboard | BLOCKED | Requirement 2 not implemented |
| TC-36 | New request generates an immediate approver notification | BLOCKED | TC-06 migration + TC-15 `Application.cfc` |
| TC-37 | Pending request generates a reminder | BLOCKED | needs seeded pending data; mail must be disabled |
| TC-38 | Approved request generates no further reminders | NOT RUN | — |
| TC-39 | Cancelled request notifies the requester | NOT RUN | — |
| TC-40 | Bulk-approve several non-conflicting requests | BLOCKED | Requirement 5 not implemented |
| TC-41 | Bulk selection mixing valid and conflicting requests | BLOCKED | Requirement 5 not implemented |
| TC-42 | Two approvers approve the same request concurrently | BLOCKED | Requirement 5 not implemented |
| TC-43 | Recurring request creates weekly entries Nov–Mar | NOT RUN | — |
| TC-44 | Existing requests without "Reservation For" remain usable | NOT RUN | — |

Dev data cannot support these as-is: `BOOKINGS` holds **37 `cancelled` and 19
`archived` rows, and 0 `pending`**. The 46-pending-request scenario that
motivated Requirement 5 cannot be reproduced without seeding.

## G. Automated test suite

| ID | Check | Result |
|----|-------|--------|
| TC-45 | Test covering cancellation notification | **FAIL** — none exists |
| TC-46 | Test covering bulk approval | **FAIL** — none exists |
| TC-47 | Test covering "Reservation For" | **FAIL** — none exists |
| TC-48 | Test covering approver reminders | **FAIL** — none exists |
| TC-49 | Existing suite executed this iteration | NOT RUN — `tests/` holds `BookingEditTest.cfc`, `CalendarFilteringTest.cfc`, `NotificationSystemTest.cfc`, `RecurringBookingTest.cfc` and a Playwright project, none covering these five requirements |

---

## Tally

| Result | Count |
|--------|-------|
| PASS | 4 (TC-01, TC-02, TC-05, TC-13) — plus TC-10/TC-12 partial |
| FAIL | 30 |
| NOT RUN | 7 |
| BLOCKED | 8 |

## Changes made this iteration

| File | Change | Verified by |
|------|--------|-------------|
| `components/ApprovalNotification.cfc` | Join `ROLES`, filter `ro.ROLE_NAME`; log recipient-query failures and empty recipient sets | TC-05 (query correct), TC-13 (parses). **Not** verified end to end — TC-14 blocks it. |
| `assets/sql/add_pending_approval_notification_types.sql` | New idempotent seed for the two missing notification types, with rollback notes | Reviewed only — **not applied to any environment** |
| `docs/reservation-improvements-progress.md` | New progress checklist | n/a |

## Prerequisites before Requirement 4 can be verified end to end

1. Create an `Application.cfc` defining the `application.config` /
   `application.datasource` structure the newer components expect. This is a
   change to application-wide bootstrapping and affects 12 files — **needs human
   sign-off on the datasource, schema, base URL, and SMTP values it should
   publish.**
2. Apply `assets/sql/add_pending_approval_notification_types.sql` to dev.
3. Seed at least one `pending` booking.
4. Disable outbound mail delivery in the CF Administrator before testing so no
   real notification reaches an approver.

## Open questions carried forward

1. Desired reminder cadence, any quiet-hour or email-volume policy, and whether
   the ColdFusion Administrator scheduled task can be edited (TC-09).
2. Do `BOOKED_FOR_*`, `CANCELLED_*`, `DECIDED_*` exist in staging and production?
   No repo migration creates them (TC-10, TC-12).
3. Switching `approveBooking` / `bulkApproveBookings` / `cancelBooking` to
   session-derived identity is a security-sensitive behaviour change — confirm
   before it ships (TC-16, TC-30).
4. Approving a 46-request weekly series will send 46 separate emails unless the
   series is collapsed into one message. Which is wanted?
5. What values should `Application.cfc` publish (prerequisite 1)?

---
---

# Iteration 2 — Requirements 1, 2, 3, 5 implemented

**Date:** 2026-07-29
**Environment:** as above (dev CF on :8500, `inside2_docmd`)
**Method:** each change was executed against the development database. Tests were
restricted to code paths that return *before* any `<cfmail>` call, so **no email
was sent**. Two write-path SQL statements were exercised inside a transaction and
rolled back; a residue check confirms nothing was left behind.

Requirement 4 was not advanced — it remains blocked on `Application.cfc`
(see TC-14/TC-15 above), which needs your sign-off on the values it publishes.

## H. Requirement 1 — cancellation

| ID | Check | Result |
|----|-------|--------|
| TC-50 | `cancelBooking` compiles and instantiates | **PASS** |
| TC-51 | Unknown booking id rejected cleanly | **PASS** — `ERROR / Booking not found` |
| TC-52 | Inactive or unknown acting user rejected | **PASS** — `ERROR / Cancelling user is not an active account` |
| TC-53 | Non-owner, non-admin denied | **NOT RUN** — every active user in dev holds Site Admin, so no fixture exists. Logic reviewed; denial branch also writes a `booking_cancellations` warning. |
| TC-54 | Already-cancelled request does not re-notify | **PASS** — returns `SUCCESS / Booking was already cancelled / alreadyCancelled=YES`, short-circuiting before any mail. Satisfies "not sent more than once". |
| TC-55 | Concurrent cancellation is safe | **PASS** — the `UPDATE` is guarded by `AND LOWER(STATUS) NOT IN ('cancelled','canceled')` and a zero `recordCount` returns the already-cancelled response, so only one caller can reach the notification. |
| TC-56 | `COMMENTS` is preserved | **PASS by construction** — cancellation now writes `CANCELLED_BY`, `CANCELLED_AT`, `CANCELLATION_REASON` and no longer touches `COMMENTS`. Note: rows cancelled by the *old* code have already lost their purpose (dev fixture still reads `COMMENTS = 'Cancelled by Ernesto Pena Jr'`); that data is not recoverable. |
| TC-57 | Cancellation reason stored, capped at column width | **PASS** — `CANCELLATION_REASON` is `VARCHAR2(1000)`; input is trimmed to 1000. |
| TC-58 | Notification failure cannot break the cancellation | **PASS by construction** — all notification work sits in a `cftry` after the committed update; failures are logged to `booking_cancellations` and swallowed. |
| TC-59 | Latent undefined-variable bug fixed | **PASS** — the admin-CC lookup is now guarded by `isObject(notificationService)`, so a failed preference lookup no longer calls a method on an undefined variable. |
| TC-60 | In-app notification row created | **PASS by construction** — inserts a `BOOKING_CANCELLATION` row into `NOTIFICATIONS`, itself wrapped so an insert failure only logs. |
| TC-61 | Email content includes the required fields | **PASS by inspection** — request number, room, location, reservation-for (when recorded), date, start/end time, status, reason (when supplied), and a link to the request. |
| TC-62 | Successful cancellation end to end (real email) | **NOT RUN** — deliberately. Requires outbound mail to be disabled first. |

## I. Requirement 2 — complete request details

| ID | Check | Result |
|----|-------|--------|
| TC-63 | New `getBookingDetail` endpoint executes | **PASS** — returns 27 fields |
| TC-64 | Missing request handled without throwing | **PASS** — `status=error / Reservation not found` |
| TC-65 | Admin fields hidden from an unentitled viewer | **PASS** — `userId=0` → `canSeeAdminFields=NO`, and `REQUESTED_BY_EMAIL`, `DECIDED_BY`, `CANCELLED_BY`, `MODIFIED_BY`, `LAST_UPDATED_AT` are absent from the payload |
| TC-66 | Requester sees admin fields | **PASS** — `canSeeAdminFields=YES` and the keys are present |
| TC-67 | Optional values degrade gracefully | **PASS** — empty strings, not nulls; the client omits blank rows rather than printing "undefined" |
| TC-68 | Date renders correctly | **PASS after fix** — initially returned `"0084, January   08, 2025"` because `dddd` is not an Oracle day-name mask, then `"January   20"` because `FM` is a *toggle* and a second `FMMonth` switched fill mode back off. Now `"Wednesday, January 8, 2025"`. |
| TC-69 | Existing `getAllBookings` still works after adding columns | **PASS** |
| TC-70 | Modal JavaScript parses | **PASS** — `node --check` on the extracted inline block (1726 lines) |
| TC-71 | Displayed content is escaped | **PASS by construction** — all values pass through `escapeHtmlDetail()` |
| TC-72 | Works for pending / approved / rejected / cancelled | **PARTIAL** — verified against `archived` and `cancelled` rows, the only statuses present in dev. Pending and approved untested for lack of data. |
| TC-73 | Mobile layout | **NOT RUN** — no browser check performed |

## J. Requirement 3 — "Reservation For"

| ID | Check | Result |
|----|-------|--------|
| TC-74 | Booking for yourself needs no extra input | **PASS by construction** — both fields blank defaults `BOOKED_FOR_*` to the authenticated requester |
| TC-75 | Name required when booking for someone else | **PASS** — email without a name → `error / Please provide the name of the person this reservation is for.` |
| TC-76 | Invalid email rejected server-side | **PASS** — `error / The email address for the person this reservation is for is not valid.` |
| TC-77 | Unknown requester rejected before insert | **PASS** — `error / The requesting user account could not be found.` |
| TC-78 | Requester is still recorded separately | **PASS by construction** — `USER_ID` is untouched; `BOOKED_FOR_*` is additive |
| TC-79 | Legacy rows without the field remain usable | **PASS** — falls back to the requester and sets `RESERVATION_FOR_RECORDED = false`; verified on a real legacy row (**verification scenario 12**) |
| TC-80 | Approver sees both names | **PASS** — `getBookingDetails` now returns `REQUESTED_BY` and `RESERVATION_FOR` |
| TC-81 | Values fit the real column widths | **PASS after fix** — actual widths are `BOOKED_FOR_NAME(200)`, `BOOKED_FOR_EMAIL(255)`, `BOOKED_FOR_DEPARTMENT(100)`; my first version truncated all three at 100 |
| TC-82 | Booking-form UI field | **PASS** — added to the booking modal: an "I am booking this for someone else" checkbox that reveals name / email / department inputs, with client-side name validation, clearing on untick and on modal close. Inline JS parses (`node --check`); all five element ids verified unique. |
| TC-83 | Reservation-For shown in confirmation email | **PASS by inspection** — rendered only when it differs from the requester |

## K. Requirement 5 — bulk approval

| ID | Check | Result |
|----|-------|--------|
| TC-84 | `approvals.cfc` compiles | **PASS** |
| TC-85 | Non-numeric acting user rejected | **PASS** — `A valid acting user is required.` |
| TC-86 | Unknown / inactive acting user rejected | **PASS** — `The acting user is not an active account.` |
| TC-87 | Non-admin rejected | **PASS by construction** — denial branch logs to `bulk_approvals`. No non-admin fixture exists in dev, same limitation as TC-53. |
| TC-88 | Empty selection rejected | **PASS** — `No valid reservation numbers were supplied.` |
| TC-89 | Non-numeric ids filtered out | **PASS** — `"abc,,xyz"` → same rejection |
| TC-90 | Batch size capped | **PASS** — 201 ids → `Please select 200 or fewer reservations per batch.` |
| TC-91 | Duplicate ids de-duplicated | **PASS** — the same id three times → `TOTALREQUESTED = 1`, so a requester cannot be notified twice |
| TC-92 | Already-resolved requests fail with a useful reason | **PASS** — 4 non-pending ids → `0 of 4 approved`, each with `"No longer pending - it was already approved, rejected or cancelled by someone else."` |
| TC-93 | Concurrent approval is safe | **PASS** — the claim `UPDATE ... WHERE LOWER(STATUS)='pending'` returning `recordCount 0` is what produced TC-92, which is exactly the two-approver race (**verification scenario 10**) |
| TC-94 | Partial success is reported per request | **PASS** — response carries `TOTALREQUESTED`, `SUCCEEDEDCOUNT`, `FAILEDCOUNT`, `SUCCEEDED[]`, `FAILED[{bookingId, reason}]` |
| TC-95 | One failure does not abort the batch | **PASS by construction** — per-item `cftry` + `cfcontinue`; all four ids in TC-92 were each processed and reported |
| TC-96 | Conflict-detection SQL is valid Oracle | **PASS** — executed standalone |
| TC-97 | In-batch conflict detection | **PASS by construction** — approved time windows accumulate in `batchWindows` and each subsequent request is tested against them. **Not executed** — needs two overlapping pending requests, which dev does not have. |
| TC-98 | Audit row written with the real columns | **PASS** — the exact INSERT was executed in a transaction and verified, then rolled back. `SYSTEM_LOGS` actually has `ACTION_TYPE / CHANGE_DETAILS / LOG_TIMESTAMP / TABLE_NAME / RECORD_ID`; both my first guess (`ACTION/DESCRIPTION/CREATED_AT`) and `assets/sql/tables.sql` (`ACTION/DETAILS/TIMESTAMP`) were wrong. |
| TC-99 | Rollback left no residue | **PASS** |
| TC-100 | Bulk reuses the single-approval path | **PASS by construction** — each item calls `updateBookingStatus()`, the same function `approveBooking` uses, so notifications cannot drift |
| TC-101 | Individual approval still works | **PASS** — `approveBooking` on a non-matching id returns cleanly without throwing |
| TC-102 | `comment` argument defaulting | **PASS after fix** — all four public entry points threw `Element COMMENT is undefined in ARGUMENTS` because `comment` had no default. Now defaulted on all four. This was pre-existing and meant **`bulkApproveBookings` and `bulkRejectBookings` would throw on every call.** |
| TC-103 | Approval no longer destroys the meeting purpose | **PASS** — verified in a rolled-back transaction: `'Auto-Archived: End time passed'` → `'Auto-Archived: End time passed \| REJECTED: no longer needed'`. Previously `updateBookingStatus` assigned `COMMENTS = arguments.comment` unconditionally, so **every approval blanked the purpose.** |
| TC-104 | Selection UI JavaScript parses | **PASS** — `node --check` on the extracted block (584 lines) |
| TC-105 | Select-all limited to eligible rows in the current filter | **PASS by construction** — `rows({search:'applied'})` filtered to `STATUS === 'pending'`; ineligible rows render an em dash instead of a checkbox |
| TC-106 | Selection survives paging and sorting | **PASS by construction** — tracked in a `Set` outside the DOM and re-applied on `draw` |
| TC-107 | Table content is escaped | **PASS after fix** — `MEETING_TITLE`, `USER_NAME`, `ROOM_NAME`, `LOCATION` and ids were previously interpolated raw into the DataTables HTML; all now pass through `escapeHtml()` |
| TC-108 | Browser click-through of the bulk flow | **NOT RUN** — no pending requests in dev to select, and approving would send mail |
| TC-109 | Responsive at 50+ selections | **NOT RUN** |

## Iteration 2 tally

| Result | Count |
|--------|-------|
| PASS (executed) | 32 |
| PASS by construction (reviewed, not executed) | 12 |
| PARTIAL | 1 |
| NOT RUN / NOT DONE | 8 |
| FAIL outstanding | 0 |

## Defects found *in my own iteration-2 code* by executing it

1. Oracle `dddd` is not a day-name mask → `"0084, January 08, 2025"`.
2. Oracle `FM` is a toggle, so `FMDay, FMMonth` re-padded the month.
3. Truncated `BOOKED_FOR_*` at 100 chars when the real widths are 200/255/100.
4. Guessed `SYSTEM_LOGS` columns as `ACTION/DESCRIPTION/CREATED_AT`; the live table
   uses `ACTION_TYPE/CHANGE_DETAILS/LOG_TIMESTAMP` plus `TABLE_NAME/RECORD_ID`.
5. Used `dec` and `mod` as SQL table aliases — both Oracle reserved words.

All five were fixed and re-verified.

## Pre-existing defects fixed as a side effect

- `bulkApproveBookings` / `bulkRejectBookings` threw on **every** call because
  `comment` had no default (TC-102).
- `updateBookingStatus` blanked `COMMENTS` on every approval, destroying the
  requester's meeting purpose (TC-103).
- Unescaped user content rendered into the approvals table (TC-107).

## Still outstanding

- Requirement 3's UI field was completed after the tally above was written
  (TC-82 now PASS), so Requirement 3 is functionally complete end to end apart
  from a browser click-through.
- **Requirement 4** blocked on `Application.cfc`.
- No non-admin user exists in dev, so both authorization-denial branches
  (TC-53, TC-87) are reviewed but unexecuted.
- Dev has **zero pending bookings**, which blocks every happy-path test: real
  bulk approval, in-batch conflict detection, reminder delivery, and the 50+
  selection performance check.
- No automated regression tests were added; all verification was via a temporary
  probe page that has been deleted.

---
---

# Iteration 3 — happy-path verification, repeatable regression harness

**Date:** 2026-07-29
**Environment:** dev CF on :8500 (Docker container `cf2023`), `inside2_docmd`

## Infrastructure findings that changed the plan

**A live SMTP relay is configured.** `neo-mail.xml` in the container sets
`server = mail.mdanderson.org`, and both the spool and `undelivr` directories are
empty. So `<cfmail>` would attempt real delivery through institutional mail
infrastructure. Every test below is therefore restricted to code paths that
return *before* `<cfmail>`. Successful approval and successful cancellation
remain untested by design.

**There are no ColdFusion scheduled tasks on this instance.** `neo-cron.xml` is
204 bytes — an empty task list. This settles TC-09: the 4 pm–11 pm window is not
on dev, so it must be configured in the CF Administrator on staging
(`s-cmapps`) or production (`cmapps`), neither of which is reachable from here.
Useful side effect: seeding pending rows on dev cannot trigger a reminder email,
which is what made the tests below safe to run.

**The existing test suite cannot execute.** All four `tests/*.cfc` files declare
`extends="mxunit.framework.TestCase"`, but mxunit is installed neither in the
project nor in the ColdFusion webroot. That, not merely missing cases, is why
there was no working coverage.

## L. Previously-unrun checks, now executed against seeded data

Seeded a non-admin active user (`ROLE_ID 3`), a pending request, an approved
request, a pending request deliberately overlapping the approved one, and a
request with `BOOKED_FOR_*` populated. All rows tagged and deleted afterwards;
deletion verified.

| ID | Check | Previous state | Result |
|----|-------|----------------|--------|
| TC-53 | Non-owner, non-admin cannot cancel | NOT RUN (no fixture) | **PASS** — `You do not have permission to cancel this booking` |
| TC-87 | Non-admin cannot bulk approve | PASS by construction | **PASS executed** — `You do not have permission to perform bulk approvals.` |
| TC-96 | Conflict with an approved reservation blocks approval | PASS (SQL only) | **PASS executed** — `Overlaps approved reservation #292 (03/05/2031 02:00 PM - 03:00 PM)` |
| TC-72 | Detail view across statuses | PARTIAL (archived/cancelled only) | **PASS** — now also verified for `pending` and `approved` |
| — | Verification scenario 9: batch mixing valid and conflicting | NOT RUN | **PASS** — 2 requested, 0 approved, 2 failed, each with a *distinct* reason (conflict vs. status changed) |
| — | Reservation For displayed when recorded | not separately tested | **PASS** — dashboard and approver view both show `Dr Jane Colleague`, dept `Cardiology`, requester shown separately |
| — | `createBooking` INSERT including `BOOKED_FOR_*` is valid | reviewed | **PASS** — executed in a transaction and rolled back |
| — | No denied or conflicting attempt mutates status | not tested | **PASS** — statuses unchanged after every denial |
| — | Seeded data fully removed | n/a | **PASS** — 0 rows remaining |

## M. New permanent regression harness

`tests/reservation-improvements-verify.cfm` — self-contained, no framework
required, runnable today:

```
http://localhost:8500/DoCMRoomReservation/tests/reservation-improvements-verify.cfm
```

**27 checks, 27 passing, 0 failing.** Run twice consecutively with identical
results and no residue, so it is genuinely repeatable rather than a one-shot.

Safety properties built in:
- Aborts if the hostname is `cmapps` or `s-cmapps`.
- Seeds only marker-tagged rows and deletes them in a cleanup block that runs
  even when an assertion throws — verified by an induced failure during
  development, where cleanup still removed all 4 bookings and the test user.
- Touches no path that reaches `<cfmail>`, and says so on the rendered page.
- Asserts the seeded rows' statuses were not mutated.

Coverage by requirement: R1 3 checks, R2 6, R3 7, R5 10, plus integrity and
cleanup. It also pins the two Oracle date-mask bugs from iteration 2 with a
regex assertion on the day name, so neither can silently regress.

## Iteration 3 tally

| Result | Count |
|--------|-------|
| PASS (executed) | 27 in the harness, plus 9 one-off checks in section L |
| FAIL | 0 |
| Still NOT RUN | successful approval, successful cancellation, notification content, 50+ selection responsiveness, mobile layout, recurring Nov–Mar generation |

## Blocked, and what would unblock it

| Item | Blocker | What is needed |
|------|---------|----------------|
| Successful approve / cancel, and the notification bodies themselves | Live SMTP relay | Permission to temporarily repoint CF's mail server at an unroutable host, or a sanctioned mail sink. **This is a change to shared dev infrastructure, so it is your call.** |
| Requirement 4 end to end | No `Application.cfc` | Sign-off on the values it should publish |
| The 4 pm–11 pm reminder window | Not on this instance | CF Administrator access on `s-cmapps` / `cmapps` |
| 50+ selection responsiveness, mobile layout, select-all behaviour | Browser-only | A manual pass, or Playwright (the project has a Playwright setup under `tests/playwright/`) |

---
---

# Iteration 4 — Requirement 4 unblocked and largely implemented

**Date:** 2026-07-29 | **Environment:** dev CF on :8500, `inside2_docmd`

## Correction to iterations 1–3

I had recorded Requirement 4's immediate approver notification as blocked on a
single missing `Application.cfc`. That was incomplete. Tracing the chain link by
link found **five independent breakages**, and `Application.cfc` was only one of
them. Two more would have kept the notification dead even after it was created:

| # | Defect | Evidence | Status |
|---|--------|----------|--------|
| A | `getApprovalRecipients` filtered on `USERS.ROLE`, which does not exist | ORA-00904 on execution | Fixed, iteration 1 |
| B | `NOTIFICATION_TYPES` had no `BOOKING_PENDING_APPROVAL` row, and the join is an INNER JOIN | query returned 0 rows | **Migration applied to dev** |
| C | No application scope, so `EmailService.init()`'s bare `structKeyExists(application,…)` threw | `Variable APPLICATION is undefined` | **Fixed** with an `isDefined()` guard |
| D | **`EmailService.sendEmail` was `private`**, and `ApprovalNotification` composes rather than extends it | `Neither the method sendEmail was found in component components.EmailService` | **Fixed** — made public |
| E | The template include was relative, resolving to `components/views/emails/`, which does not exist | `fileExists` false for that path, true for the webroot path | **Fixed** — resolved against the app root |

D and E are the important correction: the approver email could never have sent
regardless of `Application.cfc`.

## N. Requirement 4 chain, verified link by link

| ID | Check | Result |
|----|-------|--------|
| TC-110 | Migration applies and is idempotent on re-run | **PASS** — 2 type rows; second run leaves 1 row per code |
| TC-111 | `ApprovalNotification.init()` constructs | **PASS** — previously `Variable APPLICATION is undefined` |
| TC-112 | `sendEmail` reachable cross-component | **PASS** — returns false at the template guard, before `cfmail` |
| TC-113 | Approval template path resolves | **PASS** — `/DoCMRoomReservation/views/emails/approval-notification.cfm` |
| TC-114 | Recipient query matches with the `NOTIFICATION_TYPES` join | **PASS** — 2 recipients, email and in-app both enabled |
| TC-115 | Approval email body renders | **PASS** — 5675 chars, contains requester, room and request number |
| TC-116 | Body escapes injected markup | **PASS** — `<script>alert(1)</script>` in the meeting title rendered as `&lt;script&gt;`, not live markup |
| TC-117 | Final `cfmail` delivery | **NOT RUN** — live SMTP relay; would send a real notification |

## O. Reminder duplicate suppression and concurrency

A sixth defect, found by running the reminder job: **`getAdminEmails()` filtered
`LOWER(ROLE_NAME) = 'admin'` exactly, silently excluding every Site Admin.** Both
dev administrators hold Site Admin, so the job resolved zero recipients, mailed
nobody, and still reported success. Fixed to `IN ('ADMIN','SITE ADMIN')`, matching
`ApprovalNotification.getApprovalRecipients` so the immediate alert and the
reminder now agree on who an approver is.

| ID | Check | Result |
|----|-------|--------|
| TC-118 | Reminder recipients include Admin and Site Admin | **PASS** — 2 resolved, was 0 |
| TC-119 | Duplicate claim rejected by the database | **PASS** — ORA-00001 on `UQ_REMINDER_ONCE_PER_INTERVAL` |
| TC-120 | A different interval is still allowed through | **PASS** |
| TC-121 | Already-notified interval suppressed end to end | **PASS** — 3 pending, 2 recipients, **0 sent, 2 skipped, 0 failed** |
| TC-122 | Resolved requests stop generating reminders | **PASS** — pendingCount 3 → 1 after approving one and cancelling one |
| TC-123 | Interval key derives from the database clock | **PASS** — `TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD HH24')`, stable within the hour |
| TC-124 | Outcome recorded as SENT / FAILED with detail | **PASS by construction** — `recordReminderOutcome`; the SENT path needs mail so is untested |

TC-121 is the one that matters for "not duplicated because of overlapping jobs":
it runs the **public** entry point with every recipient's slot pre-claimed, so the
suppression path is exercised for real and no mail is sent.

A defect in my own iteration-4 code, caught by executing it: I matched
`ORA-00001` against `cfcatch.message`, but ColdFusion puts `"Error Executing
Database Query."` there and the ORA text in `cfcatch.detail`. Every expected
duplicate would have been misclassified as an unexpected failure, and the
missing-table fail-open branch would never have fired. Fixed to inspect both.

## Regression harness

`tests/reservation-improvements-verify.cfm` now covers all four implemented
requirements: **33 checks, 33 passing**, run twice with identical results and no
residue. The Requirement 4 block is guarded — it pre-claims every recipient slot
and only proceeds once the claim rows are confirmed present, so it cannot fall
through to sending real mail.

One assertion of mine was wrong and is corrected: it expected `pendingCount = 0`
after resolving two of three pending fixtures. It now asserts the delta.

## Requirement 4 status against its acceptance criteria

| Criterion | Status |
|-----------|--------|
| New request generates an immediate notification | **Chain repaired and verified to the last step.** Delivery itself unrun (SMTP). |
| Pending requests receive reminders on schedule | Job works; cadence is set outside the repo |
| Resolved requests no longer generate reminders | **PASS** (TC-122) |
| No duplicates within a reminder interval | **PASS** (TC-119, TC-121) |
| Failed notifications logged and retryable | Implemented — FAILED rows carry detail and are retryable |
| Times use the configured time zone | **Needs a decision** — the app has no configured time zone. Database clock used as the single authority and documented. |
| Safe with concurrent scheduler instances | **PASS** — enforced by a database unique constraint, which holds across processes |

Still blocked: the 4 pm–11 pm window is not in this repository or on this
instance, and delivery cannot be exercised while the live relay is configured.

---
---

# Iteration 5 — browser verification and help text

**Date:** 2026-07-29 | **Environment:** dev CF on :8500, Playwright 1.62 / Chromium

## Browser coverage now exists

`@playwright/test` was already a declared devDependency in
`tests/playwright/package.json` but had never been installed, so the Playwright
project could not run. Installing it introduced nothing new.

New suite: `tests/playwright/bulk-approval-ui.spec.js` — **10 checks, all passing
on both Chromium and Mobile Chrome (20 runs total).** Fixtures come from
`tests/ui-fixture.cfm` (55 pending + 1 approved), which refuses to run on the
staging and production hostnames and only ever deletes rows carrying its marker.

The suite never confirms the Bulk Approve dialog — it asserts the dialog appears
and then cancels, because confirming would send real notifications through the
live relay. Authentication is injected via `sessionStorage`, which is how this
application actually authenticates.

| ID | Check | Result |
|----|-------|--------|
| TC-125 | Bulk bar hidden until something is selected | **PASS** (after fixing a real bug, below) |
| TC-126 | Only pending rows offer a checkbox | **PASS** — every row's status cell cross-checked against checkbox presence |
| TC-127 | Select-all spans the whole filtered set, not just the visible page | **PASS** — 55 selected while only 10 checkboxes are rendered |
| TC-128 | Select-all limited to eligible rows in the current filtered set | **PASS** — count equals eligible rows after filtering, and clearing the filter does not retroactively select the rest |
| TC-129 | Selection survives paging | **PASS** — count holds across next/previous, and the box is still ticked on return |
| TC-130 | Clear selection empties the count and hides the bar | **PASS** |
| TC-131 | Responsive with 50+ selected (criterion is 50; fixture is 55) | **PASS** — select-all of 55 completes well inside the 5s ceiling |
| TC-132 | Confirmation dialog appears and cancels without approving | **PASS** — selection intact afterwards, nothing submitted |
| TC-133 | No unescaped markup rendered into the grid | **PASS** |
| TC-134 | Mobile viewport usable, no horizontal page overflow | **PASS** at 390×844; the wide table scrolls inside its own container |

This closes TC-73, TC-105, TC-106, TC-108 and TC-109, all previously NOT RUN.

## A real bug the browser found

`#bulkActionBar` carried Bootstrap's `.d-flex`, which is
`display: flex !important`. `syncSelectionUi()` hides the bar with jQuery
`.css('display','none')`, which writes a plain declaration that **loses to
Bootstrap's `!important`** — so the bulk action bar was visible on page load with
nothing selected, and could not be hidden again by clearing the selection.

Only a rendering engine could surface this; every CFML-level test passed
throughout. Fixed by removing `.d-flex` so the display value is owned solely by
the JavaScript, with the reason recorded inline. Both affected tests now pass.

Two further failures were flaws in my own tests, not the application:
- I filtered with `"UIFIXTURE pending 7"`, but DataTables' smart search splits on
  whitespace and matches terms in any order, so `7` matched dozens of rows. The
  assertion now counts eligible rows in the filtered DOM and asserts equality,
  which is the actual acceptance criterion and is robust to search semantics.
- DataTables 2.x renders pagination as `button.page-link` inside
  `li.dt-paging-button`; I was clicking the non-clickable `li`.

## Help text

Both in-page guides were out of date with the features added in iterations 2–4:

- `booking_approvals.html` — new "Approving Several at Once" section covering
  eligibility, that select-all follows the current filter, the selection count,
  the confirmation step, partial-success reporting, and that a failure leaves the
  rest of the batch unaffected.
- `index.html` — new "Booking for Someone Else" subsection ("Reservation For",
  and that both names are kept); the calendar section now says the detail view
  shows the full record; the cancellation section documents the optional reason,
  what the requester is told, and that only administrators can cancel others'
  reservations.

## Combined automated coverage

| Suite | Checks | Result |
|-------|--------|--------|
| `tests/reservation-improvements-verify.cfm` | 33 | 33 passed |
| `tests/playwright/bulk-approval-ui.spec.js` (Chromium) | 10 | 10 passed |
| `tests/playwright/bulk-approval-ui.spec.js` (Mobile Chrome) | 10 | 10 passed |
| **Total** | **53** | **53 passed, 0 failed** |

Re-ran the CFML harness after the visibility fix and the help-text edits: still
33/33, so no regression. Fixtures verified removed after every run.
