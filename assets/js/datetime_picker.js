/**
 * DateTimePicker - jQuery Plugin
 * A flexible jQuery/Bootstrap based date and time picker for single date selection
 */
(function ($) {
    'use strict';

    // Plugin definition
    $.fn.dateTimePicker = function (options) { // Default settings
        const defaults = {
            label: 'Select Date and Time',
            dateFormat: 'MM/DD/YYYY, h:mm A',
            defaultDate: new Date(),
            minuteInterval: 5,
            onChange: null
        };

        // Merge user options with defaults
        const settings = $.extend({}, defaults, options);

        // Plugin functionality
        return this.each(function () {
            const $container = $(this);
            let pickerHtml = '';
            let selectedDate = new Date(settings.defaultDate);
            let currentDate = new Date(settings.defaultDate);
            let activeTab = 'date';
            let pickerId = 'datetime-picker-' + Math.floor(Math.random() * 1000000);

            // Generate picker HTML
            function createPickerHtml() {
                pickerHtml = `
          <div class="form-floating position-relative mb-3">
            <input type="text" class="form-control datetime-input" id="datetime-${pickerId}" placeholder=" " readonly>
            <label for="datetime-${pickerId}">${
                    settings.label
                }</label>
            <button type="button" class="btn position-absolute top-50 end-0 translate-middle-y me-2 datetime-toggle">
              <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-calendar" viewBox="0 0 16 16">
                <path d="M3.5 0a.5.5 0 0 1 .5.5V1h8V.5a.5.5 0 0 1 1 0V1h1a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V3a2 2 0 0 1 2-2h1V.5a.5.5 0 0 1 .5-.5zM1 4v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V4H1z"/>
              </svg>
            </button>
          </div>
            
          <!-- DateTimePicker Dropdown -->
          <div class="datetime-picker-dropdown" id="${pickerId}">
            <!-- Header -->
            <div class="datetime-picker-header">
              <button type="button" class="btn datetime-picker-date-btn">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-calendar-date" viewBox="0 0 16 16">
                  <path d="M6.445 11.688V6.354h-.633A12.6 12.6 0 0 0 4.5 7.16v.695c.375-.257.969-.62 1.258-.777h.012v4.61h.675zm1.188-1.305c.047.64.594 1.406 1.703 1.406 1.258 0 2-1.066 2-2.871 0-1.934-.781-2.668-1.953-2.668-.926 0-1.797.672-1.797 1.809 0 1.16.824 1.77 1.676 1.77.746 0 1.23-.376 1.383-.79h.027c-.004 1.316-.461 2.164-1.305 2.164-.664 0-1.008-.45-1.05-.82h-.684zm2.953-2.317c0 .696-.559 1.18-1.184 1.18-.601 0-1.144-.383-1.144-1.2 0-.823.582-1.21 1.168-1.21.633 0 1.16.398 1.16 1.23z"/>
                  <path d="M3.5 0a.5.5 0 0 1 .5.5V1h8V.5a.5.5 0 0 1 1 0V1h1a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V3a2 2 0 0 1 2-2h1V.5a.5.5 0 0 1 .5-.5zM1 4v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V4H1z"/>
                </svg>
              </button>
              <div class="header-title datetime-picker-header-title">Select Date</div>
              <button type="button" class="btn datetime-picker-time-btn">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-clock" viewBox="0 0 16 16">
                  <path d="M8 3.5a.5.5 0 0 0-1 0V9a.5.5 0 0 0 .252.434l3.5 2a.5.5 0 0 0 .496-.868L8 8.71V3.5z"/>
                  <path d="M8 16A8 8 0 1 0 8 0a8 8 0 0 0 0 16zm7-8A7 7 0 1 1 1 8a7 7 0 0 1 14 0z"/>
                </svg>
              </button>
            </div>
            
            <!-- Body -->
            <div class="datetime-picker-body">
              <!-- Date Tab Content -->
              <div class="date-tab tab-content">
                <div class="month-nav">
                  <button type="button" class="btn btn-sm btn-outline-secondary prev-month">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-chevron-left" viewBox="0 0 16 16">
                      <path fill-rule="evenodd" d="M11.354 1.646a.5.5 0 0 1 0 .708L5.707 8l5.647 5.646a.5.5 0 0 1-.708.708l-6-6a.5.5 0 0 1 0-.708l6-6a.5.5 0 0 1 .708 0z"/>
                    </svg>
                  </button>
                  <span class="current-month-year">May 2025</span>
                  <button type="button" class="btn btn-sm btn-outline-secondary next-month">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-chevron-right" viewBox="0 0 16 16">
                      <path fill-rule="evenodd" d="M4.646 1.646a.5.5 0 0 1 .708 0l6 6a.5.5 0 0 1 0 .708l-6 6a.5.5 0 0 1-.708-.708L10.293 8 4.646 2.354a.5.5 0 0 1 0-.708z"/>
                    </svg>
                  </button>
                </div>
                <div class="weekday-header calendar-grid">
                  <div>Su</div>
                  <div>Mo</div>
                  <div>Tu</div>
                  <div>We</div>
                  <div>Th</div>
                  <div>Fr</div>
                  <div>Sa</div>
                </div>
                <div class="calendar-grid calendar-days">
                  <!-- Days will be populated with JavaScript -->
                </div>
              </div>
              
              <!-- Time Tab Content -->
              <div class="time-tab tab-content" style="display: none;">
                <div class="time-container">
                  <div class="time-column">
                    <div class="time-header">Hour</div>
                    <div class="time-grid hour-grid">
                      <!-- Hours will be populated with JavaScript -->
                    </div>
                  </div>
                  <div class="time-column">
                    <div class="time-header">Minute</div>
                    <div class="time-grid minute-grid">
                      <!-- Minutes will be populated with JavaScript -->
                    </div>
                  </div>
                  <div class="time-column">
                    <div class="time-header">AM/PM</div>
                    <div class="ampm-buttons">
                      <div class="ampm-btn am-btn">AM</div>
                      <div class="ampm-btn pm-btn">PM</div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
            
            <!-- Footer -->
            <div class="datetime-picker-footer">
              <button type="button" class="btn btn-secondary me-2 cancel-btn">Cancel</button>
              <button type="button" class="btn btn-primary ok-btn">OK</button>
            </div>
          </div>`;

                $container.html(pickerHtml);
            }

            // Initialize the picker
            createPickerHtml();

            // Format functions
            function formatDate(date) {
                const day = String(date.getDate()).padStart(2, '0');
                const month = String(date.getMonth() + 1).padStart(2, '0');
                const year = date.getFullYear();
                const hours = date.getHours();
                const minutes = String(date.getMinutes()).padStart(2, '0');
                const ampm = hours >= 12 ? 'PM' : 'AM';
                const formattedHours = hours % 12 || 12;

                // Default format: MM/DD/YYYY, h:mm A
                return `${month}/${day}/${year}, ${formattedHours}:${minutes} ${ampm}`;
            }

            function updateInputValue() {
                $container.find('.datetime-input').val(formatDate(selectedDate));

                // Fire callback if defined
                if (typeof settings.onChange === 'function') {
                    settings.onChange(selectedDate);
                }
            }

            // Update the calendar
            function updateCalendar() {
                try {
                    // Validate currentDate
                    if (!currentDate || !(currentDate instanceof Date) || isNaN(currentDate.getTime())) {
                        console.error('Invalid currentDate, resetting to now');
                        currentDate = new Date();
                    }

                    const year = currentDate.getFullYear();
                    const month = currentDate.getMonth();

                    // Update month/year title
                    const monthNames = [
                        'January',
                        'February',
                        'March',
                        'April',
                        'May',
                        'June',
                        'July',
                        'August',
                        'September',
                        'October',
                        'November',
                        'December'
                    ];
                    
                    const $monthYearElement = $container.find('.current-month-year');
                    if ($monthYearElement.length > 0) {
                        $monthYearElement.text(`${monthNames[month]} ${year}`);
                    }

                    // Generate calendar days
                    const $calendarDays = $container.find('.calendar-days');
                    if ($calendarDays.length > 0) {
                        $calendarDays.empty();
                    } else {
                        console.error('Calendar days container not found');
                        return;
                    }

                    const firstDay = new Date(year, month, 1);
                    const lastDay = new Date(year, month + 1, 0);
                    const daysInMonth = lastDay.getDate();
                    const startingDay = firstDay.getDay();
                    // 0 = Sunday

                    // Add empty cells for days before the first day of the month
                    for (let i = 0; i < startingDay; i++) {
                        $calendarDays.append('<div></div>');
                    }

                    function isSelected(day) {
                        // Validate selectedDate
                        if (!selectedDate || !(selectedDate instanceof Date) || isNaN(selectedDate.getTime())) {
                            return false;
                        }
                        return day === selectedDate.getDate() && month === selectedDate.getMonth() && year === selectedDate.getFullYear();
                    }

                    // Add cells for each day of the month
                    for (let i = 1; i <= daysInMonth; i++) {
                        const dayCell = $('<div>').addClass('day-cell').text(i);

                        if (isSelected(i)) {
                            dayCell.addClass('selected');
                        }

                        dayCell.off('click').on('click', function () {
                            try {
                                $container.find('.day-cell').removeClass('selected');
                                $(this).addClass('selected');

                                const newDate = new Date(selectedDate);
                                newDate.setFullYear(year);
                                newDate.setMonth(month);
                                newDate.setDate(i);
                                selectedDate = newDate;

                                updateInputValue();
                            } catch (error) {
                                console.error('Error selecting date:', error);
                            }
                        });

                        $calendarDays.append(dayCell);
                    }
                } catch (error) {
                    console.error('Error updating calendar:', error);
                }
            }

            // Update the time picker
            function updateTimePicker() { // Generate hours
                const $hourGrid = $container.find('.hour-grid');
                $hourGrid.empty();
                for (let i = 1; i <= 12; i++) {
                    const isSelected = (selectedDate.getHours() % 12 || 12) === i;

                    const hourCell = $('<div>').addClass('hour-cell').text(i);

                    if (isSelected) {
                        hourCell.addClass('selected');
                    }

                    hourCell.on('click', function (e) {
                        e.preventDefault();
                        e.stopPropagation();
                        $container.find('.hour-cell').removeClass('selected');
                        $(this).addClass('selected');

                        const newDate = new Date(selectedDate);
                        const isPM = selectedDate.getHours() >= 12;
                        const newHour = isPM ? i + 12 : i;
                        newDate.setHours(newHour === 24 ? 12 : newHour);
                        selectedDate = newDate;

                        updateInputValue();
                    });

                    $hourGrid.append(hourCell);
                }

                // Generate minutes
                const $minuteGrid = $container.find('.minute-grid');
                $minuteGrid.empty();
                for (let i = 0; i < 60; i += settings.minuteInterval) {
                    const isSelected = Math.floor(selectedDate.getMinutes() / settings.minuteInterval) * settings.minuteInterval === i;

                    const minuteCell = $('<div>').addClass('minute-cell').text(String(i).padStart(2, '0'));

                    if (isSelected) {
                        minuteCell.addClass('selected');
                    }

                    minuteCell.on('click', function (e) {
                        e.preventDefault();
                        e.stopPropagation();
                        $container.find('.minute-cell').removeClass('selected');
                        $(this).addClass('selected');

                        const newDate = new Date(selectedDate);
                        newDate.setMinutes(i);
                        selectedDate = newDate;

                        updateInputValue();
                    });

                    $minuteGrid.append(minuteCell);
                }

                // Update AM/PM buttons
                if (selectedDate.getHours() < 12) {
                    $container.find('.am-btn').addClass('selected');
                    $container.find('.pm-btn').removeClass('selected');
                } else {
                    $container.find('.am-btn').removeClass('selected');
                    $container.find('.pm-btn').addClass('selected');
                }
            }

            // Toggle between date and time tabs
            function showTab(tab) {
                activeTab = tab;

                if (tab === 'date') {
                    $container.find('.date-tab').show();
                    $container.find('.time-tab').hide();
                    $container.find('.datetime-picker-header-title').text('Select Date');
                } else {
                    $container.find('.date-tab').hide();
                    $container.find('.time-tab').show();
                    $container.find('.datetime-picker-header-title').text('Select Time');
                }
            }

            // Initialize the picker
            updateInputValue();

            // Event handlers
            // Show the picker when clicking on the input or toggle button
            $container.on('click', '.datetime-input, .datetime-toggle', function (e) {
                e.preventDefault();
                e.stopPropagation();
                $container.find('.datetime-picker-dropdown').show();
                updateCalendar();
                updateTimePicker();
                showTab('date');
            });

            // Hide the picker when clicking outside - using namespaced event to avoid conflicts
            const clickOutsideEvent = `mousedown.dateTimePicker.${pickerId}`;
            $(document).off(clickOutsideEvent).on(clickOutsideEvent, function (e) {
                const $picker = $container.find('.datetime-picker-dropdown');

                // Check if the picker is visible first
                if ($picker.is(':visible')) { // Check if the click was inside the picker or its related elements
                    const $input = $container.find('.datetime-input');
                    const $toggle = $container.find('.datetime-toggle');

                    // If the click is outside all picker-related elements, hide the picker
                    if (! $picker.is(e.target) && $picker.has(e.target).length === 0 && ! $input.is(e.target) && ! $toggle.is(e.target) && $toggle.has(e.target).length === 0) {
                        $picker.hide();
                    }
                }
            });

            // Clean up the event handler when the element is removed
            $container.on('remove', function () {
                $(document).off(clickOutsideEvent);
            });

            // Tab navigation
            $container.on('click', '.datetime-picker-date-btn', function (e) {
                e.preventDefault();
                e.stopPropagation();
                showTab('date');
            });

            $container.on('click', '.datetime-picker-time-btn', function (e) {
                e.preventDefault();
                e.stopPropagation();
                showTab('time');
            });

            // Month navigation
            $container.off('click', '.prev-month').on('click', '.prev-month', function (e) {
                e.preventDefault();
                e.stopPropagation();
                try {
                    // Create a new date object to avoid mutation issues
                    const newDate = new Date(currentDate.getFullYear(), currentDate.getMonth() - 1, 1);
                    currentDate = newDate;
                    updateCalendar();
                } catch (error) {
                    console.error('Error navigating to previous month:', error);
                }
            });

            $container.off('click', '.next-month').on('click', '.next-month', function (e) {
                e.preventDefault();
                e.stopPropagation();
                try {
                    // Create a new date object to avoid mutation issues
                    const newDate = new Date(currentDate.getFullYear(), currentDate.getMonth() + 1, 1);
                    currentDate = newDate;
                    updateCalendar();
                } catch (error) {
                    console.error('Error navigating to next month:', error);
                }
            });

            // AM/PM toggle
            $container.on('click', '.am-btn', function (e) {
                e.preventDefault();
                e.stopPropagation();
                if (selectedDate.getHours() >= 12) {
                    const newDate = new Date(selectedDate);
                    newDate.setHours(newDate.getHours() - 12);
                    selectedDate = newDate;

                    $container.find('.am-btn').addClass('selected');
                    $container.find('.pm-btn').removeClass('selected');
                    updateInputValue();
                }
            });

            $container.on('click', '.pm-btn', function (e) {
                e.preventDefault();
                e.stopPropagation();
                if (selectedDate.getHours() < 12) {
                    const newDate = new Date(selectedDate);
                    newDate.setHours(newDate.getHours() + 12);
                    selectedDate = newDate;

                    $container.find('.am-btn').removeClass('selected');
                    $container.find('.pm-btn').addClass('selected');
                    updateInputValue();
                }
            });

            // Cancel and OK buttons
            $container.on('click', '.cancel-btn', function (e) {
                e.preventDefault();
                e.stopPropagation();
                $container.find('.datetime-picker-dropdown').hide();
            });

            $container.on('click', '.ok-btn', function (e) {
                e.preventDefault();
                e.stopPropagation();
                $container.find('.datetime-picker-dropdown').hide();
            });

            // Initialize
            updateCalendar();
            updateTimePicker();

            // Save instance data
            $container.data('dateTimePicker', {
                getDate: function () {
                    return new Date(selectedDate);
                },
                setDate: function (date) {
                    selectedDate = new Date(date);
                    updateInputValue();
                    updateCalendar();
                    updateTimePicker();
                    return this;
                },
                show: function () {
                    $container.find('.datetime-picker-dropdown').show();
                    return this;
                },
                hide: function () {
                    $container.find('.datetime-picker-dropdown').hide();
                    return this;
                }
            });

            return $container;
        });
    };
})(jQuery);
