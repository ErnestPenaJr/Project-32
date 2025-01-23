$(document).ready(function() {
    // Initialize charts
    let reservationTrendsChart, roomDistributionChart;
    
    // Dashboard time period
    let currentPeriod = 'daily';
    
    // Initialize the dashboard
    initializeDashboard();
    
    // Event listeners for period buttons
    $('#btnDaily, #btnWeekly, #btnMonthly').on('click', function() {
        const period = $(this).attr('id').replace('btn', '').toLowerCase();
        updatePeriod(period);
    });
    
    // Export button handler
    $('#btnExport').on('click', exportDashboard);
    
    function initializeDashboard() {
        initializeCharts();
        loadDashboardData();
        setupRefreshInterval();
    }
    
    function initializeCharts() {
        // Reservation Trends Chart
        const trendsCtx = document.getElementById('reservationTrendsChart').getContext('2d');
        reservationTrendsChart = new Chart(trendsCtx, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'Reservations',
                    data: [],
                    borderColor: '#007bff',
                    tension: 0.1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'top',
                    }
                }
            }
        });
        
        // Room Distribution Chart
        const distributionCtx = document.getElementById('roomDistributionChart').getContext('2d');
        roomDistributionChart = new Chart(distributionCtx, {
            type: 'doughnut',
            data: {
                labels: [],
                datasets: [{
                    data: [],
                    backgroundColor: [
                        '#007bff',
                        '#28a745',
                        '#ffc107',
                        '#dc3545',
                        '#6c757d'
                    ]
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false
            }
        });
    }
    
    function loadDashboardData() {
        $.ajax({
            url: 'assets/cfc/reporting.cfc',
            method: 'GET',
            data: {
                method: 'getDashboardData',
                period: currentPeriod
            },
            success: function(response) {
                updateDashboardStats(response.stats);
                updateCharts(response.chartData);
                updateTables(response.tableData);
            },
            error: function(xhr, status, error) {
                console.error('Error loading dashboard data:', error);
                // Show error message to user
                showErrorMessage('Failed to load dashboard data. Please try again later.');
            }
        });
    }
    
    function updateDashboardStats(stats) {
        // Update overview cards
        $('#totalReservations').text(stats.totalReservations);
        $('#activeUsers').text(stats.activeUsers);
        $('#roomUtilization').text(stats.roomUtilization + '%');
        $('#cancellationRate').text(stats.cancellationRate + '%');
        
        // Update trends
        updateTrendIndicator('#reservationTrend', stats.reservationTrend);
        updateTrendIndicator('#usersTrend', stats.usersTrend);
        updateTrendIndicator('#utilizationTrend', stats.utilizationTrend);
        updateTrendIndicator('#cancellationTrend', stats.cancellationTrend);
    }
    
    function updateTrendIndicator(selector, value) {
        const element = $(selector);
        element.text(value + '%');
        if (value > 0) {
            element.addClass('text-success').removeClass('text-danger');
            element.prepend('<i class="fas fa-arrow-up me-1"></i>');
        } else if (value < 0) {
            element.addClass('text-danger').removeClass('text-success');
            element.prepend('<i class="fas fa-arrow-down me-1"></i>');
        }
    }
    
    function updateCharts(chartData) {
        // Update Reservation Trends Chart
        reservationTrendsChart.data.labels = chartData.trends.labels;
        reservationTrendsChart.data.datasets[0].data = chartData.trends.data;
        reservationTrendsChart.update();
        
        // Update Room Distribution Chart
        roomDistributionChart.data.labels = chartData.distribution.labels;
        roomDistributionChart.data.datasets[0].data = chartData.distribution.data;
        roomDistributionChart.update();
    }
    
    function updateTables(tableData) {
        // Update Room Table
        const roomTableBody = $('#roomTable tbody');
        roomTableBody.empty();
        
        tableData.rooms.forEach(room => {
            roomTableBody.append(`
                <tr>
                    <td>${room.name}</td>
                    <td>${room.totalBookings}</td>
                    <td>${room.utilizationRate}%</td>
                    <td>${room.averageRating} <i class="fas fa-star text-warning"></i></td>
                    <td><span class="badge bg-${room.status === 'Available' ? 'success' : 'danger'}">${room.status}</span></td>
                </tr>
            `);
        });
        
        // Update User Table
        const userTableBody = $('#userTable tbody');
        userTableBody.empty();
        
        tableData.users.forEach(user => {
            userTableBody.append(`
                <tr>
                    <td>${user.name}</td>
                    <td>${user.totalBookings}</td>
                    <td>${user.avgDuration} hours</td>
                    <td>${user.preferredRoom}</td>
                    <td>${user.lastActive}</td>
                </tr>
            `);
        });
    }
    
    function updatePeriod(period) {
        currentPeriod = period;
        // Update active button state
        $('.btn-group .btn').removeClass('active');
        $(`#btn${period.charAt(0).toUpperCase() + period.slice(1)}`).addClass('active');
        // Reload dashboard data
        loadDashboardData();
    }
    
    function setupRefreshInterval() {
        // Refresh dashboard data every 5 minutes
        setInterval(loadDashboardData, 5 * 60 * 1000);
    }
    
    function exportDashboard() {
        $.ajax({
            url: 'assets/cfc/reporting.cfc',
            method: 'GET',
            data: {
                method: 'exportDashboardData',
                period: currentPeriod
            },
            success: function(response) {
                // Create and trigger download
                const blob = new Blob([response], { type: 'text/csv' });
                const url = window.URL.createObjectURL(blob);
                const a = document.createElement('a');
                a.href = url;
                a.download = `dashboard_report_${currentPeriod}_${new Date().toISOString().split('T')[0]}.csv`;
                document.body.appendChild(a);
                a.click();
                window.URL.revokeObjectURL(url);
                document.body.removeChild(a);
            },
            error: function(xhr, status, error) {
                console.error('Error exporting dashboard data:', error);
                showErrorMessage('Failed to export dashboard data. Please try again later.');
            }
        });
    }
    
    function showErrorMessage(message) {
        const alertHtml = `
            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                ${message}
                <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
            </div>
        `;
        $('main').prepend(alertHtml);
    }
});
