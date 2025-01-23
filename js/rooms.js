$(document).ready(function() {
    let roomsTable = $('#roomsTable').DataTable({
        ajax: {
            url: 'cfcs/Room.cfc?method=getAllRooms',
            dataSrc: ''
        },
        columns: [
            { data: 'ROOMID' },
            { data: 'ROOMNAME' },
            { data: 'LOCATION' },
            { data: 'CAPACITY' },
            { data: 'ROOM_TYPE' },
            { data: 'STATUS' },
            {
                data: null,
                render: function(data, type, row) {
                    return `
                        <button class="btn btn-sm btn-primary edit-room" data-id="${row.ROOMID}">Edit</button>
                        <button class="btn btn-sm btn-danger delete-room" data-id="${row.ROOMID}">Delete</button>
                    `;
                }
            }
        ]
    });

    // Load departments for select dropdown
    $.get('cfcs/Room.cfc?method=getDepartments', function(data) {
        const departments = JSON.parse(data);
        const select = $('#deptId');
        departments.forEach(dept => {
            select.append(new Option(dept.DEPARTMENT_NAME, dept.DEPARTMENT_ID));
        });
    });

    // Handle room form submission
    $('#saveRoom').click(function() {
        const formData = $('#roomForm').serializeArray().reduce((obj, item) => {
            obj[item.name] = item.value;
            return obj;
        }, {});

        // Add checkbox values
        ['videoconf', 'clickshare', 'hasDoor', 'computer', 'phone', 'camera'].forEach(field => {
            formData[field] = $('#' + field).prop('checked') ? 1 : 0;
        });

        const method = formData.roomId ? 'updateRoom' : 'createRoom';
        
        $.ajax({
            url: 'cfcs/Room.cfc?method=' + method,
            method: 'POST',
            data: formData,
            success: function(response) {
                if (response) {
                    Swal.fire({
                        title: 'Success',
                        text: 'Room ' + (method === 'updateRoom' ? 'updated' : 'created') + ' successfully',
                        icon: 'success'
                    });
                    $('#roomModal').modal('hide');
                    roomsTable.ajax.reload();
                } else {
                    Swal.fire({
                        title: 'Error',
                        text: 'Failed to ' + (method === 'updateRoom' ? 'update' : 'create') + ' room',
                        icon: 'error'
                    });
                }
            },
            error: function() {
                Swal.fire({
                    title: 'Error',
                    text: 'An error occurred while processing your request',
                    icon: 'error'
                });
            }
        });
    });

    // Handle edit room
    $('#roomsTable').on('click', '.edit-room', function() {
        const roomId = $(this).data('id');
        $.get('cfcs/Room.cfc?method=getRoomByID&roomID=' + roomId, function(data) {
            const room = JSON.parse(data);
            $('#roomId').val(room.ROOMID);
            $('#roomName').val(room.ROOMNAME);
            $('#deptId').val(room.DEPTID);
            $('#location').val(room.LOCATION);
            $('#capacity').val(room.CAPACITY);
            $('#building').val(room.BUILDING);
            $('#floor').val(room.FLOOR);
            $('#roomType').val(room.ROOM_TYPE);
            $('#roomDescription').val(room.ROOM_DESCRIPTION);
            $('#equipment').val(room.EQUIPMENT);
            $('#comments').val(room.COMMENTS);

            // Set checkboxes
            ['videoconf', 'clickshare', 'hasDoor', 'computer', 'phone', 'camera'].forEach(field => {
                $('#' + field).prop('checked', room[field.toUpperCase()] === 1);
            });

            $('#roomModal').modal('show');
        });
    });

    // Handle delete room
    $('#roomsTable').on('click', '.delete-room', function() {
        const roomId = $(this).data('id');
        Swal.fire({
            title: 'Are you sure?',
            text: "You won't be able to revert this!",
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#3085d6',
            confirmButtonText: 'Yes, delete it!'
        }).then((result) => {
            if (result.isConfirmed) {
                $.post('cfcs/Room.cfc?method=deleteRoom', { roomID: roomId }, function(response) {
                    if (response) {
                        Swal.fire('Deleted!', 'Room has been deleted.', 'success');
                        roomsTable.ajax.reload();
                    } else {
                        Swal.fire('Error', 'Failed to delete room', 'error');
                    }
                });
            }
        });
    });

    // Clear form when modal is closed
    $('#roomModal').on('hidden.bs.modal', function() {
        $('#roomForm')[0].reset();
        $('#roomId').val('');
    });
});
