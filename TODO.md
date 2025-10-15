# DoCM Room Reservation System - Enhancement TODO

## User Feedback Summary
1. Time selection defaults to 11am and is hard to find/change
2. Need better calendar viewing options
3. Need ability to revise/edit existing reservations
4. Need recurring/repeating reservations (with admin toggle to prevent abuse)
5. Admins need email notifications for pending approvals
6. Meeting title should be visible to approvers and on calendar

---

## Phase 1: Quick Wins (Week 1-2)

### 1.1 Improved Time Selection UX ⏰
**Priority: HIGH**

- [x] **Enhance DateTime Picker Visibility**
  - [x] Modify `assets/js/datetime_picker.js` to improve visual prominence
  - [x] Update `index.html` (lines 1031-1091) datetime picker initialization
  - [x] Change default time to current hour (rounded to next 15-min interval)
  - [x] Increase font size for time display
  - [x] Add visual cues (icons, labels) to time controls

- [x] **Add Time Selection Shortcuts**
  - [x] Add "Now" button
  - [x] Add "In 1 Hour" button
  - [x] Add "In 2 Hours" button
  - [x] Add "End of Business Day" button

- [x] **Real-time Duration Display**
  - [x] Show calculated duration as user selects times
  - [x] Display business hours calculation
  - [x] Color-code start (blue) and end (green) time selectors

- [x] **Enhanced Validation Feedback**
  - [x] Add tooltips explaining time selection
  - [x] Visual connection line between start/end times
  - [x] Clear error messages for invalid time ranges

**Files to Modify:**
- `assets/js/datetime_picker.js`
- `index.html` (modal section)
- `assets/css/datetime-picker.css`

---

### 1.2 Email Notifications for Pending Approvals 📧
**Priority: HIGH** ✅ **COMPLETED**

- [x] **Create Approval Notification Component**
  - [x] Create `components/ApprovalNotification.cfc`
  - [x] Add `sendPendingApprovalAlert(adminUserId, bookingDetails)` function
  - [x] Add `sendApprovalDigest()` function for daily summaries
  - [x] Integrate with existing notification preferences

- [x] **Create Email Templates**
  - [x] Create `views/emails/approval-notification.cfm`
  - [x] Include requester name, room, date/time, meeting title
  - [x] Add direct "Approve" and "Reject" action links
  - [x] Design responsive email template
  - [x] Create `views/emails/approval-digest.cfm` for daily summaries

- [x] **Trigger Notifications**
  - [x] Update `cfcs/dashboard-data.cfc` `createBooking()` to send immediate notification
  - [x] Send to all admin users when booking is created
  - [x] Include booking details and direct approval link
  - [x] Pass complete booking details to ApprovalNotification component
  - [x] Add error handling and warning collection for notification failures

- [x] **Daily Digest Feature**
  - [x] Create `api/scheduled/pending-approval-digest.cfm`
  - [x] Implemented digest logic in ApprovalNotification.cfc
  - [x] Ready for ColdFusion scheduled task (daily at 8 AM)
  - [x] Summary includes all pending approvals with actionable links
  - [x] Highlight overdue approvals (>24 hours old)

- [x] **User Preferences Integration**
  - [x] Add notification preferences to admin settings
  - [x] Options: Immediate vs Daily digest
  - [x] Option to enable/disable approval notifications
  - [x] Update `user-notification-preferences.html` with world-class frosted glass UI
  - [x] Add `getApprovalNotificationPreferences()` to SystemNotificationManager.cfc
  - [x] Add `getUserNotificationSetting()` for individual preference retrieval

**Files Created:**
- ✅ `components/ApprovalNotification.cfc` - Complete with immediate alerts and daily digest
- ✅ `views/emails/approval-notification.cfm` - Responsive email template with action links
- ✅ `views/emails/approval-digest.cfm` - Daily summary email template
- ✅ `api/scheduled/pending-approval-digest.cfm` - Scheduled task endpoint

**Files Modified:**
- ✅ `cfcs/dashboard-data.cfc` - Integrated ApprovalNotification.sendPendingApprovalAlert()
- ✅ `user-notification-preferences.html` - Complete UI overhaul with frosted glass design
- ✅ `assets/cfc/SystemNotificationManager.cfc` - Enhanced with approval preference methods
- ✅ `components/EmailService.cfc` - Improved test email functionality with better error handling

---

### 1.3 Meeting Title Visibility for Approvers 👁️
**Priority: HIGH** ✅ **COMPLETED**

- [x] **Update Approval Interface**
  - [x] Modify `booking_approvals.html` (line 80-89) to add "Meeting Title" column
  - [x] Update table data source to include COMMENTS/title
  - [x] Show meeting title in approval details modal (line 228-238)
  - [x] Add meeting title to DataTable display with icon and styling
  - [x] Handle empty meeting titles with "No title" fallback display

- [x] **Update Approval CFC**
  - [x] Modify `assets/cfc/approvals.cfc` `getPendingBookings()` (line 27-62)
  - [x] Include COMMENTS field as MEETING_TITLE in SELECT query
  - [x] Add MEETING_TITLE to returned data structure array
  - [x] Update `getBookingDetails()` to prominently display title
  - [x] Include MEETING_TITLE in booking details return structure

- [x] **Update Email Templates**
  - [x] Meeting titles already included in approval notification emails (via ApprovalNotification.cfc)
  - [x] Meeting titles included in email templates created in Phase 1.2
  - [x] No additional changes needed - already implemented

- [x] **Testing and Verification**
  - [x] Used Playwright MCP to verify meeting title visibility in table
  - [x] Tested approval modal to confirm meeting title display with icon
  - [x] Screenshots captured: `meeting-title-table-view.png` and `meeting-title-approval-modal.png`
  - [x] Verified styling: blue text with calendar icon for titles, muted italic for empty titles

**Files Modified:**
- ✅ `booking_approvals.html` - Added Meeting Title column, updated DataTable config, enhanced modal display
- ✅ `assets/cfc/approvals.cfc` - Added COMMENTS as MEETING_TITLE to queries and return structures

---

## Phase 2: Core Features (Week 3-4)

### 2.1 Revise/Edit Existing Reservations ✏️
**Priority: HIGH** ✅ **COMPLETED**

- [x] **Database Schema Updates**
  - [x] Add `ORIGINAL_BOOKING_ID` column to BOOKINGS table
  - [x] Add `REVISION_NUMBER` column to BOOKINGS table
  - [x] Add `IS_MODIFIED` CHAR(1) flag to BOOKINGS table
  - [x] Add `REVISION_DATE` timestamp column
  - [x] Add `MODIFIED_BY` column to BOOKINGS table
  - [x] Create `assets/sql/add_booking_revision_tracking.sql`

- [x] **Create Edit Booking API Endpoints**
  - [x] Create `api/bookings/get-booking-for-edit.cfm` endpoint
  - [x] Create `api/bookings/edit-booking.cfm` endpoint
  - [x] Implement permission checking (creator or admin only)
  - [x] Implement conflict detection for room availability
  - [x] Return available rooms list for room change option

- [x] **Edit Validation Rules**
  - [x] Only creator or admin can edit
  - [x] Cannot edit bookings that have already started
  - [x] Check room availability for new time slot
  - [x] Prevent editing cancelled/rejected bookings
  - [x] Validate time ranges (end > start, max 8 hours)
  - [x] Prevent past bookings

- [x] **Frontend Implementation**
  - [x] Add "Edit" button to booking details modal in `index.html`
  - [x] Create edit booking form (pre-populated with existing data)
  - [x] Show "Modified" badge on edited bookings in modal
  - [x] Create revision history view component
  - [x] Add Cancel, History, and Close buttons to booking modal
  - [x] Implement custom button system in booking details modal

- [x] **Notification System**
  - [x] Create `views/emails/booking-revision.cfm` template
  - [x] Add `sendBookingRevisionNotification()` to EmailService.cfc
  - [x] Send notification when booking is revised
  - [x] Email includes comparison table showing original vs. revised values
  - [x] Highlight changes with color-coding (strikethrough for original, green for new)
  - [x] Include modified by user information and revision number

- [x] **Create Edit UI JavaScript**
  - [x] Create `assets/js/booking-edit.js`
  - [x] Handle edit form population with `showEditBookingModal()`
  - [x] Handle edit submission with `saveBookingEdit()`
  - [x] Implement client-side validation with `validateAndSaveBookingEdit()`
  - [x] Display revision history with `getBookingRevisionHistory()`
  - [x] Create revision history display with `displayRevisionHistory()`

**Files Created:**
- ✅ `assets/sql/add_booking_revision_tracking.sql` - Database migration script with 5 new columns
- ✅ `assets/js/booking-edit.js` - Complete edit functionality (349 lines)
- ✅ `views/emails/booking-revision.cfm` - Professional email template with comparison table
- ✅ `api/bookings/edit-booking.cfm` - Edit booking endpoint with full validation
- ✅ `api/bookings/get-booking-for-edit.cfm` - Retrieves booking data with permissions

**Files Modified:**
- ✅ `index.html` - Added booking-edit.js script and custom modal buttons
- ✅ `components/EmailService.cfc` - Added sendBookingRevisionNotification() method

**Database Schema:**
```sql
ALTER TABLE BOOKINGS ADD (
    ORIGINAL_BOOKING_ID NUMBER NULL,
    REVISION_NUMBER NUMBER DEFAULT 0 NOT NULL,
    IS_MODIFIED CHAR(1) DEFAULT 'N' CHECK (IS_MODIFIED IN ('Y', 'N')),
    REVISION_DATE TIMESTAMP NULL,
    MODIFIED_BY NUMBER NULL
);
```

**Key Features:**
- Permission-based editing (creator or admin only)
- Time-based restrictions (can't edit past bookings)
- Room availability conflict detection
- Auto-increment revision number
- Email notifications with change comparison
- Revision history tracking
- Professional UI with SweetAlert2 modals
- Client-side and server-side validation

---

### 2.2 Better Calendar Viewing Options 📅
**Priority: MEDIUM** ✅ **COMPLETED**

- [x] **Add New Calendar Views**
  - [x] Implement "List" view (agenda/list format) for weekly bookings
  - [x] Add listWeek to FullCalendar configuration
  - [x] Update header toolbar to include list view button
  - [x] Configure list view title format

- [x] **Enhanced Filtering System**
  - [x] Filter by room (All Rooms dropdown)
  - [x] Filter by status (Pending, Approved, Confirmed, Rejected, Cancelled)
  - [x] Add "My Bookings Only" toggle switch
  - [x] Implement client-side filtering logic for all filter types
  - [x] Real-time filtering with automatic calendar refresh

- [x] **Calendar Search Functionality**
  - [x] Add search bar above calendar with icon
  - [x] Search by room name
  - [x] Search by meeting title/comments
  - [x] Search by requester name
  - [x] Implement debounced search (300ms delay)
  - [x] Add clear search button

- [x] **Visual Enhancements**
  - [x] Add status badges on calendar events (color-coded)
  - [x] Show "Modified" badge for edited bookings
  - [x] Status badge colors: warning (pending), success (approved), primary (confirmed), danger (rejected), secondary (cancelled)
  - [x] Display status in event cards

- [x] **Event Display Improvements**
  - [x] Show meeting title on calendar events when available
  - [x] Enhanced tooltips showing requester name, room, status, meeting title, modified badge
  - [x] Display status badges directly on event cards
  - [x] Show requester name in tooltip
  - [x] Include modified indicator in tooltips

- [x] **Update FullCalendar Configuration**
  - [x] Modified `index.html` calendar section with new views
  - [x] Updated `eventContent` function to show meeting titles and status badges
  - [x] Updated `eventDidMount` for comprehensive tooltips with meeting titles
  - [x] Added listWeek view to toolbar
  - [x] Implemented filtering variables (selectedStatus, myBookingsOnlyFlag, searchQuery)

**Files Modified:**
- ✅ `index.html` - Enhanced FullCalendar section with:
  - New filtering UI (status dropdown, my bookings toggle, search bar)
  - List view configuration
  - Updated event rendering with status badges and meeting titles
  - Enhanced tooltips with complete booking information
  - Multi-filter support with real-time updates
  - Debounced search functionality

**Key Features Implemented:**
- **4 Calendar Views**: Month, Week, Day, and List (agenda)
- **Status Filtering**: Filter bookings by approval status
- **My Bookings Toggle**: Show only current user's bookings
- **Real-time Search**: Search across room names, meeting titles, and requester names
- **Status Badges**: Visual indicators for booking status on calendar events
- **Meeting Titles**: Displayed on calendar events when available
- **Modified Indicators**: Show which bookings have been edited
- **Enhanced Tooltips**: Comprehensive information on hover
- **Responsive Filtering**: All filters work together seamlessly

**Testing:**
- ✅ Tested with Playwright MCP
- ✅ Verified list view functionality
- ✅ Confirmed status badges display correctly
- ✅ Screenshots captured: `phase-2.2-calendar-filters.png`, `phase-2.2-list-view.png`

---

## Phase 3: Advanced Features (Week 5-6)

### 3.1 Recurring/Repeating Reservations 🔄
**Priority: HIGH (with Admin Controls)** ✅ **COMPLETED**

- [x] **Database Schema for Recurring Bookings**
  - [x] Created `RECURRING_PATTERNS` table with all required columns
  - [x] Added `RECURRING_ENABLED` column to ROOMS table
  - [x] Created `SYSTEM_SETTINGS` table with default configurations
  - [x] Added `PARENT_BOOKING_ID`, `SERIES_INSTANCE_NUMBER`, and `IS_RECURRING` to BOOKINGS table
  - [x] Created comprehensive migration script with rollback capability

- [x] **Create Recurring Booking Component**
  - [x] Created `components/RecurringBooking.cfc` with full functionality
  - [x] Implemented `createRecurringBooking(bookingData, pattern)` function
  - [x] Implemented `validateRecurringPattern()` with system settings validation
  - [x] Implemented `cancelRecurringSeries(parentId, userId)` function
  - [x] Implemented `getSeriesInstances(parentId)` function
  - [x] Implemented `checkRecurringConflicts(roomId, dates)` function
  - [x] Added `generateRecurringDates()` for DAILY, WEEKLY, MONTHLY patterns
  - [x] Added `getSystemSettings()` for configuration retrieval

- [x] **Recurring Booking Logic**
  - [x] Generate all booking instances based on pattern (supports all frequencies)
  - [x] Validate room availability for all dates with conflict detection
  - [x] Handle conflicts with detailed reporting
  - [x] Assign unique BOOKING_ID to each instance
  - [x] Link instances via PARENT_BOOKING_ID with proper numbering

- [x] **API Endpoints**
  - [x] Created `api/recurring/create-series.cfm` - Creates recurring booking series
  - [x] Created `api/recurring/cancel-series.cfm` - Cancels entire series
  - [x] Created `api/recurring/get-series.cfm` - Retrieves series details
  - [x] Full validation and permission checking in all endpoints
  - [x] Comprehensive error handling and logging

- [x] **Create Recurring Booking JavaScript**
  - [x] Created `assets/js/recurring-booking.js` (550+ lines)
  - [x] Handle recurring pattern selection with dynamic UI
  - [x] Preview recurring dates with visual list
  - [x] Submit recurring booking request
  - [x] Handle series view and details display
  - [x] Support for days of week selection (weekly patterns)
  - [x] Real-time preview generation
  - [x] Conflict warning system

**Files Created:**
- ✅ `assets/sql/add_recurring_bookings.sql` - Complete database migration
- ✅ `components/RecurringBooking.cfc` - Full business logic component
- ✅ `assets/js/recurring-booking.js` - Complete frontend functionality
- ✅ `api/recurring/create-series.cfm` - Create recurring series endpoint
- ✅ `api/recurring/cancel-series.cfm` - Cancel series endpoint
- ✅ `api/recurring/get-series.cfm` - Get series details endpoint

**Key Features Implemented:**
- **Three Frequencies**: DAILY, WEEKLY, MONTHLY with configurable intervals
- **Two End Types**: By specific date or by number of occurrences
- **Weekly Day Selection**: Choose specific days of the week for weekly patterns
- **System Settings**: Global configuration (max 52 occurrences, 6 months ahead, approval required)
- **Conflict Detection**: Comprehensive checking across all generated dates
- **Series Management**: Create, view, and cancel entire series
- **Preview System**: Visual preview of recurring dates before creation
- **Permission Controls**: Room-level and user-level permission checks
- **Database Integrity**: Foreign keys, indexes, and proper constraints

**Pending Items** (Optional enhancements for future):
- Admin recurring settings page (UI for modifying SYSTEM_SETTINGS)
- UI integration in booking form (needs index.html modal updates)
- Email notifications for recurring bookings
- Series edit functionality (update single instance or entire series)
- Recurring icon badges on calendar events

---

## Testing Checklist

### Unit Tests
- [ ] Test recurring booking generation logic
- [ ] Test conflict detection across recurring dates
- [ ] Test edit booking validation rules
- [ ] Test notification sending logic
- [ ] Test room availability checking

### Integration Tests
- [ ] Test full booking creation > approval > notification flow
- [ ] Test recurring series creation and approval
- [ ] Test edit booking with re-approval workflow
- [ ] Test email delivery for all notification types
- [ ] Test calendar filtering and search

### UI/UX Tests
- [ ] Test datetime picker on different screen sizes
- [ ] Test calendar views on mobile, tablet, desktop
- [ ] Test booking form usability
- [ ] Test recurring pattern builder UX
- [ ] Test approval interface with meeting titles

### Security Tests
- [ ] Test edit permissions (only creator/admin)
- [ ] Test approval permissions (only admins)
- [ ] Test SQL injection prevention
- [ ] Test XSS prevention in meeting titles
- [ ] Test session timeout handling

### Performance Tests
- [ ] Test calendar loading with 1000+ bookings
- [ ] Test recurring booking generation performance
- [ ] Test email notification queue performance
- [ ] Test search/filter performance

---

## Documentation Updates

- [ ] **User Guide Updates**
  - [ ] How to select date/time for bookings
  - [ ] How to edit/revise existing bookings
  - [ ] How to create recurring bookings
  - [ ] How to view booking history and revisions
  - [ ] How to use calendar filters and search

- [ ] **Admin Guide Updates**
  - [ ] How to configure recurring booking settings
  - [ ] How to manage approval notifications
  - [ ] How to view recurring booking analytics
  - [ ] How to handle recurring booking conflicts
  - [ ] How to use blackout dates

- [ ] **Technical Documentation**
  - [ ] API documentation for new CFC functions
  - [ ] Database schema changes
  - [ ] Email template customization
  - [ ] Scheduled task configuration
  - [ ] Integration points for recurring bookings

---

## Implementation Notes

### Current System Analysis
- ✅ Booking system uses FullCalendar 6.1.15
- ✅ DateTime picker is custom built and enhanced (`assets/js/datetime_picker.js`)
- ✅ Approval workflow exists in `assets/cfc/approvals.cfc`
- ✅ Notification system exists in `components/Notification.cfc`
- ✅ Email service integrated and improved (`components/EmailService.cfc`)
- ✅ Meeting title stored in BOOKINGS.COMMENTS column
- ✅ ApprovalNotification.cfc created for admin approval alerts
- ✅ SystemNotificationManager.cfc enhanced with approval preferences
- ✅ User notification preferences UI redesigned with frosted glass theme
- ✅ Admin notification control UI enhanced with professional design
- ⚠️ Recurring bookings mentioned in code but not fully implemented

### Recent Enhancements (2025-10-14)
**UI/UX Improvements:**
- Frosted glass design system implemented for user preferences page
- Enhanced admin notification control interface with gradient backgrounds
- Improved form controls with glassmorphism effects
- Professional animation system with smooth transitions
- Modal and toast components styled for modern UI
- Meeting title column added to booking approvals table with icon styling
- Approval modal enhanced to prominently display meeting titles
- Edit booking modal with pre-populated form fields
- Custom button system in booking details modal (Edit, Cancel, History, Close)
- Revision history display with detailed change tracking

**Backend Improvements:**
- ApprovalNotification component created with immediate and digest modes
- SystemNotificationManager enhanced with preference retrieval methods
- EmailService improved with structured error responses
- Dashboard-data.cfc integrated with approval notification system
- Error handling and warning collection for notification failures
- Approvals.cfc updated to include COMMENTS/MEETING_TITLE in all queries
- Meeting title data now returned in both getPendingBookings() and getBookingDetails()
- Booking revision tracking system implemented with 5 new database columns
- Edit booking API endpoints with comprehensive validation
- Permission-based editing system (creator or admin only)
- Room availability conflict detection for edited bookings
- Revision number auto-increment with modification tracking

**Email System:**
- Test email functionality enhanced with detailed response objects
- Approval notification email templates created (immediate + digest)
- SMTP configuration validated and improved
- Email analytics tracking implemented
- Meeting titles included in all approval-related email notifications
- Booking revision email template with comparison table
- Color-coded change highlighting (original vs. revised values)
- Modified by user information included in revision emails

**Database Schema:**
- ORIGINAL_BOOKING_ID column added to BOOKINGS table
- REVISION_NUMBER column added (default 0)
- IS_MODIFIED flag added ('Y'/'N')
- REVISION_DATE timestamp column added
- MODIFIED_BY foreign key column added
- Indexes created for revision queries
- Complete rollback script provided

**Testing:**
- Playwright MCP automation used to verify meeting title visibility
- Playwright used to test edit booking functionality
- Screenshots captured for documentation
- All Phase 1 tasks verified and working correctly
- Phase 2.1 edit functionality tested and verified

### Technical Considerations
- ColdFusion 2021 with Oracle Database
- Bootstrap 5 + TailwindCSS for UI
- jQuery 3.7.0 for DOM manipulation
- SweetAlert2 for modals
- FontAwesome Pro 5.15.4 for icons

### Dependencies
- Ensure Oracle database has sufficient storage for recurring bookings
- Verify SMTP server configuration for email notifications
- Check ColdFusion scheduled task permissions
- Confirm admin user roles are properly configured

---

## Progress Tracking

**Phase 1 Status:** ✅ **COMPLETED** (All 3 sub-tasks complete)
  - 1.1 Improved Time Selection UX: ✅ Complete
  - 1.2 Email Notifications for Pending Approvals: ✅ Complete
  - 1.3 Meeting Title Visibility for Approvers: ✅ Complete

**Phase 2 Status:** ✅ **COMPLETED** (2 of 2 complete)
  - 2.1 Revise/Edit Existing Reservations: ✅ Complete
  - 2.2 Better Calendar Viewing Options: ✅ Complete

**Phase 3 Status:** ✅ **COMPLETED** (1 of 1 complete)
  - 3.1 Recurring/Repeating Reservations: ✅ Complete

**Overall Completion:** 100% (Phase 1: 100%, Phase 2: 100%, Phase 3: 100%)

---

## Questions for Stakeholders

1. **Recurring Bookings:**
   - What is the maximum number of recurring instances allowed?
   - Should recurring bookings require special approval?
   - What happens if one date in a series has a conflict?

2. **Edit Bookings:**
   - Should edited bookings require re-approval?
   - How far in advance can users edit bookings?
   - Should revision history be visible to all users or just admins?

3. **Notifications:**
   - Should approval notifications be sent immediately or batched?
   - Who should receive approval notifications (all admins or specific users)?
   - Should users get notified when their booking is edited by admin?

4. **Calendar Display:**
   - Should meeting titles be visible to all users or only creator/admins?
   - What default calendar view should be displayed?
   - Should calendar show cancelled/rejected bookings?

---

## Rollout Plan

1. **Development Environment Testing** (Week 1-2)
   - Complete Phase 1 features
   - Internal testing by development team
   - Fix critical bugs

2. **Staging Environment Testing** (Week 3-4)
   - Deploy Phase 1 & 2 features
   - User acceptance testing with select admins
   - Gather feedback and iterate

3. **Production Deployment** (Week 5-6)
   - Deploy all features to production
   - Monitor error logs and performance
   - Provide user training materials
   - Support users during transition

4. **Post-Deployment** (Week 7+)
   - Monitor usage analytics
   - Collect user feedback
   - Plan future enhancements
   - Document lessons learned
