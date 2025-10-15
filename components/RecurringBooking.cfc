component {
    // Database configuration
    property name="dbServer";
    property name="dbUser";
    property name="dbPass";
    property name="dbSchema";

    /**
     * Constructor - Initialize database configuration
     */
    public function init() {
        // Determine environment and set database credentials
        if (listFirst(CGI.SERVER_NAME, '.') EQ 'cmapps') {
            variables.dbServer = "inside2_docmp";
            variables.dbUser = "CONFROOM_USER";
            variables.dbPass = "1DOCMAU4CNFRM6";
            variables.dbSchema = "CONFROOM";
        } else if (listFirst(CGI.SERVER_NAME, '.') EQ 's-cmapps') {
            variables.dbServer = "inside2_docms";
            variables.dbUser = "CONFROOM";
            variables.dbPass = "1DOCMOA4CNFRM3";
            variables.dbSchema = "CONFROOM";
        } else {
            variables.dbServer = "inside2_docmd";
            variables.dbUser = "CONFROOM";
            variables.dbPass = "1DOCMOA4CNFRM3";
            variables.dbSchema = "CONFROOM";
        }

        return this;
    }

    /**
     * Get system settings for recurring bookings
     * @return struct System settings
     */
    public struct function getSystemSettings() {
        var qSettings = queryExecute("
            SELECT SETTING_KEY, SETTING_VALUE, SETTING_TYPE
            FROM #variables.dbSchema#.SYSTEM_SETTINGS
            WHERE SETTING_KEY LIKE 'RECURRING%' OR SETTING_KEY LIKE 'MAX_RECURRING%'
        ", {}, {
            datasource = variables.dbServer,
            username = variables.dbUser,
            password = variables.dbPass
        });

        var settings = {};
        for (var row in qSettings) {
            var key = row.SETTING_KEY;
            var value = row.SETTING_VALUE;
            var type = row.SETTING_TYPE;

            // Convert value based on type
            if (type == 'BOOLEAN') {
                settings[key] = (value == 'Y' || value == 'true' || value == '1');
            } else if (type == 'NUMBER') {
                settings[key] = val(value);
            } else {
                settings[key] = value;
            }
        }

        return settings;
    }

    /**
     * Validate recurring pattern against system settings
     * @param struct pattern The recurring pattern to validate
     * @return struct {valid: boolean, message: string}
     */
    public struct function validateRecurringPattern(required struct pattern) {
        var settings = getSystemSettings();
        var result = {valid: true, message: ""};

        // Check if recurring system is enabled
        if (!structKeyExists(settings, "RECURRING_SYSTEM_ENABLED") || !settings.RECURRING_SYSTEM_ENABLED) {
            result.valid = false;
            result.message = "Recurring bookings are currently disabled by the administrator";
            return result;
        }

        // Validate frequency
        if (!structKeyExists(pattern, "frequency") || !listFindNoCase("DAILY,WEEKLY,MONTHLY", pattern.frequency)) {
            result.valid = false;
            result.message = "Invalid frequency. Must be DAILY, WEEKLY, or MONTHLY";
            return result;
        }

        // Validate interval count
        if (!structKeyExists(pattern, "intervalCount") || val(pattern.intervalCount) < 1) {
            result.valid = false;
            result.message = "Interval count must be at least 1";
            return result;
        }

        // Validate end type
        if (!structKeyExists(pattern, "endType") || !listFindNoCase("DATE,OCCURRENCES", pattern.endType)) {
            result.valid = false;
            result.message = "End type must be DATE or OCCURRENCES";
            return result;
        }

        // Validate based on end type
        if (pattern.endType == "OCCURRENCES") {
            if (!structKeyExists(pattern, "maxOccurrences") || val(pattern.maxOccurrences) < 1) {
                result.valid = false;
                result.message = "Maximum occurrences must be at least 1";
                return result;
            }

            var maxAllowed = structKeyExists(settings, "MAX_RECURRING_OCCURRENCES") ? settings.MAX_RECURRING_OCCURRENCES : 52;
            if (val(pattern.maxOccurrences) > maxAllowed) {
                result.valid = false;
                result.message = "Maximum occurrences cannot exceed #maxAllowed#";
                return result;
            }
        } else if (pattern.endType == "DATE") {
            if (!structKeyExists(pattern, "endDate") || !isDate(pattern.endDate)) {
                result.valid = false;
                result.message = "Valid end date is required";
                return result;
            }

            var maxMonthsAhead = structKeyExists(settings, "MAX_RECURRING_MONTHS_AHEAD") ? settings.MAX_RECURRING_MONTHS_AHEAD : 6;
            var maxEndDate = dateAdd("m", maxMonthsAhead, now());

            if (parseDateTime(pattern.endDate) > maxEndDate) {
                result.valid = false;
                result.message = "End date cannot be more than #maxMonthsAhead# months ahead";
                return result;
            }
        }

        // Validate days of week for weekly patterns
        if (pattern.frequency == "WEEKLY") {
            if (!structKeyExists(pattern, "daysOfWeek") || len(trim(pattern.daysOfWeek)) == 0) {
                result.valid = false;
                result.message = "Days of week are required for weekly recurring bookings";
                return result;
            }
        }

        return result;
    }

    /**
     * Generate recurring booking dates based on pattern
     * @param date startDate The initial start date/time
     * @param date endDate The initial end date/time
     * @param struct pattern The recurring pattern
     * @return array Array of {startDate, endDate} structs
     */
    public array function generateRecurringDates(required date startDate, required date endDate, required struct pattern) {
        var dates = [];
        var currentDate = arguments.startDate;
        var duration = dateDiff("n", arguments.startDate, arguments.endDate); // Duration in minutes
        var count = 0;
        var maxDate = pattern.endType == "DATE" ? parseDateTime(pattern.endDate) : dateAdd("y", 2, now()); // 2 year limit
        var maxOccurrences = pattern.endType == "OCCURRENCES" ? val(pattern.maxOccurrences) : 365; // 365 limit for date-based

        while (count < maxOccurrences && currentDate <= maxDate) {
            // For weekly patterns, check if current day matches selected days
            if (pattern.frequency == "WEEKLY" && len(trim(pattern.daysOfWeek)) > 0) {
                var dayOfWeek = uCase(dayOfWeekAsString(dayOfWeek(currentDate)));
                var shortDay = left(dayOfWeek, 3);

                if (listFindNoCase(pattern.daysOfWeek, shortDay)) {
                    var instanceEnd = dateAdd("n", duration, currentDate);
                    arrayAppend(dates, {
                        startDate = currentDate,
                        endDate = instanceEnd,
                        instanceNumber = count + 1
                    });
                    count++;
                }
            } else {
                // For daily and monthly patterns, add every occurrence
                var instanceEnd = dateAdd("n", duration, currentDate);
                arrayAppend(dates, {
                    startDate = currentDate,
                    endDate = instanceEnd,
                    instanceNumber = count + 1
                });
                count++;
            }

            // Calculate next occurrence based on frequency
            if (pattern.frequency == "DAILY") {
                currentDate = dateAdd("d", val(pattern.intervalCount), currentDate);
            } else if (pattern.frequency == "WEEKLY") {
                currentDate = dateAdd("d", 1, currentDate); // Increment by 1 day for weekly to check all days
                // If we've gone through a full week cycle, jump to next interval
                if (dayOfWeek(currentDate) == dayOfWeek(arguments.startDate)) {
                    currentDate = dateAdd("ww", val(pattern.intervalCount), currentDate);
                }
            } else if (pattern.frequency == "MONTHLY") {
                currentDate = dateAdd("m", val(pattern.intervalCount), currentDate);
            }
        }

        return dates;
    }

    /**
     * Check for conflicts across recurring dates
     * @param numeric roomId The room ID
     * @param array dates Array of date structs
     * @return array Array of conflicts {date, conflictingBookingId}
     */
    public array function checkRecurringConflicts(required numeric roomId, required array dates) {
        var conflicts = [];

        for (var dateInfo in arguments.dates) {
            var qConflicts = queryExecute("
                SELECT BOOKING_ID, START_TIME, END_TIME
                FROM #variables.dbSchema#.BOOKINGS
                WHERE ROOM_ID = :roomId
                AND STATUS IN ('Pending', 'Approved', 'Confirmed')
                AND (
                    (START_TIME < :endTime AND END_TIME > :startTime)
                )
            ", {
                roomId = {value = arguments.roomId, cfsqltype = "cf_sql_numeric"},
                startTime = {value = dateInfo.startDate, cfsqltype = "cf_sql_timestamp"},
                endTime = {value = dateInfo.endDate, cfsqltype = "cf_sql_timestamp"}
            }, {
                datasource = variables.dbServer,
                username = variables.dbUser,
                password = variables.dbPass
            });

            if (qConflicts.recordCount > 0) {
                arrayAppend(conflicts, {
                    startDate = dateInfo.startDate,
                    endDate = dateInfo.endDate,
                    instanceNumber = dateInfo.instanceNumber,
                    conflictingBookingId = qConflicts.BOOKING_ID
                });
            }
        }

        return conflicts;
    }

    /**
     * Create a recurring booking series
     * @param struct bookingData Initial booking data
     * @param struct pattern Recurring pattern
     * @return struct {success: boolean, parentBookingId: number, instancesCreated: number, conflicts: array}
     */
    public struct function createRecurringBooking(required struct bookingData, required struct pattern) {
        var result = {
            success = false,
            parentBookingId = 0,
            instancesCreated = 0,
            conflicts = [],
            message = ""
        };

        try {
            // Validate pattern
            var validation = validateRecurringPattern(arguments.pattern);
            if (!validation.valid) {
                result.message = validation.message;
                return result;
            }

            // Generate all dates
            var dates = generateRecurringDates(
                parseDateTime(bookingData.startTime),
                parseDateTime(bookingData.endTime),
                arguments.pattern
            );

            // Check for conflicts
            var conflicts = checkRecurringConflicts(bookingData.roomId, dates);
            if (arrayLen(conflicts) > 0) {
                result.conflicts = conflicts;
                result.message = "Found #arrayLen(conflicts)# conflict(s) in the recurring series";
                return result;
            }

            // Create parent booking (first instance)
            var firstDate = dates[1];
            var parentBookingId = createSingleBooking(
                bookingData.userId,
                bookingData.roomId,
                firstDate.startDate,
                firstDate.endDate,
                bookingData.comments,
                true, // isRecurring
                0, // No parent for first instance
                1 // Instance number
            );

            if (parentBookingId == 0) {
                result.message = "Failed to create parent booking";
                return result;
            }

            result.parentBookingId = parentBookingId;
            result.instancesCreated = 1;

            // Create recurring pattern record
            createRecurringPattern(parentBookingId, arguments.pattern);

            // Create remaining instances
            for (var i = 2; i <= arrayLen(dates); i++) {
                var dateInfo = dates[i];
                var instanceId = createSingleBooking(
                    bookingData.userId,
                    bookingData.roomId,
                    dateInfo.startDate,
                    dateInfo.endDate,
                    bookingData.comments,
                    true, // isRecurring
                    parentBookingId, // Parent booking ID
                    i // Instance number
                );

                if (instanceId > 0) {
                    result.instancesCreated++;
                }
            }

            result.success = true;
            result.message = "Created #result.instancesCreated# recurring booking instances";

        } catch (any e) {
            result.message = "Error creating recurring booking: " & e.message;
            writeLog(file="recurring-bookings", text="Error creating recurring booking: #e.message# #e.detail#", type="error");
        }

        return result;
    }

    /**
     * Create a single booking instance (helper function)
     * @private
     */
    private numeric function createSingleBooking(
        required numeric userId,
        required numeric roomId,
        required date startTime,
        required date endTime,
        string comments = "",
        boolean isRecurring = false,
        numeric parentBookingId = 0,
        numeric instanceNumber = 1
    ) {
        var bookingId = 0;

        try {
            var qInsert = queryExecute("
                INSERT INTO #variables.dbSchema#.BOOKINGS (
                    USER_ID, ROOM_ID, START_TIME, END_TIME, COMMENTS,
                    STATUS, IS_RECURRING, PARENT_BOOKING_ID, SERIES_INSTANCE_NUMBER,
                    CREATED_AT
                ) VALUES (
                    :userId, :roomId, :startTime, :endTime, :comments,
                    'Pending', :isRecurring, :parentBookingId, :instanceNumber,
                    CURRENT_TIMESTAMP
                )
            ", {
                userId = {value = arguments.userId, cfsqltype = "cf_sql_numeric"},
                roomId = {value = arguments.roomId, cfsqltype = "cf_sql_numeric"},
                startTime = {value = arguments.startTime, cfsqltype = "cf_sql_timestamp"},
                endTime = {value = arguments.endTime, cfsqltype = "cf_sql_timestamp"},
                comments = {value = arguments.comments, cfsqltype = "cf_sql_varchar"},
                isRecurring = {value = arguments.isRecurring ? 'Y' : 'N', cfsqltype = "cf_sql_char"},
                parentBookingId = {value = arguments.parentBookingId == 0 ? javaCast("null", "") : arguments.parentBookingId, cfsqltype = "cf_sql_numeric", null = arguments.parentBookingId == 0},
                instanceNumber = {value = arguments.instanceNumber, cfsqltype = "cf_sql_numeric"}
            }, {
                datasource = variables.dbServer,
                username = variables.dbUser,
                password = variables.dbPass,
                result = "insertResult"
            });

            // Get the generated booking ID
            var qGetId = queryExecute("
                SELECT BOOKING_ID
                FROM #variables.dbSchema#.BOOKINGS
                WHERE USER_ID = :userId
                AND ROOM_ID = :roomId
                AND START_TIME = :startTime
                AND END_TIME = :endTime
                ORDER BY BOOKING_ID DESC
                FETCH FIRST 1 ROWS ONLY
            ", {
                userId = {value = arguments.userId, cfsqltype = "cf_sql_numeric"},
                roomId = {value = arguments.roomId, cfsqltype = "cf_sql_numeric"},
                startTime = {value = arguments.startTime, cfsqltype = "cf_sql_timestamp"},
                endTime = {value = arguments.endTime, cfsqltype = "cf_sql_timestamp"}
            }, {
                datasource = variables.dbServer,
                username = variables.dbUser,
                password = variables.dbPass
            });

            if (qGetId.recordCount > 0) {
                bookingId = qGetId.BOOKING_ID;
            }

        } catch (any e) {
            writeLog(file="recurring-bookings", text="Error creating single booking: #e.message#", type="error");
        }

        return bookingId;
    }

    /**
     * Create recurring pattern record (helper function)
     * @private
     */
    private void function createRecurringPattern(required numeric parentBookingId, required struct pattern) {
        queryExecute("
            INSERT INTO #variables.dbSchema#.RECURRING_PATTERNS (
                PARENT_BOOKING_ID, FREQUENCY, INTERVAL_COUNT,
                END_TYPE, END_DATE, MAX_OCCURRENCES, DAYS_OF_WEEK
            ) VALUES (
                :parentBookingId, :frequency, :intervalCount,
                :endType, :endDate, :maxOccurrences, :daysOfWeek
            )
        ", {
            parentBookingId = {value = arguments.parentBookingId, cfsqltype = "cf_sql_numeric"},
            frequency = {value = arguments.pattern.frequency, cfsqltype = "cf_sql_varchar"},
            intervalCount = {value = val(arguments.pattern.intervalCount), cfsqltype = "cf_sql_numeric"},
            endType = {value = arguments.pattern.endType, cfsqltype = "cf_sql_varchar"},
            endDate = {value = structKeyExists(arguments.pattern, "endDate") ? parseDateTime(arguments.pattern.endDate) : javaCast("null", ""), cfsqltype = "cf_sql_date", null = !structKeyExists(arguments.pattern, "endDate")},
            maxOccurrences = {value = structKeyExists(arguments.pattern, "maxOccurrences") ? val(arguments.pattern.maxOccurrences) : javaCast("null", ""), cfsqltype = "cf_sql_numeric", null = !structKeyExists(arguments.pattern, "maxOccurrences")},
            daysOfWeek = {value = structKeyExists(arguments.pattern, "daysOfWeek") ? arguments.pattern.daysOfWeek : javaCast("null", ""), cfsqltype = "cf_sql_varchar", null = !structKeyExists(arguments.pattern, "daysOfWeek")}
        }, {
            datasource = variables.dbServer,
            username = variables.dbUser,
            password = variables.dbPass
        });
    }

    /**
     * Get all instances in a recurring series
     * @param numeric parentBookingId The parent booking ID
     * @return query Query of all instances
     */
    public query function getSeriesInstances(required numeric parentBookingId) {
        return queryExecute("
            SELECT
                b.BOOKING_ID,
                b.USER_ID,
                b.ROOM_ID,
                b.START_TIME,
                b.END_TIME,
                b.COMMENTS,
                b.STATUS,
                b.SERIES_INSTANCE_NUMBER,
                r.ROOM_NAME,
                u.FIRST_NAME,
                u.LAST_NAME
            FROM #variables.dbSchema#.BOOKINGS b
            JOIN #variables.dbSchema#.ROOMS r ON b.ROOM_ID = r.ROOM_ID
            JOIN #variables.dbSchema#.USERS u ON b.USER_ID = u.USER_ID
            WHERE b.PARENT_BOOKING_ID = :parentBookingId
            OR b.BOOKING_ID = :parentBookingId
            ORDER BY b.SERIES_INSTANCE_NUMBER
        ", {
            parentBookingId = {value = arguments.parentBookingId, cfsqltype = "cf_sql_numeric"}
        }, {
            datasource = variables.dbServer,
            username = variables.dbUser,
            password = variables.dbPass
        });
    }

    /**
     * Cancel an entire recurring series
     * @param numeric parentBookingId The parent booking ID
     * @param numeric userId User performing the cancellation
     * @return struct {success: boolean, cancelled: number}
     */
    public struct function cancelRecurringSeries(required numeric parentBookingId, required numeric userId) {
        var result = {
            success = false,
            cancelled = 0,
            message = ""
        };

        try {
            queryExecute("
                UPDATE #variables.dbSchema#.BOOKINGS
                SET
                    STATUS = 'Cancelled',
                    UPDATED_AT = CURRENT_TIMESTAMP
                WHERE (PARENT_BOOKING_ID = :parentBookingId OR BOOKING_ID = :parentBookingId)
                AND STATUS != 'Cancelled'
            ", {
                parentBookingId = {value = arguments.parentBookingId, cfsqltype = "cf_sql_numeric"}
            }, {
                datasource = variables.dbServer,
                username = variables.dbUser,
                password = variables.dbPass,
                result = "updateResult"
            });

            result.cancelled = updateResult.recordCount;
            result.success = true;
            result.message = "Cancelled #result.cancelled# bookings in the series";

        } catch (any e) {
            result.message = "Error cancelling series: " & e.message;
            writeLog(file="recurring-bookings", text="Error cancelling recurring series: #e.message#", type="error");
        }

        return result;
    }
}
