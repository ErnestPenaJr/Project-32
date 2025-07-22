/**
 * DateTimeRange Picker - jQuery Plugin
 * A flexible jQuery/Bootstrap based date and time range picker
 */
(function ($) {
    'use strict';

    // Plugin definition
    $.fn.dateTimeRangePicker = function (options) { // Default settings
        const defaults = {
            startDateLabel: 'Start Date and Time',
            endDateLabel: 'End Date and Time',
            dateFormat: 'MM/DD/YYYY, h:mm A',
            defaultStartDate: new Date(),
            defaultEndDate: new Date(new Date().getTime() + 60 * 60 * 1000), // 1 hour later
            minuteInterval: 5,
            onStartDateChange: null,
            onEndDateChange: null,
            onSelect: null
        };

        // Merge user options with defaults
        const settings = $.extend({}, defaults, options);

        // Plugin functionality
        return this.each(function () {
            const $container = $(this);
            let pickerHtml = '';
            let startDate = new Date(settings.defaultStartDate);
            let endDate = new Date(settings.defaultEndDate);
            let currentDate = new Date();
            let activeTab = 'date';
            let activeRange = 'start'; // 'start' or 'end'
            let pickerId = 'datetime-picker-' + Math.floor(Math.random() * 1000000);

            // Generate picker HTML
            function createPickerHtml() {
                pickerHtml = `
          <div class="row">
            <div class="col-md-6">
              <!-- Start Date Input -->
              <div class="form-floating position-relative mb-3">
                <input type="text" class="form-control start-datetime-input" id="start-datetime-${pickerId}" placeholder=" " readonly>
                <label for="start-datetime-${pickerId}">${
                    settings.startDateLabel
                }</label>
                <button class="btn position-absolute top-50 end-0 translate-middle-y me-2 start-datetime-toggle">
                  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-calendar" viewBox="0 0 16 16">
                    <path d="M3.5 0a.5.5 0 0 1 .5.5V1h8V.5a.5.5 0 0 1 1 0V1h1a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V3a2 2 0 0 1 2-2h1V.5a.5.5 0 0 1 .5-.5zM1 4v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V4H1z"/>
                  </svg>
                </button>
              </div>
            </div>
            <div class="col-md-6">
              <!-- End Date Input -->
              <div class="form-floating position-relative mb-3">
                <input type="text" class="form-control end-datetime-input" id="end-datetime-${pickerId}" placeholder=" " readonly>
                <label for="end-datetime-${pickerId}">${
                    settings.endDateLabel
                }</label>
                <button class="btn position-absolute top-50 end-0 translate-middle-y me-2 end-datetime-toggle">
                  <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-calendar" viewBox="0 0 16 16">
                    <path d="M3.5 0a.5.5 0 0 1 .5.5V1h8V.5a.5.5 0 0 1 1 0V1h1a2 2 0 0 1 2 2v11a2 2 0 0 1-2 2H2a2 2 0 0 1-2-2V3a2 2 0 0 1 2-2h1V.5a.5.5 0 0 1 .5-.5zM1 4v10a1 1 0 0 0 1 1h12a1 1 0 0 0 1-1V4H1z"/>
                  </svg>
                </button>
              </div>
            </div>
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
              <div class="header-title datetime-picker-header-title">Select Date Range</div>
              <button type="button" class="btn datetime-picker-time-btn">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-clock" viewBox="0 0 16 16">
                  <path d="M8 3.5a.5.5 0 0 0-1 0V9a.5.5 0 0 0 .252.434l3.5 2a.5.5 0 0 0 .496-.868L8 8.71V3.5z"/>
                  <path d="M8 16A8 8 0 1 0 8 0a8 8 0 0 0 0 16zm7-8A7 7 0 1 1 1 8a7 7 0 0 1 14 0z"/>
                </svg>
              </button>
            </div>
            
            <!-- Body -->
            <div class="datetime-picker-body">
              <div class="range-selection-toggle">
                <button type="button" class="btn btn-sm btn-primary active start-range-btn">Start Date/Time</button>
                <button type="button" class="btn btn-sm btn-outline-primary end-range-btn">End Date/Time</button>
              </div>
              
              <!-- Date Tab Content -->
              <div class="date-tab tab-content">
                <div class="month-nav">
                  <button class="btn btn-sm btn-outline-secondary prev-month">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="currentColor" class="bi bi-chevron-left" viewBox="0 0 16 16">
                      <path fill-rule="evenodd" d="M11.354 1.646a.5.5 0 0 1 0 .708L5.707 8l5.647 5.646a.5.5 0 0 1-.708.708l-6-6a.5.5 0 0 1 0-.708l6-6a.5.5 0 0 1 .708 0z"/>
                    </svg>
                  </button>
                  <span class="current-month-year">May 2025</span>
                  <button class="btn btn-sm btn-outline-secondary next-month">
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

            function updateInputValues() {
                $container.find('.start-datetime-input').val(formatDate(startDate));
                $container.find('.end-datetime-input').val(formatDate(endDate));

                // Fire callbacks if defined
                if (typeof settings.onStartDateChange === 'function') {
                    settings.onStartDateChange(startDate);
                }

                if (typeof settings.onEndDateChange === 'function') {
                    settings.onEndDateChange(endDate);
                }
            }

            // Get current active date based on which range is active
            function getActiveDate() {
                return activeRange === 'start' ? startDate : endDate;
            }

            // Set the active date based on which range is active
            function setActiveDate(date) {
                if (activeRange === 'start') {
                    startDate = date;
                    // Ensure end date is not before start date
                    if (endDate < startDate) {
                        const newEndDate = new Date(startDate);
                        newEndDate.setHours(newEndDate.getHours() + 1);
                        endDate = newEndDate;
                    }
                } else {
                    endDate = date;
                    // Ensure start date is not after end date
                    if (startDate > endDate) {
                        const newStartDate = new Date(endDate);
                        newStartDate.setHours(newStartDate.getHours() - 1);
                        startDate = newStartDate;
                    }
                } updateInputValues();

                // Fire select callback if defined
                if (typeof settings.onSelect === 'function') {
                    settings.onSelect(startDate, endDate);
                }
            }

            // Update the calendar
            function updateCalendar() {
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
                $container.find('.current-month-year').text(`${
                    monthNames[month]
                } ${year}`);

                // Generate calendar days
                const $calendarDays = $container.find('.calendar-days');
                $calendarDays.empty();

                const firstDay = new Date(year, month, 1);
                const lastDay = new Date(year, month + 1, 0);
                const daysInMonth = lastDay.getDate();
                const startingDay = firstDay.getDay();
                // 0 = Sunday

                // Add empty cells for days before the first day of the month
                for (let i = 0; i < startingDay; i++) {
                    $calendarDays.append('<div></div>');
                }

                // Helper function to check if a date is in the selected range
                function isInRange(day) {
                    const currentDayDate = new Date(year, month, day);
                    const startDateNoTime = new Date(startDate.getFullYear(), startDate.getMonth(), startDate.getDate());
                    const endDateNoTime = new Date(endDate.getFullYear(), endDate.getMonth(), endDate.getDate());
                    return currentDayDate > startDateNoTime && currentDayDate < endDateNoTime;
                }

                function isRangeStart(day) {
                    return day === startDate.getDate() && month === startDate.getMonth() && year === startDate.getFullYear();
                }

                function isRangeEnd(day) {
                    return day === endDate.getDate() && month === endDate.getMonth() && year === endDate.getFullYear();
                }

                // Add cells for each day of the month
                for (let i = 1; i <= daysInMonth; i++) {
                    const isStart = isRangeStart(i);
                    const isEnd = isRangeEnd(i);
                    const isRange = isInRange(i);

                    const dayCell = $('<div>').addClass('day-cell').text(i);

                    if (isStart) {
                        dayCell.addClass('range-start');
                    } else if (isEnd) {
                        dayCell.addClass('range-end');
                    } else if (isRange) {
                        dayCell.addClass('range');
                    }

                    dayCell.on('click', function () {
                        const newDate = new Date(getActiveDate());
                        newDate.setFullYear(year);
                        newDate.setMonth(month);
                        newDate.setDate(i);

                        setActiveDate(newDate);
                        updateCalendar();
                    });

                    $calendarDays.append(dayCell);
                }
            }

            // Update the time picker
            function updateTimePicker() {
                const activeDate = getActiveDate();

                // Generate hours
                const $hourGrid = $container.find('.hour-grid');
                $hourGrid.empty();
                for (let i = 1; i <= 12; i++) {
                    const isSelected = (activeDate.getHours() % 12 || 12) === i;

                    const hourCell = $('<div>').addClass('hour-cell').text(i);

                    if (isSelected) {
                        hourCell.addClass('selected');
                    }

                    hourCell.on('click', function () {
                        $container.find('.hour-cell').removeClass('selected');
                        $(this).addClass('selected');

                        const newDate = new Date(activeDate);
                        const isPM = activeDate.getHours() >= 12;
                        const newHour = isPM ? i + 12 : i;
                        newDate.setHours(newHour === 24 ? 12 : newHour);

                        setActiveDate(newDate);
                    });

                    $hourGrid.append(hourCell);
                }

                // Generate minutes
                const $minuteGrid = $container.find('.minute-grid');
                $minuteGrid.empty();
                for (let i = 0; i < 60; i += settings.minuteInterval) {
                    const isSelected = Math.floor(activeDate.getMinutes() / settings.minuteInterval) * settings.minuteInterval === i;

                    const minuteCell = $('<div>').addClass('minute-cell').text(String(i).padStart(2, '0'));

                    if (isSelected) {
                        minuteCell.addClass('selected');
                    }

                    minuteCell.on('click', function () {
                        $container.find('.minute-cell').removeClass('selected');
                        $(this).addClass('selected');

                        const newDate = new Date(activeDate);
                        newDate.setMinutes(i);

                        setActiveDate(newDate);
                    });

                    $minuteGrid.append(minuteCell);
                }

                // Update AM/PM buttons
                if (activeDate.getHours() < 12) {
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
                    $container.find('.datetime-picker-header-title').text(activeRange === 'start' ? 'Select Start Date' : 'Select End Date');
                } else {
                    $container.find('.date-tab').hide();
                    $container.find('.time-tab').show();
                    $container.find('.datetime-picker-header-title').text(activeRange === 'start' ? 'Select Start Time' : 'Select End Time');
                }
            }

            // Set active range (start or end)
            function setActiveRange(range) {
                activeRange = range;

                if (range === 'start') {
                    $container.find('.start-range-btn').addClass('btn-primary').removeClass('btn-outline-primary');
                    $container.find('.end-range-btn').addClass('btn-outline-primary').removeClass('btn-primary');
                } else {
                    $container.find('.start-range-btn').addClass('btn-outline-primary').removeClass('btn-primary');
                    $container.find('.end-range-btn').addClass('btn-primary').removeClass('btn-outline-primary');
                }

                // Update header title based on active tab and range
                if (activeTab === 'date') {
                    $container.find('.datetime-picker-header-title').text(activeRange === 'start' ? 'Select Start Date' : 'Select End Date');
                } else {
                    $container.find('.datetime-picker-header-title').text(activeRange === 'start' ? 'Select Start Time' : 'Select End Time');
                } updateTimePicker();
            }

            // Initialize the picker
            updateInputValues();

            // Event handlers
            // Show the picker when clicking on the inputs or toggle buttons
            $container.on('click', '.start-datetime-input, .start-datetime-toggle', function () {
                $container.find('.datetime-picker-dropdown').show();
                setActiveRange('start');
                updateCalendar();
                updateTimePicker();
                showTab('date');
            });

            $container.on('click', '.end-datetime-input, .end-datetime-toggle', function () {
                $container.find('.datetime-picker-dropdown').show();
                setActiveRange('end');
                updateCalendar();
                updateTimePicker();
                showTab('date');
            });

            // Hide the picker when clicking outside - using namespaced event to avoid conflicts
            const clickOutsideEvent = `mousedown.dateTimeRangePicker.${pickerId}`;
            $(document).off(clickOutsideEvent).on(clickOutsideEvent, function (e) {
                const $picker = $container.find('.datetime-picker-dropdown');

                // Check if the picker is visible first
                if ($picker.is(':visible')) { // Check if the click was inside the picker or its related elements
                    const $startInput = $container.find('.start-datetime-input');
                    const $endInput = $container.find('.end-datetime-input');
                    const $startToggle = $container.find('.start-datetime-toggle');
                    const $endToggle = $container.find('.end-datetime-toggle');

                    // If the click is outside all picker-related elements, hide the picker
                    if (! $picker.is(e.target) && $picker.has(e.target).length === 0 && ! $startInput.is(e.target) && ! $endInput.is(e.target) && ! $startToggle.is(e.target) && $startToggle.has(e.target).length === 0 && ! $endToggle.is(e.target) && $endToggle.has(e.target).length === 0) {
                        $picker.hide();
                    }
                }
            });

            // Clean up the event handler when the element is removed
            $container.on('remove', function () {
                $(document).off(clickOutsideEvent);
            });

            // Range toggle buttons
            $container.on('click', '.start-range-btn', function () {
                setActiveRange('start');
                updateCalendar();
            });

            $container.on('click', '.end-range-btn', function () {
                setActiveRange('end');
                updateCalendar();
            });

            // Tab navigation
            $container.on('click', '.datetime-picker-date-btn', function () {
                showTab('date');
            });

            $container.on('click', '.datetime-picker-time-btn', function () {
                showTab('time');
            });

            // Month navigation
            $container.on('click', '.prev-month', function () {
                currentDate.setMonth(currentDate.getMonth() - 1);
                updateCalendar();
            });

            $container.on('click', '.next-month', function () {
                currentDate.setMonth(currentDate.getMonth() + 1);
                updateCalendar();
            });

            // AM/PM toggle
            $container.on('click', '.am-btn', function () {
                const activeDate = getActiveDate();
                if (activeDate.getHours() >= 12) {
                    const newDate = new Date(activeDate);
                    newDate.setHours(newDate.getHours() - 12);
                    setActiveDate(newDate);

                    $container.find('.am-btn').addClass('selected');
                    $container.find('.pm-btn').removeClass('selected');
                }
            });

            $container.on('click', '.pm-btn', function () {
                const activeDate = getActiveDate();
                if (activeDate.getHours() < 12) {
                    const newDate = new Date(activeDate);
                    newDate.setHours(newDate.getHours() + 12);
                    setActiveDate(newDate);

                    $container.find('.am-btn').removeClass('selected');
                    $container.find('.pm-btn').addClass('selected');
                }
            });

            // Cancel and OK buttons
            $container.on('click', '.cancel-btn', function () {
                $container.find('.datetime-picker-dropdown').hide();
            });

            $container.on('click', '.ok-btn', function () {
                $container.find('.datetime-picker-dropdown').hide();
            });

            // Initialize
            updateCalendar();
            updateTimePicker();

            // Save instance data
            $container.data('dateTimeRangePicker', {
                getStartDate: function () {
                    return new Date(startDate);
                },
                getEndDate: function () {
                    return new Date(endDate);
                },
                setStartDate: function (date) {
                    startDate = new Date(date);
                    updateInputValues();
                    updateCalendar();
                    updateTimePicker();
                    return this;
                },
                setEndDate: function (date) {
                    endDate = new Date(date);
                    updateInputValues();
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
