<!DOCTYPE html>
<html lang="en" data-theme="light">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MD Anderson Room Reservation System</title>
    
    <!-- Tailwind CSS and DaisyUI -->
    <link href="https://cdn.jsdelivr.net/npm/daisyui@3.9.3/dist/full.css" rel="stylesheet" type="text/css" />
    <script src="https://cdn.tailwindcss.com"></script>
    
    <!-- Custom Tailwind Configuration -->
    <script>
        tailwind.config = {
            theme: {
                extend: {
                    colors: {
                        'mdacc-red': '#E41E2B',
                        'mdacc-blue': '#006BA6',
                        'mdacc-gray': '#58595B'
                    }
                }
            },
            plugins: [require("daisyui")],
            daisyui: {
                themes: [
                    {
                        light: {
                            ...require("daisyui/src/theming/themes")["[data-theme=light]"],
                            primary: "#006BA6",
                            secondary: "#E41E2B",
                            accent: "#58595B"
                        }
                    }
                ]
            }
        }
    </script>
    
    <!-- Flatpickr for Date/Time Selection -->
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/flatpickr/dist/flatpickr.min.css">
    <script src="https://cdn.jsdelivr.net/npm/flatpickr"></script>
    
    <!-- Custom CSS -->
    <style>
        .loading-spinner {
            @apply animate-spin h-5 w-5 text-white;
        }
        .btn-primary {
            @apply bg-mdacc-blue hover:bg-mdacc-blue/90;
        }
        .btn-secondary {
            @apply bg-mdacc-red hover:bg-mdacc-red/90;
        }
    </style>
</head>
<body class="min-h-screen bg-gray-50">
    <!-- Navigation -->
    <cfinclude template="/components/navigation.cfm">
    
    <!-- Main Content -->
    <main class="container mx-auto px-4 py-8">
        <cfoutput>
            #body#
        </cfoutput>
    </main>
    
    <!-- Footer -->
    <cfinclude template="/components/footer.cfm">
    
    <!-- Toast Notifications -->
    <div id="toast-container" class="fixed bottom-4 right-4 z-50"></div>
    
    <!-- Loading Overlay -->
    <div id="loading-overlay" class="fixed inset-0 bg-black bg-opacity-50 items-center justify-center z-50 hidden">
        <div class="loading-spinner"></div>
    </div>
    
    <!-- Custom JavaScript -->
    <script src="/assets/js/main.js"></script>
</body>
</html>
