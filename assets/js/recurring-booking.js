/**
 * Recurring Booking Functionality
 * Handles creation and management of recurring room reservations
 */

// Global state for recurring booking
let recurringEnabled = false;
let recurringPreviewDates = [];

/**
 * Initialize recurring booking functionality
 */
function initRecurringBooking() {
    // Handle recurring details dropdown change
    $('#recurringDetails').on('change', function() {
        const selectedValue = $(this).val();
        recurringEnabled = (selectedValue !== '');

        if (recurringEnabled) {
            // Show the recurring pattern container
            $('#recurringPatternContainer').removeClass('d-none').slideDown();

            // Update interval label based on frequency
            updateFrequencyOptions(selectedValue);

            // Set default end date to 3 months from now
            const defaultEndDate = new Date();
            defaultEndDate.setMonth(defaultEndDate.getMonth() + 3);
            $('#recurringEndDate').val(defaultEndDate.toISOString().split('T')[0]);
        } else {
            $('#recurringPatternContainer').slideUp(function() {
                $(this).addClass('d-none');
            });
            clearRecurringPreview();
        }
    });

    // Handle end type radio buttons
    $('input[name="endType"]').on('change', function() {
        const endType = $(this).val();
        if (endType === 'date') {
            $('#endDateContainer').removeClass('d-none');
            $('#occurrencesContainer').addClass('d-none');
        } else {
            $('#endDateContainer').addClass('d-none');
            $('#occurrencesContainer').removeClass('d-none');
        }
    });

    // Handle preview button
    $('#previewRecurringDates').on('click', function() {
        generateRecurringPreview();
    });

    // Handle interval changes to update label
    $('#recurringInterval').on('input', function() {
        const frequency = $('#recurringDetails').val();
        updateIntervalLabel(frequency, parseInt($(this).val()));
    });

    // Handle days of week checkboxes for auto-preview update
    $('input[id^="day_"]').on('change', function() {
        if ($('#recurringPreviewContainer').is(':visible')) {
            generateRecurringPreview();
        }
    });
}

/**
 * Update UI based on selected frequency
 */
function updateFrequencyOptions(frequency) {
    const $weeklyDaysContainer = $('#weeklyDaysContainer');

    // Update interval label
    updateIntervalLabel(frequency, parseInt($('#recurringInterval').val()) || 1);

    // Show/hide weekly days selection
    if (frequency === 'WEEKLY') {
        $weeklyDaysContainer.removeClass('d-none');
    } else {
        $weeklyDaysContainer.addClass('d-none');
    }
}

/**
 * Update interval label based on frequency and value
 */
function updateIntervalLabel(frequency, intervalValue) {
    let labelText = '';
    const plural = intervalValue > 1 ? 's' : '';

    switch (frequency) {
        case 'DAILY':
            labelText = `day${plural}`;
            break;
        case 'WEEKLY':
            labelText = `week${plural}`;
            break;
        case 'MONTHLY':
            labelText = `month${plural}`;
            break;
        default:
            labelText = 'interval(s)';
    }

    $('#intervalLabel').text(labelText);
}

/**
 * Update end type fields (date picker or occurrences)
 */
function updateEndTypeFields() {
    const endType = $('#recurringEndType').val();
    const $endDateContainer = $('#recurringEndDateContainer');
    const $endOccurrencesContainer = $('#recurringEndOccurrencesContainer');

    if (endType === 'date') {
        $endDateContainer.slideDown();
        $endOccurrencesContainer.slideUp();
    } else {
        $endDateContainer.slideUp();
        $endOccurrencesContainer.slideDown();
    }
}

/**
 * Generate and display recurring preview
 */
function generateRecurringPreview() {
    const frequency = $('#recurringDetails').val();
    const interval = parseInt($('#recurringInterval').val()) || 1;
    const endType = $('input[name="endType"]:checked').val();
    const startTime = $('#startTime').val();
    const endTime = $('#endTime').val();

    if (!frequency || !startTime || !endTime) {
        Swal.fire({
            icon: 'warning',
            title: 'Missing Information',
            text: 'Please select frequency and date/time before previewing',
            confirmButtonClass: 'btn btn-primary'
        });
        return;
    }

    const startDate = new Date(startTime);
    const endDate = new Date(endTime);
    const duration = endDate - startDate;

    // Get end condition
    let maxDates;
    let endByDate;

    if (endType === 'date') {
        const endDateValue = $('#recurringEndDate').val();
        if (!endDateValue) {
            Swal.fire({
                icon: 'warning',
                title: 'Missing End Date',
                text: 'Please select an end date for the recurring series',
                confirmButtonClass: 'btn btn-primary'
            });
            return;
        }
        endByDate = new Date(endDateValue);
        maxDates = 100; // Safety limit
    } else {
        maxDates = parseInt($('#recurringOccurrences').val()) || 10;
    }

    // Get days of week for weekly patterns
    let selectedDays = [];
    if (frequency === 'WEEKLY') {
        $('input[id^="day_"]:checked').each(function() {
            selectedDays.push(parseInt($(this).val()));
        });

        if (selectedDays.length === 0) {
            Swal.fire({
                icon: 'warning',
                title: 'Select Days',
                text: 'Please select at least one day of the week',
                confirmButtonClass: 'btn btn-primary'
            });
            return;
        }
    }

    // Generate dates
    recurringPreviewDates = generateDates(startDate, duration, frequency, interval, endType, endByDate, maxDates, selectedDays);

    // Display preview
    displayRecurringPreview(recurringPreviewDates);
}

/**
 * Generate recurring dates
 */
function generateDates(startDate, duration, frequency, interval, endType, endByDate, maxDates, selectedDays) {
    const dates = [];
    let currentDate = new Date(startDate);
    let count = 0;

    while (count < maxDates) {
        if (endType === 'date' && currentDate > endByDate) {
            break;
        }

        // For weekly patterns, check if current day matches selected days
        if (frequency === 'WEEKLY') {
            const dayOfWeek = currentDate.getDay(); // 0 = Sunday, 1 = Monday, etc.

            if (selectedDays.includes(dayOfWeek)) {
                const instanceEnd = new Date(currentDate.getTime() + duration);
                dates.push({
                    start: new Date(currentDate),
                    end: instanceEnd,
                    instanceNumber: count + 1
                });
                count++;
            }

            // Move to next day
            currentDate.setDate(currentDate.getDate() + 1);

            // If we've completed a week and haven't found all days, jump to next interval
            if (currentDate.getDay() === startDate.getDay()) {
                currentDate.setDate(currentDate.getDate() + (7 * (interval - 1)));
            }
        } else {
            // For daily and monthly patterns
            const instanceEnd = new Date(currentDate.getTime() + duration);
            dates.push({
                start: new Date(currentDate),
                end: instanceEnd,
                instanceNumber: count + 1
            });
            count++;

            // Calculate next occurrence
            if (frequency === 'DAILY') {
                currentDate.setDate(currentDate.getDate() + interval);
            } else if (frequency === 'MONTHLY') {
                currentDate.setMonth(currentDate.getMonth() + interval);
            }
        }
    }

    return dates;
}

/**
 * Display recurring preview
 */
function displayRecurringPreview(dates) {
    const $preview = $('#recurringPreviewContainer');
    const $list = $('#recurringPreviewList');

    $list.empty();

    if (dates.length === 0) {
        $list.html('<p class="text-muted mb-0">No dates generated</p>');
    } else {
        // Show first 10 dates
        const displayDates = dates.slice(0, 10);
        let html = '<ul class="list-group list-group-flush">';

        displayDates.forEach(function(date, index) {
            const startStr = formatDateTime(date.start);
            const endStr = formatDateTime(date.end);

            html += `
                <li class="list-group-item py-1 px-2">
                    <strong>#${date.instanceNumber}:</strong>
                    <small>${startStr} - ${endStr}</small>
                </li>
            `;
        });

        if (dates.length > 10) {
            html += `
                <li class="list-group-item text-center text-muted py-1 px-2">
                    ... and ${dates.length - 10} more occurrence(s)
                </li>
            `;
        }

        html += `
            <li class="list-group-item text-center bg-light py-1 px-2">
                <strong>Total Occurrences: ${dates.length}</strong>
            </li>
        `;
        html += '</ul>';

        $list.html(html);
    }

    $preview.removeClass('d-none').slideDown();
}

/**
 * Clear recurring preview
 */
function clearRecurringPreview() {
    $('#recurringPreviewContainer').slideUp(function() {
        $(this).addClass('d-none');
    });
    $('#recurringPreviewList').empty();
    recurringPreviewDates = [];
}

/**
 * Format date/time for display
 */
function formatDateTime(date) {
    return date.toLocaleString('en-US', {
        weekday: 'short',
        month: 'short',
        day: 'numeric',
        hour: 'numeric',
        minute: '2-digit'
    });
}

/**
 * Submit recurring booking
 */
function submitRecurringBooking() {
    const userId = sessionStorage.getItem('USER_ID');
    const roomId = $('#roomSelect').val();
    const startTime = $('#startTime').val();
    const endTime = $('#endTime').val();
    const comments = $('#comments').val();
    const frequency = $('#recurringDetails').val();
    const intervalCount = $('#recurringInterval').val();
    const endType = $('#recurringEndType').val();

    let endDate = '';
    let maxOccurrences = 0;
    let daysOfWeek = '';

    if (endType === 'date') {
        endDate = $('#recurringEndDate').val();
    } else {
        maxOccurrences = $('#recurringEndValue').val();
    }

    if (frequency === 'weekly') {
        const selectedDays = [];
        $('.recurring-day-checkbox:checked').each(function() {
            selectedDays.push($(this).val());
        });
        daysOfWeek = selectedDays.join(',');

        if (selectedDays.length === 0) {
            Swal.showValidationMessage('Please select at least one day of the week for weekly recurring bookings');
            return false;
        }
    }

    return $.ajax({
        url: 'api/recurring/create-series.cfm',
        type: 'POST',
        data: {
            userId: userId,
            roomId: roomId,
            startTime: startTime,
            endTime: endTime,
            comments: comments,
            frequency: frequency,
            intervalCount: intervalCount,
            endType: endType,
            endDate: endDate,
            maxOccurrences: maxOccurrences,
            daysOfWeek: daysOfWeek
        },
        dataType: 'json'
    });
}

/**
 * Helper function to get day abbreviation
 */
function getDayAbbreviation(dayIndex) {
    const days = ['SUN', 'MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT'];
    return days[dayIndex];
}

/**
 * Format date/time for display
 */
function formatDateTime(date) {
    return date.toLocaleString('en-US', {
        month: 'short',
        day: 'numeric',
        year: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
        hour12: true
    });
}

/**
 * Get formatted duration
 */
function getFormattedDuration(start, end) {
    const duration = (end - start) / (1000 * 60); // Duration in minutes
    const hours = Math.floor(duration / 60);
    const minutes = duration % 60;

    if (hours > 0 && minutes > 0) {
        return `${hours}h ${minutes}m`;
    } else if (hours > 0) {
        return `${hours}h`;
    } else {
        return `${minutes}m`;
    }
}

/**
 * View recurring series details
 */
function viewRecurringSeries(parentBookingId) {
    const userId = sessionStorage.getItem('USER_ID');

    Swal.fire({
        title: 'Loading series details...',
        html: '<div class="spinner-border text-primary" role="status"></div>',
        showConfirmButton: false,
        allowOutsideClick: false
    });

    $.ajax({
        url: 'api/recurring/get-series.cfm',
        type: 'GET',
        data: {
            parentBookingId: parentBookingId,
            userId: userId
        },
        dataType: 'json',
        success: function(response) {
            if (response.success) {
                displaySeriesModal(response);
            } else {
                Swal.fire({
                    title: 'Error',
                    text: response.message || 'Failed to load series details',
                    icon: 'error'
                });
            }
        },
        error: function() {
            Swal.fire({
                title: 'Error',
                text: 'Failed to load series details',
                icon: 'error'
            });
        }
    });
}

/**
 * Display recurring series modal
 */
function displaySeriesModal(data) {
    const pattern = data.pattern;
    const instances = data.instances;

    let patternDescription = `${pattern.frequency} `;
    if (pattern.intervalCount > 1) {
        patternDescription += `(every ${pattern.intervalCount} ${pattern.frequency.toLowerCase()})`;
    }

    if (pattern.frequency === 'WEEKLY' && pattern.daysOfWeek) {
        patternDescription += ` on ${pattern.daysOfWeek}`;
    }

    const modalHtml = `
        <div class="recurring-series-details text-start">
            <div class="alert alert-info">
                <h5><i class="fas fa-repeat me-2"></i>Recurring Pattern</h5>
                <p class="mb-1"><strong>Frequency:</strong> ${patternDescription}</p>
                <p class="mb-1"><strong>End Type:</strong> ${pattern.endType === 'DATE' ? 'End Date: ' + pattern.endDate : 'Max Occurrences: ' + pattern.maxOccurrences}</p>
                <p class="mb-0"><strong>Total Instances:</strong> ${data.totalInstances}</p>
            </div>

            <h6>Booking Instances:</h6>
            <div class="list-group" style="max-height: 400px; overflow-y: auto;">
                ${instances.map(instance => `
                    <div class="list-group-item">
                        <div class="d-flex justify-content-between align-items-center">
                            <div>
                                <strong>Instance #${instance.instanceNumber}</strong>
                                <span class="badge bg-${getStatusBadgeColor(instance.status)} ms-2">${instance.status}</span>
                                <br>
                                <small>${instance.startTime} - ${instance.endTime}</small>
                                <br>
                                <small class="text-muted">${instance.roomName}</small>
                            </div>
                        </div>
                    </div>
                `).join('')}
            </div>
        </div>
    `;

    Swal.fire({
        title: 'Recurring Series Details',
        html: modalHtml,
        width: '700px',
        confirmButtonText: 'Close'
    });
}

/**
 * Get status badge color
 */
function getStatusBadgeColor(status) {
    const colors = {
        'Pending': 'warning',
        'Approved': 'success',
        'Confirmed': 'primary',
        'Rejected': 'danger',
        'Cancelled': 'secondary'
    };
    return colors[status] || 'secondary';
}

// Initialize when document is ready
$(document).ready(function() {
    initRecurringBooking();
});
