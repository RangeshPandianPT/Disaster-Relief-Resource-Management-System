"""
Disaster management CLI commands.
"""

import click
from tabulate import tabulate
from db_connection import execute_query, call_procedure


@click.group()
def disaster():
    """Disaster management commands."""
    pass


@disaster.command('list')
@click.option('--status', '-s', type=click.Choice(['Active', 'Resolved', 'Monitoring']), 
              help='Filter by status')
@click.option('--limit', '-l', default=10, help='Number of records to show')
def list_disasters(status, limit):
    """List all disasters."""
    query = "SELECT disaster_id, disaster_name, disaster_type, severity, status, start_date FROM Disaster"
    params = []
    
    if status:
        query += " WHERE status = %s"
        params.append(status)
    
    query += f" ORDER BY start_date DESC LIMIT {limit}"
    
    results = execute_query(query, params)
    
    if results:
        # Format for display
        table_data = []
        for r in results:
            severity_icon = {'Extreme': '🔴', 'Severe': '🟠', 'Moderate': '🟡', 'Minor': '🟢'}.get(r['severity'], '⚪')
            status_icon = '✅' if r['status'] == 'Resolved' else '🔄' if r['status'] == 'Active' else '👁️'
            table_data.append([
                r['disaster_id'],
                r['disaster_name'],
                r['disaster_type'],
                f"{severity_icon} {r['severity']}",
                f"{status_icon} {r['status']}",
                r['start_date'].strftime('%Y-%m-%d') if r['start_date'] else 'N/A'
            ])
        
        click.echo("\n📋 Disaster List:")
        click.echo(tabulate(table_data, 
                           headers=['ID', 'Name', 'Type', 'Severity', 'Status', 'Start Date'],
                           tablefmt='rounded_grid'))
        click.echo(f"\nTotal: {len(results)} disaster(s)")
    else:
        click.echo("No disasters found.")


@disaster.command('add')
@click.option('--name', '-n', required=True, help='Disaster name')
@click.option('--type', '-t', 'dtype', required=True, 
              type=click.Choice(['Flood', 'Cyclone', 'Earthquake', 'Drought', 'Landslide', 'Other']),
              help='Disaster type')
@click.option('--severity', '-s', required=True,
              type=click.Choice(['Minor', 'Moderate', 'Severe', 'Extreme']),
              help='Severity level')
@click.option('--location', '-l', required=True, help='Primary affected location')
def add_disaster(name, dtype, severity, location):
    """Add a new disaster."""
    query = """
        INSERT INTO Disaster (disaster_name, disaster_type, severity, affected_location, status, start_date)
        VALUES (%s, %s, %s, %s, 'Active', CURDATE())
    """
    
    result = execute_query(query, (name, dtype, severity, location), fetch=False)
    
    if result:
        click.echo(f"✅ Disaster '{name}' added successfully! (ID: {result})")
    else:
        click.echo("❌ Failed to add disaster.")


@disaster.command('view')
@click.argument('disaster_id', type=int)
def view_disaster(disaster_id):
    """View detailed disaster information."""
    # Get disaster details
    query = "SELECT * FROM Disaster WHERE disaster_id = %s"
    disaster = execute_query(query, (disaster_id,))
    
    if not disaster:
        click.echo(f"❌ Disaster with ID {disaster_id} not found.")
        return
    
    d = disaster[0]
    click.echo(f"\n🌀 Disaster Details: {d['disaster_name']}")
    click.echo("=" * 50)
    click.echo(f"  ID:         {d['disaster_id']}")
    click.echo(f"  Type:       {d['disaster_type']}")
    click.echo(f"  Severity:   {d['severity']}")
    click.echo(f"  Status:     {d['status']}")
    click.echo(f"  Location:   {d['affected_location']}")
    click.echo(f"  Start Date: {d['start_date']}")
    click.echo(f"  End Date:   {d.get('end_date', 'Ongoing')}")
    
    # Get affected areas
    areas_query = """
        SELECT area_name, district, state, population_affected, priority 
        FROM Affected_Area WHERE disaster_id = %s
    """
    areas = execute_query(areas_query, (disaster_id,))
    
    if areas:
        click.echo(f"\n📍 Affected Areas ({len(areas)}):")
        area_data = [[a['area_name'], a['district'], a['state'], 
                      f"{a['population_affected']:,}", a['priority']] for a in areas]
        click.echo(tabulate(area_data, 
                           headers=['Area', 'District', 'State', 'Population', 'Priority'],
                           tablefmt='simple'))
    
    # Get teams
    teams_query = """
        SELECT team_name, team_type, leader_name, status
        FROM Relief_Team WHERE disaster_id = %s
    """
    teams = execute_query(teams_query, (disaster_id,))
    
    if teams:
        click.echo(f"\n👥 Relief Teams ({len(teams)}):")
        team_data = [[t['team_name'], t['team_type'], t['leader_name'], t['status']] for t in teams]
        click.echo(tabulate(team_data,
                           headers=['Team', 'Type', 'Leader', 'Status'],
                           tablefmt='simple'))


@disaster.command('update')
@click.argument('disaster_id', type=int)
@click.option('--status', '-s', type=click.Choice(['Active', 'Resolved', 'Monitoring']),
              help='Update status')
@click.option('--severity', type=click.Choice(['Minor', 'Moderate', 'Severe', 'Extreme']),
              help='Update severity')
def update_disaster(disaster_id, status, severity):
    """Update disaster status or severity."""
    updates = []
    params = []
    
    if status:
        updates.append("status = %s")
        params.append(status)
        if status == 'Resolved':
            updates.append("end_date = CURDATE()")
    
    if severity:
        updates.append("severity = %s")
        params.append(severity)
    
    if not updates:
        click.echo("No updates specified. Use --status or --severity.")
        return
    
    params.append(disaster_id)
    query = f"UPDATE Disaster SET {', '.join(updates)} WHERE disaster_id = %s"
    
    execute_query(query, params, fetch=False)
    click.echo(f"✅ Disaster {disaster_id} updated successfully!")


@disaster.command('report')
@click.argument('disaster_id', type=int)
def disaster_report(disaster_id):
    """Generate a comprehensive disaster report."""
    results = call_procedure('sp_get_disaster_report', (disaster_id,))
    
    if results:
        click.echo(f"\n📊 Disaster Report (ID: {disaster_id})")
        click.echo("=" * 60)
        for r in results:
            for key, value in r.items():
                click.echo(f"  {key}: {value}")
            click.echo("-" * 40)
    else:
        click.echo("Failed to generate report or disaster not found.")
