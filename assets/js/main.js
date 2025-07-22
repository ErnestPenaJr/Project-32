// Global utility functions and event handlers

// Format currency
function formatCurrency(amount) {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'USD'
    }).format(amount);
}

// Format date
function formatDate(date) {
    return new Intl.DateTimeFormat('en-US', {
        year: 'numeric',
        month: 'long',
        day: 'numeric'
    }).format(new Date(date));
}

// Show loading spinner
function showLoading(elementId) {
    const element = document.getElementById(elementId);
    if (element) {
        element.innerHTML = `
            <div class="flex justify-center items-center">
                <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-600"></div>
            </div>
        `;
    }
}

// Show toast notification
function showToast(message, type = 'success') {
    const toast = document.createElement('div');
    toast.className = `fixed bottom-4 right-4 p-4 rounded-lg shadow-lg text-white ${
        type === 'success' ? 'bg-green-500' : 'bg-red-500'
    }`;
    toast.textContent = message;
    document.body.appendChild(toast);
    
    setTimeout(() => {
        toast.remove();
    }, 3000);
}

// Form validation
function validateForm(formData, rules) {
    const errors = {};
    
    for (const [field, value] of formData.entries()) {
        if (rules[field]) {
            const fieldRules = rules[field];
            
            // Required check
            if (fieldRules.required && !value) {
                errors[field] = `${field} is required`;
                continue;
            }
            
            // Minimum length check
            if (fieldRules.minLength && value.length < fieldRules.minLength) {
                errors[field] = `${field} must be at least ${fieldRules.minLength} characters`;
                continue;
            }
            
            // Maximum length check
            if (fieldRules.maxLength && value.length > fieldRules.maxLength) {
                errors[field] = `${field} must be no more than ${fieldRules.maxLength} characters`;
                continue;
            }
            
            // Pattern check
            if (fieldRules.pattern && !fieldRules.pattern.test(value)) {
                errors[field] = fieldRules.message || `${field} is invalid`;
                continue;
            }
            
            // Custom validation
            if (fieldRules.validate && !fieldRules.validate(value)) {
                errors[field] = fieldRules.message || `${field} is invalid`;
                continue;
            }
        }
    }
    
    return {
        isValid: Object.keys(errors).length === 0,
        errors
    };
}

// Handle API errors
function handleApiError(error) {
    console.error('API Error:', error);
    
    if (error.response) {
        // Server responded with an error status
        showToast(error.response.data.message || 'An error occurred', 'error');
    } else if (error.request) {
        // Request was made but no response received
        showToast('Unable to connect to the server', 'error');
    } else {
        // Error in request setup
        showToast('An error occurred while processing your request', 'error');
    }
}

// Debounce function for search inputs
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

// Image upload preview
function previewImage(input, previewElement) {
    if (input.files && input.files[0]) {
        const reader = new FileReader();
        
        reader.onload = function(e) {
            previewElement.src = e.target.result;
        };
        
        reader.readAsDataURL(input.files[0]);
    }
}

// Date range picker configuration
const dateRangeConfig = {
    minDate: new Date(),
    dateFormat: "Y-m-d",
    mode: "range",
    disable: [
        function(date) {
            // Disable weekends
            return date.getDay() === 0 || date.getDay() === 6;
        }
    ],
    onChange: function(selectedDates, dateStr, instance) {
        if (selectedDates.length === 2) {
            // Calculate number of nights
            const nights = Math.round((selectedDates[1] - selectedDates[0]) / (1000 * 60 * 60 * 24));
            const nightsElement = document.getElementById('nights');
            if (nightsElement) {
                nightsElement.textContent = nights;
            }
            
            // Update total price if price per night is available
            const pricePerNight = document.getElementById('price-per-night')?.dataset.price;
            const totalPriceElement = document.getElementById('total-price');
            if (pricePerNight && totalPriceElement) {
                const totalPrice = nights * parseFloat(pricePerNight);
                totalPriceElement.textContent = formatCurrency(totalPrice);
            }
        }
    }
};

// Initialize components when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
    // Initialize date pickers
    const dateRangePickers = document.querySelectorAll('.date-range-picker');
    dateRangePickers.forEach(picker => {
        flatpickr(picker, dateRangeConfig);
    });
    
    // Initialize tooltips
    const tooltips = document.querySelectorAll('[data-tooltip]');
    tooltips.forEach(tooltip => {
        tippy(tooltip, {
            content: tooltip.dataset.tooltip,
            placement: 'top'
        });
    });
    
    // Initialize modals
    const modalTriggers = document.querySelectorAll('[data-modal-target]');
    modalTriggers.forEach(trigger => {
        trigger.addEventListener('click', () => {
            const modal = document.getElementById(trigger.dataset.modalTarget);
            if (modal) {
                modal.classList.remove('hidden');
            }
        });
    });
    
    const modalCloseButtons = document.querySelectorAll('[data-modal-close]');
    modalCloseButtons.forEach(button => {
        button.addEventListener('click', () => {
            const modal = button.closest('.modal');
            if (modal) {
                modal.classList.add('hidden');
            }
        });
    });
    
    // Close modals when clicking outside
    window.addEventListener('click', (e) => {
        if (e.target.classList.contains('modal')) {
            e.target.classList.add('hidden');
        }
    });
    
    // Initialize file upload previews
    const imageInputs = document.querySelectorAll('[data-preview-target]');
    imageInputs.forEach(input => {
        const previewElement = document.getElementById(input.dataset.previewTarget);
        if (previewElement) {
            input.addEventListener('change', () => previewImage(input, previewElement));
        }
    });
});

// Export functions for use in other scripts
export {
    formatCurrency,
    formatDate,
    showLoading,
    showToast,
    validateForm,
    handleApiError,
    debounce,
    previewImage
};
