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
- **npm**: Package management and build processes
- **PostCSS**: CSS processing with autoprefixer
- **SweetAlert2**: Enhanced alert dialogs
- **DataTables**: Advanced table functionality
- **FullCalendar**: Interactive calendar for booking management
- **Flatpickr**: Date/time picker
- **Select2**: Enhanced dropdowns
- **Moment.js**: Date manipulation

## Common Development Commands

### CSS Development
- CSS is compiled from /src/input.css to /assets/css/styles.css
- Use bootstrap 5 for responsive design
- Use FontAwesome Pro for icons


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
- Style guide documentation (`styleguide.html`) with accessibility-compliant text contrast
- Proper CSS variable usage for consistent theming and accessibility

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

## UI/UX Design Integration

This project benefits from UI/UX design expertise to enhance user experience and interface quality. The UI/UX designer agent should be consulted for design-related tasks and improvements.

### When to Use the UI/UX Designer Agent

#### Design System and Component Development
- Creating design systems for consistent UI components across the reservation system
- Establishing color schemes, typography scales, and spacing standards
- Developing component libraries that work with Bootstrap 5 and TailwindCSS
- Designing reusable UI patterns for booking forms, calendar views, and admin interfaces

#### User Experience Optimization
- **Room Search and Filtering**: Improving the room discovery experience with better filtering, sorting, and search functionality
- **Booking Flow**: Optimizing the multi-step booking process for reduced friction and higher completion rates
- **Calendar Interactions**: Enhancing FullCalendar UI for better date/time selection and availability visualization
- **Mobile Experience**: Ensuring responsive design works optimally across devices for on-the-go bookings
- **Administrative Dashboards**: Designing intuitive interfaces for room management, user administration, and reporting

#### Accessibility and Inclusive Design
- Ensuring WCAG 2.1 AA compliance across all interfaces
- Designing for keyboard navigation and screen reader compatibility
- Creating high-contrast modes and font size options
- Testing color accessibility for colorblind users
- Implementing proper ARIA labels and semantic HTML structure
- Maintaining accessible documentation (style guides with proper text contrast)
- Fixing text visibility issues in design documentation and examples
- Ensuring code elements in documentation have proper background/text color combinations

#### User Research and Testing
- Conducting usability testing for booking workflows
- Creating user personas for different roles (employees, administrators, maintenance staff)
- Mapping user journeys for common tasks (booking a room, managing reservations, handling conflicts)
- Analyzing user pain points in the current system
- Developing user feedback collection mechanisms

### UI/UX Agent Integration Examples

#### Example 1: Booking Form Redesign
```markdown
Request: "I need to improve the room booking form UX. Users are struggling with the multi-step process."

UI/UX Agent Response:
- User journey mapping for the booking process
- Wireframes for a simplified single-page booking form
- Progressive disclosure patterns for advanced options
- Clear validation messaging and error handling design
- Mobile-first responsive layout specifications
```

#### Example 2: Room Search Interface
```markdown
Request: "Design a better room search experience with filtering capabilities."

UI/UX Agent Response:
- Information architecture for room attributes and amenities
- Filter panel design with clear categorization
- Search result card layouts with key information hierarchy
- Quick filter chips for common requests
- Advanced search patterns for complex queries
```

#### Example 3: Administrative Dashboard
```markdown
Request: "Create an intuitive admin dashboard for managing room reservations and conflicts."

UI/UX Agent Response:
- Dashboard layout with priority-based information hierarchy
- Data visualization patterns for booking analytics
- Conflict resolution workflow design
- Bulk action interfaces for managing multiple bookings
- Permission-based UI states for different admin roles
```

### Design System Guidelines for This Project

#### Component Integration with Existing Stack
- **Bootstrap 5 Components**: Use as foundation, customize with TailwindCSS utilities
- **Custom Components**: Design system components should extend Bootstrap patterns
- **Color Palette**: Work within medical center branding guidelines
- **Typography**: Leverage existing font choices while ensuring readability hierarchy

#### Responsive Design Patterns
- **Mobile-First**: Design for smartphone users who need quick room bookings
- **Tablet Optimization**: Optimize calendar views for tablet interfaces
- **Desktop Enhancement**: Leverage larger screens for complex administrative tasks

#### Accessibility Standards
- **Color Contrast**: Maintain 4.5:1 ratio for normal text, 3:1 for large text (recently enforced in styleguide.html)
- **Text Visibility**: Ensure no white text on white background issues (fixed in style guide documentation)
- **Code Elements**: Use light gray backgrounds with dark text for optimal readability
- **Keyboard Navigation**: Ensure all interactive elements are keyboard accessible
- **Screen Reader Support**: Provide meaningful ARIA labels and descriptions
- **Focus Management**: Clear focus indicators and logical tab order
- **CSS Variables**: Use proper color variable references (avoid invalid variables like --color-light-blue)
- **Global Accessibility Rules**: Implement comprehensive CSS rules for consistent text contrast across all components

### Implementation Workflow

#### 1. Design Phase
- Consult UI/UX designer agent for wireframes and user flow documentation
- Create design specifications that align with TailwindCSS utility classes
- Ensure designs work within ColdFusion template structure

#### 2. Development Phase
- Implement designs using existing CSS framework stack
- Update TailwindCSS configuration as needed for custom design tokens
- Test responsive behavior across devices

#### 3. Testing and Iteration
- Conduct usability testing with actual users
- Gather feedback and iterate on designs
- Monitor analytics for user behavior insights

### Design Documentation Standards

When working with the UI/UX designer agent, maintain documentation for:
- **User Personas**: Roles, goals, and pain points for different user types
- **User Journey Maps**: Step-by-step flows for key tasks
- **Wireframes**: Low and high-fidelity layouts for new features
- **Design Specifications**: Detailed implementation guidelines
- **Accessibility Requirements**: WCAG compliance checklists and testing results
- **Usability Testing Results**: Findings and recommendations from user testing sessions

### Integration with Development Process

#### Frontend Development
- UI/UX designs should specify TailwindCSS classes where possible
- Provide Bootstrap 5 component modifications and extensions
- Include responsive breakpoint specifications
- Document JavaScript interaction patterns

#### Backend Integration
- Design database schema considerations for user preferences
- Plan for accessibility metadata storage
- Consider performance implications of design choices
- Ensure designs work with ColdFusion template limitations

#### Testing Strategy
- Include design review checkpoints in development workflow
- Establish usability testing schedules for major features
- Create accessibility testing protocols
- Monitor user experience metrics post-deployment

## Documentation Maintenance and Update System

This project utilizes an automated documentation maintenance system to ensure all project documentation remains current, comprehensive, and accurate. The doc-updater agent works proactively to maintain documentation hygiene and developer productivity.

### When to Use the Doc-Updater Agent

The doc-updater agent MUST BE USED PROACTIVELY after the following changes:

#### Code Modifications (MANDATORY TRIGGERS)
- **ColdFusion Files**: Any changes to `.cfm`, `.cfc`, or `.cfml` files
- **Frontend Files**: Modifications to `.html`, `.css`, `.js`, `.jsx`, `.ts`, `.tsx` files
- **Configuration Files**: Updates to `package.json`, `postcss.config.js`, `tailwind.config.js`
- **Database Scripts**: Changes to files in `/assets/sql/` directory
- **API Endpoints**: New or modified files in `/api/` directory

#### Feature and Functionality Changes (MANDATORY TRIGGERS)
- **New API Endpoints**: Any new REST endpoints or ColdFusion remote functions
- **Database Schema Changes**: New tables, columns, indexes, or constraints
- **New Features**: Implementation of booking workflows, notification systems, etc.
- **UI/UX Improvements**: Interface changes, new components, accessibility enhancements
- **Configuration Changes**: Environment variables, database connections, third-party integrations
- **Security Updates**: Authentication changes, permission modifications
- **Integration Updates**: Office 365, calendar sync, email notification changes

#### UI/UX and Design Changes (MANDATORY TRIGGERS)
- **Icon Changes**: Bootstrap Icons to FontAwesome migrations
- **Branding Updates**: MD Anderson branding implementations
- **Responsive Design**: Mobile-first design implementations
- **Accessibility Improvements**: WCAG compliance enhancements
- **CSS Framework Updates**: TailwindCSS utility additions, Bootstrap customizations
- **Animation and Interaction**: New CSS animations, JavaScript interactions

### Documentation Standards for This Project

#### File Naming and Organization
- Use descriptive, consistent naming conventions
- Maintain chronological change logs with ISO date format (YYYY-MM-DD)
- Group related changes in logical sections
- Use clear headings and subheadings for navigation

#### Content Guidelines
- **Clarity**: Write in plain English, avoid unnecessary jargon
- **Completeness**: Include setup instructions, usage examples, and troubleshooting
- **Accuracy**: Ensure all code examples work and all links are valid
- **Consistency**: Follow established formatting patterns across all documentation

#### Technical Documentation Requirements
- **API Documentation**: Include request/response examples for all endpoints
- **Database Schema**: Document table relationships, constraints, and indexes
- **Configuration Examples**: Provide working examples for all environments
- **Error Handling**: Document common errors and their solutions
- **Dependencies**: List all required software, versions, and installation steps

### Documentation Files to Maintain

#### Primary Documentation Files
```
/CLAUDE.md                    # Project instructions and architecture (this file)
/README.md                    # Project overview and quick start guide
/package.json                 # Dependencies and build scripts
/docs/setup.md               # Detailed setup and installation guide
/docs/api.md                 # API endpoint documentation
/docs/database.md            # Database schema and migration guide
/docs/deployment.md          # Deployment and environment configuration
/docs/troubleshooting.md     # Common issues and solutions
```

#### Component-Specific Documentation
```
/assets/cfc/README.md        # ColdFusion component documentation
/components/README.md        # Reusable component documentation
/api/README.md               # API endpoint listing and examples
/assets/js/README.md         # JavaScript library and custom code documentation
/assets/css/README.md        # CSS framework usage and customization guide
```

### Doc-Updater Agent Integration Examples

#### Example 1: New API Endpoint Added
When a new ColdFusion API endpoint is created:

```cfm
<!-- /api/rooms/availability.cfm -->
<cfcomponent>
    <cffunction name="checkAvailability" access="remote" returnformat="json">
        <!--- New room availability checking logic --->
    </cffunction>
</cfcomponent>
```

**Required Documentation Updates:**
- Update `/docs/api.md` with new endpoint documentation
- Add endpoint to API listing in `CLAUDE.md`
- Update `/api/README.md` with usage examples
- Document request/response format and authentication requirements

#### Example 2: UI/UX Enhancement Implementation
When admin-notification-control.html is updated with MD Anderson branding:

```html
<!-- Enhanced with FontAwesome icons and professional styling -->
<div class="admin-notification-panel">
    <i class="fas fa-bell" aria-hidden="true"></i>
    <span class="notification-text">System Notifications</span>
</div>
```

**Required Documentation Updates:**
- Update `CLAUDE.md` Frontend Development Notes with FontAwesome version
- Document new CSS variables and animation classes in `/assets/css/README.md`
- Update accessibility compliance notes
- Add branding guidelines to design documentation
- Update responsive design patterns documentation

#### Example 3: Database Schema Change
When a new notification preferences table is added:

```sql
-- /assets/sql/notifications_preferences.sql
CREATE TABLE NOTIFICATION_PREFERENCES (
    USER_ID NUMBER NOT NULL,
    EMAIL_ENABLED CHAR(1) DEFAULT 'Y',
    IN_APP_ENABLED CHAR(1) DEFAULT 'Y',
    CREATED_DATE DATE DEFAULT SYSDATE
);
```

**Required Documentation Updates:**
- Update `/docs/database.md` with new table documentation
- Add table relationships to schema diagram
- Update `CLAUDE.md` Database Schema section
- Document migration scripts and rollback procedures

### Integration with UI/UX Designer Agent

The doc-updater agent works in conjunction with the UI/UX designer agent to maintain comprehensive design and implementation documentation:

#### Collaborative Documentation Workflow
1. **UI/UX Designer Agent** creates design specifications and user experience documentation
2. **Doc-Updater Agent** ensures implementation documentation reflects design decisions
3. **Both agents** maintain consistency between design intent and technical implementation

#### Design Documentation Integration
- **Design System Updates**: When UI/UX agent updates design systems, doc-updater ensures technical documentation reflects new patterns
- **Accessibility Documentation**: Both agents maintain WCAG compliance documentation
- **Component Documentation**: UI/UX designs and technical implementation documentation stay synchronized
- **User Experience Documentation**: User flows, personas, and technical capabilities are documented together

### Automation Workflow

#### Trigger Detection
The doc-updater agent monitors for:
- Git commits affecting documentation-relevant files
- New files in critical directories (`/api/`, `/components/`, `/assets/cfc/`)
- Changes to configuration files
- UI/UX improvements and design system updates

#### Update Process
1. **Analyze Changes**: Scan modified files for documentation impact
2. **Identify Documentation Files**: Determine which documentation needs updates
3. **Generate Content**: Create accurate, comprehensive documentation updates
4. **Validate Links**: Ensure all internal and external links remain functional
5. **Check Consistency**: Maintain formatting and style consistency across files

#### Quality Assurance
- **Accuracy Verification**: Ensure all code examples work correctly
- **Completeness Check**: Verify all new features and changes are documented
- **Cross-Reference Validation**: Maintain consistency across related documentation files
- **Accessibility Review**: Ensure documentation itself meets accessibility standards

### Technology Stack Documentation Guidelines

#### ColdFusion-Specific Documentation
- **Component Documentation**: Use CFDoc standards for ColdFusion components
- **Database Integration**: Document Oracle-specific syntax and considerations
- **Error Handling**: Include ColdFusion error handling patterns and logging
- **Security Practices**: Document cfqueryparam usage and session management

#### Frontend Technology Documentation
- **Bootstrap 5 Integration**: Document component customizations and extensions
- **TailwindCSS Usage**: Maintain utility class documentation and custom configurations
- **JavaScript Libraries**: Document jQuery plugins, FullCalendar customizations
- **Build Process**: Keep npm scripts and PostCSS configuration documented

#### Build and Deployment Documentation
- **Environment Configuration**: Document development, staging, and production differences
- **CSS Compilation**: Maintain TailwindCSS build process documentation
- **Database Deployment**: Document schema migration and rollback procedures
- **Server Configuration**: Document ColdFusion server requirements and setup

### Recent Documentation Updates

#### 2025-08-15: Style Guide Accessibility Improvements
- **Text Visibility Fixes**: Resolved white text on white background issues throughout styleguide.html
- **Typography Enhancements**: Fixed typography examples with proper dark text colors for optimal readability
- **Code Element Styling**: Added light gray backgrounds with dark text for all code elements
- **CSS Variable Fixes**: Corrected invalid CSS variable reference from --color-light-blue to --md-dark
- **Icon Examples**: Enhanced icon examples with proper text colors and background styling for code elements
- **Card Components**: Improved card components with proper text contrast ratios
- **Color Swatch Updates**: Fixed color swatch code elements with proper background and text colors
- **Global Accessibility Rules**: Added comprehensive CSS rules ensuring all text elements meet WCAG contrast requirements
- **Accessibility Compliance**: Achieved proper contrast ratios (4.5:1 for normal text, 3:1 for large text)
- **Readability Enhancement**: Ensured all documentation elements have clear visibility against their backgrounds

#### 2025-08-15: Enhanced Admin Notification Control
- **UI/UX Improvements**: Updated admin-notification-control.html with MD Anderson branding
- **Icon Migration**: Changed from Bootstrap Icons to FontAwesome Pro 5.15.4
- **Accessibility**: Enhanced ARIA labels and keyboard navigation
- **Responsive Design**: Improved mobile and tablet interface layouts
- **CSS Enhancements**: Added new CSS variables and professional animations
- **Documentation Impact**: Updated Frontend Development Notes, accessibility guidelines, and design system documentation

### Maintenance Schedule

#### Daily Monitoring
- Monitor git commits for documentation-relevant changes
- Check for new API endpoints and database modifications
- Validate external links and references

#### Weekly Review
- Comprehensive documentation accuracy review
- Update version numbers and dependency information
- Review and update troubleshooting sections

#### Monthly Audit
- Complete documentation coverage audit
- Update setup and installation procedures
- Review and update architecture documentation
- Validate all code examples and configurations

## Style Guide Enforcement System

This project utilizes a comprehensive style guide enforcement system to ensure all user interfaces maintain consistency with the established design standards. The styleguide-enforcer agent works proactively to validate compliance with the MD Anderson branding guidelines and accessibility standards defined in `styleguide.html`.

### When to Use the Styleguide-Enforcer Agent

The styleguide-enforcer agent MUST BE USED PROACTIVELY during the following development activities:

#### HTML/CSS Development (MANDATORY TRIGGERS)
- **New HTML Files**: Any creation of new `.html`, `.cfm`, or template files
- **CSS Modifications**: Changes to `.css` files, custom stylesheets, or style blocks
- **Component Creation**: Development of new UI components or layout elements
- **Page Updates**: Modifications to existing pages that affect styling or layout
- **Template Changes**: Updates to ColdFusion templates that include HTML/CSS
- **Email Template Development**: Creation or modification of email templates in `/views/emails/`

#### Visual Element Changes (MANDATORY TRIGGERS)
- **Typography Updates**: Font changes, text styling, or heading modifications
- **Color Palette Changes**: Implementation of new colors or modification of existing color schemes
- **Button Styling**: Creation or modification of button components and styles
- **Form Design**: Updates to form layouts, input styling, or form component design
- **Navigation Elements**: Changes to top navigation, breadcrumbs, or menu styling
- **Card Components**: Creation or modification of card layouts and styling
- **Modal Design**: Updates to modal dialogs, alerts, or popup styling
- **Icon Implementation**: Adding or changing FontAwesome icons and their styling

#### UI/UX Improvements (MANDATORY TRIGGERS)
- **Responsive Design**: Implementation of mobile-first design patterns
- **Accessibility Enhancements**: WCAG compliance improvements or accessibility fixes
- **Animation Implementation**: Adding CSS animations, transitions, or AOS effects
- **Layout Changes**: Grid system modifications, spacing updates, or container changes
- **Interactive Components**: Toggle switches, badges, status indicators, or custom controls
- **Branding Updates**: MD Anderson logo placement, color scheme implementation

### Style Guide Compliance Standards

The styleguide-enforcer agent ensures adherence to the standards defined in `/Users/epena1/ColdFusion_2021/ColdFusion/cfusion/wwwroot/DoCMRoomReservation/styleguide.html`:

#### Color Palette Enforcement
```css
/* MD Anderson Primary Colors - MANDATORY COMPLIANCE */
--md-primary: #003C7F;           /* Main brand color, primary buttons, headers */
--md-secondary: #006BA6;         /* Secondary actions, gradients */
--md-success: #28a745;           /* Success states, confirmations */
--md-danger: #dc3545;            /* Errors, deletions, warnings */
--md-warning: #ffc107;           /* Cautions, pending states */
--md-info: #17a2b8;              /* Information, highlights */
--md-light: #f8f9fa;             /* Light backgrounds */
--md-dark: #343a40;              /* Dark text, borders */
--user-nav-primary: #4F46E5;     /* User navigation elements */
--user-nav-hover: #4338CA;       /* User navigation hover states */
```

**Validation Requirements:**
- All custom colors must use CSS variables from the defined palette
- No arbitrary hex colors outside the approved palette
- Room color system must follow the 25-color accessibility-compliant scheme
- Contrast ratios must meet WCAG AA standards (4.5:1 for normal text, 3:1 for large text)

#### Typography Standards
```css
/* Montserrat Font Family - MANDATORY USAGE */
font-family: 'Montserrat', sans-serif;

/* Typography Scale - MANDATORY COMPLIANCE */
h1 { font-size: 2.5rem; }      /* 40px */
h2 { font-size: 2rem; }        /* 32px */
h3 { font-size: 1.75rem; }     /* 28px */
h4 { font-size: 1.5rem; }      /* 24px */
h5 { font-size: 1.25rem; }     /* 20px */
h6 { font-size: 1rem; }        /* 16px */
body { font-size: 1rem; }      /* 16px */
small { font-size: 0.875rem; } /* 14px */
```

**Validation Requirements:**
- All text must use Montserrat font family
- Font sizes must conform to the established scale
- Font weights limited to 400 (regular), 600 (semi-bold), 700 (bold)
- All headings must use proper color variables (--md-primary or --md-dark)

#### Component Structure Compliance
```html
<!-- Button Components - MANDATORY STRUCTURE -->
<button type="button" class="btn btn-primary">Standard Button</button>
<button type="button" class="btn-enhanced btn-primary">Enhanced Button</button>
<a href="#" class="btn-admin-topNav">Admin Navigation</a>
<a href="#" class="btn-user-topNav">User Navigation</a>

<!-- Card Components - MANDATORY STRUCTURE -->
<div class="card">                    <!-- Standard cards -->
<div class="enhanced-card">           <!-- Enhanced cards with animations -->

<!-- Form Controls - MANDATORY STRUCTURE -->
<input type="text" class="form-control">           <!-- Standard forms -->
<input type="text" class="form-control-enhanced">  <!-- Enhanced forms -->
```

**Validation Requirements:**
- All buttons must use approved CSS classes
- Card components must follow established structure patterns
- Form controls must use proper Bootstrap or enhanced classes
- No custom component classes without style guide approval

#### Spacing and Layout Standards
```css
/* Spacing System - MANDATORY COMPLIANCE */
margin/padding: 0.5rem, 1rem, 1.5rem, 2rem, 3rem;  /* Bootstrap spacing scale */

/* Border Radius - MANDATORY VALUES */
border-radius: 0.25rem, 0.5rem, 0.75rem, 1rem;

/* Box Shadow - MANDATORY USAGE */
--shadow-sm: 0 0.125rem 0.25rem rgba(0, 0, 0, 0.075);
--shadow: 0 0.5rem 1rem rgba(0, 0, 0, 0.15);
--shadow-lg: 0 1rem 3rem rgba(0, 0, 0, 0.175);
```

**Validation Requirements:**
- Spacing must use Bootstrap spacing utilities (m-*, p-*, etc.)
- Border radius values must be from approved scale
- Box shadows must use CSS variables, not arbitrary values
- Grid system must use Bootstrap classes (container, row, col-*)

#### Responsive Design Implementation
```css
/* Bootstrap Breakpoints - MANDATORY COMPLIANCE */
xs: <576px     /* Mobile phones */
sm: ≥576px     /* Large phones, small tablets */
md: ≥768px     /* Tablets */
lg: ≥992px     /* Laptops, small desktops */
xl: ≥1200px    /* Large desktops */
xxl: ≥1400px   /* Extra large desktops */
```

**Validation Requirements:**
- Mobile-first design approach mandatory
- All layouts must be responsive across breakpoints
- Use Bootstrap grid classes (col-sm-*, col-md-*, etc.)
- Test across all device sizes

#### Accessibility Standards Enforcement
```html
<!-- ARIA Labels - MANDATORY IMPLEMENTATION -->
<button aria-label="Close dialog" class="btn-close"></button>
<nav aria-label="breadcrumb"></nav>
<div aria-live="polite" id="status"></div>

<!-- Semantic HTML - MANDATORY USAGE -->
<main>, <nav>, <header>, <footer>, <section>, <article>

<!-- Form Labels - MANDATORY ASSOCIATION -->
<label for="email">Email Address</label>
<input type="email" id="email" class="form-control" required>
```

**Validation Requirements:**
- All interactive elements must have proper ARIA labels
- Semantic HTML must be used for page structure
- Form inputs must have associated labels
- Focus indicators must be clearly visible
- Color cannot be the sole means of conveying information

#### CSS Class Naming Conventions
```css
/* Approved Naming Patterns */
.btn-enhanced          /* Enhanced component variations */
.form-control-enhanced /* Enhanced form controls */
.enhanced-card         /* Enhanced card components */
.status-badge         /* Status indicators */
.toggle-switch        /* Custom toggle controls */
.fade-in, .slide-in   /* Animation classes */
.style-section        /* Style guide specific classes */
```

**Validation Requirements:**
- Use descriptive, semantic class names
- Follow BEM methodology where appropriate
- Prefix custom classes appropriately
- No abbreviations or unclear naming

### Styleguide-Enforcer Agent Integration Workflow

#### 1. Pre-Development Validation
Before implementing any UI changes:
```markdown
1. Reference styleguide.html for approved patterns
2. Validate color choices against CSS variables
3. Confirm typography scale compliance
4. Review component structure requirements
5. Plan responsive design approach
```

#### 2. Development Phase Enforcement
During active development:
```markdown
1. Real-time validation of HTML structure
2. CSS property compliance checking
3. Color palette adherence verification
4. Typography scale validation
5. Accessibility requirement verification
6. Component pattern compliance
```

#### 3. Post-Development Review
After implementation:
```markdown
1. Cross-browser compatibility check
2. Responsive design validation
3. Accessibility audit (WCAG AA compliance)
4. Performance impact assessment
5. Visual consistency verification
6. Documentation update requirements
```

### Agent Collaboration Framework

#### Integration with UI/UX Designer Agent
The styleguide-enforcer works in conjunction with the UI/UX designer agent:

```markdown
**UI/UX Designer Agent Responsibilities:**
- Create design specifications within style guide parameters
- Propose new component patterns for style guide inclusion
- Ensure user experience optimizes within design constraints
- Provide accessibility guidance and testing recommendations

**Styleguide-Enforcer Agent Responsibilities:**
- Validate implementation against approved design patterns
- Enforce consistency across all UI components
- Ensure accessibility compliance in implementation
- Maintain style guide documentation accuracy
```

#### Integration with Doc-Updater Agent
The styleguide-enforcer collaborates with the doc-updater agent:

```markdown
**Collaborative Documentation Workflow:**
1. Styleguide-enforcer validates implementation compliance
2. Doc-updater updates technical documentation to reflect changes
3. Both agents ensure styleguide.html remains current
4. Cross-reference validation between style guide and implementation docs
```

### Technology Stack Integration

#### ColdFusion Backend Integration
```cfm
<!-- ColdFusion Template Compliance -->
<cfoutput>
<!DOCTYPE html>
<html lang="en">
<head>
    <!-- Required style guide CSS loading order -->
    <link href="node_modules/bootstrap/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="assets/fontawesome-pro-5.15.4/css/all.css" rel="stylesheet">
    <link href="assets/css/styles.css" rel="stylesheet">
</head>
<body>
    <!-- Compliant component usage -->
    <div class="enhanced-card">
        <div class="card-header">
            <h5><i class="fas fa-calendar me-2"></i>#pageTitle#</h5>
        </div>
        <div class="card-body">
            <!-- Content with proper styling -->
        </div>
    </div>
</body>
</html>
</cfoutput>
```

#### Bootstrap 5 Framework Compliance
```html
<!-- Approved Bootstrap Component Usage -->
<button class="btn btn-primary">Standard Bootstrap</button>
<button class="btn btn-enhanced btn-primary">Enhanced with custom styling</button>

<!-- Grid System Compliance -->
<div class="container">
    <div class="row">
        <div class="col-md-6 col-lg-4">Content</div>
    </div>
</div>
```

#### TailwindCSS Utility Integration
```css
/* Limited TailwindCSS Usage - Only for Utilities */
/* Primary styling must use Bootstrap + custom CSS */
.utility-spacing { @apply p-4 m-2; }  /* Acceptable utility usage */
.custom-component { /* Must follow style guide patterns */ }
```

#### jQuery and JavaScript Integration
```javascript
// Style guide compliant JavaScript patterns
$(document).ready(function() {
    // Enhanced component initialization
    $('.btn-enhanced').on('click', function() {
        $(this).addClass('fade-in');
        setTimeout(() => {
            $(this).removeClass('fade-in');
        }, 500);
    });
    
    // Form validation with style guide messaging
    $('.form-control-enhanced').on('focus', function() {
        $(this).addClass('focused');
    });
});
```

### Validation Examples and Compliance Checks

#### Example 1: Button Component Validation
**Non-Compliant Code:**
```html
<button style="background: #ff6b6b; padding: 12px 24px; border-radius: 8px;">
    Custom Button
</button>
```

**Style Guide Compliant Code:**
```html
<button type="button" class="btn-enhanced btn-primary">
    <i class="fas fa-save me-1"></i>Custom Button
</button>
```

**Enforcement Actions:**
- Remove inline styles
- Apply approved button classes
- Use CSS variables for colors
- Add proper icon with spacing

#### Example 2: Form Component Validation
**Non-Compliant Code:**
```html
<input type="text" style="border: 2px solid blue; border-radius: 10px;">
```

**Style Guide Compliant Code:**
```html
<div class="mb-3">
    <label for="textInput" class="form-label">Text Input</label>
    <input type="text" class="form-control-enhanced" id="textInput" placeholder="Enter text">
</div>
```

**Enforcement Actions:**
- Remove inline styles
- Add proper form structure with labels
- Use enhanced form control classes
- Ensure accessibility compliance

#### Example 3: Color Usage Validation
**Non-Compliant Code:**
```css
.custom-header {
    background-color: #3498db;
    color: #2c3e50;
}
```

**Style Guide Compliant Code:**
```css
.custom-header {
    background: linear-gradient(135deg, var(--md-primary) 0%, var(--md-secondary) 100%);
    color: white;
}
```

**Enforcement Actions:**
- Replace arbitrary colors with CSS variables
- Use approved gradient patterns
- Ensure proper contrast ratios

### Automated Validation Checklist

#### HTML Structure Validation
- [ ] Semantic HTML elements used appropriately
- [ ] Proper heading hierarchy (h1-h6) maintained
- [ ] All interactive elements have proper ARIA labels
- [ ] Form inputs have associated labels
- [ ] Required accessibility attributes present

#### CSS Compliance Validation
- [ ] All colors use CSS variables from approved palette
- [ ] Typography uses Montserrat font family and approved scale
- [ ] Spacing uses Bootstrap utilities or approved values
- [ ] Border radius values from approved scale
- [ ] Box shadows use CSS variables

#### Component Pattern Validation
- [ ] Button components use approved classes
- [ ] Card components follow established structure
- [ ] Form controls use proper Bootstrap or enhanced classes
- [ ] Navigation elements follow approved patterns
- [ ] Icons use FontAwesome Pro 5.15.4 classes

#### Responsive Design Validation
- [ ] Mobile-first design approach implemented
- [ ] Responsive across all Bootstrap breakpoints
- [ ] Grid system uses Bootstrap classes
- [ ] No horizontal scrolling on mobile devices
- [ ] Touch targets meet minimum size requirements (44px)

#### Accessibility Validation
- [ ] WCAG AA contrast ratios met (4.5:1 normal, 3:1 large text)
- [ ] Keyboard navigation functional
- [ ] Focus indicators clearly visible
- [ ] Screen reader compatibility verified
- [ ] No reliance on color alone for information

### Error Reporting and Correction Workflow

#### Validation Error Categories
```markdown
**Critical Errors (Must Fix Immediately):**
- Accessibility violations (WCAG AA non-compliance)
- Arbitrary colors outside approved palette
- Missing semantic HTML structure
- Non-responsive design implementation

**High Priority Errors (Fix Before Deployment):**
- Incorrect component structure patterns
- Typography scale violations
- Missing CSS variable usage
- Bootstrap framework misuse

**Medium Priority Errors (Fix in Next Sprint):**
- Spacing inconsistencies
- Animation implementation issues
- Icon usage inconsistencies
- Minor styling deviations

**Low Priority Errors (Technical Debt):**
- CSS optimization opportunities
- Component consolidation possibilities
- Documentation update needs
- Performance enhancement opportunities
```

#### Correction Implementation Process
```markdown
1. **Error Identification**
   - Automated scanning of HTML/CSS files
   - Manual review of component implementations
   - Cross-reference with styleguide.html standards

2. **Priority Assessment**
   - Categorize errors by severity level
   - Consider accessibility impact
   - Evaluate user experience implications

3. **Correction Implementation**
   - Apply approved style guide patterns
   - Update component structure as needed
   - Validate accessibility compliance
   - Test responsive design functionality

4. **Verification and Documentation**
   - Re-scan for compliance after corrections
   - Update component documentation
   - Record lessons learned for future reference
   - Update style guide if new patterns emerge
```

### Style Guide Maintenance and Evolution

#### Continuous Improvement Process
The styleguide-enforcer agent participates in the ongoing evolution of the design system:

```markdown
**Monthly Style Guide Review:**
- Assess new component pattern needs
- Review accessibility standard updates
- Evaluate user feedback on interface design
- Consider technology stack updates (Bootstrap, FontAwesome, etc.)

**Quarterly Design System Audit:**
- Comprehensive compliance review across all pages
- Accessibility testing with real users
- Performance impact assessment of design decisions
- Update style guide documentation with new patterns

**Annual Style Guide Major Review:**
- Evaluate MD Anderson branding guideline changes
- Consider major framework updates (Bootstrap 6, etc.)
- Assess emerging accessibility standards
- Plan major design system improvements
```

#### Integration with Development Lifecycle
```markdown
**Pre-Development Phase:**
- Style guide consultation mandatory for new features
- Component pattern approval required before implementation
- Accessibility planning integrated into design phase

**Development Phase:**
- Real-time style guide validation during coding
- Automated compliance checking in development environment
- Peer review includes style guide compliance verification

**Testing Phase:**
- Style guide compliance included in QA checklist
- Accessibility testing mandatory before deployment
- Cross-browser style guide validation required

**Deployment Phase:**
- Final style guide compliance verification
- Documentation updates deployed with code changes
- Style guide pattern updates distributed to team
```

This comprehensive style guide enforcement system ensures that the DoCM Room Reservation System maintains visual consistency, accessibility compliance, and adherence to MD Anderson branding standards across all development activities.