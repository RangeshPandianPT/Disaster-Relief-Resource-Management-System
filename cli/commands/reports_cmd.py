"""
Report generation CLI commands.
"""

import click
from tabulate import tabulate
from db_connection import execute_query


@click.group()
def report():
    """Report generation commands."""
    pass


@report.command('dashboard')
def dashboard():
    """Display main dashboard summary."""
    click.echo("\n" + "=" * 60)
    click.echo("    🌍 DRRMS DASHBOARD - Disaster Relief Management")
    click.echo("=" * 60)
    
    # Active disasters
    disasters = execute_query("""
        SELECT COUNT(*) as count, 
               SUM(CASE WHEN severity = 'Extreme' THEN 1 ELSE 0 END) as extreme,
               SUM(CASE WHEN severity = 'Severe' THEN 1 ELSE 0 END) as severe
        FROM Disaster WHERE status = 'Active'
    """)
    
    if disasters:
        d = disasters[0]
        click.echo(f"\n🌀 Active Disasters: {d['count']}")
        click.echo(f"   🔴 Extreme: {d['extreme']}  |  🟠 Severe: {d['severe']}")
    
    # Affected population
    population = execute_query("""
        SELECT SUM(aa.population_affected) as total
        FROM Affected_Area aa
        INNER JOIN Disaster d ON aa.disaster_id = d.disaster_id
        WHERE d.status = 'Active'
    """)
    
    if population and population[0]['total']:
        click.echo(f"\n👥 Total Affected Population: {population[0]['total']:,}")
    
    # Pending requests
    requests = execute_query("""
        SELECT 
            COUNT(*) as total,
            SUM(CASE WHEN urgency = 'Critical' THEN 1 ELSE 0 END) as critical,
            SUM(CASE WHEN urgency = 'High' THEN 1 ELSE 0 END) as high
        FROM Request WHERE status = 'Pending'
    """)
    
    if requests:
        r = requests[0]
        click.echo(f"\n📋 Pending Requests: {r['total']}")
        click.echo(f"   🔴 Critical: {r['critical']}  |  🟠 High: {r['high']}")
    
    # Low stock alerts
    alerts = execute_query("""
        SELECT COUNT(*) as count
        FROM Inventory i
        INNER JOIN Resource r ON i.resource_id = r.resource_id
        WHERE i.quantity_available < r.min_stock
    """)
    
    if alerts:
        click.echo(f"\n⚠️  Low Stock Alerts: {alerts[0]['count']}")
    
    # Active volunteers
    volunteers = execute_query("""
        SELECT 
            COUNT(*) as total,
            SUM(CASE WHEN availability = 'Busy' THEN 1 ELSE 0 END) as deployed
        FROM Volunteer
    """)
    
    if volunteers:
        v = volunteers[0]
        click.echo(f"\n👷 Volunteers: {v['deployed']} deployed / {v['total']} total")
    
    # Recent donations
    donations = execute_query("""
        SELECT 
            COALESCE(SUM(CASE WHEN donation_type = 'Money' THEN amount ELSE 0 END), 0) as monetary,
            COUNT(CASE WHEN donation_type = 'Material' THEN 1 END) as material_count
        FROM Donation
        WHERE donation_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
    """)
    
    if donations:
        dn = donations[0]
        click.echo(f"\n💰 Donations (30 days): ₹{dn['monetary']:,.0f}")
        click.echo(f"   📦 Material donations: {dn['material_count']}")
    
    click.echo("\n" + "=" * 60)


@report.command('donations')
@click.option('--month', '-m', type=int, help='Month (1-12)')
@click.option('--year', '-y', type=int, default=2024, help='Year')
def donation_report(month, year):
    """Generate donation report."""
    query = """
        SELECT 
            d.donor_name, d.donor_type,
            SUM(CASE WHEN dn.donation_type = 'Money' THEN dn.amount ELSE 0 END) as monetary,
            COUNT(CASE WHEN dn.donation_type = 'Material' THEN 1 END) as material_count
        FROM Donor d
        LEFT JOIN Donation dn ON d.donor_id = dn.donor_id
    """
    params = []
    
    if month:
        query += " WHERE MONTH(dn.donation_date) = %s AND YEAR(dn.donation_date) = %s"
        params = [month, year]
    
    query += """
        GROUP BY d.donor_id, d.donor_name, d.donor_type
        HAVING monetary > 0 OR material_count > 0
        ORDER BY monetary DESC
    """
    
    results = execute_query(query, params if params else None)
    
    period = f"{month}/{year}" if month else "All Time"
    click.echo(f"\n💰 Donation Report ({period})")
    click.echo("=" * 70)
    
    if results:
        table_data = []
        total_monetary = 0
        total_material = 0
        
        for r in results:
            type_icon = {'Corporate': '🏢', 'Individual': '👤', 'NGO': '🤝'}.get(r['donor_type'], '❓')
            table_data.append([
                f"{type_icon} {r['donor_name'][:25]}",
                r['donor_type'],
                f"₹{r['monetary']:,.0f}",
                r['material_count']
            ])
            total_monetary += r['monetary']
            total_material += r['material_count']
        
        click.echo(tabulate(table_data,
                           headers=['Donor', 'Type', 'Monetary', 'Material'],
                           tablefmt='rounded_grid'))
        
        click.echo(f"\nTotals: ₹{total_monetary:,.0f} monetary | {total_material} material donations")
    else:
        click.echo("No donations found for this period.")


@report.command('fulfillment')
def fulfillment_report():
    """Show request fulfillment report by disaster."""
    query = """
        SELECT 
            d.disaster_name,
            d.severity,
            COUNT(r.request_id) as total_requests,
            SUM(CASE WHEN r.status = 'Fulfilled' THEN 1 ELSE 0 END) as fulfilled,
            SUM(CASE WHEN r.status = 'Pending' THEN 1 ELSE 0 END) as pending,
            ROUND(SUM(CASE WHEN r.status = 'Fulfilled' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) as rate
        FROM Disaster d
        LEFT JOIN Affected_Area aa ON d.disaster_id = aa.disaster_id
        LEFT JOIN Request r ON aa.area_id = r.area_id
        WHERE d.status = 'Active'
        GROUP BY d.disaster_id, d.disaster_name, d.severity
        ORDER BY d.severity DESC
    """
    
    results = execute_query(query)
    
    click.echo("\n📊 Fulfillment Report - Active Disasters")
    click.echo("=" * 70)
    
    if results:
        for r in results:
            rate = r['rate'] or 0
            bar_len = int(rate / 5)
            bar = '█' * bar_len + '░' * (20 - bar_len)
            
            sev_icon = {'Extreme': '🔴', 'Severe': '🟠', 'Moderate': '🟡', 'Minor': '🟢'}.get(r['severity'], '⚪')
            
            click.echo(f"\n{sev_icon} {r['disaster_name']}")
            click.echo(f"   [{bar}] {rate:.1f}% fulfilled")
            click.echo(f"   Total: {r['total_requests']} | Fulfilled: {r['fulfilled']} | Pending: {r['pending']}")
    else:
        click.echo("No active disasters found.")


@report.command('inventory-summary')
def inventory_summary():
    """Inventory summary by category."""
    query = """
        SELECT 
            r.category,
            COUNT(DISTINCT r.resource_id) as resource_types,
            SUM(i.quantity_available) as total_stock,
            SUM(CASE WHEN i.quantity_available < r.min_stock THEN 1 ELSE 0 END) as low_stock_items
        FROM Resource r
        LEFT JOIN Inventory i ON r.resource_id = i.resource_id
        GROUP BY r.category
        ORDER BY total_stock DESC
    """
    
    results = execute_query(query)
    
    click.echo("\n📦 Inventory Summary by Category")
    click.echo("=" * 60)
    
    if results:
        table_data = []
        for r in results:
            cat_icon = {
                'Food': '🍚', 'Water': '💧', 'Medicine': '💊',
                'Shelter': '🏕️', 'Clothing': '👕'
            }.get(r['category'], '📦')
            
            alert = '⚠️' if r['low_stock_items'] > 0 else '✅'
            
            table_data.append([
                f"{cat_icon} {r['category']}",
                r['resource_types'],
                f"{r['total_stock']:,}" if r['total_stock'] else '0',
                f"{alert} {r['low_stock_items']}"
            ])
        
        click.echo(tabulate(table_data,
                           headers=['Category', 'Types', 'Total Stock', 'Low Stock'],
                           tablefmt='rounded_grid'))


@report.command('teams')
def teams_report():
    """Active teams report."""
    query = """
        SELECT 
            t.team_name, t.team_type, t.leader_name,
            d.disaster_name,
            COUNT(v.volunteer_id) as volunteer_count,
            aa.area_name
        FROM Relief_Team t
        INNER JOIN Disaster d ON t.disaster_id = d.disaster_id
        LEFT JOIN Affected_Area aa ON t.area_id = aa.area_id
        LEFT JOIN Volunteer v ON t.team_id = v.team_id
        WHERE t.status = 'Active'
        GROUP BY t.team_id, t.team_name, t.team_type, t.leader_name, 
                 d.disaster_name, aa.area_name
        ORDER BY d.disaster_name, t.team_type
    """
    
    results = execute_query(query)
    
    click.echo("\n👥 Active Relief Teams")
    click.echo("=" * 70)
    
    if results:
        current_disaster = None
        for r in results:
            if r['disaster_name'] != current_disaster:
                current_disaster = r['disaster_name']
                click.echo(f"\n🌀 {current_disaster}")
                click.echo("-" * 50)
            
            type_icon = {
                'Rescue': '🚑', 'Medical': '⚕️', 'Distribution': '📦',
                'Assessment': '📋', 'Logistics': '🚛'
            }.get(r['team_type'], '👷')
            
            click.echo(f"   {type_icon} {r['team_name']}")
            click.echo(f"      Leader: {r['leader_name']} | Volunteers: {r['volunteer_count']}")
            click.echo(f"      Area: {r['area_name'] or 'Not assigned'}")
    else:
        click.echo("No active teams found.")
