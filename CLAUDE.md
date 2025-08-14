# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the DoCM Room Reservation System - a comprehensive office reservation management system built for MD Anderson Cancer Center. The system combines ColdFusion backend services with modern frontend technologies to provide room booking, user management, and administrative capabilities.

## Technology Stack

### Backend
- **ColdFusion 2021**: Primary server-side language for business logic and database interactions
- **Oracle Database**: Main data store with comprehensive schema for users, rooms, bookings, and amenities
- **ColdFusion Components (CFCs)**: Object-oriented approach for data access and business logic

### Frontend  
- **HTML5/CSS3**: Standard markup and styling
- **JavaScript/jQuery**: Client-side interactivity and AJAX communications
- **Bootstrap 5**: CSS framework for responsive design
- **TailwindCSS**: Utility-first CSS framework (compiled via npm)
- **FullCalendar**: Interactive calendar for booking management
- **SweetAlert2**: Enhanced alert dialogs
- **DataTables**: Advanced table functionality

### Build Tools
- **Node.js/npm**: Package management and build processes
- **TailwindCSS CLI**: CSS compilation and optimization
- **PostCSS**: CSS processing with autoprefixer

## Common Development Commands

### CSS Development
```bash
# Watch and compile TailwindCSS during development
npm run dev

# Build and minify CSS for production
npm run build
```

### Testing and Development
- Use local ColdFusion server for development
- Database connections configured per environment (dev/staging/prod)
- Oracle database requires appropriate credentials and schema access

## Project Architecture

### Core Directory Structure
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
```

### Key ColdFusion Components
- `assets/cfc/functions.cfc` - Core utility functions and database queries
- `components/Room.cfc` - Room management and availability checking
- `components/User.cfc` - User authentication and management
- `components/Booking.cfc` - Booking creation and management
- `components/Notification.cfc` - Notification system

### Database Schema
The Oracle database uses a comprehensive schema with:
- **USERS**: User accounts with role-based permissions
- **ROOMS**: Room inventory with capacity and amenities
- **BOOKINGS**: Reservation records with status tracking
- **AMENITIES**: Room features (projectors, whiteboards, etc.)
- **NOTIFICATIONS**: User notification system
- **MAINTENANCE**: Room maintenance scheduling

### Environment Configuration
The system detects environment based on server hostname:
- Production: `cmapps.mdanderson.org`
- Staging: `s-cmapps.mdanderson.org`
- Development: Local/other hostnames

Database connections and credentials are environment-specific.

## Frontend Development Notes

### CSS Framework Usage
- Primary framework is Bootstrap 5 for components
- TailwindCSS used for custom utilities and rapid styling
- FontAwesome Pro icons (version 5.15.4) available
- Custom CSS in `/assets/css/styles.css` (compiled from `/src/input.css`)

### JavaScript Libraries
- jQuery 3.7.0 for DOM manipulation and AJAX
- FullCalendar 6.1.15 for calendar interactions
- Flatpickr for date/time picking
- Select2 for enhanced dropdowns
- Moment.js for date manipulation

### API Integration
- RESTful endpoints in `/api/` directory
- ColdFusion components return JSON for AJAX calls
- Authentication required for most API calls
- Office 365 calendar integration available

## Development Guidelines

### ColdFusion Best Practices
- Use parameterized queries to prevent SQL injection
- Implement proper error handling with try/catch blocks
- Log errors to `/assets/logs/` directory
- Follow component-based architecture patterns
- Use remote access="remote" for AJAX-callable functions

### Database Interactions
- All database credentials managed in `config/database.cfc`
- Use Oracle-specific SQL syntax (LISTAGG, TO_CHAR, etc.)
- Implement proper transaction handling for complex operations
- Index foreign keys for optimal performance

### Security Considerations
- Role-based access control implemented
- Session timeout management
- SQL injection prevention via cfqueryparam
- Sensitive data (passwords, API keys) managed securely

## Special Features

### Office 365 Integration
- Calendar synchronization capabilities
- Authentication callback handling in `/api/auth/office365-callback.cfm`

### Notification System
- In-app notifications with read/unread status
- Email notifications for bookings and reminders
- User preference management for notification types

### Maintenance Management
- Room maintenance status tracking
- Scheduling system for maintenance windows
- Impact on room availability

## File Upload and Management
- Temporary files stored in `/assets/temp/`
- Room images stored as CLOB in database
- ICS calendar file generation for bookings

## Common Issues and Solutions

### Database Connection Issues
- Verify Oracle database credentials in environment-specific config
- Check network connectivity to database servers
- Ensure proper schema permissions

### CSS Compilation Issues
- Run `npm install` to ensure all dependencies are available
- Check PostCSS configuration in `postcss.config.js`
- Verify TailwindCSS config includes all necessary file paths

### JavaScript Errors
- Check browser console for client-side errors
- Verify jQuery and required libraries are loading
- Ensure AJAX endpoints return proper JSON responses