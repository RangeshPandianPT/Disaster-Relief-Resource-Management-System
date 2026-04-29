/**
 * DRRMS Live Alerts System
 * Feature 3: Real-Time Polling for Critical Events
 */

let shownAlerts = new Set();
let initialAlertPopupShown = sessionStorage.getItem('drrms-initial-alert-popup-shown') === 'true';
// We'll poll every 15 seconds for demonstration purposes
const POLL_INTERVAL = 15000;

document.addEventListener('DOMContentLoaded', () => {
    // Initial fetch
    fetchLiveAlerts(true);
    
    // Set up polling
    setInterval(() => fetchLiveAlerts(false), POLL_INTERVAL);
});

async function fetchLiveAlerts(isInitialLoad = false) {
    try {
        const response = await fetch('/api/live_alerts');
        if (!response.ok) return;
        
        const alerts = await response.json();
        let newAlertsCount = 0;
        const shouldShowPopups = isInitialLoad && !initialAlertPopupShown;
        
        alerts.forEach(alert => {
            if (!shownAlerts.has(alert.id)) {
                // New alert found
                shownAlerts.add(alert.id);
                if (shouldShowPopups) {
                    showToast(alert);
                }
                newAlertsCount++;
            }
        });

        if (shouldShowPopups) {
            initialAlertPopupShown = true;
            sessionStorage.setItem('drrms-initial-alert-popup-shown', 'true');
        }
        
        updateBadge(newAlertsCount);
    } catch (error) {
        console.error('Error fetching live alerts:', error);
    }
}

function showToast(alert) {
    const container = document.getElementById('toast-container');
    if (!container) return;
    
    const toast = document.createElement('div');
    toast.className = `toast ${alert.severity}`;
    
    const icon = alert.severity === 'critical' ? 'Critical' : 'Warning';
    
    toast.innerHTML = `
        <div style="display: flex; justify-content: space-between; align-items: start; margin-bottom: 5px;">
            <strong style="display: flex; align-items: center; gap: 5px;">
                <span>${icon}</span> ${alert.title}
            </strong>
        </div>
        <p style="margin: 0; font-size: 0.85rem; color: var(--text-secondary);">
            New event detected.
            ${alert.link ? `<a href="${alert.link}" style="color: var(--accent-primary); text-decoration: none; font-weight: 500;">View Details →</a>` : ''}
        </p>
    `;
    
    container.appendChild(toast);
    
    // Auto remove after 2 seconds
    setTimeout(() => {
        toast.classList.add('hiding');
        setTimeout(() => {
            if (toast.parentNode) {
                toast.parentNode.removeChild(toast);
            }
        }, 300); // Wait for fade out animation
    }, 2000);
}

function updateBadge(newCount) {
    const badge = document.getElementById('notif-badge');
    if (!badge) return;
    
    // For a real app we might keep a running total, here we just show an active dot
    // if there have been any new alerts this polling cycle
    let currentTotal = shownAlerts.size;
    
    if (currentTotal > 0) {
        badge.textContent = currentTotal > 9 ? '9+' : currentTotal;
        badge.classList.add('visible');
    }
}
