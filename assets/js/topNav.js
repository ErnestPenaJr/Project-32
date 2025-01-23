// if session storage is 0 or does not exist, redirect to login page
if (!sessionStorage.getItem('USER_ID')) { // clear all sessions storage
    sessionStorage.clear();
    localStorage.clear();
    window.location.href = 'login.html';
}

$('.logout-btn').on('click', function () {
    window.location.href = 'logout.html';
});

// Notification handling functions
function checkNewUsers() {
    $.ajax({
        url: './assets/cfc/user.cfc',
        type: 'GET',
        data: {
            method: 'getNewUsersCount'
        },
        success: function (response) {
            const count = parseInt(response);
            const badge = $('#newUserBadge');
            if (count > 0) {
                badge.text(count).removeClass('d-none');
            } else {
                badge.addClass('d-none');
            }
        }
    });
}

function checkPendingApprovals() {
    $.ajax({
        url: './assets/cfc/approvals.cfc',
        type: 'GET',
        data: {
            method: 'getPendingApprovalsCount'
        },
        success: function (response) {
            const count = parseInt(response);
            const badge = $('#pendingApprovalsBadge');
            if (count > 0) {
                badge.text(count).removeClass('d-none');
            } else {
                badge.addClass('d-none');
            }
        }
    });
}

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

// get users info on page load


// Check notifications on page load
$(document).ready(function () {
    checkNewUsers();
    checkPendingApprovals();
    initSessionTimeout();
    getNotifications();
    // Set welcome message


});
