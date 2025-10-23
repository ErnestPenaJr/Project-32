# DoCM Room Reservation System - Testing Guide

This guide covers all testing approaches for the DoCM Room Reservation System, including unit tests, integration tests, and automated end-to-end tests.

## 📚 Table of Contents

1. [Unit Tests (ColdFusion)](#unit-tests-coldfusion)
2. [Playwright Automated Tests](#playwright-automated-tests)
3. [Manual Testing Checklist](#manual-testing-checklist)
4. [Test Coverage Summary](#test-coverage-summary)

---

## 🧪 Unit Tests (ColdFusion)

### Location
`/tests/unit/`

### Available Test Suites

#### 1. Recurring Booking Tests
**File**: `RecurringBookingTests.cfc`

**Tests**:
- Daily recurring pattern generation
- Weekly recurring pattern with specific days
- Monthly recurring pattern
- Max occurrences limit validation
- End date limit validation
- Conflict detection across recurring dates

#### 2. Edit Booking Tests
**File**: `EditBookingTests.cfc`

**Tests**:
- Edit permissions (creator/admin only)
- Cannot edit past bookings
- Time range validation
- Maximum duration validation (8 hours)
- Cannot edit cancelled/rejected bookings
- Revision number increment
- Room availability conflict detection

### Running Unit Tests

**Via Web Browser**:
```
http://localhost:8500/DoCMRoomReservation/tests/test-runner.cfm
```

**Features**:
- ✅ Visual test result display
- ✅ Summary statistics (pass/fail rate)
- ✅ Detailed error messages
- ✅ Professional UI with color coding
- ✅ Easy re-run capability

**Expected Results**:
- **Total Tests**: 13
- **Pass Rate**: 100% (target)

---

## 🎭 Playwright Automated Tests

### Location
`/tests/playwright/`

### Setup (One-time)

```bash
cd tests/playwright
./setup.sh
```

Or manually:
```bash
cd tests/playwright
npm install
npx playwright install
```

### Test Coverage

#### Phase 1 Tests (Quick Wins)
- **1.1 Improved Time Selection UX** (3 tests)
  - Enhanced datetime picker visibility
  - Real-time duration calculation
  - Color-coded time selectors

- **1.2 Email Notifications** (2 tests)
  - Notification preferences page
  - Admin notification control

- **1.3 Meeting Title Visibility** (2 tests)
  - Meeting title in approvals
  - Meeting title in booking modal

#### Phase 2 Tests (Core Features)
- **2.1 Edit Reservations** (2 tests)
  - Edit functionality availability
  - Revision history capability

- **2.2 Calendar Viewing Options** (4 tests)
  - Multiple calendar views
  - Filtering system
  - Search functionality
  - Status badges on events

#### Phase 3 Tests (Advanced Features)
- **3.1 Recurring Reservations** (7 tests)
  - Recurring UI elements
  - Frequency selection
  - Weekly days selection
  - End type options
  - Preview functionality
  - Recurring icon badges

#### Comprehensive Tests (5 tests)
- Phase 1 feature validation
- Phase 2 feature validation
- Phase 3 feature validation
- Screenshot capture
- Overall system validation

#### Accessibility Tests (2 tests)
- Keyboard navigation
- Mobile responsiveness

### Running Playwright Tests

**All Tests**:
```bash
cd tests/playwright
npm test
```

**Interactive UI Mode** (Recommended):
```bash
npm run test:ui
```

**Watch Tests Run**:
```bash
npm run test:headed
```

**Run Specific Phase**:
```bash
npm run test:phase1  # Phase 1 only
npm run test:phase2  # Phase 2 only
npm run test:phase3  # Phase 3 only
```

**Debug Mode**:
```bash
npm run test:debug
```

**View Report**:
```bash
npm run test:report
```

### Test Results

After running tests, results are available:
- **HTML Report**: `playwright-report/index.html`
- **Screenshots**: `screenshots/` directory
- **Videos**: `test-results/` (on failures)
- **JSON**: `test-results.json`

### Expected Results
- **Total Tests**: 27
- **Pass Rate**: 100% (target)
- **Coverage**: All TODO.md features

---

## ✅ Manual Testing Checklist

### Phase 1: Quick Wins

#### 1.1 Time Selection UX
- [ ] Open booking modal
- [ ] Verify datetime pickers are prominently displayed
- [ ] Click "Now" button - time should set to current time
- [ ] Click "In 1 Hour" button - time should set to +1 hour
- [ ] Click "End of Business Day" button - time should set to 5 PM
- [ ] Select start and end times - duration should calculate and display
- [ ] Verify start time node is blue, end time node is green
- [ ] Verify connector bar shows progress

#### 1.2 Email Notifications
- [ ] Navigate to User Notification Preferences
- [ ] Toggle notification settings
- [ ] Verify settings save correctly
- [ ] As admin, navigate to Admin Notification Control
- [ ] Verify admin notification settings available
- [ ] Create a booking requiring approval
- [ ] Verify admin receives email notification
- [ ] Check email includes booking details and action links

#### 1.3 Meeting Title Visibility
- [ ] Navigate to Booking Approvals page
- [ ] Verify "Meeting Title" column exists
- [ ] Create booking with meeting title/comments
- [ ] Verify title appears in approvals table
- [ ] Click booking to view details
- [ ] Verify meeting title displayed in modal
- [ ] Verify meeting title included in approval email

### Phase 2: Core Features

#### 2.1 Edit Existing Reservations
- [ ] Create a booking
- [ ] Click on the booking in calendar
- [ ] Verify "Edit" button appears in booking details
- [ ] Click Edit button
- [ ] Modify booking details (time, room, or comments)
- [ ] Save changes
- [ ] Verify "Modified" badge appears on booking
- [ ] Click "History" button
- [ ] Verify revision history displays with change details
- [ ] Verify revision notification email sent

#### 2.2 Calendar Viewing Options
- [ ] Verify calendar toolbar shows view buttons
- [ ] Click "month" view - calendar switches to month view
- [ ] Click "week" view - calendar switches to week view
- [ ] Click "day" view - calendar switches to day view
- [ ] Click "list" view - calendar switches to agenda list
- [ ] Verify status filter dropdown exists
- [ ] Select "Pending" from status filter
- [ ] Verify only pending bookings display
- [ ] Toggle "My Bookings Only" switch
- [ ] Verify only your bookings display
- [ ] Type in search box (room name or meeting title)
- [ ] Verify filtered results display
- [ ] Verify status badges appear on calendar events
- [ ] Verify meeting titles display on events (when present)

### Phase 3: Advanced Features

#### 3.1 Recurring Reservations
- [ ] Open booking modal
- [ ] Verify "Recurring Schedule" dropdown exists
- [ ] Select "Daily" from dropdown
- [ ] Verify recurring pattern configuration appears
- [ ] Verify "Repeat Every" field shows "day(s)"
- [ ] Change interval to 2
- [ ] Verify label updates to "day(s)" (plural)
- [ ] Select "Weekly" frequency
- [ ] Verify "Repeat On" section appears with day checkboxes
- [ ] Select Monday, Wednesday, Friday
- [ ] Verify interval label changes to "week(s)"
- [ ] Select "Monthly" frequency
- [ ] Verify interval label changes to "month(s)"
- [ ] Verify "Ends" section with two radio options
- [ ] Select "On Date" option
- [ ] Verify date picker appears
- [ ] Select "After Number of Occurrences" option
- [ ] Verify occurrences input appears
- [ ] Set valid start/end times
- [ ] Click "Preview Recurring Dates"
- [ ] Verify preview list displays with dates
- [ ] Verify total occurrences count shown
- [ ] Create recurring booking
- [ ] Verify recurring icon badges appear on calendar events
- [ ] Hover over recurring event
- [ ] Verify tooltip shows "Recurring" badge and instance number

### Cross-Browser Testing
- [ ] Test on Chrome
- [ ] Test on Firefox
- [ ] Test on Safari
- [ ] Test on Edge
- [ ] Test on Mobile Chrome
- [ ] Test on Mobile Safari

### Accessibility Testing
- [ ] Navigate using Tab key only
- [ ] Verify all interactive elements accessible
- [ ] Verify focus indicators visible
- [ ] Test with screen reader
- [ ] Verify ARIA labels present
- [ ] Check color contrast ratios

---

## 📊 Test Coverage Summary

### Unit Tests (ColdFusion)
| Test Suite | Tests | Focus Area |
|------------|-------|------------|
| RecurringBookingTests.cfc | 6 | Recurring logic validation |
| EditBookingTests.cfc | 7 | Edit validation rules |
| **Total** | **13** | **Backend logic** |

### Playwright Tests (JavaScript/E2E)
| Test Category | Tests | Focus Area |
|---------------|-------|------------|
| Phase 1.1 | 3 | Time selection UX |
| Phase 1.2 | 2 | Email notifications |
| Phase 1.3 | 2 | Meeting title visibility |
| Phase 2.1 | 2 | Edit reservations |
| Phase 2.2 | 4 | Calendar views/filtering |
| Phase 3.1 | 7 | Recurring reservations |
| Comprehensive | 5 | Full system validation |
| Accessibility | 2 | A11y and responsive |
| **Total** | **27** | **End-to-end UI/UX** |

### Overall Coverage
- **Total Automated Tests**: 40 (13 unit + 27 E2E)
- **Manual Test Scenarios**: 50+
- **TODO.md Feature Coverage**: 100%
- **Browser Coverage**: 6 browsers
- **Mobile Coverage**: iOS and Android

---

## 🐛 Troubleshooting

### ColdFusion Unit Tests

**Issue**: Test runner shows errors
- Ensure ColdFusion server is running
- Verify component paths are correct
- Check database connectivity

**Issue**: Tests fail unexpectedly
- Review error messages in test results
- Check database has test data
- Verify system settings are configured

### Playwright Tests

**Issue**: "Connection refused" errors
- Ensure ColdFusion server running on port 8500
- Verify application is accessible in browser first

**Issue**: Timeout errors
- Increase timeout in `playwright.config.js`
- Check if application is slow to load
- Verify network connectivity

**Issue**: Browser not installed
```bash
npx playwright install --force
```

**Issue**: Tests fail on specific browser
```bash
# Run on specific browser to debug
npx playwright test --project=chromium --headed
```

---

## 📈 Continuous Integration

For CI/CD pipelines:

```bash
# Set CI environment variable
export CI=true

# Run all tests
cd tests/playwright
npm test
```

CI mode enables:
- Automatic retries (2x)
- Single worker (no parallelization)
- Strict mode

---

## 🎯 Success Criteria

### All Tests Pass
- ✅ 13 unit tests passing
- ✅ 27 Playwright tests passing
- ✅ Manual testing checklist completed

### Feature Validation
- ✅ All Phase 1 features working
- ✅ All Phase 2 features working
- ✅ All Phase 3 features working

### Quality Metrics
- ✅ Test coverage >90%
- ✅ No critical bugs
- ✅ Accessibility compliance (WCAG AA)
- ✅ Mobile responsive
- ✅ Cross-browser compatible

---

## 📞 Support

### Getting Help
1. Check test output and error messages
2. Review screenshots/videos in test-results
3. Examine HTML test reports
4. Review TODO.md for requirements
5. Check CLAUDE.md for project documentation

### Common Resources
- **Unit Test Runner**: http://localhost:8500/DoCMRoomReservation/tests/test-runner.cfm
- **Playwright Docs**: https://playwright.dev/docs/intro
- **Test Directory**: `/tests/`
- **TODO.md**: Project enhancement requirements

---

**Last Updated**: 2025-10-23
**Test Coverage**: 100% of TODO.md features
**Automated Tests**: 40 (13 unit + 27 E2E)
