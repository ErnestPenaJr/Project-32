$('document').ready(function () {
    // Load top navigation
    if (sessionStorage.getItem('ROLE') == 'Admin' || sessionStorage.getItem('ROLE') == 'Site Admin') {
        $('#topNav').load('topNav-Admin.html');
    } else {
        $('#topNav').load('topNav-User.html');
    }
    AOS.init();
});
    function handleLogout() {
        window.location.href = "logout.html";
    }
