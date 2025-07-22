// if session storage is 0 or does not exist, redirect to login page
if (!sessionStorage.getItem('USER_ID')) { // clear all sessions storage
    sessionStorage.clear();
    localStorage.clear();
    window.location.href = 'login.html';
}

$('.logout-btn').on('click', function () {
    window.location.href = 'logout.html';
});


// Initialize session timeout
function initSessionTimeout() {
    $.sessionTimeout({
        keepAliveUrl: './cfcs/Authenticate.cfc?method=checkSession',
        logoutUrl: 'logout.html',
        redirUrl: 'login.html',
        warnAfter: 1140000, // 19 minutes
        redirAfter: 1200000, // 20 minutes
        keepAliveInterval: 300000, // 5 minutes
        onWarn: function () {
            Swal.fire({
                title: 'Session Expiring',
                text: 'Your session is about to expire. Would you like to stay signed in?',
                icon: 'warning',
                showCancelButton: true,
                confirmButtonText: 'Stay Signed In',
                cancelButtonText: 'Sign Out',
                reverseButtons: true
            }).then((result) => {
                if (result.isConfirmed) {
                    $.ajax({
                        url: './cfcs/Authenticate.cfc',
                        method: 'POST',
                        data: {
                            method: 'checkSession',
                            returnformat: 'json'
                        }
                    });
                } else {
                    window.location.href = 'logout.html';
                }
            });
        }
    });
}

// get user notifications on page load
function getNotifications() {
    $.ajax({
        url: './assets/cfc/notifications.cfc',
        type: 'GET',
        dataType: 'json',
        data: {
            method: 'get_user_notifications',
            user_id: sessionStorage.getItem('USER_ID')
        },
        success: function (response) {
            const notifications = response.NOTIFICATIONS;
            if (notifications && notifications.length > 0) {
                $('#notificationDropdown').empty();
                notifications.forEach(notification => {
                    const notificationItem = $(`
                        <div class="dropdown-item">
                            <i class="fa fa-bell"></i> ${
                        notification.MESSAGE
                    }
                        </div>
                    `);
                    $('#notificationDropdown').append(notificationItem);
                });
            } else {
                $('#notificationDropdown').empty();
            }
        }
    });
}

function myHelpRequest(data) {
    $.ajax({
        url: 'assets/cfc/helpRequests.cfc',
        type: 'POST',
        data: data,
        success: function (data) {},
        error: function (jqXHR, textStatus, errorThrown, FN) {
            errorHandler(jqXHR, textStatus, errorThrown, FN)
        }
    });
}

// get users info on page load


// Check notifications on page load
$(document).ready(function () {
    checkNewUsers();
    checkPendingApprovals();
    initSessionTimeout();
    getNotifications();

    // Set welcome message
    $('#helpRequest').on('click', function () {
        $('#helpForm').modal('show');
    });

    $('#help_emplid').on('keypress', function () {
        if ($(this).val().length >= 5) {
            $(this).removeClass('is-invalid');
            $(this).addClass('is-valid');
        } else {
            $(this).removeClass('is-valid');
            $(this).addClass('is-invalid');
        }
    });
    $('#help_Priority').on('change', function () {
        if ($(this).val() == '') {
            $(this).removeClass('is-valid');
            $(this).addClass('is-invalid');
        } else {
            $(this).removeClass('is-invalid');
            $(this).addClass('is-valid');
        }
    })
    $('#helpDescription').on('keypress', function () {
        if ($(this).val().length >= 5) {
            $(this).removeClass('is-invalid');
            $(this).addClass('is-valid');
        } else {
            $(this).removeClass('is-valid');
            $(this).addClass('is-invalid');
        }
    })

    $(document).ready(function () { // Ensure we remove any previous click handlers before binding
        $('#Submit_Help_Request').off('click').on('click', function (event) { // Prevent the default form submission
            event.preventDefault();

            var data = {
                method: 'helpRequest',
                emplid: $('#help_emplid').val(),
                priority: $('#help_Priority').val(),
                priorityText: $('#help_Priority option:selected').text(),
                description: $('#helpDescription').val()
            };

            // Simple client-side validation
            if (data.emplid === '') {
                $('#help_emplid').addClass('is-invalid');
                return;
            }
            if (data.priority === '') {
                $('#help_Priority').addClass('is-invalid');
                return;
            }
            if (data.description === '') {
                $('#helpDescription').addClass('is-invalid');
                return;
            }

            // Display submission feedback
            $('#help_text_block').slideUp(500);
            $('#messageSubmitted').slideDown(500);

            // Hide the modal after 6 seconds and reset form fields
            setTimeout(function () {
                $('#helpForm').modal('hide');
                $('#helpDescription').val('');
                $('#help_emplid').val('');
            }, 6000);

            // Countdown timer before closing the modal form and resetting fields
            var countDownDate = new Date().getTime() + 4000;
            var x = setInterval(function () {
                var now = new Date().getTime();
                var distance = countDownDate - now;
                var seconds = Math.floor((distance % (1000 * 60)) / 1000);
                $('#Submit_Help_Request').html('<i class="far fa-hourglass fa-spin"></i> Closing in ' + seconds + ' seconds. ');
                if (distance < 0) {
                    clearInterval(x);
                    $('#helpForm').modal('hide');
                    $('#helpDescription').val('');
                    $('#help_emplid').val('');
                    $('#Submit_Help_Request').html('<i class="far fa-paper-plane"></i> Send Request').prop('disabled', true);
                    $('#help_Priority').val('');
                }
            }, 1000);

            // Call the AJAX function once
            myHelpRequest(data);
        });
    });

});
