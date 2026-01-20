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

// Page ready
document.addEventListener('DOMContentLoaded', () => {
    console.log('🌍 DRRMS Web Application Loaded');
    
    // Setup theme toggle button
    const themeToggle = document.getElementById('themeToggle');
    if (themeToggle) {
        themeToggle.addEventListener('click', toggleTheme);
    }
    
    // Re-apply theme on DOM load to ensure UI is correct
    const savedTheme = localStorage.getItem('drrms-theme') || 'light';
    setTheme(savedTheme);
});
