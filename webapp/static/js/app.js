/**
 * DRRMS Web Application JavaScript
 * Common utilities and functionality
 */

// Format large numbers
function formatNumber(num) {
    if (num === null || num === undefined) return '0';
    if (num >= 10000000) return (num / 10000000).toFixed(1) + 'Cr';
    if (num >= 100000) return (num / 100000).toFixed(1) + 'L';
    if (num >= 1000) return (num / 1000).toFixed(1) + 'K';
    return num.toLocaleString();
}

// Format currency
function formatCurrency(amount) {
    return '₹' + formatNumber(amount);
}

// Format date
function formatDate(dateStr) {
    if (!dateStr) return 'N/A';
    const date = new Date(dateStr);
    return date.toLocaleDateString('en-IN', {
        year: 'numeric',
        month: 'short',
        day: 'numeric'
    });
}

// Show notification
function showNotification(message, type = 'info') {
    const notification = document.createElement('div');
    notification.className = `notification ${type}`;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    setTimeout(() => {
        notification.classList.add('show');
    }, 10);
    
    setTimeout(() => {
        notification.classList.remove('show');
        setTimeout(() => notification.remove(), 300);
    }, 3000);
}

// API helper
async function api(endpoint, options = {}) {
    try {
        const response = await fetch(`/api${endpoint}`, {
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            },
            ...options
        });
        
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        
        return await response.json();
    } catch (error) {
        console.error('API Error:', error);
        showNotification('An error occurred. Please try again.', 'error');
        throw error;
    }
}

// Chart color palette
const chartColors = {
    primary: '#3b82f6',
    success: '#10b981',
    warning: '#f59e0b',
    danger: '#ef4444',
    info: '#06b6d4',
    purple: '#8b5cf6',
    pink: '#ec4899',
    gray: '#6b7280'
};

// Theme Management
function initTheme() {
    const savedTheme = localStorage.getItem('drrms-theme') || 'light';
    setTheme(savedTheme);
}

function setTheme(theme) {
    const html = document.documentElement;
    const themeIcon = document.getElementById('themeIcon');
    const themeText = document.getElementById('themeText');
    
    if (theme === 'dark') {
        html.setAttribute('data-theme', 'dark');
        if (themeIcon) themeIcon.textContent = '🌙';
        if (themeText) themeText.textContent = 'Dark';
        updateChartColors(true);
    } else {
        html.removeAttribute('data-theme');
        if (themeIcon) themeIcon.textContent = '☀️';
        if (themeText) themeText.textContent = 'Light';
        updateChartColors(false);
    }
    
    localStorage.setItem('drrms-theme', theme);
}

function toggleTheme() {
    const currentTheme = localStorage.getItem('drrms-theme') || 'light';
    const newTheme = currentTheme === 'light' ? 'dark' : 'light';
    setTheme(newTheme);
}

function updateChartColors(isDark) {
    if (typeof Chart !== 'undefined') {
        Chart.defaults.color = isDark ? '#94a3b8' : '#64748b';
        Chart.defaults.borderColor = isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)';
        
        // Update existing charts if any
        Chart.instances.forEach(chart => {
            if (chart.options.scales) {
                Object.values(chart.options.scales).forEach(scale => {
                    if (scale.grid) {
                        scale.grid.color = isDark ? 'rgba(255, 255, 255, 0.1)' : 'rgba(0, 0, 0, 0.1)';
                    }
                    if (scale.ticks) {
                        scale.ticks.color = isDark ? '#94a3b8' : '#64748b';
                    }
                });
            }
            chart.update('none');
        });
    }
}

// Initialize theme before page renders (prevent flash)
initTheme();

// ============================================================
// HAMBURGER MENU FUNCTIONALITY
// ============================================================

function initHamburgerMenu() {
    const hamburger = document.getElementById('hamburger');
    const navLinks = document.getElementById('navLinks');
    
    if (hamburger && navLinks) {
        hamburger.addEventListener('click', () => {
            hamburger.classList.toggle('active');
            navLinks.classList.toggle('active');
            
            // Update aria-expanded attribute
            const isExpanded = hamburger.classList.contains('active');
            hamburger.setAttribute('aria-expanded', isExpanded);
        });
        
        // Close menu when clicking on a link
        navLinks.querySelectorAll('a').forEach(link => {
            link.addEventListener('click', () => {
                hamburger.classList.remove('active');
                navLinks.classList.remove('active');
                hamburger.setAttribute('aria-expanded', 'false');
            });
        });
        
        // Close menu when clicking outside
        document.addEventListener('click', (e) => {
            if (!hamburger.contains(e.target) && !navLinks.contains(e.target)) {
                hamburger.classList.remove('active');
                navLinks.classList.remove('active');
                hamburger.setAttribute('aria-expanded', 'false');
            }
        });
    }
}

// ============================================================
// SCROLL TO TOP BUTTON
// ============================================================

function initScrollToTop() {
    const scrollToTopBtn = document.getElementById('scrollToTop');
    
    if (scrollToTopBtn) {
        // Show/hide button based on scroll position
        window.addEventListener('scroll', () => {
            if (window.scrollY > 300) {
                scrollToTopBtn.classList.add('visible');
            } else {
                scrollToTopBtn.classList.remove('visible');
            }
        }, { passive: true });
        
        // Scroll to top when clicked
        scrollToTopBtn.addEventListener('click', () => {
            window.scrollTo({
                top: 0,
                behavior: 'smooth'
            });
        });
    }
}

// ============================================================
// KEYBOARD NAVIGATION
// ============================================================

function initKeyboardNavigation() {
    // ESC key closes modals and menus
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            // Close hamburger menu
            const hamburger = document.getElementById('hamburger');
            const navLinks = document.getElementById('navLinks');
            if (hamburger && navLinks) {
                hamburger.classList.remove('active');
                navLinks.classList.remove('active');
                hamburger.setAttribute('aria-expanded', 'false');
            }
            
            // Close any open modals
            document.querySelectorAll('.modal:not(.hidden)').forEach(modal => {
                modal.classList.add('hidden');
            });
        }
    });
}

// ============================================================
// TOUCH GESTURES (for mobile)
// ============================================================

function initTouchGestures() {
    let touchStartX = 0;
    let touchEndX = 0;
    
    const navLinks = document.getElementById('navLinks');
    const hamburger = document.getElementById('hamburger');
    
    if (navLinks && hamburger) {
        // Swipe left to close menu
        document.addEventListener('touchstart', (e) => {
            touchStartX = e.changedTouches[0].screenX;
        }, { passive: true });
        
        document.addEventListener('touchend', (e) => {
            touchEndX = e.changedTouches[0].screenX;
            const swipeDistance = touchStartX - touchEndX;
            
            // Swipe left (close menu)
            if (swipeDistance > 50 && navLinks.classList.contains('active')) {
                hamburger.classList.remove('active');
                navLinks.classList.remove('active');
                hamburger.setAttribute('aria-expanded', 'false');
            }
        }, { passive: true });
    }
}

// ============================================================
// LOADING STATE HELPERS
// ============================================================

function showLoading(container) {
    if (container) {
        container.innerHTML = `
            <div class="skeleton skeleton-card"></div>
            <div class="skeleton skeleton-card"></div>
            <div class="skeleton skeleton-card"></div>
        `;
    }
}

function hideLoading(container, content) {
    if (container) {
        container.innerHTML = content;
    }
}

// ============================================================
// DEBOUNCE UTILITY
// ============================================================

function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

// ============================================================
// RESIZE HANDLER
// ============================================================

function initResizeHandler() {
    const handleResize = debounce(() => {
        // Close hamburger menu on resize to larger screen
        if (window.innerWidth > 768) {
            const hamburger = document.getElementById('hamburger');
            const navLinks = document.getElementById('navLinks');
            if (hamburger && navLinks) {
                hamburger.classList.remove('active');
                navLinks.classList.remove('active');
                hamburger.setAttribute('aria-expanded', 'false');
            }
        }
    }, 150);
    
    window.addEventListener('resize', handleResize, { passive: true });
}

// ============================================================
// PAGE READY
// ============================================================

document.addEventListener('DOMContentLoaded', () => {
    console.log('🌍 DRRMS Web Application Loaded');
    
    // Initialize theme toggle
    const themeToggle = document.getElementById('themeToggle');
    if (themeToggle) {
        themeToggle.addEventListener('click', toggleTheme);
    }
    
    // Re-apply theme on DOM load
    const savedTheme = localStorage.getItem('drrms-theme') || 'light';
    setTheme(savedTheme);
    
    // Initialize all mobile features
    initHamburgerMenu();
    initScrollToTop();
    initKeyboardNavigation();
    initTouchGestures();
    initResizeHandler();
    
    // Add fade-in animation to main content
    const mainContent = document.querySelector('.main-content');
    if (mainContent) {
        mainContent.classList.add('fade-in');
    }
    
    // Mark page as loaded for any loading animations
    document.body.classList.add('loaded');
});

// ============================================================
// VISIBILITY CHANGE HANDLER
// ============================================================

document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') {
        // Re-sync theme when tab becomes visible
        const savedTheme = localStorage.getItem('drrms-theme') || 'light';
        setTheme(savedTheme);
    }
});

