# DoCM Room Reservation System - Integration Tests

## Test Suite Overview

This document describes the integration tests for the DoCM Room Reservation System using Playwright MCP for browser automation and end-to-end testing.

---

## Test Categories

### 1. Booking Workflow Integration Tests
**Purpose:** Verify complete booking creation, modification, and cancellation workflows

### 2. Calendar Interaction Tests
**Purpose:** Verify calendar filtering, searching, and event interaction functionality

### 3. Notification System Integration Tests
**Purpose:** Verify email and in-app notification delivery across workflows

### 4. User Permission Tests
**Purpose:** Verify role-based access control and permission enforcement

---

## Integration Test Scenarios

### Test Group 1: Complete Booking Workflow

#### Test 1.1: Create Standard Booking
**Scenario:** User creates a single booking for a conference room

**Prerequisites:**
- User is logged in as epena1
- At least one room is available in the system

**Steps:**
1. Navigate to room reservation dashboard
2. Click "Book a Room" button
3. Select room from dropdown
4. Select future date and time
5. Enter meeting title and comments
6. Submit booking form
7. Verify success message appears
8. Verify booking appears on calendar

**Expected Results:**
- ✅ Booking created successfully
- ✅ Booking ID generated
- ✅ Status set to "Pending" or "Approved" based on room approval settings
- ✅ Event appears on calendar with correct details
- ✅ Notification sent to user (if enabled)

**Test Data:**
```javascript
{
    room: "Conference Room A",
    startTime: "Tomorrow 10:00 AM",
    endTime: "Tomorrow 11:00 AM",
    meetingTitle: "Integration Test Meeting",
    comments: "Automated test booking"
}
```

---

#### Test 1.2: Edit Existing Booking
**Scenario:** User modifies their existing booking

**Prerequisites:**
- User has at least one existing booking
- Booking status is "Pending" or "Approved"
- Booking start time is in the future

**Steps:**
1. Navigate to room reservation dashboard
2. Click on existing booking event on calendar
3. Click "Edit" button in booking detail modal
4. Modify meeting title or time
5. Submit changes
6. Verify revision number increments
7. Verify IS_MODIFIED flag is set

**Expected Results:**
- ✅ Booking updated successfully
- ✅ Revision number incremented (1, 2, 3, etc.)
- ✅ IS_MODIFIED flag set to 'Y'
- ✅ REVISION_DATE updated to current timestamp
- ✅ MODIFIED_BY set to current user ID
- ✅ Modified badge appears on calendar event
- ✅ Revision notification email sent (if enabled)

**Test Data:**
```javascript
{
    originalMeetingTitle: "Integration Test Meeting",
    updatedMeetingTitle: "Updated Integration Test Meeting",
    originalTime: "Tomorrow 10:00 AM - 11:00 AM",
    updatedTime: "Tomorrow 10:30 AM - 11:30 AM"
}
```

---

#### Test 1.3: Cancel Booking
**Scenario:** User cancels their existing booking

**Prerequisites:**
- User has at least one existing booking
- Booking has not started yet

**Steps:**
1. Navigate to room reservation dashboard
2. Click on existing booking event on calendar
3. Click "Cancel" button in booking detail modal
4. Confirm cancellation in dialog
5. Verify booking status changes to "Cancelled"
6. Verify event is removed from calendar or marked as cancelled

**Expected Results:**
- ✅ Booking status updated to "Cancelled"
- ✅ Event removed from active calendar view
- ✅ Cancellation notification sent to user
- ✅ Room becomes available for others to book

---

### Test Group 2: Recurring Booking Workflow

#### Test 2.1: Create Daily Recurring Booking
**Scenario:** User creates a daily recurring booking pattern

**Prerequisites:**
- User is logged in
- Room allows recurring bookings (RECURRING_ENABLED = 'Y')

**Steps:**
1. Navigate to room reservation dashboard
2. Click "Book a Room" button
3. Select room from dropdown
4. Select recurring pattern: "Daily"
5. Set interval to 1 (every day)
6. Set end type to "Occurrences" with 5 occurrences
7. Preview recurring dates
8. Verify preview shows 5 consecutive days
9. Submit booking
10. Verify series created successfully

**Expected Results:**
- ✅ Parent booking created with PARENT_BOOKING_ID = NULL
- ✅ 5 child bookings created with PARENT_BOOKING_ID referencing parent
- ✅ Each instance has correct SERIES_INSTANCE_NUMBER (1, 2, 3, 4, 5)
- ✅ All instances marked with IS_RECURRING = 'Y'
- ✅ RECURRING_PATTERNS record created
- ✅ All instances appear on calendar
- ✅ Duration preserved across all instances

**Test Data:**
```javascript
{
    frequency: "DAILY",
    intervalCount: 1,
    endType: "OCCURRENCES",
    maxOccurrences: 5,
    startTime: "Tomorrow 2:00 PM",
    endTime: "Tomorrow 3:00 PM",
    duration: "1 hour"
}
```

---

#### Test 2.2: Create Weekly Recurring Booking
**Scenario:** User creates a weekly recurring booking for specific days

**Prerequisites:**
- User is logged in
- Room allows recurring bookings

**Steps:**
1. Navigate to room reservation dashboard
2. Click "Book a Room" button
3. Select room from dropdown
4. Select recurring pattern: "Weekly"
5. Select days: Monday, Wednesday, Friday
6. Set interval to 1 (every week)
7. Set end type to "Occurrences" with 6 occurrences
8. Preview recurring dates
9. Verify preview shows 2 weeks of Mon/Wed/Fri
10. Submit booking

**Expected Results:**
- ✅ 6 bookings created (2 weeks × 3 days)
- ✅ Only Monday, Wednesday, Friday instances created
- ✅ DAYS_OF_WEEK stored as "MON,WED,FRI" in RECURRING_PATTERNS
- ✅ All instances appear on calendar
- ✅ Date calculation correct for selected days

**Test Data:**
```javascript
{
    frequency: "WEEKLY",
    intervalCount: 1,
    endType: "OCCURRENCES",
    maxOccurrences: 6,
    daysOfWeek: ["MON", "WED", "FRI"],
    startTime: "Next Monday 9:00 AM",
    endTime: "Next Monday 10:00 AM"
}
```

---

#### Test 2.3: Create Monthly Recurring Booking
**Scenario:** User creates a monthly recurring booking

**Prerequisites:**
- User is logged in
- Room allows recurring bookings

**Steps:**
1. Navigate to room reservation dashboard
2. Click "Book a Room" button
3. Select room from dropdown
4. Select recurring pattern: "Monthly"
5. Set interval to 1 (every month)
6. Set end type to "Occurrences" with 3 occurrences
7. Preview recurring dates
8. Verify preview shows same day of month for 3 consecutive months
9. Submit booking

**Expected Results:**
- ✅ 3 bookings created (3 consecutive months)
- ✅ Same day of month used for all instances
- ✅ Duration preserved across all instances
- ✅ All instances appear on calendar

**Test Data:**
```javascript
{
    frequency: "MONTHLY",
    intervalCount: 1,
    endType: "OCCURRENCES",
    maxOccurrences: 3,
    startTime: "15th of next month 1:00 PM",
    endTime: "15th of next month 2:00 PM"
}
```

---

#### Test 2.4: Cancel Entire Recurring Series
**Scenario:** User cancels all instances of a recurring booking

**Prerequisites:**
- User has an existing recurring booking series
- Series has multiple future instances

**Steps:**
1. Navigate to room reservation dashboard
2. Click on any instance of the recurring series
3. Click "Cancel Series" button
4. Confirm cancellation for entire series
5. Verify all instances are cancelled

**Expected Results:**
- ✅ All instances in series marked as "Cancelled"
- ✅ All future instances removed from calendar
- ✅ PARENT_BOOKING_ID link maintained for audit trail
- ✅ Cancellation notifications sent for all instances

---

### Test Group 3: Calendar Filtering and Search

#### Test 3.1: Filter by Room
**Scenario:** User filters calendar to show only bookings for specific room

**Prerequisites:**
- User is logged in
- Multiple rooms exist with bookings

**Steps:**
1. Navigate to room reservation dashboard
2. Select specific room from "Room Filter" dropdown
3. Verify calendar updates to show only that room's bookings
4. Clear filter
5. Verify all bookings reappear

**Expected Results:**
- ✅ Calendar displays only selected room's bookings
- ✅ Event count updates correctly
- ✅ Other rooms' bookings are hidden
- ✅ Clearing filter restores all bookings

---

#### Test 3.2: Filter by Status
**Scenario:** User filters calendar to show only bookings with specific status

**Prerequisites:**
- User is logged in
- Bookings exist with different statuses (Pending, Approved, Confirmed)

**Steps:**
1. Navigate to room reservation dashboard
2. Select "Pending" from "Status Filter" dropdown
3. Verify only pending bookings are shown
4. Change to "Approved" status
5. Verify only approved bookings are shown
6. Clear filter
7. Verify all bookings reappear

**Expected Results:**
- ✅ Calendar displays only bookings matching selected status
- ✅ Status badges correctly reflect filtered status
- ✅ Changing filter immediately updates calendar
- ✅ Clearing filter restores all bookings

---

#### Test 3.3: My Bookings Only Toggle
**Scenario:** User toggles "My Bookings Only" to see only their bookings

**Prerequisites:**
- User is logged in
- Calendar has bookings from multiple users

**Steps:**
1. Navigate to room reservation dashboard
2. Check "My Bookings Only" toggle
3. Verify only current user's bookings are shown
4. Uncheck "My Bookings Only" toggle
5. Verify all users' bookings reappear

**Expected Results:**
- ✅ Calendar displays only current user's bookings when toggled
- ✅ Other users' bookings are hidden
- ✅ Toggle off restores all bookings
- ✅ User ID filtering works correctly

---

#### Test 3.4: Search by Meeting Title
**Scenario:** User searches for bookings by meeting title

**Prerequisites:**
- User is logged in
- Calendar has bookings with different meeting titles

**Steps:**
1. Navigate to room reservation dashboard
2. Enter search text in "Search" input (e.g., "Team Meeting")
3. Verify calendar updates to show matching bookings
4. Clear search
5. Verify all bookings reappear

**Expected Results:**
- ✅ Calendar displays only bookings with matching titles
- ✅ Search is case-insensitive
- ✅ Partial matches are found
- ✅ Search debounce works (300ms delay)
- ✅ Clearing search restores all bookings

---

#### Test 3.5: Combined Filters
**Scenario:** User applies multiple filters simultaneously

**Prerequisites:**
- User is logged in
- Calendar has diverse bookings

**Steps:**
1. Navigate to room reservation dashboard
2. Select specific room from "Room Filter"
3. Select "Approved" from "Status Filter"
4. Check "My Bookings Only"
5. Enter search text
6. Verify only bookings matching ALL criteria are shown
7. Clear all filters
8. Verify all bookings reappear

**Expected Results:**
- ✅ All filters work together (AND logic)
- ✅ Only bookings matching all criteria are displayed
- ✅ Clearing one filter updates results appropriately
- ✅ Clearing all filters restores all bookings

---

### Test Group 4: User Permission Tests

#### Test 4.1: Creator Can Edit Own Booking
**Scenario:** User edits their own booking

**Prerequisites:**
- User is logged in as booking creator
- Booking exists and has not started

**Steps:**
1. Navigate to room reservation dashboard
2. Click on user's own booking
3. Verify "Edit" button is visible and enabled
4. Click "Edit" button
5. Modify booking details
6. Submit changes
7. Verify changes are saved

**Expected Results:**
- ✅ Edit button visible for own bookings
- ✅ Edit permission granted
- ✅ Changes saved successfully
- ✅ Revision tracking updated

---

#### Test 4.2: User Cannot Edit Other User's Booking
**Scenario:** Regular user attempts to edit another user's booking

**Prerequisites:**
- User is logged in as regular user (not admin)
- Booking exists from different user

**Steps:**
1. Navigate to room reservation dashboard
2. Click on another user's booking
3. Verify "Edit" button is hidden or disabled
4. Attempt to modify booking (if possible)
5. Verify permission denied

**Expected Results:**
- ✅ Edit button not visible for other users' bookings
- ✅ Edit permission denied if attempted
- ✅ Error message displayed if unauthorized action attempted

---

#### Test 4.3: Admin Can Edit Any Booking
**Scenario:** Admin user edits any booking

**Prerequisites:**
- User is logged in as admin
- Bookings exist from various users

**Steps:**
1. Navigate to room reservation dashboard
2. Click on any user's booking
3. Verify "Edit" button is visible and enabled
4. Click "Edit" button
5. Modify booking details
6. Submit changes
7. Verify changes are saved

**Expected Results:**
- ✅ Edit button visible for all bookings (admin privilege)
- ✅ Edit permission granted
- ✅ Changes saved successfully
- ✅ MODIFIED_BY field set to admin's user ID
- ✅ Revision tracking updated

---

#### Test 4.4: Cannot Edit Started Booking
**Scenario:** User attempts to edit a booking that has already started

**Prerequisites:**
- User is logged in
- Booking exists with start time in the past

**Steps:**
1. Navigate to room reservation dashboard
2. Click on started booking
3. Verify "Edit" button is hidden or disabled
4. Verify message indicates booking cannot be edited

**Expected Results:**
- ✅ Edit button not visible for started bookings
- ✅ Edit permission denied
- ✅ User-friendly message explains why editing is not allowed

---

### Test Group 5: Conflict Detection

#### Test 5.1: Detect Overlapping Booking Conflict
**Scenario:** User attempts to create booking that overlaps existing booking

**Prerequisites:**
- User is logged in
- Existing booking: Conference Room A, Tomorrow 10:00 AM - 11:00 AM

**Steps:**
1. Navigate to room reservation dashboard
2. Click "Book a Room"
3. Select "Conference Room A"
4. Select Tomorrow 10:30 AM - 11:30 AM (overlaps existing)
5. Submit booking
6. Verify conflict detected
7. Verify error message displayed

**Expected Results:**
- ✅ Conflict detected before booking created
- ✅ Error message lists conflicting booking details
- ✅ Booking not created
- ✅ User prompted to select different time or room

**Test Data:**
```javascript
{
    existingBooking: {
        room: "Conference Room A",
        startTime: "Tomorrow 10:00 AM",
        endTime: "Tomorrow 11:00 AM"
    },
    attemptedBooking: {
        room: "Conference Room A",
        startTime: "Tomorrow 10:30 AM",
        endTime: "Tomorrow 11:30 AM"
    }
}
```

---

#### Test 5.2: Allow Adjacent Bookings
**Scenario:** User creates booking immediately after existing booking

**Prerequisites:**
- User is logged in
- Existing booking: Conference Room A, Tomorrow 10:00 AM - 11:00 AM

**Steps:**
1. Navigate to room reservation dashboard
2. Click "Book a Room"
3. Select "Conference Room A"
4. Select Tomorrow 11:00 AM - 12:00 PM (adjacent to existing)
5. Submit booking
6. Verify no conflict detected
7. Verify booking created successfully

**Expected Results:**
- ✅ No conflict detected (adjacent times allowed)
- ✅ Booking created successfully
- ✅ Both bookings appear on calendar
- ✅ No gap or overlap between bookings

**Test Data:**
```javascript
{
    existingBooking: {
        room: "Conference Room A",
        startTime: "Tomorrow 10:00 AM",
        endTime: "Tomorrow 11:00 AM"
    },
    newBooking: {
        room: "Conference Room A",
        startTime: "Tomorrow 11:00 AM",
        endTime: "Tomorrow 12:00 PM"
    }
}
```

---

#### Test 5.3: Detect Recurring Booking Conflicts
**Scenario:** User attempts to create recurring booking with conflicts

**Prerequisites:**
- User is logged in
- Existing booking: Conference Room A, Every Monday 10:00 AM - 11:00 AM (recurring)

**Steps:**
1. Navigate to room reservation dashboard
2. Click "Book a Room"
3. Select "Conference Room A"
4. Select recurring pattern: Daily
5. Set time: 10:00 AM - 11:00 AM
6. Set 5 occurrences (will conflict on Monday)
7. Preview recurring dates
8. Verify conflict detected in preview
9. Attempt to submit
10. Verify error message lists conflicts

**Expected Results:**
- ✅ Conflicts detected in preview before submission
- ✅ Conflicting dates highlighted in preview
- ✅ Error message lists all conflicting instances
- ✅ Booking not created if conflicts exist
- ✅ User prompted to modify pattern or exclude conflicting dates

---

### Test Group 6: Notification Integration

#### Test 6.1: Booking Confirmation Email
**Scenario:** Verify booking confirmation email is sent

**Prerequisites:**
- User is logged in
- Email notifications are enabled
- User has email notifications enabled in preferences

**Steps:**
1. Create new booking
2. Submit booking
3. Verify success message
4. Check email inbox (or email logs)
5. Verify confirmation email received

**Expected Results:**
- ✅ Confirmation email sent immediately after booking creation
- ✅ Email contains booking details (room, date, time, title)
- ✅ Email contains booking ID and status
- ✅ Email formatted correctly with branding

---

#### Test 6.2: Booking Revision Email
**Scenario:** Verify booking revision email is sent when booking is edited

**Prerequisites:**
- User is logged in
- Email notifications are enabled
- Existing booking exists

**Steps:**
1. Edit existing booking
2. Modify meeting title or time
3. Submit changes
4. Check email inbox (or email logs)
5. Verify revision notification email received

**Expected Results:**
- ✅ Revision email sent after booking modification
- ✅ Email shows original vs. updated details
- ✅ Email includes revision number
- ✅ Email identifies who made the change (MODIFIED_BY)

---

#### Test 6.3: Booking Cancellation Email
**Scenario:** Verify booking cancellation email is sent

**Prerequisites:**
- User is logged in
- Email notifications are enabled
- Existing booking exists

**Steps:**
1. Cancel existing booking
2. Confirm cancellation
3. Check email inbox (or email logs)
4. Verify cancellation email received

**Expected Results:**
- ✅ Cancellation email sent after booking cancelled
- ✅ Email contains cancelled booking details
- ✅ Email confirms cancellation was successful

---

#### Test 6.4: In-App Notification
**Scenario:** Verify in-app notification appears

**Prerequisites:**
- User is logged in
- In-app notifications are enabled
- Notification event occurs (booking approved, reminder, etc.)

**Steps:**
1. Trigger notification event (e.g., admin approves booking)
2. Verify notification badge appears in header
3. Click notification icon
4. Verify notification details displayed
5. Mark notification as read
6. Verify badge count decreases

**Expected Results:**
- ✅ Notification appears in notification dropdown
- ✅ Badge count updates correctly
- ✅ Notification content is accurate
- ✅ Marking as read updates status
- ✅ Read notifications move to bottom or separate section

---

### Test Group 7: Calendar View Tests

#### Test 7.1: Switch Calendar Views
**Scenario:** User switches between different calendar views

**Prerequisites:**
- User is logged in
- Bookings exist on calendar

**Steps:**
1. Navigate to room reservation dashboard
2. Verify default view (Month view)
3. Switch to Week view
4. Verify events display correctly
5. Switch to Day view
6. Verify events display correctly
7. Switch to List view
8. Verify events display correctly

**Expected Results:**
- ✅ Month view shows all days of month with events
- ✅ Week view shows 7-day week with hourly slots
- ✅ Day view shows single day with detailed time slots
- ✅ List view shows chronological list of events
- ✅ All views display same bookings, just different formats
- ✅ View switching is smooth and immediate

---

#### Test 7.2: Navigate Between Dates
**Scenario:** User navigates forward and backward through calendar

**Prerequisites:**
- User is logged in
- Bookings exist in different months

**Steps:**
1. Navigate to room reservation dashboard
2. Note current month
3. Click "Next" button
4. Verify calendar advances to next month
5. Click "Previous" button twice
6. Verify calendar goes back two months
7. Click "Today" button
8. Verify calendar returns to current month

**Expected Results:**
- ✅ Next button advances calendar by one period
- ✅ Previous button goes back by one period
- ✅ Today button returns to current date
- ✅ Calendar title updates to reflect current period
- ✅ Events load correctly for each period

---

#### Test 7.3: Event Display on Calendar
**Scenario:** Verify booking events display correctly on calendar

**Prerequisites:**
- User is logged in
- Various bookings exist with different statuses

**Steps:**
1. Navigate to room reservation dashboard
2. Verify events appear on calendar
3. Check event displays meeting title
4. Check event displays time
5. Check event displays status badge
6. Check event displays modified badge (if applicable)
7. Verify room color coding (if implemented)

**Expected Results:**
- ✅ Events appear on correct dates
- ✅ Event time displayed prominently
- ✅ Meeting title visible (truncated if long)
- ✅ Status badge shows current status with correct color
- ✅ Modified badge appears for revised bookings
- ✅ Room colors help distinguish different rooms
- ✅ Events are clickable

---

#### Test 7.4: Click Event to View Details
**Scenario:** User clicks calendar event to view booking details

**Prerequisites:**
- User is logged in
- Bookings exist on calendar

**Steps:**
1. Navigate to room reservation dashboard
2. Click on calendar event
3. Verify booking detail modal opens
4. Verify all booking details displayed
5. Verify action buttons appropriate for user permissions
6. Close modal
7. Verify calendar still visible

**Expected Results:**
- ✅ Modal opens immediately when event clicked
- ✅ Booking ID, room, date, time, title, status displayed
- ✅ Creator information displayed
- ✅ Revision history visible (if modified)
- ✅ Appropriate action buttons (Edit, Cancel) based on permissions
- ✅ Modal can be closed without navigating away from calendar

---

### Test Group 8: Error Handling and Validation

#### Test 8.1: Past Date Validation
**Scenario:** User attempts to book room in the past

**Prerequisites:**
- User is logged in

**Steps:**
1. Navigate to room reservation dashboard
2. Click "Book a Room"
3. Select past date and time
4. Attempt to submit
5. Verify validation error

**Expected Results:**
- ✅ Error message: "Cannot schedule bookings in the past"
- ✅ Booking not created
- ✅ Form remains open for correction
- ✅ Past date/time highlighted as invalid

---

#### Test 8.2: Duration Limit Validation
**Scenario:** User attempts to book room for more than 8 hours

**Prerequisites:**
- User is logged in
- System has 8-hour booking limit

**Steps:**
1. Navigate to room reservation dashboard
2. Click "Book a Room"
3. Select start time
4. Select end time 9 hours later
5. Attempt to submit
6. Verify validation error

**Expected Results:**
- ✅ Error message: "Booking duration cannot exceed 8 hours"
- ✅ Booking not created
- ✅ Form remains open for correction
- ✅ Duration highlighted as invalid

---

#### Test 8.3: Required Field Validation
**Scenario:** User attempts to submit booking without required fields

**Prerequisites:**
- User is logged in

**Steps:**
1. Navigate to room reservation dashboard
2. Click "Book a Room"
3. Leave room field empty
4. Attempt to submit
5. Verify validation error
6. Fill room, leave date empty
7. Attempt to submit
8. Verify validation error

**Expected Results:**
- ✅ Error messages for each missing required field
- ✅ Fields highlighted as invalid
- ✅ Booking not created
- ✅ User-friendly error messages
- ✅ Form remains open for correction

---

#### Test 8.4: Network Error Handling
**Scenario:** Simulate network failure during booking submission

**Prerequisites:**
- User is logged in
- Ability to simulate network failure (disconnect, timeout)

**Steps:**
1. Navigate to room reservation dashboard
2. Click "Book a Room"
3. Fill in all booking details
4. Simulate network disconnection
5. Submit booking
6. Verify error handling

**Expected Results:**
- ✅ User-friendly error message displayed
- ✅ "Network error" or "Connection failed" message
- ✅ Booking not created
- ✅ Form data preserved (not lost)
- ✅ User can retry after network restored
- ✅ No duplicate bookings created on retry

---

### Test Group 9: Performance Tests

#### Test 9.1: Calendar Load Time
**Scenario:** Measure calendar load time with large dataset

**Test Data:**
- 1000+ bookings across 6 months
- 20+ rooms
- Multiple users

**Measurements:**
- Initial calendar load time
- Filter application time
- Search execution time
- View switching time

**Acceptance Criteria:**
- ✅ Initial load < 2 seconds
- ✅ Filter application < 500ms
- ✅ Search execution < 300ms
- ✅ View switching < 500ms

---

#### Test 9.2: Recurring Booking Generation Performance
**Scenario:** Measure time to generate large recurring booking series

**Test Data:**
- Daily recurring pattern
- 100 occurrences
- Full conflict checking

**Measurements:**
- Date generation time
- Conflict detection time
- Database insertion time
- Total processing time

**Acceptance Criteria:**
- ✅ Date generation < 100ms
- ✅ Conflict detection < 500ms per date
- ✅ Total processing < 10 seconds for 100 occurrences

---

## Test Execution Instructions

### Running Integration Tests with Playwright MCP

1. **Setup Playwright MCP Connection**
   ```javascript
   // Playwright MCP should be running and connected
   // Browser window will be automated
   ```

2. **Execute Test Suite**
   ```bash
   # Individual test execution
   playwright test booking-workflow.spec.ts

   # Full integration test suite
   playwright test integration-tests/

   # With verbose output
   playwright test --debug
   ```

3. **Test Reporting**
   ```bash
   # Generate HTML report
   playwright show-report

   # View test results
   playwright test --reporter=html
   ```

### Manual Test Execution

For tests that cannot be automated:

1. Follow step-by-step instructions in each test scenario
2. Document actual results vs. expected results
3. Take screenshots of any failures
4. Record any deviations from expected behavior

---

## Test Results Tracking

### Integration Test Results Summary

| Test ID | Test Name | Status | Notes |
|---------|-----------|--------|-------|
| 1.1 | Create Standard Booking | ⏳ Pending | Awaiting execution |
| 1.2 | Edit Existing Booking | ⏳ Pending | Awaiting execution |
| 1.3 | Cancel Booking | ⏳ Pending | Awaiting execution |
| 2.1 | Create Daily Recurring Booking | ⏳ Pending | Awaiting execution |
| 2.2 | Create Weekly Recurring Booking | ⏳ Pending | Awaiting execution |
| 2.3 | Create Monthly Recurring Booking | ⏳ Pending | Awaiting execution |
| 2.4 | Cancel Entire Recurring Series | ⏳ Pending | Awaiting execution |
| 3.1 | Filter by Room | ⏳ Pending | Awaiting execution |
| 3.2 | Filter by Status | ⏳ Pending | Awaiting execution |
| 3.3 | My Bookings Only Toggle | ⏳ Pending | Awaiting execution |
| 3.4 | Search by Meeting Title | ⏳ Pending | Awaiting execution |
| 3.5 | Combined Filters | ⏳ Pending | Awaiting execution |
| 4.1 | Creator Can Edit Own Booking | ⏳ Pending | Awaiting execution |
| 4.2 | User Cannot Edit Other User's Booking | ⏳ Pending | Awaiting execution |
| 4.3 | Admin Can Edit Any Booking | ⏳ Pending | Awaiting execution |
| 4.4 | Cannot Edit Started Booking | ⏳ Pending | Awaiting execution |
| 5.1 | Detect Overlapping Booking Conflict | ⏳ Pending | Awaiting execution |
| 5.2 | Allow Adjacent Bookings | ⏳ Pending | Awaiting execution |
| 5.3 | Detect Recurring Booking Conflicts | ⏳ Pending | Awaiting execution |
| 6.1 | Booking Confirmation Email | ⏳ Pending | Awaiting execution |
| 6.2 | Booking Revision Email | ⏳ Pending | Awaiting execution |
| 6.3 | Booking Cancellation Email | ⏳ Pending | Awaiting execution |
| 6.4 | In-App Notification | ⏳ Pending | Awaiting execution |
| 7.1 | Switch Calendar Views | ⏳ Pending | Awaiting execution |
| 7.2 | Navigate Between Dates | ⏳ Pending | Awaiting execution |
| 7.3 | Event Display on Calendar | ⏳ Pending | Awaiting execution |
| 7.4 | Click Event to View Details | ⏳ Pending | Awaiting execution |
| 8.1 | Past Date Validation | ⏳ Pending | Awaiting execution |
| 8.2 | Duration Limit Validation | ⏳ Pending | Awaiting execution |
| 8.3 | Required Field Validation | ⏳ Pending | Awaiting execution |
| 8.4 | Network Error Handling | ⏳ Pending | Awaiting execution |
| 9.1 | Calendar Load Time | ⏳ Pending | Awaiting execution |
| 9.2 | Recurring Booking Generation Performance | ⏳ Pending | Awaiting execution |

---

## Known Issues and Limitations

### Testing Environment Limitations

1. **Database Dependency**
   - Tests require actual database connection
   - Test data should use dedicated test database or cleanup procedures
   - Transactions should be rolled back after tests

2. **Email Testing**
   - Email notifications tested manually or with SMTP mock server
   - Email delivery confirmation not automated
   - Email content validation requires manual inspection

3. **Network Conditions**
   - Network error simulation requires manual disconnection or proxy tools
   - Timeout scenarios difficult to automate consistently

4. **Performance Baselines**
   - Performance benchmarks may vary based on server hardware
   - Database size affects performance metrics
   - Network latency impacts load times

---

## Recommendations for Test Automation

### Short-term Improvements

1. **Playwright Test Scripts**
   - Create Playwright test scripts for each test scenario
   - Implement page object models for maintainability
   - Add screenshot capture on failures

2. **Test Data Management**
   - Create test data fixtures
   - Implement database seeding scripts
   - Automate test data cleanup

3. **Continuous Integration**
   - Integrate tests into CI/CD pipeline
   - Run tests on every commit or pull request
   - Generate test reports automatically

### Long-term Improvements

1. **Comprehensive Test Coverage**
   - Expand tests to cover edge cases
   - Add stress testing for high-volume scenarios
   - Implement security testing (SQL injection, XSS)

2. **Performance Monitoring**
   - Set up continuous performance monitoring
   - Track performance metrics over time
   - Alert on performance regressions

3. **User Acceptance Testing**
   - Conduct UAT with actual end users
   - Gather feedback on usability and workflows
   - Iterate based on user feedback

---

## Conclusion

The integration test suite provides comprehensive coverage of the DoCM Room Reservation System's core workflows and functionality. These tests ensure that all components work together correctly and that the user experience meets requirements.

**Test Execution Status:** ⏳ Pending (Awaiting Playwright MCP automation or manual execution)

**Overall Coverage:** Comprehensive (Booking, Recurring, Filtering, Notifications, Permissions, Validation)

**Next Steps:** Execute tests using Playwright MCP and document actual results
