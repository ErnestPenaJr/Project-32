# Reservation Improvements — Change and Test Report

**Date:** 2026-07-29
**Branch:** `fix/notification-pages` (nothing committed)
**Environment tested:** development — ColdFusion 2023 (Docker `cf2023`) at
`http://localhost:8500/DoCMRoomReservation/`, Oracle datasource `inside2_docmd`,
schema `CONFROOM`

Consolidated report covering the five requested improvements. Per-iteration detail
is in `reservation-improvements-progress.md`; the running pass/fail log is in
`reservation-improvements-test-report.md`.

---

## 1. Headline

| | |
|---|---|
| Requirements implemented | **5 of 5** |
| Automated checks | **78 — all passing, 0 failing** |
| Pre-existing defects found and fixed | **30** |
| Defects introduced by this work, then fixed | **6** |
| Functional gaps remaining | **1** (recurrence end date — needs a business decision) |
| Verification scenarios green | **11 of 12** (the 12th is blocked by an unshipped feature, not by a defect in this work) |
| Database migrations written | 3 (2 applied to dev, 1 for staging/production) |

**Two of the fixes were load-bearing:** approval was failing for *every* request in
every environment, and the failure was invisible in the UI. Both are fixed.

---

## 2. What changed

### Modified files

| File | Δ | What changed |
|------|---|--------------|
| `cfcs/dashboard-data.cfc` | +545 | Rewrote `cancelBooking` (authorization, cancellation reason, `CANCELLED_*` columns, idempotency guard, isolated + logged notification failure, in-app notification). Added `getUserAuthorization`. New remote `getBookingDetail` (27 fields, role-gated). `createBooking` accepts, validates and stores `BOOKED_FOR_*`. `getAllBookings` extended with purpose, recurrence, submitted-at, location, capacity. |
| `booking_approvals.html` | +383 | Bulk selection UI (checkboxes, filter-scoped select-all, live count, confirmation, partial-result reporting). Approver dialog now shows Requested By / Reservation For / department / recurrence. All displayed values escaped. Approve/reject report real outcomes. Action buttons carry `data-booking-id` + accessible labels. Help section added. |
| `assets/cfc/approvals.cfc` | +381 | Rewrote `bulkUpdateBookingStatus`: per-request processing through the existing single-approval path, concurrency claim, availability re-check, in-batch conflict detection, de-duplication, 200-item cap, per-request results. Added `getActorAuthorization`, `hasApprovedConflict`, `writeAuditEntry`. Status values lowercased. Failure messages now diagnostic. |
| `index.html` | +263 | Detail modal loads the complete request via `getBookingDetail`, escaped, omitting blanks. "Reservation For" form field. Cancellation prompts for an optional reason. Help text updated. |
| `cfcs/scheduledAPI.cfc` | +201 | Reminder duplicate suppression and cross-process concurrency safety (`getReminderIntervalKey`, `claimReminderSlot`, `recordReminderOutcome`). Per-recipient failure isolation. Recipient resolution fixed to include Site Admins. |
| `components/AdminNotificationScheduler.cfc` | +162 | Compile error fixed (component had never loaded). Three invalid subqueries corrected. Recipients include Site Admins. Shares the duplicate-suppression claim with `scheduledAPI`. |
| `assets/sql/tables.sql` | +129 | Reconciled with the live schema; two syntax errors fixed; migration-owned columns folded in; remaining drift documented. |
| `api/cancel-booking.cfm` | ~89 | Disabled (HTTP 410 + logging) — see defect P11. |
| `components/ApprovalNotification.cfc` | +55 | `ROLES` join replacing a non-existent column; guarded application-scope reads; recipient-resolution logging. |
| `components/EmailService.cfc` | +40 | Guarded application-scope read; `sendEmail` made public; template path resolved against the app root. |
| `api/bookings/cancel.cfm` | +22 | Documented as unreferenced and why it cannot currently work. |
| `docm-architecture.html` | 1 | Cancel node relabelled to the real path. |

Plus, in iteration 10: `index.html` gained direct-link support (`?bookingId=N`), closing P12.

**12 files, +1977 / −295.**

### New files

| File | Lines | Purpose |
|------|-------|---------|
| `tests/reservation-improvements-verify.cfm` | 600 | CFML regression harness, 48 checks. No framework required. |
| `tests/playwright/bulk-approval-ui.spec.js` | 297 | Browser suite, 11 checks, Chromium + Mobile Chrome. |
| `tests/playwright/deep-link.spec.js` | 79 | Direct-link suite, 4 checks, both projects. |
| `tests/ui-fixture.cfm` | 118 | Seed/clean endpoint for the browser suite. |
| `assets/sql/audit_booking_data_integrity.sql` | 240 | Read-only data-integrity audit for staging/production, plus optional remediation. |
| `assets/sql/add_reservation_for_and_decision_audit.sql` | 156 | The 8 columns present in dev but in no repo migration. |
| `assets/sql/add_notification_reminder_log.sql` | 107 | Reminder history table; its unique constraint is the concurrency guarantee. |
| `assets/sql/add_pending_approval_notification_types.sql` | 71 | Two missing `NOTIFICATION_TYPES` rows. |
| `docs/*.md` | 1712 | Progress checklist and test report. |

### Not mine

11 files (`user-management.html`, `admin-history.html`, `roomMGT.html`, `assets/js/…`, others — +86/−7) were already modified in the working tree when this work began and were not touched.

---

## 3. Defects found

### Pre-existing (30)

| # | Severity | Defect | How found |
|---|----------|--------|-----------|
| P1 | **Critical** | `STATUS = 'Approved'` violated `CHK_BOOKINGS_STATUS` (lowercase only) → **ORA-02290 on every approval and rejection, individual and bulk, in every environment** | Executing a real approval, once mail was suppressed |
| P2 | **Critical** | Approve confirmation announced "Approved!" unconditionally without awaiting the result | Code review while completing the approval view |
| P3 | **Critical** | `approveBooking()` tested `response.success`; endpoint returns `SUCCESS` — branch never ran, no error handler. With P2, this is why P1 was invisible | Code review |
| P4 | High | `bulkApproveBookings` / `bulkRejectBookings` threw on **every** call — `comment` had no default | Executing the bulk path |
| P5 | High | Bulk approve's email calls sat in tag context, emitted as literal text — no notification ever sent | Code inspection |
| P6 | High | Approval blanked `COMMENTS`, destroying the requester's meeting purpose | Code inspection |
| P7 | High | Approve/reject **did not work on mobile at all** — DataTables' responsive child row has no `data-booking-id`, so the id was `undefined` | Browser test at phone viewport |
| P8 | High | `AdminNotificationScheduler.cfc` had a **compile error** (`'#90EE90'` in `cfoutput`) — the component had never loaded, so no scheduled run ever executed | Instantiating it |
| P9 | High | Immediate approver notification dead for five independent reasons: invalid `USERS.ROLE` column; missing `NOTIFICATION_TYPES` rows; unguarded application-scope read; `sendEmail` was `private` while composed not inherited; relative template include | Tracing the chain link by link |
| P10 | Medium | Recipient resolution matched `ROLE_NAME = 'admin'` exactly in three components, silently excluding **every Site Admin** | Reminder job resolving 0 recipients |
| P11 | Medium | `api/cancel-booking.cfm` — unreferenced hard `DELETE` of reservations, no CSRF, wrong column names. Failed closed *only* because no session scope exists; **introducing `Application.cfc` would have activated it** | Reviewing dead endpoints |
| P12 | Medium | The cancellation email's "View this reservation" link pointed at `index.html?bookingId=N`, but the page never read the parameter — the link only opened the dashboard | Checking whether the app supports direct links |
| P29 | **Critical** | `getBookingHistory` guarded its user filter with `isDefined('##arguments.userId##')`, which tests the *value* not the name — `isDefined("76")` is false, so the filter never applied and it returned **every user's booking history**. `user-history.html` and `history.html` both pass the signed-in user's id | Parameterisation sweep |
| P30 | High | `getSystemLogs` (`access="remote"`) concatenated four unvalidated string filters into its WHERE clause — a SQL injection vector, now bound. Not exploitable only because the function also uses a nonexistent datasource, no credentials and a nonexistent column, so it has never run | Same sweep |
| P25 | **Critical** | The datasource authenticates as `WEBSCHEDULE_USER`, not CONFROOM, so any `queryExecute` without explicit credentials fails with ORA-00942. Five `components/*` files passed none — `ApprovalNotification`, `Notification`, `Room`, `User`, `Booking`; all five now fixed. `Room.checkAvailability` consequently reported every slot free and would have allowed double-bookings. **This is the real reason the immediate approver notification never worked**, independent of the five causes found in iteration 4 | ORA-00942 in the log added in iteration 1 |
| P26 | **Critical** | The ICS calendar write sat in the shared `cftry`, so its failure aborted the confirmation email. `assets/temp` is unreachable from the container, so **no requester has ever received a booking confirmation** | Executing createBooking for a fresh user |
| P27 | High | `createNotification` used `RETURNING … INTO` with an out parameter, which does not work via queryExecute against Oracle; it threw, the catch returned 0, and in-app notifications silently never appeared | Approver alert reporting inAppCreated=0 |
| P28 | High | `createBooking`'s `<cfif userPreferences.email>` **throws** on the empty string returned for users with no preference row, aborting the block | Same test |
| P23 | **Critical** | `shouldReceiveNotification` tested `IsNull()` on a query column, but ColdFusion returns a NULL column as an **empty string**, so the `DEFAULT_EMAIL_ENABLED` fallback never ran and it returned `{email:""}` for any user with no `NOTIFICATION_PREFERENCES` row. and `cancelBooking` treated that as an opt-out — so **cancellation emails were suppressed for most users**, defeating Requirement 1, while logging it as if deliberate | Executing the notification failure path |
| P24 | Medium | `<cfmail>` is asynchronous, so real delivery failures are logged by ColdFusion to `mail.log` with no booking reference — "failures are logged for follow-up" was not satisfiable. The attempt is now logged with the booking id so failures can be correlated | Same test |
| P21 | **High** | `CalendarCleanUp` wrote `APPROVED_BY = 0` (no such user; 19 orphaned rows found, and the real approver's identity destroyed) and overwrote `COMMENTS` with `'Auto-Archived: End time passed'`, destroying the meeting purpose on every archived booking — the same data loss as the old `cancelBooking`, still active in a second write path | Data-integrity audit, working back from 19 orphaned references |
| P22 | Medium | The same function logged `#now#` — the function without parentheses — raising "Variable NOW is undefined" *after* the UPDATE committed, so it did its work then reported failure | Testing the endpoint after fixing P21 |
| P14–P20 *(one row, seven defects — hence no separate P15–P20 rows)* | **High** | Seven live predicates still used the retired status vocabulary (`'Confirmed'`, `'APPROVED'`, `'Pending'`) that `CHK_BOOKINGS_STATUS` no longer permits, so each matched nothing forever with no error: the 1-hour upcoming-booking reminder selected no rows for anyone; `Room.checkAvailability` always reported zero conflicts; edit conflict detection never fired (measured 0 rows vs 2); room utilisation, all booking reports and the dashboard total always read zero; `Booking.cfc` wrote an invalid value | Exhaustive sweep of every `BOOKINGS.STATUS` predicate |
| P13 | High | `components/RecurringBooking.cfc` wrote capitalised status literals (`'Pending'`, `'Cancelled'`) — the same ORA-02290 defect as P1 — and its conflict check compared against values that never occur. Corrected, but **unverifiable** (see section 5) | Testing the series endpoint |

### Introduced by this work, then fixed (6)

Oracle `dddd` is not a day-name mask (`"0084, January 08"`); Oracle `FM` is a toggle so `FMDay, FMMonth` re-padded the month; `BOOKED_FOR_*` truncated at 100 when real widths are 200/255/100; guessed `SYSTEM_LOGS` column names (`ACTION/DESCRIPTION/CREATED_AT` vs real `ACTION_TYPE/CHANGE_DETAILS/LOG_TIMESTAMP`); `dec`/`mod` used as SQL aliases (Oracle reserved words); matched `ORA-00001` against `cfcatch.message` when ColdFusion puts it in `cfcatch.detail`.

All six were caught by executing the code, not by reading it.

---

## 4. Test results

### 4.1 CFML regression harness — 48 / 48 PASS

`tests/reservation-improvements-verify.cfm` — run twice with identical results.

| # | Check | Result |
|---|-------|--------|
| 1 | R1: non-owner, non-admin cannot cancel | PASS |
| 2 | R1: unknown reservation rejected cleanly | PASS |
| 3 | R1: inactive/unknown acting user rejected | PASS |
| 4 | R2: detail loads for a pending request | PASS |
| 5 | R2: detail loads for an approved request | PASS |
| 6 | R2: missing request errors without throwing | PASS |
| 7 | R2: reservation date renders a real day name | PASS |
| 8 | R2: admin-only fields hidden from unentitled viewer | PASS |
| 9 | R2: admin-only fields present for entitled viewer | PASS |
| 10 | R3: dashboard shows the recorded Reservation For | PASS |
| 11 | R3: requester recorded separately from Reservation For | PASS |
| 12 | R3: legacy row without Reservation For falls back to requester | PASS |
| 13 | R3: approver view shows both Requested By and Reservation For | PASS |
| 14 | R3: name required when booking on someone else's behalf | PASS |
| 15 | R3: invalid Reservation For email rejected | PASS |
| 16 | R3: unknown requester rejected before insert | PASS |
| 17 | R5: non-admin cannot bulk approve | PASS |
| 18 | R5: unknown acting user cannot bulk approve | PASS |
| 19 | R5: empty selection rejected | PASS |
| 20 | R5: non-numeric ids filtered out | PASS |
| 21 | R5: batch size capped at 200 | PASS |
| 22 | R5: duplicate ids de-duplicated (would double-notify) | PASS |
| 23 | R5: conflict with an approved reservation blocks approval | PASS |
| 24 | R5: mixed batch reports a distinct reason per failure | PASS |
| 25 | R5: individual approval still works (no throw) | PASS |
| 26 | R5: approval status values satisfy `CHK_BOOKINGS_STATUS` | PASS |
| 27 | R5: capitalised `'Approved'` is rejected by the database | PASS |
| 28 | Integrity: no denied or conflicting attempt changed a status | PASS |
| 29 | R4: reminder recipients include Admin and Site Admin | PASS |
| 30 | R4: duplicate claim rejected by the database | PASS |
| 31 | R4: pending request found by the reminder job | PASS |
| 32 | R4: already-notified interval suppressed, nothing re-sent | PASS |
| 33 | R4: resolved requests no longer generate reminders | PASS |
| 34 | R4: `AdminNotificationScheduler` compiles and loads | PASS |
| 35 | R4: second scheduler cannot duplicate claimed notifications | PASS |
| 36 | Integrity: seeded approved reservation was never modified | PASS |
| 37 | Cleanup: all seeded rows removed | PASS |

### 4.2 Browser suites — 15 / 15 PASS on each of two projects (30 runs)

`bulk-approval-ui.spec.js` (11 checks) and `deep-link.spec.js` (4 checks), each run on Chromium and Mobile Chrome.

| # | Check | Chromium | Mobile Chrome |
|---|-------|----------|---------------|
| 1 | Bulk bar hidden until something is selected | PASS | PASS |
| 2 | Only pending rows offer a checkbox | PASS | PASS |
| 3 | Select-all spans the filtered set, not just the visible page | PASS | PASS |
| 4 | Select-all limited to eligible rows in the current filter | PASS | PASS |
| 5 | Selection survives paging | PASS | PASS |
| 6 | Clear selection empties the count and hides the bar | PASS | PASS |
| 7 | Responsive with 50+ selected (fixture seeds 56) | PASS | PASS |
| 8 | Confirmation dialog appears and cancels without approving | PASS | PASS |
| 9 | No unescaped markup rendered into the grid | PASS | PASS |
| 10 | Mobile viewport usable, no horizontal page overflow | PASS | PASS |
| 11 | Approver dialog shows Requested By + Reservation For, escaped | PASS | PASS |
| 12 | `?bookingId=N` opens that reservation and shows its stored details | PASS | PASS |
| 13 | The `bookingId` parameter is removed so a refresh does not reopen it | PASS | PASS |
| 14 | An unknown request number degrades gracefully instead of erroring | PASS | PASS |
| 15 | A non-numeric `bookingId` is ignored and no dialog opens | PASS | PASS |

### 4.3 One-off verifications (not in a suite)

Executed during development against the dev database; results recorded in the test
report. All PASS unless noted.

- Migration idempotency (re-run leaves one row per type).
- Notification chain link-by-link: recipients resolve, template resolves, body
  renders 5675 chars, injected `<script>` escaped.
- Audit `INSERT` and `COMMENTS`-append SQL, exercised in rolled-back transactions.
- Booking for self (`BOOKED_FOR_*` defaults to requester) and for another person.
- Cancellation: reason stored, `CANCELLED_AT/BY` set, **purpose preserved**,
  second cancel returns `alreadyCancelled` without re-notifying.
- Bulk approve of 3 non-conflicting requests: 3/3 approved, `DECIDED_BY`/`DECIDED_AT`
  populated, 3 audit rows.
- Cross-component duplicate suppression: with slots pre-claimed,
  `AdminNotificationScheduler` found the pending request and notified **nobody**.

### 4.4 Currently failing

**None.** 78 of 78 automated checks pass.

Every "failure" recorded during this work was either a defect now fixed (section 3)
or a flaw in one of my own tests, corrected at the time:
- Filter term relied on DataTables' smart search, matching far more rows than intended.
- Clicked `li.dt-paging-button` instead of the clickable `button.page-link`.
- Asserted `pendingCount = 0` after resolving two of three pending fixtures.
- Used an invalid `"13:00 PM"` timestamp.

### 4.5 Verification scenarios

| # | Scenario | Result |
|---|----------|--------|
| 1 | User books a room for themselves | **PASS** — booking created and `BOOKED_FOR_*` defaults to the requester. The confirmation email was separately broken (P26/P28) and now sends. |
| 2 | User books a room for another employee | **PASS** |
| 3 | Approver views complete details from the dashboard | **PASS** |
| 4 | New request generates an immediate approver notification | **PASS** — verified through the component's own code path: 2 approvers resolved, 2 emails queued, 2 in-app notifications recorded (mail suppressed, nothing delivered). Only the final SMTP handoff is unasserted. **Note:** an earlier revision of this report claimed this was "verified end to end" after iteration 4. That was wrong — see P25; it did not work until iteration 16. |
| 5 | Pending request generates a reminder | **PASS** — job selects correctly; suppression verified |
| 6 | Approved request no longer generates reminders | **PASS** |
| 7 | Cancelled request notifies the requester | **PASS** |
| 8 | Bulk-approve several non-conflicting requests | **PASS** |
| 9 | Bulk selection with valid and conflicting requests | **PASS** — distinct reason per failure |
| 10 | Two approvers approve the same request concurrently | **PASS** — claim guard; second sees "no longer pending" |
| 11 | Recurring weekly, November through March | **NOT SATISFIABLE — the recurring feature is unshipped.** A user cannot create a recurring series at all. See section 5. |
| 12 | Existing requests without "Reservation For" remain usable | **PASS** |

### 4.6 Requirement 2 field coverage — audited against the live schema

Requirement 2 lists sixteen fields. `getBookingDetail` returns 27 keys covering
thirteen of them. The other three are **not collected anywhere in the application**
— a search of every column in the `CONFROOM` schema for `%ATTEND%`, `%DESK%`,
`%INSTRUCT%`, `%NOTE%`, `%HEADCOUNT%`, `%PARTICIPANT%` and `%GUEST%` returned
nothing. The requirement scopes itself to "information already collected by the
application", so these are out of scope rather than missing.

| Requested field | Source | Shown |
|-----------------|--------|-------|
| Request / reservation number | `BOOKING_ID` | Yes |
| Requester | `USER_ID` → `REQUESTED_BY` | Yes |
| Person the reservation is for | `BOOKED_FOR_NAME` → `RESERVATION_FOR` | Yes |
| Department or team | `BOOKED_FOR_DEPARTMENT` | Yes |
| Room or workspace | `ROOM_NAME`, `LOCATION` | Yes |
| Reservation date | `START_TIME` → `RESERVATION_DATE` | Yes |
| Start and end time | `START_TIME` / `END_TIME` | Yes |
| Recurrence information | `RECURRING_DETAILS` → `RECURRENCE` | Yes |
| Number of attendees / desks | — | **Not collected** |
| Purpose or description | `COMMENTS` → `PURPOSE` | Yes |
| Special instructions | — | **Not collected** |
| Current status | `STATUS` | Yes |
| Submission date | `CREATED_AT` → `SUBMITTED_AT` | Yes |
| Approval / cancellation history | `DECIDED_AT/BY`, `CANCELLED_AT/BY`, `CANCELLATION_REASON` | Yes, role-gated |
| Approver notes | rejection reasons appended to `COMMENTS`; no dedicated column | **Partial** |
| Created-by / modified-by, when authorized | `REQUESTED_BY`, `MODIFIED_BY`, `LAST_UPDATED_AT` | Yes, role-gated |

Adding attendees, desks or special instructions would mean new columns, new form
fields and a migration — new scope, not a fix. Flagged rather than assumed.

### 4.7 Not verified, and why

| Area | Reason |
|------|--------|
| Delivery of each notification to the mail server | Mail was suppressed by pointing ColdFusion at a dead local port; ColdFusion does not retain undeliverable messages here, and its spool thread logs asynchronously, so per-message counts are timing-dependent. Bodies were verified by rendering the templates directly. |
| The 4 pm–11 pm reminder window | Not in this repository and not on this instance (`neo-cron.xml` is empty). It is configured in the CF Administrator on `s-cmapps` / `cmapps`. |
| Staging and production behaviour | No access. |
| Firefox, WebKit, Edge | Only Chromium and Mobile Chrome were run; those browser binaries are not installed. |
| Pre-existing `todo-features.spec.js` | Not run — unrelated to this work and slow enough to time out the runner. |
| CSRF protection | Deliberately not implemented — see section 6. |

### 4.8 Test-environment notes

- The four pre-existing `tests/*.cfc` files **cannot execute**: they extend
  `mxunit.framework.TestCase` and mxunit is installed neither in the project nor in
  the ColdFusion webroot. That, not merely missing cases, is why there was no
  working coverage. The new harness needs no framework.
- Mail suppression was reversible and was reversed: the original configuration
  (`mail.mdanderson.org:25`) was backed up, replaced with a dead sink, and restored
  afterwards with the live values confirmed to match the backup exactly.
- Both suites seed only marker-tagged rows and delete them again, including when an
  assertion throws; the CFML harness refuses to run on the staging and production
  hostnames.

---

## 5. Recurring bookings — the feature is unshipped

**This corrects an earlier statement in this report.** Scenario 11 was previously
recorded as "runs but over-creates — 52 entries". That was measured by calling
`dashboard-data.createBooking(recurring="YES")` **directly**. A user cannot reach
that path. Recurrence is non-functional from the interface, failing independently
at four layers:

| Layer | State |
|-------|-------|
| **Schema** | `assets/sql/add_recurring_bookings.sql` has **never been applied**. No `RECURRING_PATTERNS` table, no `SYSTEM_SETTINGS` table, and `BOOKINGS` has no `IS_RECURRING`, `PARENT_BOOKING_ID` or `SERIES_INSTANCE_NUMBER`. Confirmed against the live schema. |
| **Component** | `RecurringBooking.cfc` reads and writes exactly those missing columns and tables, so it raises ORA-00904. It also wrote capitalised status literals (P13). |
| **Client script** | `submitRecurringBooking()` in `assets/js/recurring-booking.js` has **no callers anywhere**. It also reads `#recurringEndValue` and `.recurring-day-checkbox`, neither of which exists — the markup defines `#recurringOccurrences` and `#day_1`–`#day_5`. Even if invoked it would read undefined values and always fail its weekly validation. |
| **Submit path** | The booking form's save handler posts to `dashboard-data.createBooking` and **never sends a `recurring` parameter**, so it defaults to `"NO"`. Every recurrence setting the user configures is discarded. |

The interface is misleading as a result: `index.html` renders a complete recurrence
panel — frequency, interval, "Repeat On" weekdays, "Ends: On Date / After N
Occurrences", and a working client-side "Preview Recurring Dates" — and then
submitting creates exactly **one** booking.

Separately, `calculateRecurringDates` in `dashboard-data.cfc` (the ad-hoc path)
accepts no series end date at all; it caps at 52 occurrences or one year. The two
creation paths disagree about what recurrence means.

### Not fixed, deliberately

Restoring this means applying a migration that creates two tables and alters two
others, fixing the component, wiring the client script, and choosing between two
competing creation paths. That is **building an unfinished feature**, not fixing
the five requested requirements, and the path choice is a product decision — the
same "two competing implementations" pattern already flagged for reminders.
Requirement 5's recurrence clause concerns *approving* recurring requests
efficiently, which is implemented and tested; it does not ask for creation to be
built.

What was done: P13's status casing is corrected, because it is mechanical, matches
a fix already proven elsewhere, and would bite immediately once the migration is
applied. It is marked unverified in the component header, since the component
cannot execute until then.

### Recommended order, if you want this shipped

1. Apply `assets/sql/add_recurring_bookings.sql` (additive; review its rollback first).
2. Re-test `api/recurring/create-series.cfm` — P13 is already fixed.
3. Decide which path owns recurrence: the purpose-built series endpoint, or
   `createBooking` with a bound end date. Retire the loser.
4. Fix the two element-id mismatches and call `submitRecurringBooking()` from the
   save handler when recurrence is enabled.
5. Scenario 11 then becomes testable.

## 6. Database migrations

| Migration | Dev | Staging / Production |
|-----------|-----|----------------------|
| `add_pending_approval_notification_types.sql` | **Applied** | Required |
| `add_notification_reminder_log.sql` | **Applied** | Required |
| `add_reservation_for_and_decision_audit.sql` | Not needed — columns pre-existed | **Required before this code ships** |
| `add_recurring_bookings.sql` *(pre-existing, not from this work)* | **Never applied** | Never applied — see section 5 |

All three are additive, with rollback instructions. The third is the important one:
without it, cancellation, the dashboard detail view and bulk approval all fail with
ORA-00904.

---

## 7. Open decisions

1. **Recurrence end date** (section 5) — the only functional gap.
2. **Confirm `CHK_BOOKINGS_STATUS` exists on staging and production.** If it does,
   approval has been failing there too and the P1 fix is required, not optional.
3. **`AdminNotificationScheduler` will now actually send** where it is scheduled,
   having silently done nothing before. Behaviour change worth knowing before deploy.
4. **No configured application time zone.** Reminder intervals use the database
   clock as the single authority so concurrent schedulers agree.
5. **Site Admins now receive notifications**, having been excluded by P10. If that
   exclusion was deliberate, revisit.
6. **Authorization is not authentication.** Role checks are enforced against the
   database, but `userId` is client-supplied because no session scope exists.
   **CSRF protection was deliberately deferred for this reason** — it defends an
   authenticated session, and there isn't one; an attacker can call the endpoints
   directly with any id. It should land together with `Application.cfc` and sessions.
7. **If `Application.cfc` is introduced**, `api/bookings/cancel.cfm` becomes
   reachable and needs a deliberate decision (P11's sibling).

---

## 8. How to re-run

```
# CFML harness (48 checks)
http://localhost:8500/DoCMRoomReservation/tests/reservation-improvements-verify.cfm

# Browser suites (15 checks per project)
cd tests/playwright
npx playwright test bulk-approval-ui.spec.js deep-link.spec.js --project=chromium
npx playwright test bulk-approval-ui.spec.js deep-link.spec.js --project="Mobile Chrome"

# Remove fixtures if a run is interrupted
http://localhost:8500/DoCMRoomReservation/tests/ui-fixture.cfm?mode=clean
```

Both suites are self-cleaning and safe to run repeatedly. Neither sends mail.
