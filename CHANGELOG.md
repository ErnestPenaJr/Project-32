# Changelog

## 2025-08-25
- fix: prevent wrapping of "New Booking" button text
  - Added `.btn-new-booking { white-space: nowrap; display: inline-flex; align-items: center; }` in `index.html` and `dashboard.html` page-scoped styles.
  - Added `text-nowrap` utility class to buttons.
  - Adjusted grid column from `col-1` to `col-auto` in `index.html` to fit button width.
  - Added global rule in `assets/css/custom.css` as a fallback.
  - Extended same CSS to `room-management.html` and `roomMGT.html` to ensure consistency across admin pages.

- feat: consolidate profile controls into navbar dropdown
  - Converted welcome message `<li>` into a profile dropdown in `topNav-User.html` and `topNav-Admin.html`.
  - Moved settings options (Notification Preferences, Dashboard, Admin: Notifications) into the new profile dropdown.
  - Removed redundant quick settings dropdown from `index.html`.

- feat: display booking duration in Booking Time section
  - Added visible duration element `#bookingDuration` beside Booking Time header in `index.html`.
  - Implemented jQuery logic to compute and update duration from `#startTime` and `#endTime` on change and on modal init/reset.
  - Updated duration to count business hours only (default Mon–Fri, 08:00–16:00), configurable via `BUSINESS_HOURS` in `index.html`.
