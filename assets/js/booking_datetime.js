document.addEventListener('DOMContentLoaded', () => {
    const initializeDateTimePicker = (selector, options = {}) => {
        const defaultOptions = {
            enableTime: true,
            dateFormat: "Y-m-d H:i", // h for 12-hour format, K for AM/PM

            time_24hr: false, // Ensure 12-hour format with AM/PM
            minuteIncrement: 15,
            minDate: "today",
            allowInput: true,
            altFormat: "Y-m-d H:i", // Show a readable format with AM/PM

            altInput: true,
            onChange: (selectedDates, dateStr, instance) => {
                const selectedTime = new Date(dateStr);
                const currentTime = new Date();

                if (selectedTime < currentTime) {
                    Swal.fire({icon: 'error', title: 'Invalid Time', text: 'Selected time cannot be in the past'});
                    // instance.clear();
                }
            }
        };

        return flatpickr(selector, {
            ... defaultOptions,
            ...options
        });
    };

    // Initialize start and end time pickers
    const startPicker = initializeDateTimePicker("#startTime", {
        onChange: function (selectedDates, dateStr, instance) {
            if (selectedDates[0]) { // Update the minimum date for the end picker
                endPicker.set("minDate", selectedDates[0]);
            }
        }
    });

    const endPicker = initializeDateTimePicker("#endTime", {
        onChange: function (selectedDates, dateStr, instance) {
            if (selectedDates[0]) {
                const startDate = startPicker.selectedDates[0];
                if (startDate && selectedDates[0] <= startDate) {
                    Swal.fire({icon: 'error', title: 'Invalid Time Range', text: 'End time must be after start time'});
                    // instance.clear();
                }
            }
        }
    });
});
