// Theme Toggle System
(function() {
    // Get saved theme or default to dark
    const savedTheme = localStorage.getItem('theme') || 'dark';
    
    // Apply theme immediately to prevent flash
    document.documentElement.setAttribute('data-theme', savedTheme);
    
    // Wait for DOM to load
    document.addEventListener('DOMContentLoaded', function() {
        initThemeToggle();
    });
    
    function initThemeToggle() {
        // Create theme toggle button
        const toggleBtn = document.createElement('button');
        toggleBtn.id = 'themeToggle';
        toggleBtn.className = 'theme-toggle-btn';
        toggleBtn.setAttribute('aria-label', 'Toggle theme');
        toggleBtn.innerHTML = savedTheme === 'dark' ? '☀️' : '🌙';
        toggleBtn.title = savedTheme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode';
        
        // Add to body
        document.body.appendChild(toggleBtn);
        
        // Toggle theme on click
        toggleBtn.addEventListener('click', toggleTheme);
    }
    
    function toggleTheme() {
        const currentTheme = document.documentElement.getAttribute('data-theme');
        const newTheme = currentTheme === 'dark' ? 'light' : 'dark';
        
        // Update theme
        document.documentElement.setAttribute('data-theme', newTheme);
        localStorage.setItem('theme', newTheme);
        
        // Update button
        const toggleBtn = document.getElementById('themeToggle');
        toggleBtn.innerHTML = newTheme === 'dark' ? '☀️' : '🌙';
        toggleBtn.title = newTheme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode';
        
        // Smooth transition
        document.body.style.transition = 'background-color 0.3s ease, color 0.3s ease';
    }
})();
