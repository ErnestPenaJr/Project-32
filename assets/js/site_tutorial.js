// Site Tutorial Implementation
$(document).ready(function() {
    // Initialize the tour
    const tour = new Shepherd.Tour({
        defaultStepOptions: {
            cancelIcon: {
                enabled: true
            },
            classes: 'shadow-md bg-purple-dark',
            scrollTo: true
        }
    });

    // Add steps to the tour
    tour.addStep({
        id: 'welcome',
        text: 'Welcome to our site! Let us show you around and help you get started.',
        attachTo: {
            element: 'body',
            on: 'center'
        },
        buttons: [
            {
                text: 'Skip Tour',
                action: tour.cancel
            },
            {
                text: 'Start Tour',
                action: tour.next
            }
        ]
    });

    // Navigation Menu
    tour.addStep({
        id: 'navigation',
        text: 'This is the main navigation menu. You can access different sections of the site from here.',
        attachTo: {
            element: '.navbar',
            on: 'bottom'
        },
        buttons: [
            {
                text: 'Back',
                action: tour.back
            },
            {
                text: 'Next',
                action: tour.next
            }
        ]
    });

    // User Profile
    tour.addStep({
        id: 'user-profile',
        text: 'Access your profile settings and account information here.',
        attachTo: {
            element: '.user-profile',
            on: 'bottom'
        },
        buttons: [
            {
                text: 'Back',
                action: tour.back
            },
            {
                text: 'Next',
                action: tour.next
            }
        ]
    });

    // Search Functionality
    tour.addStep({
        id: 'search',
        text: 'Use the search bar to quickly find what you need.',
        attachTo: {
            element: '.search-bar',
            on: 'bottom'
        },
        buttons: [
            {
                text: 'Back',
                action: tour.back
            },
            {
                text: 'Next',
                action: tour.next
            }
        ]
    });

    // Final Step
    tour.addStep({
        id: 'end',
        text: 'That concludes our quick tour! You can restart the tour anytime by clicking the "Help" button in the navigation menu.',
        attachTo: {
            element: 'body',
            on: 'center'
        },
        buttons: [
            {
                text: 'Finish',
                action: tour.complete
            }
        ]
    });

    // Function to start the tour
    window.startSiteTour = function() {
        tour.start();
    };

    // Add help button to trigger tour
    const helpButton = $('<button>')
        .addClass('btn btn-outline-info ms-2')
        .html('<i class="fas fa-question-circle"></i> Help')
        .click(function() {
            startSiteTour();
        });

    $('.navbar-nav').append(
        $('<li>').addClass('nav-item').append(helpButton)
    );

    // Check if it's the user's first visit
    if (!localStorage.getItem('tourCompleted')) {
        // Show welcome modal
        const welcomeModal = new bootstrap.Modal($('#welcomeModal'));
        welcomeModal.show();
    }
});
