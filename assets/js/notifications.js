/**
 * Notification Management JavaScript
 * Handles admin notification management functionality
 */

// Global variables
let notificationsTable;
let currentPage = 1;
const pageSize = 25;

// Initialize when document is ready
$(document).ready(function() {
    initializeNotificationManagement();
});

/**
 * Initialize notification management components
 */
function initializeNotificationManagement() {
    // Initialize DataTable
    initializeDataTable();
    
    // Load initial data
    loadNotificationStats();
    loadNotifications();
    loadUsersForBulkNotification();
    
    // Bind event handlers
    bindEventHandlers();
    
    // Initialize AOS animations
    AOS.init();
}

/**
 * Initialize DataTables
 */
function initializeDataTable() {
    notificationsTable = $('#notificationsTable').DataTable({
        "pageLength": pageSize,
        "order": [[5, "desc"]], // Sort by created date desc
        "columnDefs": [
            {
                "targets": [3], // Content column
                "render": function(data, type, row) {
                    if (type === 'display' && data.length > 100) {
                        return data.substr(0, 100) + '...';
                    }
                    return data;
                }
            },
            {
                "targets": [6], // Actions column
                "orderable": false,
                "searchable": false
            }
        ],
        "responsive": true,
        "language": {
            "emptyTable": "No notifications found"
        }
    });
}

/**
 * Bind event handlers
 */
function bindEventHandlers() {
    // Select all users checkbox
    $('#selectAllUsers').change(function() {
        const userSelect = $('#userSelection');
        if (this.checked) {
            userSelect.find('option').prop('selected', true);
        } else {
            userSelect.find('option').prop('selected', false);
        }
    });

    // Filter changes
    $('#filterType, #filterStatus').change(function() {
        loadNotifications();
    });
}

/**
 * Load notification statistics
 */
function loadNotificationStats() {
    $.ajax({
        url: 'assets/cfc/notifications.cfc?method=getNotificationStats',
        type: 'GET',
        dataType: 'json',
        success: function(response) {
            updateStatsDisplay(response);
        },
        error: function(xhr, status, error) {
            console.error('Error loading notification stats:', error);
            showToast('Error loading statistics', 'error');
        }
    });
}

/**
 * Update statistics display
 */
function updateStatsDisplay(stats) {
    $('#totalNotifications').text(stats.total || 0);
    $('#unreadNotifications').text(stats.unread || 0);
    $('#recentNotifications').text(stats.recent || 0);
    
    // Display most common notification type
    if (stats.byType && stats.byType.length > 0) {
        $('#commonType').text(stats.byType[0].type);
    } else {
        $('#commonType').text('None');
    }
}

/**
 * Load notifications with current filters
 */
function loadNotifications() {
    const filterType = $('#filterType').val();
    const filterStatus = $('#filterStatus').val();
    
    const params = {
        method: 'getAllNotifications',
        page_size: pageSize,
        page_number: currentPage
    };
    
    if (filterType) params.filter_type = filterType;
    if (filterStatus) params.filter_status = filterStatus;
    
    $.ajax({
        url: 'assets/cfc/notifications.cfc',
        type: 'GET',
        data: params,
        dataType: 'json',
        success: function(response) {
            populateNotificationsTable(response.DATA || response);
        },
        error: function(xhr, status, error) {
            console.error('Error loading notifications:', error);
            showToast('Error loading notifications', 'error');
        }
    });
}

/**
 * Populate notifications table
 */
function populateNotificationsTable(notifications) {
    // Clear existing data
    notificationsTable.clear();
    
    // Add new data
    if (Array.isArray(notifications)) {
        notifications.forEach(function(notification) {
            const row = [
                notification.NOTIFICATION_ID,
                `${notification.FIRST_NAME || ''} ${notification.LAST_NAME || ''}`.trim() || 'Unknown User',
                notification.TYPE || 'N/A',
                notification.CONTENT || '',
                getStatusBadge(notification.STATUS),
                formatDate(notification.CREATED_AT),
                getActionButtons(notification.NOTIFICATION_ID, notification.STATUS)
            ];
            notificationsTable.row.add(row);
        });
    }
    
    // Redraw table
    notificationsTable.draw();
}

/**
 * Get status badge HTML
 */
function getStatusBadge(status) {
    const statusUpper = (status || '').toUpperCase();
    switch (statusUpper) {
        case 'UNREAD':
            return '<span class="badge bg-warning">Unread</span>';
        case 'READ':
            return '<span class="badge bg-success">Read</span>';
        default:
            return '<span class="badge bg-secondary">Unknown</span>';
    }
}

/**
 * Get action buttons HTML
 */
function getActionButtons(notificationId, status) {
    const statusUpper = (status || '').toUpperCase();
    let buttons = '';
    
    // Mark as read/unread button
    if (statusUpper === 'UNREAD') {
        buttons += `<button class="btn btn-sm btn-outline-primary me-1" onclick="updateNotificationStatus(${notificationId}, 'READ')" title="Mark as Read">
                        <i class="fas fa-check"></i>
                    </button>`;
    } else {
        buttons += `<button class="btn btn-sm btn-outline-warning me-1" onclick="updateNotificationStatus(${notificationId}, 'UNREAD')" title="Mark as Unread">
                        <i class="fas fa-undo"></i>
                    </button>`;
    }
    
    // Delete button
    buttons += `<button class="btn btn-sm btn-outline-danger" onclick="deleteNotification(${notificationId})" title="Delete">
                    <i class="fas fa-trash"></i>
                </button>`;
    
    return buttons;
}

/**
 * Format date for display
 */
function formatDate(dateString) {
    if (!dateString) return 'N/A';
    
    try {
        const date = new Date(dateString);
        return date.toLocaleDateString() + ' ' + date.toLocaleTimeString();
    } catch (e) {
        return dateString;
    }
}

/**
 * Load users for bulk notification
 */
function loadUsersForBulkNotification() {
    $.ajax({
        url: 'assets/cfc/notifications.cfc?method=getUsersForNotification',
        type: 'GET',
        dataType: 'json',
        success: function(response) {
            populateUserSelection(response.DATA || response);
        },
        error: function(xhr, status, error) {
            console.error('Error loading users:', error);
            showToast('Error loading users', 'error');
        }
    });
}

/**
 * Populate user selection dropdown
 */
function populateUserSelection(users) {
    const userSelect = $('#userSelection');
    userSelect.empty();
    
    if (Array.isArray(users)) {
        users.forEach(function(user) {
            const optionText = `${user.FIRST_NAME} ${user.LAST_NAME} (${user.EMAIL}) - ${user.ROLE}`;
            userSelect.append(`<option value="${user.USER_ID}">${optionText}</option>`);
        });
    }
}

/**
 * Send bulk notification
 */
function sendBulkNotification() {
    const form = $('#bulkNotificationForm')[0];
    if (!form.checkValidity()) {
        form.reportValidity();
        return;
    }
    
    const selectedUsers = $('#userSelection').val();
    if (!selectedUsers || selectedUsers.length === 0) {
        showToast('Please select at least one user', 'warning');
        return;
    }
    
    const notificationType = $('#notificationType').val();
    const notificationMessage = $('#notificationMessage').val();
    
    // Confirm before sending
    Swal.fire({
        title: 'Send Bulk Notification?',
        text: `This will send the notification to ${selectedUsers.length} selected user(s).`,
        icon: 'question',
        showCancelButton: true,
        confirmButtonText: 'Yes, Send',
        cancelButtonText: 'Cancel'
    }).then((result) => {
        if (result.isConfirmed) {
            performBulkNotificationSend(selectedUsers.join(','), notificationType, notificationMessage);
        }
    });
}

/**
 * Perform bulk notification send
 */
function performBulkNotificationSend(userIds, type, message) {
    $.ajax({
        url: 'assets/cfc/notifications.cfc?method=createBulkNotification',
        type: 'POST',
        data: {
            user_ids: userIds,
            notification_type: type,
            notification_message: message
        },
        dataType: 'json',
        success: function(response) {
            if (response.success) {
                showToast(response.message, 'success');
                $('#bulkNotificationModal').modal('hide');
                $('#bulkNotificationForm')[0].reset();
                
                // Reload data
                loadNotificationStats();
                loadNotifications();
            } else {
                showToast(response.message || 'Error sending notifications', 'error');
            }
        },
        error: function(xhr, status, error) {
            console.error('Error sending bulk notification:', error);
            showToast('Error sending notifications', 'error');
        }
    });
}

/**
 * Update notification status
 */
function updateNotificationStatus(notificationId, newStatus) {
    $.ajax({
        url: 'assets/cfc/notifications.cfc?method=updateNotificationStatus',
        type: 'POST',
        data: {
            notification_id: notificationId,
            new_status: newStatus
        },
        dataType: 'json',
        success: function(response) {
            if (response.success) {
                showToast('Notification status updated', 'success');
                loadNotificationStats();
                loadNotifications();
            } else {
                showToast(response.message || 'Error updating notification', 'error');
            }
        },
        error: function(xhr, status, error) {
            console.error('Error updating notification status:', error);
            showToast('Error updating notification status', 'error');
        }
    });
}

/**
 * Delete notification
 */
function deleteNotification(notificationId) {
    Swal.fire({
        title: 'Delete Notification?',
        text: 'This action cannot be undone.',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonText: 'Yes, Delete',
        cancelButtonText: 'Cancel',
        confirmButtonColor: '#dc3545'
    }).then((result) => {
        if (result.isConfirmed) {
            performNotificationDelete(notificationId);
        }
    });
}

/**
 * Perform notification deletion
 */
function performNotificationDelete(notificationId) {
    $.ajax({
        url: 'assets/cfc/notifications.cfc?method=deleteNotificationAdmin',
        type: 'POST',
        data: {
            notification_id: notificationId
        },
        dataType: 'json',
        success: function(response) {
            if (response.success) {
                showToast('Notification deleted', 'success');
                loadNotificationStats();
                loadNotifications();
            } else {
                showToast(response.message || 'Error deleting notification', 'error');
            }
        },
        error: function(xhr, status, error) {
            console.error('Error deleting notification:', error);
            showToast('Error deleting notification', 'error');
        }
    });
}

/**
 * Clear filters
 */
function clearFilters() {
    $('#filterType').val('');
    $('#filterStatus').val('');
    loadNotifications();
}

/**
 * Show toast notification
 */
function showToast(message, type = 'info') {
    const Toast = Swal.mixin({
        toast: true,
        position: 'top-end',
        showConfirmButton: false,
        timer: 3000,
        timerProgressBar: true
    });

    Toast.fire({
        icon: type,
        title: message
    });
}

/**
 * Refresh all data
 */
function refreshData() {
    loadNotificationStats();
    loadNotifications();
    showToast('Data refreshed', 'success');
}