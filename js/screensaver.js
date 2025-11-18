// Screensaver functionality
class Screensaver {
  constructor() {
    this.idleTime = 0;
    this.idleThreshold = 5 * 60; // 5 minutes in seconds
    this.idleInterval = null;
    this.isActive = false;
    this.overlay = null;
    
    this.init();
  }
  
  init() {
    // Create the screensaver overlay
    this.createOverlay();
    
    // Start monitoring user activity
    this.startMonitoring();
    
    // Add event listeners for user activity
    this.addActivityListeners();
  }
  
  createOverlay() {
    // Create the screensaver overlay element
    this.overlay = document.createElement('div');
    this.overlay.className = 'screensaver-overlay';
    this.overlay.id = 'screensaver-overlay';
    
    this.overlay.innerHTML = `
      <div class="screensaver-logo">💬</div>
      <h1 class="screensaver-title">Quick Chat</h1>
      <div class="screensaver-time" id="screensaver-time"></div>
      <div class="screensaver-message">App is locked due to inactivity. Click below to unlock.</div>
      <button class="screensaver-unlock" id="screensaver-unlock">Unlock App</button>
    `;
    
    document.body.appendChild(this.overlay);
    
    // Add event listener to unlock button
    document.getElementById('screensaver-unlock').addEventListener('click', () => {
      this.deactivate();
    });
    
    // Update time every second
    setInterval(() => {
      this.updateTime();
    }, 1000);
  }
  
  updateTime() {
    if (this.overlay) {
      const now = new Date();
      const timeString = now.toLocaleTimeString();
      document.getElementById('screensaver-time').textContent = timeString;
    }
  }
  
  startMonitoring() {
    // Reset idle time on any activity
    this.idleInterval = setInterval(() => {
      this.idleTime++;
      
      // Activate screensaver if idle time exceeds threshold
      if (this.idleTime >= this.idleThreshold && !this.isActive) {
        this.activate();
      }
    }, 1000);
  }
  
  addActivityListeners() {
    // Reset idle time on user activity
    const events = ['mousedown', 'mousemove', 'keypress', 'scroll', 'touchstart', 'click'];
    
    events.forEach(event => {
      document.addEventListener(event, () => {
        this.resetIdleTime();
      }, true);
    });
    
    // Also reset on window focus
    window.addEventListener('focus', () => {
      this.resetIdleTime();
    });
  }
  
  resetIdleTime() {
    this.idleTime = 0;
  }
  
  activate() {
    this.isActive = true;
    this.overlay.classList.add('active');
    
    // Pause any ongoing activities if needed
    this.onPause();
  }
  
  deactivate() {
    this.isActive = false;
    this.overlay.classList.remove('active');
    this.resetIdleTime();
    
    // Resume activities
    this.onResume();
  }
  
  onPause() {
    // Pause any ongoing activities (e.g., notifications, animations)
    // This can be extended based on app requirements
  }
  
  onResume() {
    // Resume activities when screensaver is deactivated
    // This can be extended based on app requirements
  }
  
  // Method to manually set idle threshold (in seconds)
  setIdleThreshold(seconds) {
    this.idleThreshold = seconds;
  }
  
  // Method to manually activate screensaver
  forceActivate() {
    this.activate();
  }
  
  // Method to manually deactivate screensaver
  forceDeactivate() {
    this.deactivate();
  }
}

// Initialize screensaver when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
  // Only initialize screensaver on chat page
  if (window.location.pathname.includes('chat.html')) {
    window.screensaver = new Screensaver();
  }
});

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = Screensaver;
}