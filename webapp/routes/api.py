"""
REST API endpoints for DRRMS.
"""

from flask import Blueprint, jsonify, request
from models.database import query_db

api = Blueprint('api', __name__, url_prefix='/api')


# ============================================================
# DASHBOARD API
# ============================================================

@api.route('/dashboard/stats')
def dashboard_stats():
    """Get dashboard statistics."""
    stats = {}
    
    # Active disasters
    result = query_db("""
        SELECT COUNT(*) as count,
               SUM(CASE WHEN severity = 'Extreme' THEN 1 ELSE 0 END) as extreme,
               SUM(CASE WHEN severity = 'Severe' THEN 1 ELSE 0 END) as severe
        FROM Disaster WHERE status = 'Active'
    """, one=True)
    stats['disasters'] = result
    
    # Affected population
    result = query_db("""
        SELECT COALESCE(SUM(aa.population_affected), 0) as total
        FROM Affected_Area aa
        INNER JOIN Disaster d ON aa.disaster_id = d.disaster_id
        WHERE d.status = 'Active'
    """, one=True)
    stats['population'] = result['total'] if result else 0
    
    # Pending requests
    result = query_db("""
        SELECT COUNT(*) as total,
               SUM(CASE WHEN urgency = 'Critical' THEN 1 ELSE 0 END) as critical,
               SUM(CASE WHEN urgency = 'High' THEN 1 ELSE 0 END) as high
        FROM Request WHERE status = 'Pending'
    """, one=True)
    stats['requests'] = result
    
    # Volunteers
    result = query_db("""
        SELECT COUNT(*) as total,
               SUM(CASE WHEN availability = 'Busy' THEN 1 ELSE 0 END) as deployed
        FROM Volunteer
    """, one=True)
    stats['volunteers'] = result
    
    # Low stock alerts
    result = query_db("""
        SELECT COUNT(*) as count
        FROM Inventory i
        INNER JOIN Resource r ON i.resource_id = r.resource_id
        WHERE i.quantity_available < r.min_stock
    """, one=True)
    stats['lowStock'] = result['count'] if result else 0
    
    # Recent donations (30 days)
    result = query_db("""
        SELECT COALESCE(SUM(amount), 0) as monetary,
               COUNT(*) as count
        FROM Donation
        WHERE donation_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    """, one=True)
    stats['donations'] = result
    
    return jsonify(stats)


# ============================================================
# CHART DATA API
# ============================================================

@api.route('/charts/disaster-types')
def chart_disaster_types():
    """Get disaster type distribution for pie chart."""
    result = query_db("""
        SELECT disaster_type as label, COUNT(*) as value
        FROM Disaster
        GROUP BY disaster_type
        ORDER BY value DESC
    """)
    return jsonify(result or [])


@api.route('/charts/resource-levels')
def chart_resource_levels():
    """Get resource levels by category for bar chart."""
    result = query_db("""
        SELECT r.category as label,
               COALESCE(SUM(i.quantity_available), 0) as available,
               COALESCE(SUM(r.min_stock), 0) as minimum
        FROM Resource r
        LEFT JOIN Inventory i ON r.resource_id = i.resource_id
        GROUP BY r.category
        ORDER BY available DESC
    """)
    return jsonify(result or [])


@api.route('/charts/donation-trends')
def chart_donation_trends():
    """Get donation trends for line chart."""
    result = query_db("""
        SELECT DATE_FORMAT(donation_date, '%%Y-%%m') as month,
               SUM(CASE WHEN donation_type = 'Money' THEN amount ELSE 0 END) as monetary,
               COUNT(CASE WHEN donation_type = 'Material' THEN 1 END) as material
        FROM Donation
        WHERE donation_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
        GROUP BY DATE_FORMAT(donation_date, '%%Y-%%m')
        ORDER BY month
    """)
    return jsonify(result or [])


@api.route('/charts/request-status')
def chart_request_status():
    """Get request status distribution."""
    result = query_db("""
        SELECT status as label, COUNT(*) as value
        FROM Request
        GROUP BY status
    """)
    return jsonify(result or [])


@api.route('/charts/fulfillment-rate')
def chart_fulfillment_rate():
    """Get fulfillment rate for gauge chart."""
    result = query_db("""
        SELECT 
            COUNT(*) as total,
            SUM(CASE WHEN status = 'Fulfilled' THEN 1 ELSE 0 END) as fulfilled
        FROM Request
    """, one=True)
    
    if result and result['total'] > 0:
        rate = (result['fulfilled'] / result['total']) * 100
    else:
        rate = 0
    
    return jsonify({'rate': round(rate, 1), 'total': result['total'] if result else 0})


# ============================================================
# DISASTERS API
# ============================================================

@api.route('/disasters')
def get_disasters():
    """Get all disasters."""
    status = request.args.get('status')
    
    query = """
        SELECT d.*, 
               COUNT(DISTINCT aa.area_id) as area_count,
               COALESCE(SUM(aa.population_affected), 0) as total_affected
        FROM Disaster d
        LEFT JOIN Affected_Area aa ON d.disaster_id = aa.disaster_id
    """
    params = []
    
    if status:
        query += " WHERE d.status = %s"
        params.append(status)
    
    query += " GROUP BY d.disaster_id ORDER BY d.start_date DESC"
    
    result = query_db(query, params)
    
    # Convert dates to strings
    if result:
        for r in result:
            if r.get('start_date'):
                r['start_date'] = r['start_date'].strftime('%Y-%m-%d')
            if r.get('end_date'):
                r['end_date'] = r['end_date'].strftime('%Y-%m-%d')
    
    return jsonify(result or [])


@api.route('/disasters/<int:disaster_id>')
def get_disaster(disaster_id):
    """Get single disaster with details."""
    disaster = query_db(
        "SELECT * FROM Disaster WHERE disaster_id = %s",
        (disaster_id,), one=True
    )
    
    if not disaster:
        return jsonify({'error': 'Not found'}), 404
    
    # Get affected areas
    areas = query_db("""
        SELECT * FROM Affected_Area WHERE disaster_id = %s
    """, (disaster_id,))
    
    # Get teams
    teams = query_db("""
        SELECT t.*, COUNT(v.volunteer_id) as volunteer_count
        FROM Relief_Team t
        LEFT JOIN Volunteer v ON t.team_id = v.team_id
        WHERE t.disaster_id = %s
        GROUP BY t.team_id
    """, (disaster_id,))
    
    # Format dates
    if disaster.get('start_date'):
        disaster['start_date'] = disaster['start_date'].strftime('%Y-%m-%d')
    if disaster.get('end_date'):
        disaster['end_date'] = disaster['end_date'].strftime('%Y-%m-%d')
    
    if teams:
        for t in teams:
            if t.get('formed_date'):
                t['formed_date'] = t['formed_date'].strftime('%Y-%m-%d')
    
    return jsonify({
        'disaster': disaster,
        'areas': areas or [],
        'teams': teams or []
    })


# ============================================================
# INVENTORY API
# ============================================================

@api.route('/inventory')
def get_inventory():
    """Get inventory list."""
    category = request.args.get('category')
    low_stock = request.args.get('lowStock') == 'true'
    
    query = """
        SELECT i.*, r.resource_name, r.category, r.unit, r.min_stock,
               CASE 
                   WHEN i.quantity_available = 0 THEN 'OUT'
                   WHEN i.quantity_available < r.min_stock THEN 'LOW'
                   ELSE 'OK'
               END as stock_status
        FROM Inventory i
        INNER JOIN Resource r ON i.resource_id = r.resource_id
        WHERE 1=1
    """
    params = []
    
    if category:
        query += " AND r.category = %s"
        params.append(category)
    
    if low_stock:
        query += " AND i.quantity_available < r.min_stock"
    
    query += " ORDER BY r.category, r.resource_name"
    
    result = query_db(query, params)
    return jsonify(result or [])


@api.route('/inventory/alerts')
def get_inventory_alerts():
    """Get low stock alerts."""
    result = query_db("""
        SELECT r.resource_name, r.category, i.warehouse_location,
               i.quantity_available, r.min_stock,
               ROUND((i.quantity_available / r.min_stock) * 100, 1) as stock_pct
        FROM Inventory i
        INNER JOIN Resource r ON i.resource_id = r.resource_id
        WHERE i.quantity_available < r.min_stock
        ORDER BY (i.quantity_available / r.min_stock)
    """)
    return jsonify(result or [])


# ============================================================
# REQUESTS API
# ============================================================

@api.route('/requests')
def get_requests():
    """Get resource requests."""
    status = request.args.get('status')
    urgency = request.args.get('urgency')
    
    query = """
        SELECT r.*, aa.area_name, res.resource_name, res.unit
        FROM Request r
        INNER JOIN Affected_Area aa ON r.area_id = aa.area_id
        INNER JOIN Resource res ON r.resource_id = res.resource_id
        WHERE 1=1
    """
    params = []
    
    if status:
        query += " AND r.status = %s"
        params.append(status)
    
    if urgency:
        query += " AND r.urgency = %s"
        params.append(urgency)
    
    query += " ORDER BY FIELD(r.urgency, 'Critical', 'High', 'Medium', 'Low'), r.request_date DESC LIMIT 100"
    
    result = query_db(query, params)
    
    # Format dates
    if result:
        for r in result:
            if r.get('request_date'):
                r['request_date'] = r['request_date'].strftime('%Y-%m-%d %H:%M')
    
    return jsonify(result or [])


@api.route('/requests', methods=['POST'])
def create_request():
    """Create a new request."""
    data = request.get_json()
    
    result = query_db("""
        INSERT INTO Request (area_id, resource_id, quantity_requested, urgency, status, remarks)
        VALUES (%s, %s, %s, %s, 'Pending', %s)
    """, (
        data['area_id'],
        data['resource_id'],
        data['quantity_requested'],
        data.get('urgency', 'Medium'),
        data.get('remarks', '')
    ))
    
    if result:
        return jsonify({'id': result, 'message': 'Request created'}), 201
    return jsonify({'error': 'Failed to create request'}), 400


# ============================================================
# VOLUNTEERS API
# ============================================================

@api.route('/volunteers')
def get_volunteers():
    """Get volunteer list."""
    availability = request.args.get('availability')
    
    query = """
        SELECT v.*, t.team_name, t.team_type, d.disaster_name
        FROM Volunteer v
        LEFT JOIN Relief_Team t ON v.team_id = t.team_id
        LEFT JOIN Disaster d ON t.disaster_id = d.disaster_id
        WHERE 1=1
    """
    params = []
    
    if availability:
        query += " AND v.availability = %s"
        params.append(availability)
    
    query += " ORDER BY v.name"
    
    result = query_db(query, params)
    return jsonify(result or [])


# ============================================================
# DONATIONS API
# ============================================================

@api.route('/donations')
def get_donations():
    """Get donation list."""
    result = query_db("""
        SELECT dn.*, d.disaster_name, don.donor_name, don.donor_type,
               r.resource_name
        FROM Donation dn
        INNER JOIN Donor don ON dn.donor_id = don.donor_id
        LEFT JOIN Disaster d ON dn.disaster_id = d.disaster_id
        LEFT JOIN Resource r ON dn.resource_id = r.resource_id
        ORDER BY dn.donation_date DESC
        LIMIT 100
    """)
    
    # Format dates
    if result:
        for r in result:
            if r.get('donation_date'):
                r['donation_date'] = r['donation_date'].strftime('%Y-%m-%d')
    
    return jsonify(result or [])


@api.route('/donors')
def get_donors():
    """Get donor list with summary."""
    result = query_db("""
        SELECT d.*, 
               COUNT(dn.donation_id) as donation_count,
               COALESCE(SUM(CASE WHEN dn.donation_type = 'Money' THEN dn.amount ELSE 0 END), 0) as total_monetary
        FROM Donor d
        LEFT JOIN Donation dn ON d.donor_id = dn.donor_id
        GROUP BY d.donor_id
        ORDER BY total_monetary DESC
    """)
    return jsonify(result or [])
