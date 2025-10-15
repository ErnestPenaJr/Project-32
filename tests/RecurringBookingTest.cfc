component extends="mxunit.framework.TestCase" {

    variables.recurringBooking = "";

    /**
     * Setup - runs before each test
     */
    public void function setUp() {
        variables.recurringBooking = createObject("component", "components.RecurringBooking").init();
    }

    /**
     * Teardown - runs after each test
     */
    public void function tearDown() {
        // Clean up any test data if needed
    }

    /**
     * Test: System settings retrieval
     */
    public void function testGetSystemSettings() {
        var settings = variables.recurringBooking.getSystemSettings();

        // Assert settings structure
        assertTrue(isStruct(settings), "Settings should be a struct");
        assertTrue(structKeyExists(settings, "RECURRING_SYSTEM_ENABLED"), "Should have RECURRING_SYSTEM_ENABLED setting");
        assertTrue(structKeyExists(settings, "MAX_RECURRING_OCCURRENCES"), "Should have MAX_RECURRING_OCCURRENCES setting");
        assertTrue(structKeyExists(settings, "MAX_RECURRING_MONTHS_AHEAD"), "Should have MAX_RECURRING_MONTHS_AHEAD setting");
    }

    /**
     * Test: Valid daily recurring pattern validation
     */
    public void function testValidateDailyPattern() {
        var pattern = {
            frequency = "DAILY",
            intervalCount = 1,
            endType = "OCCURRENCES",
            maxOccurrences = 10
        };

        var result = variables.recurringBooking.validateRecurringPattern(pattern);

        assertTrue(result.valid, "Valid daily pattern should pass validation");
        assertEquals("", result.message, "Valid pattern should have no error message");
    }

    /**
     * Test: Valid weekly recurring pattern validation
     */
    public void function testValidateWeeklyPattern() {
        var pattern = {
            frequency = "WEEKLY",
            intervalCount = 1,
            endType = "OCCURRENCES",
            maxOccurrences = 10,
            daysOfWeek = "MON,WED,FRI"
        };

        var result = variables.recurringBooking.validateRecurringPattern(pattern);

        assertTrue(result.valid, "Valid weekly pattern should pass validation");
    }

    /**
     * Test: Weekly pattern without days of week should fail
     */
    public void function testValidateWeeklyPatternWithoutDays() {
        var pattern = {
            frequency = "WEEKLY",
            intervalCount = 1,
            endType = "OCCURRENCES",
            maxOccurrences = 10
        };

        var result = variables.recurringBooking.validateRecurringPattern(pattern);

        assertFalse(result.valid, "Weekly pattern without days should fail validation");
        assertTrue(len(result.message) > 0, "Should have error message");
    }

    /**
     * Test: Invalid frequency should fail
     */
    public void function testValidateInvalidFrequency() {
        var pattern = {
            frequency = "INVALID",
            intervalCount = 1,
            endType = "OCCURRENCES",
            maxOccurrences = 10
        };

        var result = variables.recurringBooking.validateRecurringPattern(pattern);

        assertFalse(result.valid, "Invalid frequency should fail validation");
        assertTrue(find("frequency", result.message) > 0, "Error message should mention frequency");
    }

    /**
     * Test: Exceeding max occurrences should fail
     */
    public void function testValidateExceedMaxOccurrences() {
        var pattern = {
            frequency = "DAILY",
            intervalCount = 1,
            endType = "OCCURRENCES",
            maxOccurrences = 1000
        };

        var result = variables.recurringBooking.validateRecurringPattern(pattern);

        assertFalse(result.valid, "Exceeding max occurrences should fail validation");
        assertTrue(find("exceed", result.message) > 0, "Error message should mention exceeding limit");
    }

    /**
     * Test: Generate daily recurring dates
     */
    public void function testGenerateDailyDates() {
        var startDate = createDateTime(2025, 10, 15, 10, 0, 0);
        var endDate = createDateTime(2025, 10, 15, 11, 0, 0);
        var pattern = {
            frequency = "DAILY",
            intervalCount = 1,
            endType = "OCCURRENCES",
            maxOccurrences = 5
        };

        var dates = variables.recurringBooking.generateRecurringDates(startDate, endDate, pattern);

        assertEquals(5, arrayLen(dates), "Should generate 5 daily occurrences");
        assertEquals(1, dates[1].instanceNumber, "First instance should be numbered 1");
        assertEquals(5, dates[5].instanceNumber, "Last instance should be numbered 5");

        // Check date intervals
        var daysBetween = dateDiff("d", dates[1].startDate, dates[2].startDate);
        assertEquals(1, daysBetween, "Daily pattern should have 1 day between occurrences");
    }

    /**
     * Test: Generate weekly recurring dates
     */
    public void function testGenerateWeeklyDates() {
        var startDate = createDateTime(2025, 10, 13, 10, 0, 0); // Monday
        var endDate = createDateTime(2025, 10, 13, 11, 0, 0);
        var pattern = {
            frequency = "WEEKLY",
            intervalCount = 1,
            endType = "OCCURRENCES",
            maxOccurrences = 4,
            daysOfWeek = "MON,WED"
        };

        var dates = variables.recurringBooking.generateRecurringDates(startDate, endDate, pattern);

        assertEquals(4, arrayLen(dates), "Should generate 4 occurrences (2 days per week for 2 weeks)");

        // Verify days of week
        for (var dateInfo in dates) {
            var dayOfWeek = dayOfWeekAsString(dayOfWeek(dateInfo.startDate));
            assertTrue(
                dayOfWeek == "Monday" || dayOfWeek == "Wednesday",
                "Generated dates should only be Monday or Wednesday"
            );
        }
    }

    /**
     * Test: Generate monthly recurring dates
     */
    public void function testGenerateMonthlyDates() {
        var startDate = createDateTime(2025, 10, 15, 10, 0, 0);
        var endDate = createDateTime(2025, 10, 15, 11, 0, 0);
        var pattern = {
            frequency = "MONTHLY",
            intervalCount = 1,
            endType = "OCCURRENCES",
            maxOccurrences = 3
        };

        var dates = variables.recurringBooking.generateRecurringDates(startDate, endDate, pattern);

        assertEquals(3, arrayLen(dates), "Should generate 3 monthly occurrences");

        // Check month intervals
        var monthsBetween = dateDiff("m", dates[1].startDate, dates[2].startDate);
        assertEquals(1, monthsBetween, "Monthly pattern should have 1 month between occurrences");
    }

    /**
     * Test: Generate dates with end date
     */
    public void function testGenerateDatesWithEndDate() {
        var startDate = createDateTime(2025, 10, 15, 10, 0, 0);
        var endDate = createDateTime(2025, 10, 15, 11, 0, 0);
        var pattern = {
            frequency = "DAILY",
            intervalCount = 1,
            endType = "DATE",
            endDate = createDateTime(2025, 10, 20, 23, 59, 59)
        };

        var dates = variables.recurringBooking.generateRecurringDates(startDate, endDate, pattern);

        assertTrue(arrayLen(dates) <= 6, "Should generate at most 6 occurrences (Oct 15-20)");

        // All dates should be before end date
        for (var dateInfo in dates) {
            assertTrue(
                dateInfo.startDate <= pattern.endDate,
                "All generated dates should be before or on end date"
            );
        }
    }

    /**
     * Test: Duration is preserved across instances
     */
    public void function testDurationPreservation() {
        var startDate = createDateTime(2025, 10, 15, 10, 0, 0);
        var endDate = createDateTime(2025, 10, 15, 12, 30, 0); // 2.5 hours
        var pattern = {
            frequency = "DAILY",
            intervalCount = 1,
            endType = "OCCURRENCES",
            maxOccurrences = 3
        };

        var dates = variables.recurringBooking.generateRecurringDates(startDate, endDate, pattern);

        // Check duration for each instance
        for (var dateInfo in dates) {
            var duration = dateDiff("n", dateInfo.startDate, dateInfo.endDate);
            assertEquals(150, duration, "Each instance should have 150 minutes (2.5 hours) duration");
        }
    }

    /**
     * Test: Bi-weekly pattern (interval = 2)
     */
    public void function testBiWeeklyPattern() {
        var startDate = createDateTime(2025, 10, 13, 10, 0, 0); // Monday
        var endDate = createDateTime(2025, 10, 13, 11, 0, 0);
        var pattern = {
            frequency = "WEEKLY",
            intervalCount = 2, // Every 2 weeks
            endType = "OCCURRENCES",
            maxOccurrences = 4,
            daysOfWeek = "MON"
        };

        var dates = variables.recurringBooking.generateRecurringDates(startDate, endDate, pattern);

        assertEquals(4, arrayLen(dates), "Should generate 4 occurrences");

        // Check 2-week intervals
        if (arrayLen(dates) >= 2) {
            var weeksBetween = dateDiff("ww", dates[1].startDate, dates[2].startDate);
            assertEquals(2, weeksBetween, "Should have 2 weeks between occurrences");
        }
    }

    /**
     * Test: Check recurring conflicts detection
     */
    public void function testCheckRecurringConflicts() {
        // Note: This test would require database setup with test data
        // For now, we'll test the structure

        var roomId = 1;
        var dates = [
            {
                startDate = createDateTime(2025, 10, 15, 10, 0, 0),
                endDate = createDateTime(2025, 10, 15, 11, 0, 0),
                instanceNumber = 1
            }
        ];

        var conflicts = variables.recurringBooking.checkRecurringConflicts(roomId, dates);

        assertTrue(isArray(conflicts), "Should return an array");
    }

    /**
     * Test: Interval count validation
     */
    public void function testValidateIntervalCount() {
        var pattern = {
            frequency = "DAILY",
            intervalCount = 0, // Invalid
            endType = "OCCURRENCES",
            maxOccurrences = 10
        };

        var result = variables.recurringBooking.validateRecurringPattern(pattern);

        assertFalse(result.valid, "Zero interval count should fail validation");
    }

    /**
     * Test: Missing end type should fail
     */
    public void function testValidateMissingEndType() {
        var pattern = {
            frequency = "DAILY",
            intervalCount = 1
            // Missing endType
        };

        var result = variables.recurringBooking.validateRecurringPattern(pattern);

        assertFalse(result.valid, "Missing end type should fail validation");
    }

    /**
     * Test: End date too far in future should fail
     */
    public void function testValidateEndDateTooFar() {
        var pattern = {
            frequency = "DAILY",
            intervalCount = 1,
            endType = "DATE",
            endDate = dateAdd("y", 2, now()) // 2 years in future
        };

        var result = variables.recurringBooking.validateRecurringPattern(pattern);

        assertFalse(result.valid, "End date too far in future should fail validation");
        assertTrue(find("months ahead", result.message) > 0, "Error should mention months ahead limit");
    }
}
