/**
 * DRRMS Interactive Disaster Map
 * Feature 1: Leaflet.js Implementation
 */

let disasterMap = null;
let markersLayer = null;

// Initialize the map
function initDisasterMap() {
    if (disasterMap) {
        // Map is already initialized, just ensure it renders properly
        setTimeout(() => disasterMap.invalidateSize(), 200);
        return;
    }

    const mapContainer = document.getElementById('map-container');
    if (!mapContainer) return;

    // Default center (India roughly) and zoom
    disasterMap = L.map('map-container').setView([20.5937, 78.9629], 5);

    // Add CartoDB Positron tile layer (clean, modern look, good for dark/light themes)
    L.tileLayer('https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png', {
        attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>',
        subdomains: 'abcd',
        maxZoom: 20
    }).addTo(disasterMap);

    markersLayer = L.layerGroup().addTo(disasterMap);

    // Load geospatial data
    loadDisastersGeo();
}

async function loadDisastersGeo() {
    if (!disasterMap || !markersLayer) return;
    
    const statusFilter = document.getElementById('status-filter')?.value || '';
    const url = statusFilter ? `/api/disasters_geo?status=${statusFilter}` : '/api/disasters_geo';

    try {
        const response = await fetch(url);
        const geojson = await response.json();

        // Clear existing markers
        markersLayer.clearLayers();

        // Add markers for each feature
        if (geojson.features && geojson.features.length > 0) {
            L.geoJSON(geojson, {
                pointToLayer: function (feature, latlng) {
                    return createCustomMarker(feature, latlng);
                },
                onEachFeature: function (feature, layer) {
                    bindPopupToMarker(feature, layer);
                }
            }).addTo(markersLayer);
            
            // Adjust map bounds to fit all markers if any exist
            if (markersLayer.getLayers().length > 0) {
                const group = new L.featureGroup(markersLayer.getLayers());
                disasterMap.fitBounds(group.getBounds(), { padding: [50, 50] });
            }
        }
    } catch (error) {
        console.error('Error loading map data:', error);
    }
}

// Custom styling based on severity and status
function createCustomMarker(feature, latlng) {
    const props = feature.properties;
    let color = '#3b82f6'; // Default Blue (Monitoring/Active)
    let radius = 8;
    
    // Status overrides color generally
    if (props.status === 'Resolved') {
        color = '#10b981'; // Green
        radius = 6;
    } else {
        // Severity dictates color and size if active/monitoring
        switch(props.severity) {
            case 'Extreme':
                color = '#ef4444'; // Red
                radius = 12;
                break;
            case 'Severe':
                color = '#f97316'; // Orange
                radius = 10;
                break;
            case 'Moderate':
                color = '#eab308'; // Yellow
                radius = 8;
                break;
            case 'Minor':
                color = '#3b82f6'; // Blue
                radius = 6;
                break;
        }
    }

    const markerStyle = {
        radius: radius,
        fillColor: color,
        color: '#ffffff',
        weight: 2,
        opacity: 1,
        fillOpacity: 0.8
    };

    // Add a pulsing effect to critical active disasters
    if (props.status === 'Active' && (props.severity === 'Extreme' || props.severity === 'Severe')) {
        // Instead of complex CSS animations on canvas, we use CircleMarker and add an extra Circle for 'glow'
        L.circle(latlng, {
            radius: radius * 3000, // meters, approx
            color: color,
            weight: 0,
            fillColor: color,
            fillOpacity: 0.2
        }).addTo(markersLayer);
    }

    return L.circleMarker(latlng, markerStyle);
}

function bindPopupToMarker(feature, layer) {
    const p = feature.properties;
    
    let severityBadgeDetails = getBadgeClass(p.severity, 'severity');
    let statusBadgeDetails = getBadgeClass(p.status, 'status');
    
    const popupContent = `
        <div style="min-width: 200px; font-family: 'Inter', sans-serif;">
            <div style="display: flex; justify-content: space-between; align-items: center; border-bottom: 1px solid #e2e8f0; padding-bottom: 8px; margin-bottom: 8px;">
                <strong style="font-size: 1.1em; color: #1e293b;">${p.name}</strong>
            </div>
            <div style="margin-bottom: 8px;">
                <span style="display: inline-block; padding: 2px 6px; border-radius: 4px; font-size: 0.75em; font-weight: 600; background: ${severityBadgeDetails.bg}; color: ${severityBadgeDetails.color}; margin-right: 4px;">${p.severity}</span>
                <span style="display: inline-block; padding: 2px 6px; border-radius: 4px; font-size: 0.75em; font-weight: 600; background: ${statusBadgeDetails.bg}; color: ${statusBadgeDetails.color};">${p.status}</span>
            </div>
            <p style="margin: 4px 0; font-size: 0.9em; color: #475569;"><strong>Type:</strong> ${p.type}</p>
            <p style="margin: 4px 0; font-size: 0.9em; color: #475569;"><strong>Location:</strong> ${p.district}, ${p.state}</p>
            <p style="margin: 4px 0; font-size: 0.9em; color: #475569;"><strong>Affected:</strong> ${p.affected.toLocaleString()}</p>
            
            <button onclick="document.querySelector('.leaflet-popup-close-button').click(); viewDisaster(${p.disaster_id});" style="margin-top: 10px; width: 100%; padding: 6px; background: #3b82f6; color: white; border: none; border-radius: 4px; cursor: pointer; font-weight: 500;">
                View Details
            </button>
        </div>
    `;
    
    layer.bindPopup(popupContent, {
        className: 'custom-popup'
    });
}

// Helper to match colors with main application
function getBadgeClass(val, type) {
    if (val === 'Extreme' || val === 'Critical') return { bg: 'rgba(239, 68, 68, 0.2)', color: '#ef4444' };
    if (val === 'Severe' || val === 'High') return { bg: 'rgba(249, 115, 22, 0.2)', color: '#f97316' };
    if (val === 'Moderate' || val === 'Monitoring') return { bg: 'rgba(234, 179, 8, 0.2)', color: '#eab308' };
    if (val === 'Minor' || val === 'Active') return { bg: 'rgba(34, 197, 94, 0.2)', color: '#22c55e' };
    if (val === 'Resolved') return { bg: 'rgba(59, 130, 246, 0.2)', color: '#3b82f6' };
    return { bg: '#f1f5f9', color: '#64748b' };
}

// Re-fetch map data when select filter changes
document.addEventListener('DOMContentLoaded', () => {
    const selectFilter = document.getElementById('status-filter');
    if (selectFilter) {
        selectFilter.addEventListener('change', () => {
            if (disasterMap && !document.getElementById('map-container').classList.contains('hidden')) {
                loadDisastersGeo();
            }
        });
    }
});
