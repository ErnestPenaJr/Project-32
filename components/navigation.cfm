<cfoutput>
<div class="navbar bg-base-100 shadow-lg">
    <div class="navbar-start">
        <div class="dropdown">
            <label tabindex="0" class="btn btn-ghost lg:hidden">
                <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h8m-8 6h16" />
                </svg>
            </label>
            <ul tabindex="0" class="menu menu-sm dropdown-content mt-3 z-[1] p-2 shadow bg-base-100 rounded-box w-52">
                <li><a href="/index.cfm">Home</a></li>
                <li><a href="/rooms/search.cfm">Find a Room</a></li>
                <li><a href="/bookings/my-bookings.cfm">My Bookings</a></li>
                <cfif session.userrole eq "Admin">
                    <li>
                        <a>Admin</a>
                        <ul class="p-2">
                            <li><a href="/admin/rooms.cfm">Manage Rooms</a></li>
                            <li><a href="/admin/users.cfm">Manage Users</a></li>
                            <li><a href="/admin/reports.cfm">Reports</a></li>
                        </ul>
                    </li>
                </cfif>
            </ul>
        </div>
        <a href="/index.cfm" class="btn btn-ghost normal-case text-xl">
            <img src="/assets/images/mdacc-logo.png" alt="MD Anderson Logo" class="h-8">
            <span class="ml-2">Room Reservation</span>
        </a>
    </div>
    
    <div class="navbar-center hidden lg:flex">
        <ul class="menu menu-horizontal px-1">
            <li><a href="/index.cfm">Home</a></li>
            <li><a href="/rooms/search.cfm">Find a Room</a></li>
            <li><a href="/bookings/my-bookings.cfm">My Bookings</a></li>
            <cfif session.userrole eq "Admin">
                <li>
                    <details>
                        <summary>Admin</summary>
                        <ul class="p-2 bg-base-100 rounded-t-none">
                            <li><a href="/admin/rooms.cfm">Manage Rooms</a></li>
                            <li><a href="/admin/users.cfm">Manage Users</a></li>
                            <li><a href="/admin/reports.cfm">Reports</a></li>
                        </ul>
                    </details>
                </li>
            </cfif>
        </ul>
    </div>
    
    <div class="navbar-end">
        <div class="dropdown dropdown-end">
            <div tabindex="0" role="button" class="btn btn-ghost btn-circle">
                <div class="indicator">
                    <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
                    </svg>
                    <span class="badge badge-sm indicator-item" id="notification-count">0</span>
                </div>
            </div>
            <div tabindex="0" class="mt-3 z-[1] card card-compact dropdown-content w-80 bg-base-100 shadow">
                <div class="card-body" id="notification-list">
                    <div class="text-center text-gray-500">No new notifications</div>
                </div>
            </div>
        </div>
        
        <div class="dropdown dropdown-end ml-4">
            <label tabindex="0" class="btn btn-ghost btn-circle avatar">
                <div class="w-10 rounded-full">
                    <img src="/assets/images/default-avatar.png" alt="Profile" />
                </div>
            </label>
            <ul tabindex="0" class="menu menu-sm dropdown-content mt-3 z-[1] p-2 shadow bg-base-100 rounded-box w-52">
                <li><a href="/profile.cfm">Profile</a></li>
                <li><a href="/settings.cfm">Settings</a></li>
                <li><a href="/logout.cfm">Logout</a></li>
            </ul>
        </div>
    </div>
</div>
</cfoutput>
