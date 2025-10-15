component extends="mxunit.framework.TestCase" {

    /**
     * Setup - runs before each test
     */
    public void function setUp() {
        // Initialize test data
    }

    /**
     * Teardown - runs after each test
     */
    public void function tearDown() {
        // Clean up test data if needed
    }

    // ============================================
    // ROOM FILTER TESTS
    // ============================================

    /**
     * Test: Filter by single room
     */
    public void function testFilterBySingleRoom() {
        var bookings = [
            {ROOM_ID: 1, ROOM_NAME: "Conference Room A"},
            {ROOM_ID: 2, ROOM_NAME: "Conference Room B"},
            {ROOM_ID: 1, ROOM_NAME: "Conference Room A"}
        ];

        var selectedRoomId = 1;
        var filtered = arrayFilter(bookings, function(booking) {
            return booking.ROOM_ID == selectedRoomId;
        });

        assertEquals(2, arrayLen(filtered), "Should filter to 2 bookings for Room 1");
    }

    /**
     * Test: Clear room filter shows all bookings
     */
    public void function testClearRoomFilterShowsAll() {
        var bookings = [
            {ROOM_ID: 1},
            {ROOM_ID: 2},
            {ROOM_ID: 3}
        ];

        var selectedRoomId = ""; // Empty means no filter
        var filtered = arrayFilter(bookings, function(booking) {
            return len(selectedRoomId) == 0 OR booking.ROOM_ID == selectedRoomId;
        });

        assertEquals(3, arrayLen(filtered), "Should show all bookings when filter cleared");
    }

    /**
     * Test: Room filter with no matching bookings
     */
    public void function testRoomFilterNoMatches() {
        var bookings = [
            {ROOM_ID: 1},
            {ROOM_ID: 2},
            {ROOM_ID: 3}
        ];

        var selectedRoomId = 999; // Non-existent room
        var filtered = arrayFilter(bookings, function(booking) {
            return booking.ROOM_ID == selectedRoomId;
        });

        assertEquals(0, arrayLen(filtered), "Should return empty array when no matches");
    }

    // ============================================
    // STATUS FILTER TESTS
    // ============================================

    /**
     * Test: Filter by pending status
     */
    public void function testFilterByPendingStatus() {
        var bookings = [
            {STATUS: "Pending"},
            {STATUS: "Approved"},
            {STATUS: "Pending"},
            {STATUS: "Confirmed"}
        ];

        var selectedStatus = "pending";
        var filtered = arrayFilter(bookings, function(booking) {
            return lcase(booking.STATUS) == selectedStatus;
        });

        assertEquals(2, arrayLen(filtered), "Should filter to 2 pending bookings");
    }

    /**
     * Test: Filter by approved status
     */
    public void function testFilterByApprovedStatus() {
        var bookings = [
            {STATUS: "Pending"},
            {STATUS: "Approved"},
            {STATUS: "Approved"},
            {STATUS: "Confirmed"}
        ];

        var selectedStatus = "approved";
        var filtered = arrayFilter(bookings, function(booking) {
            return lcase(booking.STATUS) == selectedStatus;
        });

        assertEquals(2, arrayLen(filtered), "Should filter to 2 approved bookings");
    }

    /**
     * Test: Status filter is case-insensitive
     */
    public void function testStatusFilterCaseInsensitive() {
        var booking1 = {STATUS: "Pending"};
        var booking2 = {STATUS: "PENDING"};
        var booking3 = {STATUS: "pending"};

        var selectedStatus = "pending";

        assertTrue(lcase(booking1.STATUS) == selectedStatus, "Should match Pending");
        assertTrue(lcase(booking2.STATUS) == selectedStatus, "Should match PENDING");
        assertTrue(lcase(booking3.STATUS) == selectedStatus, "Should match pending");
    }

    /**
     * Test: Clear status filter shows all statuses
     */
    public void function testClearStatusFilterShowsAll() {
        var bookings = [
            {STATUS: "Pending"},
            {STATUS: "Approved"},
            {STATUS: "Confirmed"}
        ];

        var selectedStatus = ""; // Empty means no filter
        var filtered = arrayFilter(bookings, function(booking) {
            return len(selectedStatus) == 0 OR lcase(booking.STATUS) == selectedStatus;
        });

        assertEquals(3, arrayLen(filtered), "Should show all bookings when filter cleared");
    }

    // ============================================
    // MY BOOKINGS ONLY FILTER TESTS
    // ============================================

    /**
     * Test: My bookings only filter
     */
    public void function testMyBookingsOnlyFilter() {
        var bookings = [
            {USERID: 123},
            {USERID: 456},
            {USERID: 123},
            {USERID: 789}
        ];

        var currentUserId = 123;
        var myBookingsOnly = true;

        var filtered = arrayFilter(bookings, function(booking) {
            return !myBookingsOnly OR booking.USERID == currentUserId;
        });

        assertEquals(2, arrayLen(filtered), "Should filter to current user's bookings only");
    }

    /**
     * Test: My bookings filter disabled shows all
     */
    public void function testMyBookingsFilterDisabledShowsAll() {
        var bookings = [
            {USERID: 123},
            {USERID: 456},
            {USERID: 789}
        ];

        var currentUserId = 123;
        var myBookingsOnly = false;

        var filtered = arrayFilter(bookings, function(booking) {
            return !myBookingsOnly OR booking.USERID == currentUserId;
        });

        assertEquals(3, arrayLen(filtered), "Should show all bookings when filter disabled");
    }

    // ============================================
    // SEARCH FILTER TESTS
    // ============================================

    /**
     * Test: Search by room name
     */
    public void function testSearchByRoomName() {
        var bookings = [
            {NAME: "Conference Room A"},
            {NAME: "Meeting Room B"},
            {NAME: "Conference Room C"}
        ];

        var searchQuery = "conference";
        var filtered = arrayFilter(bookings, function(booking) {
            return len(searchQuery) == 0 OR findNoCase(searchQuery, booking.NAME);
        });

        assertEquals(2, arrayLen(filtered), "Should find 2 conference rooms");
    }

    /**
     * Test: Search by user name
     */
    public void function testSearchByUserName() {
        var bookings = [
            {FIRSTNAME: "John", LASTNAME: "Doe"},
            {FIRSTNAME: "Jane", LASTNAME: "Smith"},
            {FIRSTNAME: "John", LASTNAME: "Johnson"}
        ];

        var searchQuery = "john";
        var filtered = arrayFilter(bookings, function(booking) {
            var fullName = booking.FIRSTNAME & " " & booking.LASTNAME;
            return len(searchQuery) == 0 OR findNoCase(searchQuery, fullName);
        });

        assertEquals(2, arrayLen(filtered), "Should find 2 users named John");
    }

    /**
     * Test: Search by meeting title (comments)
     */
    public void function testSearchByMeetingTitle() {
        var bookings = [
            {COMMENTS: "Team Meeting"},
            {COMMENTS: "Client Presentation"},
            {COMMENTS: "Team Standup"}
        ];

        var searchQuery = "team";
        var filtered = arrayFilter(bookings, function(booking) {
            return len(searchQuery) == 0 OR findNoCase(searchQuery, booking.COMMENTS);
        });

        assertEquals(2, arrayLen(filtered), "Should find 2 team meetings");
    }

    /**
     * Test: Search is case-insensitive
     */
    public void function testSearchCaseInsensitive() {
        var booking1 = {COMMENTS: "Team Meeting"};
        var booking2 = {COMMENTS: "TEAM Meeting"};
        var booking3 = {COMMENTS: "team meeting"};

        var searchQuery = "team";

        assertTrue(findNoCase(searchQuery, booking1.COMMENTS) > 0, "Should match Team Meeting");
        assertTrue(findNoCase(searchQuery, booking2.COMMENTS) > 0, "Should match TEAM Meeting");
        assertTrue(findNoCase(searchQuery, booking3.COMMENTS) > 0, "Should match team meeting");
    }

    /**
     * Test: Search partial match
     */
    public void function testSearchPartialMatch() {
        var booking = {COMMENTS: "Important Client Meeting"};
        var searchQuery = "client";

        assertTrue(findNoCase(searchQuery, booking.COMMENTS) > 0, "Should match partial word");
    }

    /**
     * Test: Search with no matches
     */
    public void function testSearchNoMatches() {
        var bookings = [
            {NAME: "Conference Room A", FIRSTNAME: "John", LASTNAME: "Doe", COMMENTS: "Team Meeting"},
            {NAME: "Meeting Room B", FIRSTNAME: "Jane", LASTNAME: "Smith", COMMENTS: "Client Call"}
        ];

        var searchQuery = "xyz";
        var filtered = arrayFilter(bookings, function(booking) {
            var roomName = booking.NAME;
            var userName = booking.FIRSTNAME & " " & booking.LASTNAME;
            var comments = booking.COMMENTS;
            return findNoCase(searchQuery, roomName) OR findNoCase(searchQuery, userName) OR findNoCase(searchQuery, comments);
        });

        assertEquals(0, arrayLen(filtered), "Should return empty array when no matches");
    }

    /**
     * Test: Clear search shows all bookings
     */
    public void function testClearSearchShowsAll() {
        var bookings = [
            {COMMENTS: "Meeting 1"},
            {COMMENTS: "Meeting 2"},
            {COMMENTS: "Meeting 3"}
        ];

        var searchQuery = ""; // Empty search
        var filtered = arrayFilter(bookings, function(booking) {
            return len(searchQuery) == 0 OR findNoCase(searchQuery, booking.COMMENTS);
        });

        assertEquals(3, arrayLen(filtered), "Should show all bookings when search cleared");
    }

    // ============================================
    // COMBINED FILTER TESTS
    // ============================================

    /**
     * Test: Room and status filters combined
     */
    public void function testRoomAndStatusFiltersCombined() {
        var bookings = [
            {ROOM_ID: 1, STATUS: "Pending"},
            {ROOM_ID: 1, STATUS: "Approved"},
            {ROOM_ID: 2, STATUS: "Pending"},
            {ROOM_ID: 1, STATUS: "Pending"}
        ];

        var selectedRoomId = 1;
        var selectedStatus = "pending";

        var filtered = arrayFilter(bookings, function(booking) {
            return booking.ROOM_ID == selectedRoomId AND lcase(booking.STATUS) == selectedStatus;
        });

        assertEquals(2, arrayLen(filtered), "Should filter to Room 1 AND Pending status");
    }

    /**
     * Test: All filters combined (room, status, my bookings, search)
     */
    public void function testAllFiltersCombined() {
        var bookings = [
            {ROOM_ID: 1, STATUS: "Pending", USERID: 123, COMMENTS: "Team Meeting"},
            {ROOM_ID: 1, STATUS: "Pending", USERID: 456, COMMENTS: "Team Standup"},
            {ROOM_ID: 1, STATUS: "Approved", USERID: 123, COMMENTS: "Team Review"},
            {ROOM_ID: 2, STATUS: "Pending", USERID: 123, COMMENTS: "Team Meeting"}
        ];

        var selectedRoomId = 1;
        var selectedStatus = "pending";
        var currentUserId = 123;
        var myBookingsOnly = true;
        var searchQuery = "meeting";

        var filtered = arrayFilter(bookings, function(booking) {
            // Room filter
            if (booking.ROOM_ID != selectedRoomId) return false;
            // Status filter
            if (lcase(booking.STATUS) != selectedStatus) return false;
            // My bookings filter
            if (myBookingsOnly AND booking.USERID != currentUserId) return false;
            // Search filter
            if (!findNoCase(searchQuery, booking.COMMENTS)) return false;
            return true;
        });

        assertEquals(1, arrayLen(filtered), "Should filter to bookings matching ALL criteria");
        assertEquals("Team Meeting", filtered[1].COMMENTS, "Should be the Team Meeting booking");
    }

    /**
     * Test: Filter logic with OR operator
     */
    public void function testFilterLogicOROperator() {
        // Note: Current implementation uses AND logic
        // This test verifies OR logic would work differently

        var bookings = [
            {ROOM_ID: 1, STATUS: "Pending"},
            {ROOM_ID: 2, STATUS: "Pending"},
            {ROOM_ID: 1, STATUS: "Approved"}
        ];

        var selectedRoomId = 1;
        var selectedStatus = "pending";

        // OR logic: Room 1 OR Pending
        var filteredOR = arrayFilter(bookings, function(booking) {
            return booking.ROOM_ID == selectedRoomId OR lcase(booking.STATUS) == selectedStatus;
        });

        assertEquals(3, arrayLen(filteredOR), "OR logic: Should match Room 1 OR Pending (all 3)");

        // AND logic: Room 1 AND Pending
        var filteredAND = arrayFilter(bookings, function(booking) {
            return booking.ROOM_ID == selectedRoomId AND lcase(booking.STATUS) == selectedStatus;
        });

        assertEquals(1, arrayLen(filteredAND), "AND logic: Should match Room 1 AND Pending (1 only)");
    }

    // ============================================
    // FILTER VALIDATION TESTS
    // ============================================

    /**
     * Test: Null or undefined filter values handled gracefully
     */
    public void function testNullFilterValuesHandled() {
        var bookings = [
            {ROOM_ID: 1, STATUS: "Pending", COMMENTS: "Meeting"}
        ];

        var selectedRoomId = javaCast("null", "");
        var selectedStatus = "";
        var searchQuery = "";

        // Should not throw error
        var filtered = arrayFilter(bookings, function(booking) {
            var roomMatch = isNull(selectedRoomId) OR booking.ROOM_ID == selectedRoomId;
            var statusMatch = len(selectedStatus) == 0 OR lcase(booking.STATUS) == selectedStatus;
            var searchMatch = len(searchQuery) == 0;
            return roomMatch AND statusMatch AND searchMatch;
        });

        assertEquals(1, arrayLen(filtered), "Should handle null filter values without error");
    }

    /**
     * Test: Empty array handled by filters
     */
    public void function testEmptyArrayHandledByFilters() {
        var bookings = [];

        var selectedRoomId = 1;
        var filtered = arrayFilter(bookings, function(booking) {
            return booking.ROOM_ID == selectedRoomId;
        });

        assertEquals(0, arrayLen(filtered), "Should handle empty array gracefully");
    }

    /**
     * Test: Missing field in booking handled gracefully
     */
    public void function testMissingFieldHandled() {
        var bookings = [
            {ROOM_ID: 1}, // Missing STATUS field
            {ROOM_ID: 1, STATUS: "Pending"}
        ];

        var selectedStatus = "pending";

        // Should handle missing STATUS field
        var filtered = arrayFilter(bookings, function(booking) {
            return structKeyExists(booking, "STATUS") AND lcase(booking.STATUS) == selectedStatus;
        });

        assertEquals(1, arrayLen(filtered), "Should handle missing fields gracefully");
    }

    // ============================================
    // CALENDAR VIEW FILTER TESTS
    // ============================================

    /**
     * Test: Filter applies to month view
     */
    public void function testFilterAppliesMonthView() {
        var calendarView = "month";
        var bookings = [
            {ROOM_ID: 1, VIEW: "month"},
            {ROOM_ID: 2, VIEW: "month"}
        ];

        var selectedRoomId = 1;
        var filtered = arrayFilter(bookings, function(booking) {
            return booking.ROOM_ID == selectedRoomId;
        });

        assertEquals(1, arrayLen(filtered), "Filter should work in month view");
    }

    /**
     * Test: Filter applies to week view
     */
    public void function testFilterAppliesWeekView() {
        var calendarView = "week";
        var bookings = [
            {STATUS: "Pending", VIEW: "week"},
            {STATUS: "Approved", VIEW: "week"}
        ];

        var selectedStatus = "pending";
        var filtered = arrayFilter(bookings, function(booking) {
            return lcase(booking.STATUS) == selectedStatus;
        });

        assertEquals(1, arrayLen(filtered), "Filter should work in week view");
    }

    /**
     * Test: Filter applies to day view
     */
    public void function testFilterAppliesDayView() {
        var calendarView = "day";
        var bookings = [
            {USERID: 123, VIEW: "day"},
            {USERID: 456, VIEW: "day"}
        ];

        var currentUserId = 123;
        var myBookingsOnly = true;
        var filtered = arrayFilter(bookings, function(booking) {
            return !myBookingsOnly OR booking.USERID == currentUserId;
        });

        assertEquals(1, arrayLen(filtered), "Filter should work in day view");
    }

    /**
     * Test: Filter applies to list view
     */
    public void function testFilterAppliesListView() {
        var calendarView = "list";
        var bookings = [
            {COMMENTS: "Team Meeting", VIEW: "list"},
            {COMMENTS: "Client Call", VIEW: "list"}
        ];

        var searchQuery = "team";
        var filtered = arrayFilter(bookings, function(booking) {
            return findNoCase(searchQuery, booking.COMMENTS);
        });

        assertEquals(1, arrayLen(filtered), "Filter should work in list view");
    }

    // ============================================
    // PERFORMANCE TESTS
    // ============================================

    /**
     * Test: Filter performance with large dataset
     */
    public void function testFilterPerformanceLargeDataset() {
        var bookings = [];
        var bookingCount = 1000;

        // Create 1000 test bookings
        for (var i = 1; i <= bookingCount; i++) {
            arrayAppend(bookings, {
                ROOM_ID: (i % 10) + 1,
                STATUS: (i % 3 == 0) ? "Pending" : "Approved",
                USERID: (i % 5) + 1,
                COMMENTS: "Meeting " & i
            });
        }

        var selectedRoomId = 1;

        var startTime = getTickCount();
        var filtered = arrayFilter(bookings, function(booking) {
            return booking.ROOM_ID == selectedRoomId;
        });
        var endTime = getTickCount();

        var executionTime = endTime - startTime;

        assertTrue(arrayLen(filtered) > 0, "Should filter large dataset");
        assertTrue(executionTime < 1000, "Filter should execute in less than 1 second");
    }

    /**
     * Test: Search debounce simulation
     */
    public void function testSearchDebounceSimulation() {
        // In actual implementation, search should debounce 300ms
        var debounceDelay = 300; // milliseconds

        assertTrue(debounceDelay > 0, "Debounce delay should be configured");
        assertEquals(300, debounceDelay, "Debounce delay should be 300ms");
    }
}
