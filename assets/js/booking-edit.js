/**
 * Booking Edit Functionality
 * Handles editing existing room reservations
 */

// Global variable to store current booking data
let currentBookingData = null;

/**
 * Initialize edit booking modal for a specific booking
 * @param {number} bookingId - The ID of the booking to edit
 */
function initEditBooking(bookingId) {
    const userId = sessionStorage.getItem('USER_ID');

    if (!userId) {
        showToast('Please log in to edit bookings', 'error');
        return;
    }

    // Show loading state
    Swal.fire({
        title: 'Loading booking details...',
        html: '<div class="spinner-border text-primary" role="status"><span class="visually-hidden">Loading...</span></div>',
        showConfirmButton: false,
        allowOutsideClick: false
    });

    // Fetch booking details
    $.ajax({
        url: 'api/bookings/get-booking-for-edit.cfm',
        type: 'GET',
        data: {
            bookingId: bookingId,
            userId: userId
        },
        dataType: 'json',
        success: function(response) {
            Swal.close();

            if (response.success) {
                if (response.canEdit) {
                    currentBookingData = response;
                    openBookingModalForEdit(response);
                } else {
                    Swal.fire({
                        title: 'Cannot Edit Booking',
                        text: response.editBlockReason || 'This booking cannot be edited',
                        icon: 'warning',
                        confirmButtonText: 'OK'
                    });
                }
            } else {
                Swal.fire({
                    title: 'Error',
                    text: response.message || 'Failed to load booking details',
                    icon: 'error'
                });
            }
        },
        error: function(xhr, status, error) {
            Swal.close();
            console.error('Error loading booking:', error);
            Swal.fire({
                title: 'Error',
                text: 'Failed to load booking details. Please try again.',
                icon: 'error'
            });
        }
    });
}

/**
 * Open the main booking modal for editing an existing booking
 * @param {object} data - Booking data from server
 */
function openBookingModalForEdit(data) {
    const booking = data.booking;
    const availableRooms = data.availableRooms;

    // Mark modal as in edit mode
    $('#bookingModal').attr('data-edit-mode', 'true');
    $('#bookingModal').attr('data-booking-id', booking.bookingId);

    // Update modal title
    $('#bookingModal .modal-title').html('<i class="fas fa-edit me-2"></i>Edit Booking #' + booking.bookingId);

    // Update save button text
    $('#saveBooking').html('<i class="fas fa-save me-1"></i>Update Booking');

    // Populate room dropdown (this should already be loaded)
    $('#roomSelect').val(booking.roomId).trigger('change');

    // Parse start and end times (format: "YYYY-MM-DD HH:mm")
    const startParts = booking.startTime.split(' ');
    const endParts = booking.endTime.split(' ');

    const startDate = startParts[0];
    const startTime = startParts[1];
    const endDate = endParts[0];
    const endTime = endParts[1];

    // Initialize datetime pickers with booking data
    if (window.startPicker) {
        const startDateTime = new Date(booking.startTime.replace(' ', 'T'));
        window.startPicker.setDate(startDateTime);
    }

    if (window.endPicker) {
        const endDateTime = new Date(booking.endTime.replace(' ', 'T'));
        window.endPicker.setDate(endDateTime);
    }

    // Show title field if it's not a focus room and populate it
    if (booking.comments && booking.comments.trim() !== '') {
        $('#titleContainer').removeClass('d-none');
        $('#bookingTitle').val(booking.comments);
        $('#bookingTitle').prop('required', true);
    }

    // Open the modal
    const bookingModal = new bootstrap.Modal(document.getElementById('bookingModal'));
    bookingModal.show();
}

/**
 * Display the edit booking modal with pre-filled data (LEGACY - DEPRECATED)
 * @param {object} data - Booking data from server
 * @deprecated Use openBookingModalForEdit instead
 */
function showEditBookingModal(data) {
    const booking = data.booking;
    const availableRooms = data.availableRooms;

    // Build room options dropdown
    let roomOptions = '';
    availableRooms.forEach(room => {
        const selected = room.roomId === booking.roomId ? 'selected' : '';
        roomOptions += `<option value="${room.roomId}" ${selected}>${room.roomName} (${room.location}) - Capacity: ${room.capacity}</option>`;
    });

    // Format dates for datetime-local inputs
    const startDateTime = booking.startTime.replace(' ', 'T').substring(0, 16);
    const endDateTime = booking.endTime.replace(' ', 'T').substring(0, 16);

    // Build modal HTML
    const modalHtml = `
        <div class="edit-booking-form text-start">
            <div class="mb-3">
                <label class="form-label fw-semibold"><i class="fas fa-user me-2 text-primary"></i>Requested By</label>
                <p class="form-control-plaintext">${booking.requesterName}</p>
            </div>

            ${booking.isModified === 'Y' ? `
            <div class="alert alert-info">
                <i class="fas fa-info-circle me-2"></i>
                This booking has been modified ${booking.revisionNumber} time(s).
                Last modified: ${booking.revisionDate || 'N/A'}
            </div>
            ` : ''}

            <div class="mb-3">
                <label for="editRoomSelect" class="form-label fw-semibold">
                    <i class="fas fa-door-open me-2 text-primary"></i>Room
                </label>
                <select id="editRoomSelect" class="form-select">
                    ${roomOptions}
                </select>
            </div>

            <div class="mb-3">
                <label for="editStartTime" class="form-label fw-semibold">
                    <i class="fas fa-clock me-2 text-primary"></i>Start Time
                </label>
                <input type="datetime-local" id="editStartTime" class="form-control" value="${startDateTime}">
            </div>

            <div class="mb-3">
                <label for="editEndTime" class="form-label fw-semibold">
                    <i class="fas fa-clock me-2 text-success"></i>End Time
                </label>
                <input type="datetime-local" id="editEndTime" class="form-control" value="${endDateTime}">
            </div>

            <div class="mb-3">
                <label for="editComments" class="form-label fw-semibold">
                    <i class="fas fa-calendar-alt me-2 text-primary"></i>Meeting Title
                </label>
                <input type="text" id="editComments" class="form-control" value="${booking.comments || ''}" placeholder="Enter meeting title (optional)">
            </div>

            <div class="alert alert-warning">
                <i class="fas fa-exclamation-triangle me-2"></i>
                <strong>Note:</strong> Editing this booking will increment the revision number and send notifications to relevant parties.
            </div>
        </div>
    `;

    Swal.fire({
        title: 'Edit Booking #' + booking.bookingId,
        html: modalHtml,
        width: '600px',
        showCancelButton: true,
        confirmButtonText: '<i class="fas fa-save me-2"></i>Save Changes',
        cancelButtonText: 'Cancel',
        customClass: {
            confirmButton: 'btn btn-primary',
            cancelButton: 'btn btn-secondary'
        },
        buttonsStyling: false,
        didOpen: () => {
            // Add event listeners for datetime inputs to show live updates
            const startInput = document.getElementById('editStartTime');
            const endInput = document.getElementById('editEndTime');

            if (startInput) {
                startInput.addEventListener('change', function() {
                    console.log('Start time changed to:', this.value);
                });
            }

            if (endInput) {
                endInput.addEventListener('change', function() {
                    console.log('End time changed to:', this.value);
                });
            }
        },
        preConfirm: () => {
            return validateAndSaveBookingEdit();
        }
    });
}

/**
 * Validate and save the edited booking
 * @returns {Promise} Resolves if save is successful
 */
function validateAndSaveBookingEdit() {
    const roomId = $('#editRoomSelect').val();
    const startTime = $('#editStartTime').val();
    const endTime = $('#editEndTime').val();
    const comments = $('#editComments').val();

    // Validation
    if (!startTime || !endTime) {
        Swal.showValidationMessage('Please select both start and end times');
        return false;
    }

    const start = new Date(startTime);
    const end = new Date(endTime);

    if (start >= end) {
        Swal.showValidationMessage('End time must be after start time');
        return false;
    }

    if (start < new Date()) {
        Swal.showValidationMessage('Cannot schedule bookings in the past');
        return false;
    }

    // Calculate duration in hours
    const durationHours = (end - start) / (1000 * 60 * 60);
    if (durationHours > 8) {
        Swal.showValidationMessage('Booking duration cannot exceed 8 hours');
        return false;
    }

    // Save the booking
    return saveBookingEdit(roomId, startTime, endTime, comments);
}

/**
 * Save the edited booking to the server
 * @param {number} roomId - Selected room ID
 * @param {string} startTime - Start time in datetime-local format (YYYY-MM-DDTHH:mm)
 * @param {string} endTime - End time in datetime-local format (YYYY-MM-DDTHH:mm)
 * @param {string} comments - Meeting title/comments
 * @returns {Promise}
 */
function saveBookingEdit(roomId, startTime, endTime, comments) {
    const userId = sessionStorage.getItem('USER_ID');
    const bookingId = currentBookingData.booking.bookingId;

    // Convert datetime-local format (YYYY-MM-DDTHH:mm) to ColdFusion-friendly format (YYYY-MM-DD HH:mm:ss)
    const formatForColdFusion = (datetimeLocal) => {
        if (!datetimeLocal) return '';
        // Replace 'T' with space and add seconds if not present
        const formatted = datetimeLocal.replace('T', ' ');
        return formatted.length === 16 ? formatted + ':00' : formatted;
    };

    const formattedStartTime = formatForColdFusion(startTime);
    const formattedEndTime = formatForColdFusion(endTime);

    return new Promise((resolve, reject) => {
        $.ajax({
            url: 'api/bookings/edit-booking.cfm',
            type: 'POST',
            data: {
                bookingId: bookingId,
                userId: userId,
                roomId: roomId,
                startTime: formattedStartTime,
                endTime: formattedEndTime,
                comments: comments
            },
            dataType: 'json',
            success: function(response) {
                if (response.success) {
                    showToast('Booking updated successfully!', 'success');

                    // Refresh calendar if it exists
                    if (typeof calendar !== 'undefined' && calendar) {
                        calendar.refetchEvents();
                    }

                    // Refresh global calendar if it exists
                    if (typeof globalCalendar !== 'undefined' && globalCalendar) {
                        globalCalendar.refetchEvents();
                    }

                    // Refresh bookings table if it exists
                    if (typeof refreshBookingsTable === 'function') {
                        refreshBookingsTable();
                    }

                    resolve(response);
                } else {
                    Swal.showValidationMessage(response.message || 'Failed to update booking');
                    reject(response);
                }
            },
            error: function(xhr, status, error) {
                console.error('Error updating booking:', error);
                console.error('XHR:', xhr.responseText);
                Swal.showValidationMessage('Failed to update booking. Please try again.');
                reject(error);
            }
        });
    });
}

/**
 * Get revision history for a booking
 * @param {number} bookingId - The booking ID
 */
function getBookingRevisionHistory(bookingId) {
    const userId = sessionStorage.getItem('USER_ID');

    // Show loading state
    Swal.fire({
        title: 'Loading revision history...',
        html: '<div class="spinner-border text-primary" role="status"><span class="visually-hidden">Loading...</span></div>',
        showConfirmButton: false,
        allowOutsideClick: false
    });

    $.ajax({
        url: 'api/bookings/get-revision-history.cfm',
        type: 'GET',
        data: {
            bookingId: bookingId,
            userId: userId
        },
        dataType: 'json',
        success: function(response) {
            if (response.success && response.revisions) {
                displayRevisionHistory(response.revisions);
            } else {
                Swal.fire({
                    title: 'No Revision History',
                    text: 'This booking has not been modified',
                    icon: 'info'
                });
            }
        },
        error: function() {
            Swal.close();
            showToast('Failed to load revision history', 'error');
        }
    });
}

/**
 * Display revision history in a modal
 * @param {array} revisions - Array of revision objects
 */
function displayRevisionHistory(revisions) {
    let historyHtml = '<div class="revision-history-list">';

    revisions.forEach((revision, index) => {
        historyHtml += `
            <div class="revision-item mb-3 p-3 border rounded">
                <div class="d-flex justify-content-between align-items-center mb-2">
                    <span class="badge bg-primary">Revision #${revision.revisionNumber}</span>
                    <span class="text-muted small">${revision.revisionDate}</span>
                </div>
                <div class="revision-details">
                    <p class="mb-1"><strong>Modified by:</strong> ${revision.modifiedBy}</p>
                    <p class="mb-1"><strong>Room:</strong> ${revision.roomName}</p>
                    <p class="mb-1"><strong>Time:</strong> ${revision.startTime} - ${revision.endTime}</p>
                    ${revision.comments ? `<p class="mb-0"><strong>Meeting Title:</strong> ${revision.comments}</p>` : ''}
                </div>
            </div>
        `;
    });

    historyHtml += '</div>';

    Swal.fire({
        title: 'Revision History',
        html: historyHtml,
        width: '700px',
        confirmButtonText: 'Close'
    });
}

// Helper function for toast notifications (if not already defined)
if (typeof showToast !== 'function') {
    function showToast(message, type = 'info') {
        const bgColor = type === 'success' ? 'bg-success' : type === 'error' ? 'bg-danger' : 'bg-info';
        const icon = type === 'success' ? 'fa-check-circle' : type === 'error' ? 'fa-exclamation-circle' : 'fa-info-circle';

        Swal.fire({
            toast: true,
            position: 'top-end',
            icon: type,
            title: message,
            showConfirmButton: false,
            timer: 3000,
            timerProgressBar: true
        });
    }
}
