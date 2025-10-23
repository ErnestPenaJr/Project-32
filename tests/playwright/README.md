# Playwright Automated Tests for TODO.md Features

This directory contains comprehensive Playwright automated tests that verify all features requested in the **TODO.md** enhancement document.

## 📋 Test Coverage

### Phase 1: Quick Wins
- ✅ **1.1 Improved Time Selection UX**
  - Enhanced datetime picker visibility
  - Real-time duration calculation
  - Color-coded start/end time selectors
  - Time selection shortcuts (Now, +1h, +2h, End of Day)

- ✅ **1.2 Email Notifications for Pending Approvals**
  - Notification preferences page
  - Admin notification control interface

- ✅ **1.3 Meeting Title Visibility**
  - Meeting title in booking approvals table
  - Meeting title field in booking modal

### Phase 2: Core Features
- ✅ **2.1 Revise/Edit Existing Reservations**
  - Edit booking functionality
  - Revision history capability

- ✅ **2.2 Better Calendar Viewing Options**
  - Multiple calendar views (Month, Week, Day, List)
  - Filtering system (status, my bookings, room)
  - Search functionality
  - Status badges on calendar events

### Phase 3: Advanced Features
- ✅ **3.1 Recurring/Repeating Reservations**
  - Recurring booking UI in modal
  - Frequency selection (Daily, Weekly, Monthly)
  - Weekly days-of-week selection
  - End type options (by date or occurrences)
  - Preview functionality
  - Recurring icon badges on calendar

## 🚀 Installation

### Prerequisites
- Node.js 16+ installed
- ColdFusion server running on `http://localhost:8500`
- DoCM Room Reservation application deployed

### Install Dependencies

```bash
cd /Users/epena1/ColdFusion_2021/ColdFusion/cfusion/wwwroot/DoCMRoomReservation/tests/playwright
npm install
```

This will install Playwright and all necessary dependencies.

### Install Browsers

```bash
npx playwright install
```

This installs Chromium, Firefox, and WebKit browsers for testing.

## 🧪 Running Tests

### Run All Tests
```bash
npm test
```

### Run Tests with UI (Interactive Mode)
```bash
npm run test:ui
```

### Run Tests in Headed Mode (Watch Browser)
```bash
npm run test:headed
```

### Run Tests by Phase

**Phase 1 Tests Only:**
```bash
npm run test:phase1
```

**Phase 2 Tests Only:**
```bash
npm run test:phase2
```

**Phase 3 Tests Only:**
```bash
npm run test:phase3
```

**Comprehensive Validation Tests:**
```bash
npm run test:comprehensive
```

### Debug Mode
```bash
npm run test:debug
```

### View Test Report
```bash
npm run test:report
```

## 📊 Test Results

After running tests, results are available in multiple formats:

- **HTML Report**: `playwright-report/index.html`
- **JSON Results**: `test-results.json`
- **Screenshots**: `screenshots/` directory
- **Videos**: `test-results/` directory (on failures)

## 🎯 Test Scenarios

### Enhanced Time Selection (Phase 1.1)
- Verifies datetime picker visibility enhancements
- Checks for time selection shortcuts
- Validates real-time duration display
- Confirms color-coded time selectors

### Email Notifications (Phase 1.2)
- Validates notification preferences page accessibility
- Checks admin notification control interface

### Meeting Title Visibility (Phase 1.3)
- Confirms meeting title column in approvals table
- Verifies meeting title field in booking modal

### Edit Reservations (Phase 2.1)
- Tests edit booking functionality availability
- Validates revision history capability

### Calendar Viewing Options (Phase 2.2)
- Tests multiple calendar view options
- Validates filtering system
- Checks search functionality
- Confirms status badges on events

### Recurring Reservations (Phase 3.1)
- Verifies recurring booking UI elements
- Tests frequency selection options
- Validates weekly days selection
- Checks end type options (date/occurrences)
- Confirms preview functionality
- Validates recurring icon badges

## 🖼️ Screenshots

The test suite automatically captures screenshots:

1. **booking-modal-recurring.png** - Booking modal with recurring UI expanded
2. **calendar-with-badges.png** - Calendar view showing status and recurring badges

Screenshots are saved to `screenshots/` directory.

## 🔧 Configuration

### Browser Configuration
Tests run on multiple browsers by default:
- ✅ Desktop Chrome
- ✅ Desktop Firefox
- ✅ Desktop Safari (WebKit)
- ✅ Mobile Chrome (Pixel 5)
- ✅ Mobile Safari (iPhone 12)
- ✅ Microsoft Edge

To run on specific browser:
```bash
npx playwright test --project=chromium
npx playwright test --project=firefox
npx playwright test --project=webkit
```

### Timeout Settings
- Test timeout: 30 seconds
- Action timeout: 10 seconds
- Navigation timeout: 30 seconds

These can be adjusted in `playwright.config.js`.

## 📝 Test Structure

```
todo-features.spec.js
├── Phase 1.1: Improved Time Selection UX (3 tests)
├── Phase 1.2: Email Notifications (2 tests)
├── Phase 1.3: Meeting Title Visibility (2 tests)
├── Phase 2.1: Edit Existing Reservations (2 tests)
├── Phase 2.2: Calendar Viewing Options (4 tests)
├── Phase 3.1: Recurring Reservations (7 tests)
├── Comprehensive Feature Validation (5 tests)
└── Accessibility and Responsiveness (2 tests)

Total: 27 automated tests
```

## 🐛 Troubleshooting

### Tests Fail with Connection Error
- Ensure ColdFusion server is running on `http://localhost:8500`
- Verify DoCM Room Reservation application is accessible

### Browser Installation Issues
```bash
npx playwright install --force
```

### Clear Test Artifacts
```bash
rm -rf test-results/ playwright-report/ screenshots/
```

### View Trace Files
If a test fails, view the trace:
```bash
npx playwright show-trace test-results/trace.zip
```

## 📈 Continuous Integration

For CI/CD environments, use:
```bash
CI=true npm test
```

This enables:
- Automatic retries (2x)
- Single worker (no parallelization)
- Strict mode (fails on test.only)

## 🎨 Code Generation

Generate new test code interactively:
```bash
npm run test:codegen
```

This opens a browser window and records your interactions as Playwright code.

## ✅ Success Criteria

All tests should pass, indicating:
- ✅ All Phase 1 features implemented and functional
- ✅ All Phase 2 features implemented and functional
- ✅ All Phase 3 features implemented and functional
- ✅ UI elements are visible and accessible
- ✅ JavaScript functionality is loaded
- ✅ Responsive design works on mobile
- ✅ Keyboard navigation is functional

## 📞 Support

For issues or questions:
1. Check test output and error messages
2. Review screenshots and videos in `test-results/`
3. Examine HTML report with detailed test steps
4. Review TODO.md for feature requirements

## 🔄 Updating Tests

When adding new features:
1. Add test case to appropriate Phase section
2. Update this README with new test coverage
3. Run tests to ensure they pass
4. Update TODO.md to mark feature as tested

---

**Last Updated**: 2025-10-23
**Test Coverage**: 100% of TODO.md requested features
**Total Tests**: 27 automated end-to-end tests
