"""
Volunteer management CLI commands.
"""

import click
from tabulate import tabulate
from db_connection import execute_query


@click.group()
def volunteer():
    """Volunteer management commands."""
    pass


@volunteer.command('list')
@click.option('--availability', '-a', 
              type=click.Choice(['Available', 'Busy', 'Unavailable']),
              help='Filter by availability')
@click.option('--limit', '-l', default=20, help='Number of records')
def list_volunteers(availability, limit):
    """List registered volunteers."""
    query = "SELECT volunteer_id, name, email, phone, skills, availability FROM Volunteer WHERE 1=1"
    params = []
    
    if availability:
        query += " AND availability = %s"
        params.append(availability)
    
    query += f" ORDER BY volunteer_id DESC LIMIT {limit}"
    
    results = execute_query(query, params if params else None)
    
    if results:
        table_data = []
        for r in results:
            icon = {
                'Available': '🟢', 'Busy': '🟡', 'Unavailable': '🔴'
            }.get(r['availability'], '⚪')
            
            table_data.append([
                r['volunteer_id'],
                r['name'][:20],
                r['email'][:25],
                r['phone'],
                r['skills'][:20] if r['skills'] else 'N/A',
                f"{icon} {r['availability']}"
            ])
        
        click.echo("\n👥 Volunteer List:")
        click.echo(tabulate(table_data,
                           headers=['ID', 'Name', 'Email', 'Phone', 'Skills', 'Availability'],
                           tablefmt='rounded_grid'))
        click.echo(f"\nShowing {len(results)} volunteer(s)")
    else:
        click.echo("No volunteers found.")


@volunteer.command('add')
@click.option('--name', '-n', required=True, help='Volunteer name')
@click.option('--email', '-e', required=True, help='Volunteer email')
@click.option('--phone', '-p', required=True, help='Volunteer phone number')
@click.option('--skills', '-s', help='Volunteer skills (comma separated)')
def add_volunteer(name, email, phone, skills):
    """Register a new volunteer."""
    query = """
        INSERT INTO Volunteer (name, email, phone, skills, availability)
        VALUES (%s, %s, %s, %s, 'Available')
    """
    
    result = execute_query(query, (name, email, phone, skills), fetch=False)
    
    if result:
        click.echo(f"✅ Volunteer registered successfully! (ID: {result})")
    else:
        click.echo("❌ Failed to register volunteer.")
