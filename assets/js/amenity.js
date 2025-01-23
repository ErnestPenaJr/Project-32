$(document).ready(function() {
    // Initialize DataTable
    const amenitiesTable = $('#amenitiesTable').DataTable({
        responsive: true,
        columns: [
            { data: 'id', className: 'text-center' },
            { 
                data: 'icon',
                className: 'text-center',
                render: function(data) {
                    return `<i class="${data}"></i>`;
                }
            },
            { data: 'name' },
            { data: 'description' },
            {
                data: null,
                className: 'text-center',
                render: function(data) {
                    return `
                        <button class="btn btn-sm btn-primary edit-amenity" data-id="${data.id}">
                            <i class="fas fa-edit"></i>
                        </button>
                        <button class="btn btn-sm btn-danger delete-amenity" data-id="${data.id}">
                            <i class="fas fa-trash"></i>
                        </button>
                    `;
                }
            }
        ]
    });

    // Load amenities
    function loadAmenities() {
        $.ajax({
            url: 'assets/cfc/amenity.cfc',
            method: 'GET',
            data: {
                method: 'getAllAmenities',
                returnformat: 'json'
            },
            success: function(response) {
                console.log(response);
                if (response.SUCCESS) {
                    amenitiesTable.clear().rows.add(response.DATA).draw();
                } else {
                    showAlert('error', response.MESSAGE || 'Failed to load amenities');
                }
            },
            error: function() {
                showAlert('error', 'Failed to load amenities. Please try again.');
            }
        });
    }

    // Add Amenity Button Click
    $('#addAmenityBtn').on('click', function() {
        // Clear form
        $('#addAmenityForm')[0].reset();
        $('#iconPreview').html('');
        // Show modal
        $('#addAmenityModal').modal('show');
    });

    // Icon Selection
    $('.amenity-icon').on('click', function() {
        $('.amenity-icon').removeClass('selected');
        $(this).addClass('selected');
        const iconClass = $(this).find('i').attr('class');
        $('#selectedIcon').val(iconClass);
        $('#iconPreview').html(`<i class="${iconClass} fa-2x"></i>`);
    });

    // Add Amenity Form Submit
    $('#addAmenityForm').on('submit', function(e) {
        e.preventDefault();
        
        const formData = {
            name: $('#amenityName').val(),
            description: $('#amenityDescription').val(),
            icon: $('#selectedIcon').val()
        };

        $.ajax({
            url: 'assets/cfc/amenity.cfc',
            method: 'POST',
            data: {
                method: 'addAmenity',
                ...formData,
                returnformat: 'json'
            },
            success: function(response) {
                if (response.success) {
                    $('#addAmenityModal').modal('hide');
                    showAlert('success', 'Amenity added successfully');
                    loadAmenities();
                } else {
                    showAlert('error', response.message || 'Failed to add amenity');
                }
            },
            error: function() {
                showAlert('error', 'Failed to add amenity. Please try again.');
            }
        });
    });

    // Edit Amenity
    $(document).on('click', '.edit-amenity', function() {
        const amenityId = $(this).data('id');
        
        $.ajax({
            url: 'assets/cfc/amenity.cfc',
            method: 'GET',
            data: {
                method: 'getAmenity',
                amenityId: amenityId,
                returnformat: 'json'
            },
            success: function(response) {
                if (response.success) {
                    const amenity = response.data;
                    $('#editAmenityId').val(amenity.id);
                    $('#editAmenityName').val(amenity.name);
                    $('#editAmenityDescription').val(amenity.description);
                    $('#editSelectedIcon').val(amenity.icon);
                    $('#editIconPreview').html(`<i class="${amenity.icon} fa-2x"></i>`);
                    $('#editAmenityModal').modal('show');
                } else {
                    showAlert('error', response.message || 'Failed to load amenity details');
                }
            },
            error: function() {
                showAlert('error', 'Failed to load amenity details. Please try again.');
            }
        });
    });

    // Update Amenity Form Submit
    $('#editAmenityForm').on('submit', function(e) {
        e.preventDefault();
        
        const formData = {
            amenityId: $('#editAmenityId').val(),
            name: $('#editAmenityName').val(),
            description: $('#editAmenityDescription').val(),
            icon: $('#editSelectedIcon').val()
        };

        $.ajax({
            url: 'assets/cfc/amenity.cfc',
            method: 'POST',
            data: {
                method: 'updateAmenity',
                ...formData,
                returnformat: 'json'
            },
            success: function(response) {
                if (response.success) {
                    $('#editAmenityModal').modal('hide');
                    showAlert('success', 'Amenity updated successfully');
                    loadAmenities();
                } else {
                    showAlert('error', response.message || 'Failed to update amenity');
                }
            },
            error: function() {
                showAlert('error', 'Failed to update amenity. Please try again.');
            }
        });
    });

    // Delete Amenity
    $(document).on('click', '.delete-amenity', function() {
        const amenityId = $(this).data('id');
        
        Swal.fire({
            title: 'Delete Amenity',
            text: 'Are you sure you want to delete this amenity?',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#dc3545',
            cancelButtonColor: '#6c757d',
            confirmButtonText: 'Yes, delete it!'
        }).then((result) => {
            if (result.isConfirmed) {
                $.ajax({
                    url: 'assets/cfc/amenity.cfc',
                    method: 'POST',
                    data: {
                        method: 'deleteAmenity',
                        amenityId: amenityId,
                        returnformat: 'json'
                    },
                    success: function(response) {
                        if (response.success) {
                            showAlert('success', 'Amenity deleted successfully');
                            loadAmenities();
                        } else {
                            showAlert('error', response.message || 'Failed to delete amenity');
                        }
                    },
                    error: function() {
                        showAlert('error', 'Failed to delete amenity. Please try again.');
                    }
                });
            }
        });
    });

    // Show Alert
    function showAlert(icon, message) {
        Swal.fire({
            icon: icon,
            title: message,
            toast: true,
            position: 'top-end',
            showConfirmButton: false,
            timer: 3000,
            timerProgressBar: true
        });
    }

    // Initial load
    loadAmenities();
});
