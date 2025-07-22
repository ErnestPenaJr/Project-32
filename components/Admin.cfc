component {
    // Constructor
    public function init() {
        return this;
    }
    
    // Get dashboard statistics
    public struct function getDashboardStats() {
        var stats = {};
        
        // Get total rooms
        var roomObj = new Room();
        stats.totalRooms = roomObj.getTotalRooms();
        
        // Get active bookings
        var bookingObj = new Booking();
        stats.activeBookings = bookingObj.getActiveBookingsCount();
        
        // Get total users
        var userObj = new User();
        stats.totalUsers = userObj.getTotalUsers();
        
        // Calculate room utilization
        stats.utilization = calculateUtilization();
        
        // Get recent activity
        stats.recentActivity = getRecentActivity();
        
        return stats;
    }
    
    // Calculate room utilization
    private numeric function calculateUtilization() {
        var bookingObj = new Booking();
        var roomObj = new Room();
        
        // Get total available hours for all rooms
        var totalRooms = roomObj.getTotalRooms();
        var hoursPerDay = 12; // Assuming 8am to 8pm operating hours
        var totalAvailableHours = totalRooms * hoursPerDay;
        
        // Get total booked hours for today
        var bookedHours = bookingObj.getTotalBookedHours(date: now());
        
        // Calculate utilization percentage
        if (totalAvailableHours eq 0) return 0;
        return round((bookedHours / totalAvailableHours) * 100);
    }
    
    // Get recent activity for the dashboard
    private array function getRecentActivity() {
        var activity = [];
        var bookingObj = new Booking();
        var recentBookings = bookingObj.getRecentBookings(limit: 10);
        
        // Format activity items
        for (var booking in recentBookings) {
            var item = {
                type: booking.status,
                description: "",
                timestamp: booking.createdAt,
                icon: ""
            };
            
            switch (booking.status) {
                case "active":
                    item.description = "#booking.userName# booked #booking.roomName# for #dateTimeFormat(booking.startTime, 'mmm d, h:nn tt')#";
                    item.icon = "M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z";
                    break;
                    
                case "cancelled":
                    item.description = "#booking.userName# cancelled booking for #booking.roomName#";
                    item.icon = "M6 18L18 6M6 6l12 12";
                    break;
                    
                case "completed":
                    item.description = "Booking completed: #booking.roomName# by #booking.userName#";
                    item.icon = "M5 13l4 4L19 7";
                    break;
            }
            
            arrayAppend(activity, item);
        }
        
        return activity;
    }
    
    // Get room statistics
    public struct function getRoomStats() {
        var roomObj = new Room();
        var bookingObj = new Booking();
        
        var stats = {
            totalRooms: roomObj.getTotalRooms(),
            availableNow: roomObj.getAvailableRoomsCount(now()),
            maintenanceCount: roomObj.getMaintenanceCount(),
            popularRooms: roomObj.getPopularRooms(limit: 5),
            utilizationByDay: bookingObj.getUtilizationByDay(days: 7),
            upcomingMaintenance: roomObj.getUpcomingMaintenance(limit: 5)
        };
        
        return stats;
    }
    
    // Get user statistics
    public struct function getUserStats() {
        var userObj = new User();
        var bookingObj = new Booking();
        
        var stats = {
            totalUsers: userObj.getTotalUsers(),
            activeUsers: userObj.getActiveUsersCount(),
            newUsersThisMonth: userObj.getNewUsersCount(days: 30),
            topBookers: bookingObj.getTopBookers(limit: 5),
            departmentStats: userObj.getDepartmentStats()
        };
        
        return stats;
    }
    
    // Get booking statistics
    public struct function getBookingStats() {
        var bookingObj = new Booking();
        
        var stats = {
            totalBookings: bookingObj.getTotalBookings(),
            activeBookings: bookingObj.getActiveBookingsCount(),
            cancelledBookings: bookingObj.getCancelledBookingsCount(),
            bookingsByHour: bookingObj.getBookingsByHour(),
            bookingsByDay: bookingObj.getBookingsByDay(),
            averageDuration: bookingObj.getAverageDuration()
        };
        
        return stats;
    }
}
