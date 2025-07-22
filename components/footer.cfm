<cfoutput>
<footer class="footer p-10 bg-base-200 text-base-content">
    <nav>
        <header class="footer-title">Quick Links</header> 
        <a href="/index.cfm" class="link link-hover">Home</a>
        <a href="/rooms/search.cfm" class="link link-hover">Find a Room</a>
        <a href="/bookings/my-bookings.cfm" class="link link-hover">My Bookings</a>
        <a href="/help.cfm" class="link link-hover">Help Center</a>
    </nav>
    
    <nav>
        <header class="footer-title">Support</header> 
        <a href="/contact.cfm" class="link link-hover">Contact</a>
        <a href="/faq.cfm" class="link link-hover">FAQ</a>
        <a href="/report-issue.cfm" class="link link-hover">Report an Issue</a>
        <a href="/feedback.cfm" class="link link-hover">Feedback</a>
    </nav>
    
    <nav>
        <header class="footer-title">Legal</header> 
        <a href="/terms.cfm" class="link link-hover">Terms of Use</a>
        <a href="/privacy.cfm" class="link link-hover">Privacy Policy</a>
        <a href="/accessibility.cfm" class="link link-hover">Accessibility</a>
    </nav>
    
    <form class="text-center lg:text-left">
        <header class="footer-title">Stay Updated</header> 
        <fieldset class="form-control w-80">
            <label class="label">
                <span class="label-text">Enter your email address</span>
            </label>
            <div class="join">
                <input type="email" placeholder="username@mdanderson.org" class="input input-bordered join-item" /> 
                <button class="btn btn-primary join-item">Subscribe</button>
            </div>
            <label class="label">
                <span class="label-text-alt">Subscribe to receive updates about system maintenance and new features.</span>
            </label>
        </fieldset>
    </form>
</footer>

<footer class="footer footer-center p-4 bg-base-300 text-base-content">
    <aside>
        <p>Copyright © #year(now())# - MD Anderson Cancer Center. All rights reserved.</p>
    </aside>
</footer>
</cfoutput>
