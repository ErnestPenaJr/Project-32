## Authur
- Ernest Pena Jr

## Hotel Management System

A comprehensive office reservation management system built with ColdFusion, JavaScript, and modern CSS frameworks.

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

- ColdFusion 2021
- JavaScript
- HTML
- CSS
- Bootstrap
- jQuery
- Font Awesome
- Oracle Database

## Project Structure

The project follows a modular architecture with separate directories for:
- Assets (CSS, JavaScript, Images, Fonts)
- Components (Reusable HTML components)
- Pages (Main application pages)
- Services (JavaScript services)
- CFCs (ColdFusion Components) database management
- API (REST API endpoints)
- Config (Configuration files)

## Setup Instructions

1. Clone the repository
2. Configure your ColdFusion server
3. Set up the database using the provided scripts
4. Update the database configuration in `/config/database.cfc`
5. Start the ColdFusion server
6. Access the application through your web browser

## Development

Please follow the established coding standards and guidelines when contributing to this project.

Project Overview
Project Name: DoCM Room Reservation System

Purpose
Develop a modern, efficient, and user-friendly room reservation system tailored for the MD Anderson Cancer Center. The system aims to streamline the management of conference rooms, improve booking efficiency, and enhance user experience for both administrators and staff.

Objectives
Simplify Room Booking: Provide an intuitive interface for users to search for and reserve conference rooms.
Enhance Management Capabilities: Equip administrators with tools to monitor room utilization, manage users, and schedule maintenance.
Integrate with Existing Systems: Sync with Office 365 calendars for seamless scheduling.
Improve Communication: Implement notification systems for bookings, reminders, and maintenance alerts.
Key Features
Room Management

Detailed room listings with capacity, amenities, and availability.
Real-time updates on room status.
Support for multiple buildings and floors.
Amenities tracking (projector, whiteboard, video conferencing).
Maintenance status tracking.
Booking System

Interactive calendar with multiple views (monthly, weekly, daily).
Conflict detection and real-time booking updates.
Support for recurring reservations.
Office 365 calendar integration.
Booking confirmation notifications.
User Management

Role-based access control (Admins and Users).
Department-based organization.
User account status tracking and booking history.
Customizable notification preferences.
Notifications

Booking confirmations and reminders.
Maintenance alerts and status updates.
In-app notification center.
Admin Dashboard

Overview of all bookings and room utilization statistics.
User management interface.
System logs for activity monitoring.
Tools for scheduling and managing maintenance.
Technology Stack

## Frontend
ColdFusion 2021: Server-side language for building dynamic web applications.
JavaScript: Client-side scripting language for dynamic behavior.
Bootstrap: CSS framework for responsive and mobile-friendly web design.
jQuery: JavaScript library for simplifying DOM manipulation and event handling.
Font Awesome: Icon library for adding icons to web pages.
CSS: Cascading Style Sheets for styling web pages.
HTML: Markup language for structuring web pages.

## Backend
ColdFusion 2021: Server-side language for database interaction only.
jQuery: Client-side scripting language for dynamic behavior.
Oracle Database: Relational database for data storage and retrieval.
CSS: Cascading Style Sheets for styling web pages.
HTML: Markup language for structuring web pages.

## File Structure
root/
├─ index.html               # Main application page
├─ login.html               # Login page
├─ logout.html              # Logout page
├─ README.md                # Project documentation
├─ WORKFLOW.md              # Project workflow
├─ assets/
│  ├─ cfc/                  # ColdFusion Components
│  │  ├─ functions.cfc
│  ├─ css/
│  │  └─ styles.css          # Main CSS file
│  ├─ js/
│  │  └─ app.js             # Main JavaScript file
│  ├─ images/               # Image files
│  ├─ json/                 # JSON files
│  ├─ database/
│  │  └─ schema.sql
│  ├─ fonts/                # Font files
│  │  └─ fontawesome/
│  └─ temp/                 # Temporary upload directory
├─ documents/               # Processed document storage
└─ node_modules/            # Node.js dependencies