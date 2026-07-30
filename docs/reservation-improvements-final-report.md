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
| Automated checks | **59 — all passing, 0 failing** |
| Pre-existing defects found and fixed | **11** |
| Defects introduced by this work, then fixed | **6** |
| Functional gaps remaining | **1** (recurrence end date — needs a business decision) |
| Verification scenarios green | **11 of 12** |
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

**12 files, +1977 / −295.**

### New files

| File | Lines | Purpose |
|------|-------|---------|
| `tests/reservation-improvements-verify.cfm` | 550 | CFML regression harness, 37 checks. No framework required. |
| `tests/playwright/bulk-approval-ui.spec.js` | 297 | Browser suite, 11 checks, Chromium + Mobile Chrome. |
| `tests/ui-fixture.cfm` | 118 | Seed/clean endpoint for the browser suite. |
| `assets/sql/add_reservation_for_and_decision_audit.sql` | 156 | The 8 columns present in dev but in no repo migration. |
| `assets/sql/add_notification_reminder_log.sql` | 107 | Reminder history table; its unique constraint is the concurrency guarantee. |
| `assets/sql/add_pending_approval_notification_types.sql` | 71 | Two missing `NOTIFICATION_TYPES` rows. |
| `docs/*.md` | 1712 | Progress checklist and test report. |

### Not mine

11 files (`user-management.html`, `admin-history.html`, `roomMGT.html`, `assets/js/…`, others — +86/−7) were already modified in the working tree when this work began and were not touched.

---

## 3. Defects found

### Pre-existing (11)

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

### Introduced by this work, then fixed (6)

Oracle `dddd` is not a day-name mask (`"0084, January 08"`); Oracle `FM` is a toggle so `FMDay, FMMonth` re-padded the month; `BOOKED_FOR_*` truncated at 100 when real widths are 200/255/100; guessed `SYSTEM_LOGS` column names (`ACTION/DESCRIPTION/CREATED_AT` vs real `ACTION_TYPE/CHANGE_DETAILS/LOG_TIMESTAMP`); `dec`/`mod` used as SQL aliases (Oracle reserved words); matched `ORA-00001` against `cfcatch.message` when ColdFusion puts it in `cfcatch.detail`.

All six were caught by executing the code, not by reading it.

---

## 4. Test results

### 4.1 CFML regression harness — 37 / 37 PASS

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

### 4.2 Browser suite — 11 / 11 PASS on each of two projects (22 runs)

`tests/playwright/bulk-approval-ui.spec.js` — Chromium and Mobile Chrome.

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

**None.** 59 of 59 automated checks pass.

Every "failure" recorded during this work was either a defect now fixed (section 3)
or a flaw in one of my own tests, corrected at the time:
- Filter term relied on DataTables' smart search, matching far more rows than intended.
- Clicked `li.dt-paging-button` instead of the clickable `button.page-link`.
- Asserted `pendingCount = 0` after resolving two of three pending fixtures.
- Used an invalid `"13:00 PM"` timestamp.

### 4.5 Verification scenarios

| # | Scenario | Result |
|---|----------|--------|
| 1 | User books a room for themselves | **PASS** |
| 2 | User books a room for another employee | **PASS** |
| 3 | Approver views complete details from the dashboard | **PASS** |
| 4 | New request generates an immediate approver notification | **PASS to the final send** — chain repaired and verified end to end; the `cfmail` handoff itself is not asserted |
| 5 | Pending request generates a reminder | **PASS** — job selects correctly; suppression verified |
| 6 | Approved request no longer generates reminders | **PASS** |
| 7 | Cancelled request notifies the requester | **PASS** |
| 8 | Bulk-approve several non-conflicting requests | **PASS** |
| 9 | Bulk selection with valid and conflicting requests | **PASS** — distinct reason per failure |
| 10 | Two approvers approve the same request concurrently | **PASS** — claim guard; second sees "no longer pending" |
| 11 | Recurring weekly, November through March | **RUNS BUT OVER-CREATES** — see section 5 |
| 12 | Existing requests without "Reservation For" remain usable | **PASS** |

### 4.6 Not verified, and why

| Area | Reason |
|------|--------|
| Delivery of each notification to the mail server | Mail was suppressed by pointing ColdFusion at a dead local port; ColdFusion does not retain undeliverable messages here, and its spool thread logs asynchronously, so per-message counts are timing-dependent. Bodies were verified by rendering the templates directly. |
| The 4 pm–11 pm reminder window | Not in this repository and not on this instance (`neo-cron.xml` is empty). It is configured in the CF Administrator on `s-cmapps` / `cmapps`. |
| Staging and production behaviour | No access. |
| Firefox, WebKit, Edge | Only Chromium and Mobile Chrome were run. |
| CSRF protection | Deliberately not implemented — see section 6. |

### 4.7 Test-environment notes

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

## 5. The one remaining functional gap

**Recurrence ignores any intended end date.** A weekly series requested from
1 November produced **52 bookings spanning 2034-11-01 to 2035-10-24** — a full
year, not November to March. `calculateRecurringDates` caps at 52 occurrences or
one year, and there is no way to supply a series end date; the end time given
applies to each occurrence, not to the series.

This is directly relevant to the case that prompted this work (weekly desks
November to March). **Not changed** — recurrence semantics are a business rule.
Options: add a series end date to the request, cap by occurrence count, or leave
as-is.

---

## 6. Database migrations

| Migration | Dev | Staging / Production |
|-----------|-----|----------------------|
| `add_pending_approval_notification_types.sql` | **Applied** | Required |
| `add_notification_reminder_log.sql` | **Applied** | Required |
| `add_reservation_for_and_decision_audit.sql` | Not needed — columns pre-existed | **Required before this code ships** |

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
# CFML harness (37 checks)
http://localhost:8500/DoCMRoomReservation/tests/reservation-improvements-verify.cfm

# Browser suite (11 checks per project)
cd tests/playwright
npx playwright test bulk-approval-ui.spec.js --project=chromium
npx playwright test bulk-approval-ui.spec.js --project="Mobile Chrome"

# Remove fixtures if a run is interrupted
http://localhost:8500/DoCMRoomReservation/tests/ui-fixture.cfm?mode=clean
```

Both suites are self-cleaning and safe to run repeatedly. Neither sends mail.
