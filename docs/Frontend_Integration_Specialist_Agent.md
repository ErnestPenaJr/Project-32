# Frontend Integration Specialist Agent
## DoCM Room Reservation System

### Overview
The Frontend Integration Specialist agent is designed for the DoCM Room Reservation System, combining Bootstrap 5, TailwindCSS, and jQuery expertise with deep understanding of this specific project's frontend architecture. This agent specializes in creating cohesive, performant interfaces that integrate seamlessly with the ColdFusion backend.

---

## Core Frontend Stack

### Primary Frameworks
- **Bootstrap 5.3.3** - Component library and responsive grid system
- **TailwindCSS 3.3.2** - Utility-first CSS framework with custom configuration
- **jQuery 3.7.0** - DOM manipulation and AJAX communication
- **FullCalendar 6.1.15** - Calendar component with Bootstrap5 theme integration
- **FontAwesome Pro 5.15.4** - Icon library with complete icon sets

### Specialized Libraries
```javascript
// Calendar and Date Handling
@fullcalendar/bootstrap5: ^6.1.15
@fullcalendar/core: ^6.1.15
@fullcalendar/daygrid: ^6.1.15
@fullcalendar/interaction: ^6.1.15
@fullcalendar/timegrid: ^6.1.15
flatpickr: ^4.6.13
daterangepicker: ^3.1.0
moment: ^2.30.1

// UI Enhancement
sweetalert2: ^11.7.32
select2: ^4.1.0-rc.0
select2-bootstrap-5-theme: ^1.3.0
aos: ^2.3.4
@curiosityx/bootstrap-session-timeout: ^1.0.0

// Development Tools
tailwindcss: ^3.3.2
autoprefixer: ^10.4.14
postcss: ^8.4.24
```

---

## When to Use This Agent

### Primary Use Cases
1. **Calendar Interface Development**
   - FullCalendar integration and customization
   - Room availability display with real-time updates
   - Booking conflict detection and visualization
   - Event handling and data binding

2. **Form Enhancement and Validation**
   - Bootstrap form components with TailwindCSS styling
   - Client-side validation before ColdFusion submission
   - AJAX form submission with error handling
   - Dynamic form field generation

3. **Responsive Layout Development**
   - Mobile-first design implementation
   - Bootstrap grid system optimization
   - Cross-device compatibility testing
   - Progressive enhancement patterns

4. **Interactive Component Development**
   - Modal dialogs with SweetAlert2 integration
   - Enhanced dropdowns with Select2
   - Dynamic content loading
   - Real-time notification systems

5. **Admin Dashboard Interfaces**
   - DataTables integration for data management
   - Statistical widgets and charts
   - User management interfaces
   - System monitoring dashboards

### Specific Project Scenarios
- Implementing room booking interfaces
- Creating admin management panels
- Developing notification centers
- Building user preference management
- Integrating Office365 authentication flows
- Creating maintenance status indicators

---

## Key Capabilities

### 1. Bootstrap 5 Integration
```html
<!-- Component Integration Pattern -->
<div class="container-fluid">
    <div class="row">
        <div class="col-md-8">
            <!-- Bootstrap components with custom styling -->
            <div class="card shadow-sm">
                <div class="card-header bg-primary text-white">
                    <h5 class="card-title mb-0">Room Calendar</h5>
                </div>
                <div class="card-body p-0">
                    <div id="calendar"></div>
                </div>
            </div>
        </div>
        <div class="col-md-4">
            <!-- Booking form sidebar -->
        </div>
    </div>
</div>
```

### 2. TailwindCSS Custom Configuration
```javascript
// tailwind.config.js
module.exports = {
  content: [
    './pages/**/*.{html,js,cfm}',
    './components/**/*.{html,js,cfm}',
    './layouts/**/*.{html,js,cfm}',
    './views/**/*.{html,js,cfm}',
    './*.{html,js,cfm}',
  ],
  theme: {
    extend: {
      colors: {
        primary: '#1a365d',    // Custom brand colors
        secondary: '#718096',
        accent: '#4299e1',
      },
    },
  },
  plugins: [],
}
```

### 3. Custom Component Classes
```css
/* src/input.css */
@layer components {
  .btn-primary {
    @apply bg-primary text-white font-bold py-2 px-4 rounded hover:bg-opacity-90;
  }
  .form-input {
    @apply mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-primary focus:ring focus:ring-primary focus:ring-opacity-50;
  }
  .card {
    @apply bg-white rounded-lg shadow-md p-6;
  }
}
```

---

## FullCalendar Configuration and Integration

### Basic Calendar Setup
```javascript
// Calendar initialization with Bootstrap5 theme
document.addEventListener('DOMContentLoaded', function() {
    const calendarEl = document.getElementById('calendar');
    const calendar = new FullCalendar.Calendar(calendarEl, {
        themeSystem: 'bootstrap5',
        initialView: 'dayGridMonth',
        headerToolbar: {
            left: 'prev,next today',
            center: 'title',
            right: 'dayGridMonth,timeGridWeek,timeGridDay'
        },
        events: {
            url: 'api/bookings/list.cfm',
            method: 'GET',
            failure: function() {
                alert('There was an error fetching events!');
            }
        },
        eventClick: function(info) {
            showBookingDetails(info.event);
        },
        selectable: true,
        select: function(info) {
            showBookingForm(info.start, info.end);
        }
    });
    calendar.render();
});
```

### Room-Specific Calendar Events
```javascript
// Room availability and booking display
function loadRoomEvents(roomId) {
    calendar.removeAllEvents();
    calendar.addEventSource({
        url: `api/rooms/availability.cfm?roomId=${roomId}`,
        method: 'GET',
        extraParams: {
            include_blocked: true,
            include_maintenance: true
        },
        eventDataTransform: function(eventData) {
            // Transform ColdFusion data to FullCalendar format
            return {
                id: eventData.bookingId,
                title: eventData.eventTitle,
                start: eventData.startTime,
                end: eventData.endTime,
                backgroundColor: getStatusColor(eventData.status),
                extendedProps: {
                    roomName: eventData.roomName,
                    organizer: eventData.organizer,
                    status: eventData.status
                }
            };
        }
    });
}
```

---

## jQuery and AJAX Patterns

### ColdFusion Integration Patterns
```javascript
// Standard AJAX pattern for CFC communication
function makeBooking(bookingData) {
    $.ajax({
        url: 'assets/cfc/booking.cfc',
        type: 'POST',
        data: {
            method: 'createBooking',
            returnFormat: 'json',
            ...bookingData
        },
        dataType: 'json',
        beforeSend: function() {
            showLoading('#booking-form');
        },
        success: function(response) {
            if (response.success) {
                Swal.fire({
                    title: 'Success!',
                    text: 'Booking created successfully',
                    icon: 'success',
                    confirmButtonClass: 'btn btn-primary'
                });
                calendar.refetchEvents();
            } else {
                showError(response.message);
            }
        },
        error: function(xhr, status, error) {
            console.error('Booking error:', error);
            showError('Failed to create booking. Please try again.');
        },
        complete: function() {
            hideLoading('#booking-form');
        }
    });
}
```

### Real-time Data Updates
```javascript
// Polling pattern for real-time updates
function startRealtimeUpdates() {
    setInterval(() => {
        $.get('api/dashboard-data.cfm?method=getNotificationCount')
            .done(response => {
                updateNotificationBadge(response.count);
            });
    }, 30000); // Check every 30 seconds
}

// WebSocket alternative for real-time notifications
function initializeNotifications() {
    if (window.WebSocket) {
        const ws = new WebSocket('ws://localhost:8080/notifications');
        ws.onmessage = function(event) {
            const notification = JSON.parse(event.data);
            showNotificationToast(notification);
        };
    }
}
```

---

## Build Process and Development Workflow

### TailwindCSS Compilation
```bash
# Development with watch mode
npm run dev
# npx tailwindcss -i ./src/input.css -o ./assets/css/styles.css --watch

# Production build with minification
npm run build
# npx tailwindcss -i ./src/input.css -o ./assets/css/styles.css --minify
```

### PostCSS Configuration
```javascript
// postcss.config.js
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
```

### CSS Organization Strategy
```
assets/css/
├── styles.css              # Compiled TailwindCSS output
├── datetime-picker.css     # Custom datetime picker styles
├── datetime-range-picker.css
└── site_tutorial.css       # Tutorial overlay styles
```

---

## Component Library Integration

### SweetAlert2 Integration
```javascript
// Custom SweetAlert2 configurations
const SwalConfig = {
    default: {
        confirmButtonClass: 'btn btn-primary',
        cancelButtonClass: 'btn btn-secondary',
        buttonsStyling: false
    },
    
    deleteConfirm: {
        title: 'Are you sure?',
        text: "You won't be able to revert this!",
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'Yes, delete it!',
        cancelButtonText: 'Cancel'
    }
};

// Usage
Swal.fire({
    ...SwalConfig.default,
    ...SwalConfig.deleteConfirm
}).then((result) => {
    if (result.isConfirmed) {
        performDelete();
    }
});
```

### Select2 with Bootstrap 5 Theme
```javascript
// Enhanced dropdowns with search
$('.room-select').select2({
    theme: 'bootstrap-5',
    placeholder: 'Select a room...',
    allowClear: true,
    ajax: {
        url: 'assets/cfc/room.cfc?method=searchRooms',
        dataType: 'json',
        delay: 250,
        data: function(params) {
            return {
                search: params.term,
                page: params.page || 1
            };
        },
        processResults: function(data) {
            return {
                results: data.rooms.map(room => ({
                    id: room.id,
                    text: `${room.name} - ${room.building}`,
                    capacity: room.capacity
                }))
            };
        }
    }
});
```

### DataTables Integration
```javascript
// Admin interface data tables
$('#bookings-table').DataTable({
    processing: true,
    serverSide: true,
    ajax: {
        url: 'assets/cfc/booking.cfc?method=getBookings',
        type: 'POST',
        data: function(d) {
            return {
                ...d,
                returnFormat: 'json'
            };
        }
    },
    columns: [
        { data: 'bookingId', title: 'ID' },
        { data: 'roomName', title: 'Room' },
        { data: 'organizer', title: 'Organizer' },
        { data: 'startTime', title: 'Start Time' },
        { data: 'endTime', title: 'End Time' },
        { data: 'status', title: 'Status' },
        { 
            data: null,
            title: 'Actions',
            render: function(data, type, row) {
                return `
                    <button class="btn btn-sm btn-primary edit-booking" data-id="${row.bookingId}">
                        <i class="fas fa-edit"></i>
                    </button>
                    <button class="btn btn-sm btn-danger cancel-booking" data-id="${row.bookingId}">
                        <i class="fas fa-times"></i>
                    </button>
                `;
            }
        }
    ]
});
```

---

## Responsive Design Patterns

### Bootstrap Grid Integration with TailwindCSS
```html
<!-- Responsive layout combining Bootstrap grid with Tailwind utilities -->
<div class="container-fluid">
    <div class="row">
        <div class="col-lg-8 col-md-12">
            <div class="bg-white rounded-lg shadow-md p-6 mb-4">
                <!-- Calendar container -->
                <div id="calendar" class="w-full h-auto"></div>
            </div>
        </div>
        <div class="col-lg-4 col-md-12">
            <div class="space-y-4">
                <!-- Booking form -->
                <div class="bg-white rounded-lg shadow-md p-6">
                    <h3 class="text-lg font-semibold text-gray-800 mb-4">Quick Booking</h3>
                    <!-- Form content -->
                </div>
                
                <!-- Room info -->
                <div class="bg-blue-50 rounded-lg p-4">
                    <h4 class="text-md font-medium text-blue-800 mb-2">Room Information</h4>
                    <!-- Room details -->
                </div>
            </div>
        </div>
    </div>
</div>
```

### Mobile-First Media Queries
```css
/* Custom responsive utilities */
@media (max-width: 768px) {
    .mobile-stack {
        @apply flex-col space-y-4 space-x-0;
    }
    
    .mobile-full {
        @apply w-full;
    }
    
    .mobile-hidden {
        @apply hidden;
    }
}

@media (min-width: 769px) {
    .desktop-flex {
        @apply flex space-x-4 space-y-0;
    }
}
```

---

## Performance Optimization

### CSS Optimization
```javascript
// TailwindCSS purge configuration
module.exports = {
  content: [
    './pages/**/*.{html,js,cfm}',
    './components/**/*.{html,js,cfm}',
    './layouts/**/*.{html,js,cfm}',
    './views/**/*.{html,js,cfm}',
    './*.{html,js,cfm}',
  ],
  // Only include used classes in production
}
```

### JavaScript Optimization
```javascript
// Lazy loading for heavy components
function loadCalendar() {
    if (!window.calendarLoaded) {
        import('./assets/js/calendar-config.js')
            .then(module => {
                module.initializeCalendar();
                window.calendarLoaded = true;
            });
    }
}

// Debounced search
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

const debouncedSearch = debounce((query) => {
    performSearch(query);
}, 300);
```

---

## Accessibility and Standards

### WCAG Compliance Patterns
```html
<!-- Accessible form components -->
<div class="form-group">
    <label for="room-select" class="form-label">
        Select Room <span class="text-danger" aria-label="required">*</span>
    </label>
    <select id="room-select" class="form-select" aria-describedby="room-help" required>
        <option value="">Choose a room...</option>
    </select>
    <div id="room-help" class="form-text">
        Select the room you want to reserve for your meeting.
    </div>
</div>

<!-- Accessible modal dialogs -->
<div class="modal fade" id="booking-modal" tabindex="-1" aria-labelledby="booking-modal-title" aria-hidden="true">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="booking-modal-title">Create Booking</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <!-- Modal content -->
        </div>
    </div>
</div>
```

### Keyboard Navigation
```javascript
// Enhanced keyboard navigation for calendar
document.addEventListener('keydown', function(e) {
    if (e.target.closest('#calendar')) {
        switch(e.key) {
            case 'ArrowLeft':
                calendar.prev();
                e.preventDefault();
                break;
            case 'ArrowRight':
                calendar.next();
                e.preventDefault();
                break;
            case 'Enter':
            case ' ':
                if (e.target.classList.contains('fc-daygrid-day')) {
                    handleDayClick(e.target);
                    e.preventDefault();
                }
                break;
        }
    }
});
```

---

## Troubleshooting Guide

### Common TailwindCSS Issues

**Issue: Styles not applying**
```bash
# Solution: Ensure content paths are correct in tailwind.config.js
# Check that files are included in the content array
# Verify the input.css file contains Tailwind directives
```

**Issue: Custom colors not working**
```javascript
// Solution: Extend theme properly in tailwind.config.js
theme: {
  extend: {
    colors: {
      primary: '#1a365d',  // Custom colors must be in extend
    },
  },
}
```

### Bootstrap Component Conflicts
```css
/* Solution: Use CSS specificity to override conflicts */
.tailwind-override {
    @apply !important; /* Use Tailwind's important modifier */
}

/* Or use CSS custom properties for dynamic values */
:root {
    --primary-color: #1a365d;
}

.btn-primary {
    background-color: var(--primary-color);
}
```

### FullCalendar Integration Issues
```javascript
// Issue: Events not displaying
// Solution: Ensure proper data format from ColdFusion
function transformCFData(cfData) {
    return cfData.map(event => ({
        id: event.ID,
        title: event.TITLE,
        start: event.START_TIME,
        end: event.END_TIME,
        // ColdFusion returns uppercase column names
    }));
}
```

### AJAX Communication Problems
```javascript
// Issue: ColdFusion CFC not responding
// Solution: Verify CFC method accessibility and return format
$.ajax({
    url: 'assets/cfc/booking.cfc',
    type: 'POST',
    data: {
        method: 'getBookings',
        returnFormat: 'json',  // Required for JSON response
        queryFormat: 'column'  // Recommended for arrays
    },
    // ...
});
```

---

## Best Practices

### Code Organization
```
Frontend Structure:
├── assets/
│   ├── css/
│   │   ├── styles.css        # Compiled TailwindCSS
│   │   └── custom/           # Component-specific styles
│   ├── js/
│   │   ├── main.js          # Global utilities
│   │   ├── components/      # Component-specific JS
│   │   └── config/          # Configuration files
│   └── images/
├── components/              # Reusable HTML components
├── pages/                  # Page-specific templates
└── src/
    └── input.css           # TailwindCSS source
```

### Component Development
```javascript
// Create reusable component classes
class BookingForm {
    constructor(container, options = {}) {
        this.container = container;
        this.options = {
            apiEndpoint: 'assets/cfc/booking.cfc',
            validateOnSubmit: true,
            ...options
        };
        this.init();
    }
    
    init() {
        this.bindEvents();
        this.setupValidation();
    }
    
    bindEvents() {
        $(this.container).on('submit', 'form', (e) => {
            e.preventDefault();
            this.handleSubmit(e.target);
        });
    }
    
    async handleSubmit(form) {
        const formData = new FormData(form);
        const isValid = this.validate(formData);
        
        if (isValid) {
            await this.submitBooking(formData);
        }
    }
}

// Usage
const bookingForm = new BookingForm('#booking-container', {
    onSuccess: (response) => {
        calendar.refetchEvents();
        showSuccessMessage(response.message);
    }
});
```

### Error Handling Strategy
```javascript
// Centralized error handling
class ErrorHandler {
    static handle(error, context = '') {
        console.error(`Error in ${context}:`, error);
        
        // Log to backend for monitoring
        this.logError(error, context);
        
        // Show user-friendly message
        this.showUserMessage(error);
    }
    
    static logError(error, context) {
        $.post('assets/cfc/system-logger.cfc', {
            method: 'logError',
            error: error.message,
            context: context,
            url: window.location.href,
            userAgent: navigator.userAgent
        });
    }
    
    static showUserMessage(error) {
        const message = this.getUserFriendlyMessage(error);
        Swal.fire({
            title: 'Oops!',
            text: message,
            icon: 'error',
            confirmButtonClass: 'btn btn-primary'
        });
    }
}
```

---

## Integration Testing

### Component Testing
```javascript
// Test calendar integration
function testCalendarIntegration() {
    const testEvents = [
        {
            id: 'test-1',
            title: 'Test Meeting',
            start: '2024-01-15T10:00:00',
            end: '2024-01-15T11:00:00'
        }
    ];
    
    calendar.addEventSource(testEvents);
    
    // Verify events are displayed
    const renderedEvents = calendar.getEvents();
    console.assert(renderedEvents.length === 1, 'Calendar should display test event');
}

// Test form validation
function testFormValidation() {
    const testData = new FormData();
    testData.append('roomId', '');
    testData.append('startTime', '2024-01-15T10:00');
    
    const rules = {
        roomId: { required: true },
        startTime: { required: true }
    };
    
    const result = validateForm(testData, rules);
    console.assert(!result.isValid, 'Form validation should fail for empty roomId');
}
```

---

## Conclusion

This Frontend Integration Specialist agent provides comprehensive support for the DoCM Room Reservation System's frontend architecture. It combines the power of Bootstrap 5's component library with TailwindCSS's utility-first approach, creating a maintainable and scalable frontend solution.

The agent excels at:
- Creating responsive, accessible interfaces
- Integrating complex calendar functionality
- Implementing real-time features
- Optimizing performance across devices
- Maintaining code quality and standards

Use this agent when working on any frontend aspects of the room reservation system, from simple form enhancements to complex calendar integrations and admin dashboard development.