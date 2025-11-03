## Author
- Ernest Pena Jr

## DoCM Room Reservation System

A comprehensive office reservation management system built for MD Anderson Cancer Center using ColdFusion, JavaScript, and modern CSS frameworks.

## Features

- User Authentication and Authorization
- Room Management
- Booking System
- Admin Dashboard
- Notification System
- User Profile Management
- Maintenance Tracking
- Reporting System

## Technology Stack

### Backend
- **ColdFusion 2021**: Server-side language for business logic and database interactions
- **Oracle Database**: Main data store with comprehensive schema

### Frontend
- **HTML5/CSS3**: Standard markup and styling
- **JavaScript/jQuery 3.7.0**: Client-side interactivity and AJAX
- **Bootstrap 5**: CSS framework for responsive design
- **TailwindCSS**: Utility-first CSS framework (compiled via npm)
- **FontAwesome Pro 5.15.4**: Icon library
- **FullCalendar 6.1.15**: Interactive calendar for booking management
- **SweetAlert2**: Enhanced alert dialogs
- **DataTables**: Advanced table functionality

### Build Tools
- **npm**: Package management and build processes
- **PostCSS**: CSS processing with autoprefixer

## Project Structure

```
/assets/cfc/          # ColdFusion Components (data access layer)
/components/          # Reusable ColdFusion components
/config/              # Configuration files (database, settings)
/api/                 # REST API endpoints (.cfm files)
/assets/js/           # JavaScript files and libraries
/assets/css/          # Compiled CSS and stylesheets
/assets/sql/          # Database schema and migration scripts
/pages/               # Individual page templates
/views/emails/        # Email templates
/src/                 # Source files (input.css for TailwindCSS)
```

### Key Components
- `assets/cfc/functions.cfc` - Core utility functions and database queries
- `components/Room.cfc` - Room management and availability checking
- `components/User.cfc` - User authentication and management
- `components/Booking.cfc` - Booking creation and management
- `components/Notification.cfc` - Notification system

## Setup Instructions

### Prerequisites
- ColdFusion 2021 server
- Oracle database access
- Node.js and npm (for frontend build tools)

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd DoCMRoomReservation
   ```

2. **Install frontend dependencies**
   ```bash
   npm install
   ```

3. **Configure database connection**
   - Update `/config/database.cfc` with your Oracle database credentials
   - Environment-specific settings (dev/staging/prod) are auto-detected

4. **Set up the database**
   - Run the SQL scripts in `/assets/sql/` to create the schema
   - Ensure proper permissions for the database user

5. **Build CSS assets**
   ```bash
   npm run build:css
   ```
   Or for development with watch mode:
   ```bash
   npm run watch:css
   ```

6. **Configure ColdFusion server**
   - Set the web root to the project directory
   - Ensure ColdFusion has proper database datasource configuration

7. **Access the application**
   - Navigate to `http://localhost:<port>/` in your browser
   - Login with your credentials

## Development

### CSS Development
- CSS is compiled from `/src/input.css` to `/assets/css/styles.css`
- Use Bootstrap 5 classes for responsive design
- Use FontAwesome Pro for icons
- Follow the style guide in `styleguide.html`

### ColdFusion Best Practices
- Use parameterized queries (`cfqueryparam`) to prevent SQL injection
- Implement proper error handling with try/catch blocks
- Log errors to `/assets/logs/` directory
- Use `remote access="remote"` for AJAX-callable functions

### API Development
- All API endpoints are ColdFusion files (.cfm) in the `/api/` directory
- Return JSON for AJAX calls using `returnformat="json"`
- Implement authentication checks for protected endpoints

For detailed development guidelines, see `CLAUDE.md`.

## Purpose

Develop a modern, efficient, and user-friendly room reservation system tailored for the MD Anderson Cancer Center. The system streamlines conference room management, improves booking efficiency, and enhances user experience for both administrators and staff.

## Key Objectives

- **Simplify Room Booking**: Intuitive interface for searching and reserving conference rooms
- **Enhance Management**: Tools for monitoring room utilization, managing users, and scheduling maintenance
- **System Integration**: Office 365 calendar synchronization for seamless scheduling
- **Improve Communication**: Comprehensive notification system for bookings, reminders, and alerts

## Special Features

### Office 365 Integration
- Calendar synchronization capabilities
- Authentication callback handling

### Notification System
- In-app notifications with read/unread status
- Email notifications for bookings and reminders
- User preference management for notification types

### Maintenance Management
- Room maintenance status tracking
- Scheduling system for maintenance windows
- Impact tracking on room availability

### Recurring Bookings
- Support for recurring reservation patterns
- Conflict detection across series
- Bulk management of recurring events

## Environment Configuration

The system automatically detects the environment based on server hostname:
- **Production**: `cmapps.mdanderson.org`
- **Staging**: `s-cmapps.mdanderson.org`
- **Development**: Local/other hostnames

Database connections and credentials are environment-specific.

## License

© MD Anderson Cancer Center. All rights reserved.