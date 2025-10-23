<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>DoCM Room Reservation - Unit Test Runner</title>
    <link href="../node_modules/bootstrap/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="../assets/fontawesome-pro-5.15.4/css/all.css" rel="stylesheet">
    <style>
        body {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 40px 0;
        }
        .test-container {
            background: white;
            border-radius: 15px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.2);
            padding: 30px;
            max-width: 1200px;
            margin: 0 auto;
        }
        .test-result {
            padding: 15px;
            margin: 10px 0;
            border-radius: 8px;
            border-left: 4px solid;
        }
        .test-result.success {
            background: #d4edda;
            border-color: #28a745;
        }
        .test-result.failure {
            background: #f8d7da;
            border-color: #dc3545;
        }
        .test-suite-header {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
        .summary-card {
            background: #f8f9fa;
            padding: 20px;
            border-radius: 8px;
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="test-container">
            <div class="text-center mb-4">
                <h1><i class="fas fa-vial me-2"></i>Unit Test Runner</h1>
                <p class="text-muted">DoCM Room Reservation System - Test Suite</p>
            </div>

            <cfoutput>
                <cftry>
                    <!--- Initialize test results --->
                    <cfset totalTests = 0>
                    <cfset passedTests = 0>
                    <cfset failedTests = 0>
                    <cfset allResults = []>

                    <!--- Run Recurring Booking Tests --->
                    <cfset recurringTests = createObject("component", "unit.RecurringBookingTests")>
                    <cfset recurringResults = recurringTests.runAllTests()>
                    <cfset arrayAppend(allResults, {
                        suiteName = "Recurring Booking Tests",
                        tests = recurringResults
                    })>

                    <!--- Run Edit Booking Tests --->
                    <cfset editTests = createObject("component", "unit.EditBookingTests")>
                    <cfset editResults = editTests.runAllTests()>
                    <cfset arrayAppend(allResults, {
                        suiteName = "Edit Booking Tests",
                        tests = editResults
                    })>

                    <!--- Calculate totals --->
                    <cfloop array="#allResults#" index="suite">
                        <cfloop array="#suite.tests#" index="test">
                            <cfset totalTests++>
                            <cfif test.result.success>
                                <cfset passedTests++>
                            <cfelse>
                                <cfset failedTests++>
                            </cfif>
                        </cfloop>
                    </cfloop>

                    <cfset passRate = totalTests gt 0 ? round((passedTests / totalTests) * 100) : 0>

                    <!--- Summary Card --->
                    <div class="summary-card">
                        <h3><i class="fas fa-chart-bar me-2"></i>Test Summary</h3>
                        <div class="row text-center mt-3">
                            <div class="col-md-3">
                                <h2 class="text-primary">#totalTests#</h2>
                                <p class="text-muted mb-0">Total Tests</p>
                            </div>
                            <div class="col-md-3">
                                <h2 class="text-success">#passedTests#</h2>
                                <p class="text-muted mb-0">Passed</p>
                            </div>
                            <div class="col-md-3">
                                <h2 class="text-danger">#failedTests#</h2>
                                <p class="text-muted mb-0">Failed</p>
                            </div>
                            <div class="col-md-3">
                                <h2 class="text-info">#passRate#%</h2>
                                <p class="text-muted mb-0">Pass Rate</p>
                            </div>
                        </div>
                    </div>

                    <!--- Display Test Results by Suite --->
                    <cfloop array="#allResults#" index="suite">
                        <div class="test-suite-header">
                            <h4><i class="fas fa-flask me-2"></i>#suite.suiteName#</h4>
                        </div>

                        <cfloop array="#suite.tests#" index="test">
                            <div class="test-result #test.result.success ? 'success' : 'failure'#">
                                <div class="d-flex justify-content-between align-items-start">
                                    <div>
                                        <h5>
                                            <i class="fas fa-#test.result.success ? 'check-circle text-success' : 'times-circle text-danger'# me-2"></i>
                                            #test.testName#
                                        </h5>
                                        <p class="mb-0">#test.result.message#</p>
                                        <cfif structKeyExists(test.result, "data")>
                                            <div class="mt-2">
                                                <small class="text-muted">
                                                    <strong>Additional Data:</strong>
                                                    <pre class="mb-0">#serializeJSON(test.result.data, true)#</pre>
                                                </small>
                                            </div>
                                        </cfif>
                                    </div>
                                    <span class="badge bg-#test.result.success ? 'success' : 'danger'# fs-5">
                                        #test.result.success ? 'PASS' : 'FAIL'#
                                    </span>
                                </div>
                            </div>
                        </cfloop>
                    </cfloop>

                    <!--- Overall Result --->
                    <div class="alert alert-#failedTests eq 0 ? 'success' : 'warning'# mt-4">
                        <h4>
                            <i class="fas fa-#failedTests eq 0 ? 'check-circle' : 'exclamation-triangle'# me-2"></i>
                            #failedTests eq 0 ? 'All Tests Passed!' : 'Some Tests Failed'#
                        </h4>
                        <p class="mb-0">
                            #failedTests eq 0 ? 'Congratulations! All unit tests completed successfully.' : 'Please review the failed tests above and fix the issues.'#
                        </p>
                    </div>

                    <cfcatch type="any">
                        <div class="alert alert-danger">
                            <h4><i class="fas fa-exclamation-circle me-2"></i>Test Runner Error</h4>
                            <p><strong>Error:</strong> #cfcatch.message#</p>
                            <p><strong>Detail:</strong> #cfcatch.detail#</p>
                            <p><strong>Type:</strong> #cfcatch.type#</p>
                        </div>
                    </cfcatch>
                </cftry>
            </cfoutput>

            <div class="text-center mt-4">
                <a href="../index.html" class="btn btn-primary">
                    <i class="fas fa-home me-2"></i>Return to Application
                </a>
                <button onclick="location.reload()" class="btn btn-outline-primary">
                    <i class="fas fa-redo me-2"></i>Re-run Tests
                </button>
            </div>
        </div>
    </div>

    <script src="../node_modules/jquery/dist/jquery.min.js"></script>
    <script src="../node_modules/bootstrap/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
