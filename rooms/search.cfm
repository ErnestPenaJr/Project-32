<cfscript>
    // Get search parameters
    param name="url.building" default="";
    param name="url.floor" default="";
    param name="url.capacity" default="";
    param name="url.amenities" default="";
    param name="url.date" default="#dateFormat(now(), 'yyyy-mm-dd')#";
    param name="url.startTime" default="09:00";
    param name="url.endTime" default="17:00";
    
    // Get all buildings for dropdown
    buildings = queryExecute(
        "SELECT DISTINCT BUILDING FROM ROOMS ORDER BY BUILDING",
        {},
        {datasource=application.dsn}
    );
    
    // Get all amenities for filter
    amenities = queryExecute(
        "SELECT * FROM AMENITIES ORDER BY AMENITY_NAME",
        {},
        {datasource=application.dsn}
    );
    
    // Search for rooms if parameters are provided
    if (len(url.building) || len(url.floor) || len(url.capacity) || len(url.amenities)) {
        searchCriteria = {
            building: url.building,
            floor: url.floor,
            minCapacity: url.capacity
        };
        if (len(url.amenities)) {
            searchCriteria.amenities = listToArray(url.amenities);
        }
        rooms = application.roomService.searchRooms(searchCriteria);
    }
</cfscript>

<cfoutput>
<div class="container mx-auto px-4 py-8">
    <h1 class="text-4xl font-bold mb-8">Find a Room</h1>
    
    <!-- Search Form -->
    <div class="bg-white shadow-lg rounded-lg p-6 mb-8">
        <form action="search.cfm" method="get" class="space-y-6">
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                <!-- Building Selection -->
                <div class="form-control">
                    <label class="label">
                        <span class="label-text">Building</span>
                    </label>
                    <select name="building" class="select select-bordered w-full">
                        <option value="">All Buildings</option>
                        <cfloop query="buildings">
                            <option value="#BUILDING#" <cfif url.building eq BUILDING>selected</cfif>>#BUILDING#</option>
                        </cfloop>
                    </select>
                </div>
                
                <!-- Floor Selection -->
                <div class="form-control">
                    <label class="label">
                        <span class="label-text">Floor</span>
                    </label>
                    <select name="floor" class="select select-bordered w-full">
                        <option value="">Any Floor</option>
                        <cfloop from="1" to="20" index="i">
                            <option value="#i#" <cfif url.floor eq i>selected</cfif>>#i#</option>
                        </cfloop>
                    </select>
                </div>
                
                <!-- Capacity -->
                <div class="form-control">
                    <label class="label">
                        <span class="label-text">Minimum Capacity</span>
                    </label>
                    <select name="capacity" class="select select-bordered w-full">
                        <option value="">Any Capacity</option>
                        <option value="5" <cfif url.capacity eq 5>selected</cfif>>5+ People</option>
                        <option value="10" <cfif url.capacity eq 10>selected</cfif>>10+ People</option>
                        <option value="20" <cfif url.capacity eq 20>selected</cfif>>20+ People</option>
                        <option value="50" <cfif url.capacity eq 50>selected</cfif>>50+ People</option>
                        <option value="100" <cfif url.capacity eq 100>selected</cfif>>100+ People</option>
                    </select>
                </div>
                
                <!-- Date -->
                <div class="form-control">
                    <label class="label">
                        <span class="label-text">Date</span>
                    </label>
                    <input type="date" name="date" value="#url.date#" 
                           min="#dateFormat(now(), 'yyyy-mm-dd')#"
                           class="input input-bordered w-full" />
                </div>
                
                <!-- Time Range -->
                <div class="form-control">
                    <label class="label">
                        <span class="label-text">Start Time</span>
                    </label>
                    <select name="startTime" class="select select-bordered w-full">
                        <cfloop from="7" to="21" index="hour">
                            <cfset formattedHour = numberFormat(hour, "00") & ":00">
                            <option value="#formattedHour#" <cfif url.startTime eq formattedHour>selected</cfif>>
                                #timeFormat(createTime(hour, 0), "h:mm tt")#
                            </option>
                        </cfloop>
                    </select>
                </div>
                
                <div class="form-control">
                    <label class="label">
                        <span class="label-text">End Time</span>
                    </label>
                    <select name="endTime" class="select select-bordered w-full">
                        <cfloop from="8" to="22" index="hour">
                            <cfset formattedHour = numberFormat(hour, "00") & ":00">
                            <option value="#formattedHour#" <cfif url.endTime eq formattedHour>selected</cfif>>
                                #timeFormat(createTime(hour, 0), "h:mm tt")#
                            </option>
                        </cfloop>
                    </select>
                </div>
            </div>
            
            <!-- Amenities -->
            <div class="form-control">
                <label class="label">
                    <span class="label-text">Required Amenities</span>
                </label>
                <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
                    <cfloop query="amenities">
                        <label class="label cursor-pointer justify-start gap-2">
                            <input type="checkbox" name="amenities" value="#AMENITY_NAME#" 
                                   class="checkbox checkbox-primary"
                                   <cfif listFindNoCase(url.amenities, AMENITY_NAME)>checked</cfif> />
                            <span class="label-text">#AMENITY_NAME#</span>
                        </label>
                    </cfloop>
                </div>
            </div>
            
            <div class="flex justify-end space-x-4">
                <button type="reset" class="btn btn-ghost">Reset</button>
                <button type="submit" class="btn btn-primary">Search Rooms</button>
            </div>
        </form>
    </div>
    
    <!-- Search Results -->
    <cfif isDefined("rooms")>
        <h2 class="text-2xl font-bold mb-4">Available Rooms</h2>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <cfif rooms.recordCount>
                <cfloop query="rooms">
                    <div class="card bg-base-100 shadow-xl">
                        <figure>
                            <img src="/assets/images/rooms/#ROOM_ID#.jpg" 
                                 alt="#ROOM_NAME#"
                                 onerror="this.src='/assets/images/room-placeholder.jpg'"
                                 class="w-full h-48 object-cover" />
                        </figure>
                        <div class="card-body">
                            <h3 class="card-title">#ROOM_NAME#</h3>
                            <p class="text-sm text-gray-600">
                                #BUILDING# • Floor #FLOOR# • Capacity: #CAPACITY# people
                            </p>
                            <p class="text-sm">
                                <strong>Amenities:</strong> #AMENITIES#
                            </p>
                            <div class="card-actions justify-end mt-4">
                                <a href="/rooms/details.cfm?id=#ROOM_ID#" class="btn btn-primary btn-sm">View Details</a>
                                <a href="/bookings/create.cfm?room=#ROOM_ID#&date=#url.date#&start=#url.startTime#&end=#url.endTime#" 
                                   class="btn btn-secondary btn-sm">Book Now</a>
                            </div>
                        </div>
                    </div>
                </cfloop>
            <cfelse>
                <div class="col-span-full">
                    <div class="alert">
                        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" class="stroke-info shrink-0 w-6 h-6">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path>
                        </svg>
                        <span>No rooms found matching your criteria. Try adjusting your search parameters.</span>
                    </div>
                </div>
            </cfif>
        </div>
    </cfif>
</div>

<!--- Initialize date picker --->
<script>
document.addEventListener('DOMContentLoaded', function() {
    // Initialize date picker
    flatpickr('input[type="date"]', {
        minDate: 'today',
        dateFormat: 'Y-m-d'
    });
    
    // Handle form reset
    document.querySelector('button[type="reset"]').addEventListener('click', function(e) {
        e.preventDefault();
        const form = e.target.closest('form');
        form.reset();
        form.querySelector('input[name="date"]').value = '#dateFormat(now(), "yyyy-mm-dd")#';
        window.location.href = 'search.cfm';
    });
    
    // Validate time range
    document.querySelector('form').addEventListener('submit', function(e) {
        const startTime = document.querySelector('select[name="startTime"]').value;
        const endTime = document.querySelector('select[name="endTime"]').value;
        
        if (startTime >= endTime) {
            e.preventDefault();
            alert('End time must be after start time');
            return false;
        }
    });
});
</script>
</cfoutput>
