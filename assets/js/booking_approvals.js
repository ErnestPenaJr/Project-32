$(document).ready(function() {
    // Initialize AOS
    AOS.init();

    // Initialize DataTable
    const bookingsTable = $('#bookingsTable').DataTable({
        order: [[0, 'desc']], // Order by ID column descending
        pageLength: 10,
        responsive: true,
        dom: '<"row"<"col-sm-12 col-md-6"l><"col-sm-12 col-md-6"f>>' +
             '<"row"<"col-sm-12"tr>>' +
             '<"row"<"col-sm-12 col-md-5"i><"col-sm-12 col-md-7"p>>',
        language: {
            search: "Search:",
            lengthMenu: "Show _MENU_ entries",
            info: "Showing _START_ to _END_ of _TOTAL_ entries",
            infoEmpty: "Showing 0 to 0 of 0 entries",
            infoFiltered: "(filtered from _MAX_ total entries)",
            paginate: {
                first: '<i class="fas fa-angle-double-left"></i>',
                previous: '<i class="fas fa-angle-left"></i>',
                next: '<i class="fas fa-angle-right"></i>',
                last: '<i class="fas fa-angle-double-right"></i>'
            }
        }
    });

    // Load bookings on page load
    loadBookings();

    // Handle filter application
    $('#applyFilters').click(function() {
        loadBookings();
    });

    // Handle search input
    $('#searchInput').on('keyup', function() {
        bookingsTable.search(this.value).draw();
    });

    // Handle individual approve/reject
    $(document).on('click', '.approve-booking', function() {
        const bookingId = $(this).data('id');
        approveBooking(bookingId);
    });

    $(document).on('click', '.reject-booking', function() {
        const bookingId = $(this).data('id');
        rejectBooking(bookingId);
    });

    // Handle booking details modal
    $(document).on('click', '.view-booking', function() {
        const bookingId = $(this).data('id');
        loadBookingDetails(bookingId);
    });

    // Handle modal approve/reject buttons
    $('#approveBookingBtn').click(function() {
        const bookingId = $(this).data('bookingId');
        const modal = bootstrap.Modal.getInstance(document.getElementById('bookingDetailsModal'));
        modal.hide();
        approveBooking(bookingId);
    });

    $('#rejectBookingBtn').click(function() {
        const bookingId = $(this).data('bookingId');
        const modal = bootstrap.Modal.getInstance(document.getElementById('bookingDetailsModal'));
        modal.hide();
        rejectBooking(bookingId);
    });

    // Functions
    function loadBookings() {
        const filters = {
            date: $('#dateFilter').val(),
            status: $('#statusFilter').val(),
            search: $('#searchInput').val()
        };
        
        $.ajax({
            url: 'assets/cfc/approvals.cfc',
            method: 'GET',
            dataType: 'json',
            data: {
                method: 'getPendingBookings',
                ...filters,
                returnformat: 'json'
            },
            success: function(response) {
                if (response.SUCCESS) {
                    const bookings = response.DATA;
                    const tableData = bookings.map(booking => [
                        booking.USER_NAME,
                        booking.SERVICE,
                        `${booking.BUILDING}.${booking.ROOM_NUMBER}`, 
                        booking.BOOKING_DATE,
                        `${booking.START_TIME} - ${booking.END_TIME}`,
                        `<h4 class="badge text-uppercase ${getStatusBadgeClass(booking.STATUS)}">${booking.STATUS}</h4>`,
                        `<button class="btn btn-sm btn-success approve-bookingx" data-id="${booking.ID}">
                            <i class="fas fa-check"></i>
                         </button>
                         <button class="btn btn-sm btn-danger reject-booking" data-id="${booking.ID}">
                            <i class="fas fa-times"></i>
                         </button>`
                    ]);
                    
                    bookingsTable.clear().rows.add(tableData).draw();
                    $('.approve-bookingx').on('click', function() {
                        const bookingId = $(this).data('id');
                        
                        Swal.fire({
                            customClass: {
                                confirmButton: "btn btn-success",
                                cancelButton: "btn btn-danger"
                            },
                            buttonsStyling: false
                            });
                            swalWithBootstrapButtons.fire({
                            title: "Are you sure?",
                            text: "You won't be able to revert this!",
                            icon: "warning",
                            showCancelButton: true,
                            confirmButtonText: "Yes, delete it!",
                            cancelButtonText: "No, cancel!",
                            reverseButtons: true
                            }).then((result) => {
                            if (result.isConfirmed) {
                                swalWithBootstrapButtons.fire({
                                title: "Deleted!",
                                text: "Your file has been deleted.",
                                icon: "success"
                                });
                            } else if (
                                /* Read more about handling dismissals below */
                                result.dismiss === Swal.DismissReason.cancel
                            ) {
                                swalWithBootstrapButtons.fire({
                                title: "Cancelled",
                                text: "Your imaginary file is safe :)",
                                icon: "error"
                                });
                            }
                        });
                    });
                    $('.reject-booking').on('click', function() {
                        const bookingId = $(this).data('id');
                        rejectBooking(bookingId);
                    });



                } else {
                    showAlert('error', response.MESSAGE || 'Failed to load bookings');
                }
            },
            error: function(xhr, status, error) {
                console.error('AJAX Error:', error);
                showAlert('error', 'Failed to load bookings. Please try again.');
            }
        });
    }

    function loadBookingDetails(bookingId) {
        $.ajax({
            url: 'assets/cfc/approvals.cfc',
            method: 'GET',
            dataType: 'json',
            data: {
                method: 'getBookingDetails',
                bookingId: bookingId,
            },
            success: function(response) {
                if (response.SUCCESS) {
                    // Update modal content
                    const modalBody = $('#bookingDetailsModal .modal-body');
                    modalBody.html(`
                        <div class="text-start">
                            <p><strong>Booking ID:</strong> ${response.DATA.ID}</p>
                            <p><strong>User:</strong> ${response.DATA.USER_NAME}</p>
                            <p><strong>Room:</strong> ${response.DATA.SERVICE}</p>
                            <p><strong>Building:</strong> ${response.DATA.BUILDING}</p>
                            <p><strong>Room Number:</strong> ${response.DATA.ROOM_NUMBER}</p>
                            <p><strong>Capacity:</strong> ${response.DATA.CAPACITY}</p>
                            <p><strong>Date:</strong> ${response.DATA.BOOKING_DATE}</p>
                            <p><strong>Time:</strong> ${response.DATA.START_TIME} - ${response.DATA.END_TIME}</p>
                            <p><strong>Status:</strong> <span class="badge ${getStatusBadgeClass(response.DATA.STATUS)}">${response.DATA.STATUS}</span></p>
                        </div>
                    `);
                    alert('Boom Baby!')
                    // Store booking ID for approve/reject actions
                    $('#approveBookingBtn').data('bookingId', bookingId);
                    $('#rejectBookingBtn').data('bookingId', bookingId);
                    
                    // Show modal
                    const modal = new bootstrap.Modal(document.getElementById('bookingDetailsModal'));
                    modal.show();
                } else {
                    showAlert('error', response.MESSAGE || 'Failed to load booking details');
                }
            },
            error: function(xhr, status, error) {
                console.error('AJAX Error:', error);
                showAlert('error', 'Failed to load booking details. Please try again.');
            }
        });
    }

    function getStatusBadgeClass(status) {
        switch (status.toLowerCase()) {
            case 'approved': return 'bg-success';
            case 'rejected': return 'bg-danger';
            case 'pending': return 'bg-warning';
            default: return 'bg-secondary';
        }
    }

    function showAlert(icon, message, timer = 3000) {
        Swal.fire({
            icon: icon,
            text: message,
            timer: timer,
            timerProgressBar: true,
            showConfirmButton: false,
            position: 'top-end',
            toast: true,
            background: '#fff'
        });
    }

    function approveBooking(bookingId) {
        Swal.fire({
            title: 'Approve Booking',
            text: 'Are you sure you want to approve this booking?',
            icon: 'question',
            showCancelButton: true,
            confirmButtonColor: '#28a745',
            cancelButtonColor: '#dc3545',
            confirmButtonText: 'Yes, approve it!',
            cancelButtonText: 'Cancel',
            background: '#fff',
            backdrop: 'rgba(0,0,0,0.4)'
        }).then((result) => {
            if (result.isConfirmed) {
                updateBookingStatus(bookingId, 'approved');
            }
        });
    }

    function rejectBooking(bookingId) {
        Swal.fire({
            title: 'Reject Booking',
            text: 'Are you sure you want to reject this booking?',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#dc3545',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Yes, reject it!',
            cancelButtonText: 'Cancel',
            background: '#fff',
            backdrop: 'rgba(0,0,0,0.4)'
        }).then((result) => {
            if (result.isConfirmed) {
                updateBookingStatus(bookingId, 'rejected');
            }
        });
    }

    function updateBookingStatus(bookingId, status) {
        $.ajax({
            url: 'assets/cfc/approvals.cfc',
            method: 'POST',
            data: {
                method: 'updateBookingStatus',
                bookingId: bookingId,
                status: status,
                returnformat: 'json'
            },
            dataType: 'json',
            success: function(response) {
                if (response.SUCCESS) {
                    const message = status === 'approved' ? 'Booking approved successfully' : 'Booking rejected successfully';
                    showAlert('success', message);
                    loadBookings();
                } else {
                    showAlert('error', response.MESSAGE || `Failed to ${status} booking`);
                }
            },
            error: function(xhr, status, error) {
                console.error('AJAX Error:', error);
                showAlert('error', `Failed to ${status} booking. Please try again.`);
            }
        });
    }
});
