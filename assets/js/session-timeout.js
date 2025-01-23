// Session timeout handler
(function ($) { // Add the plugin to jQuery
    $.sessionTimeout = function (options) {
        var defaults = {
            keepAliveUrl: 'keep-alive',
            logoutUrl: '../logout.html',
            redirUrl: '../login.html',
            warnAfter: 900000, // 15 minutes
            redirAfter: 1200000, // 20 minutes
            keepAliveInterval: 300000, // 5 minutes
            onWarn: null,
            onRedir: null
        };

        var opt = $.extend(defaults, options);
        var timer,
            keepAliveTimer;
        var warning = false;

        function keepAlive() {
            $.ajax({type: 'POST', url: opt.keepAliveUrl});
        }

        function startKeepAlive() {
            keepAliveTimer = setInterval(keepAlive, opt.keepAliveInterval);
        }

        function stopKeepAlive() {
            clearInterval(keepAliveTimer);
        }

        function redirect() {
            if (opt.onRedir && typeof opt.onRedir === 'function') {
                opt.onRedir();
            } else {
                window.location = opt.redirUrl;
            }
        }

        function start() {
            if (! warning) {
                warning = true;
                if (opt.onWarn && typeof opt.onWarn === 'function') {
                    opt.onWarn();
                }
                setTimeout(redirect, opt.redirAfter - opt.warnAfter);
            }
        }

        function reset() {
            warning = false;
            clearTimeout(timer);
            startKeepAlive();
            timer = setTimeout(start, opt.warnAfter);
        }

        // Initialize
        reset();

        // Reset on user activity
        $(document).on('mousemove keypress click', reset);
    };
})(jQuery);
