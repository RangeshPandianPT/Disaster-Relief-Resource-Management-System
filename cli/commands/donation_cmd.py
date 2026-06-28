"""
Donation management CLI commands.
"""

import click
from tabulate import tabulate
from db_connection import execute_query


@click.group()
def donation():
    """Donation management commands."""
    pass


@donation.command('list')
@click.option('--type', '-t', 'donation_type',
              type=click.Choice(['Money', 'Material']),
              help='Filter by donation type')
@click.option('--limit', '-l', default=20, help='Number of records')
def list_donations(donation_type, limit):
    """List donations."""
    query = """
        SELECT d.donation_id, dn.donor_name, d.donation_type, 
               d.amount, r.resource_name, d.quantity, d.status, d.donation_date
        FROM Donation d
        INNER JOIN Donor dn ON d.donor_id = dn.donor_id
        LEFT JOIN Resource r ON d.resource_id = r.resource_id
        WHERE 1=1
    """
    params = []
    
    if donation_type:
        query += " AND d.donation_type = %s"
        params.append(donation_type)
    
    query += f" ORDER BY d.donation_date DESC LIMIT {limit}"
    
    results = execute_query(query, params if params else None)
    
    if results:
        table_data = []
        for r in results:
            icon = '💰' if r['donation_type'] == 'Money' else '📦'
            details = f"${r['amount']}" if r['donation_type'] == 'Money' else f"{r['quantity']}x {r['resource_name']}"
            
            table_data.append([
                r['donation_id'],
                r['donor_name'][:20],
                f"{icon} {r['donation_type']}",
                details,
                r['status'],
                r['donation_date'].strftime('%Y-%m-%d') if r['donation_date'] else 'N/A'
            ])
        
        click.echo("\n💖 Donation List:")
        click.echo(tabulate(table_data,
                           headers=['ID', 'Donor', 'Type', 'Details', 'Status', 'Date'],
                           tablefmt='rounded_grid'))
        click.echo(f"\nShowing {len(results)} donation(s)")
    else:
        click.echo("No donations found.")


@donation.command('receive')
@click.option('--donor-id', '-d', type=int, required=True, help='Donor ID')
@click.option('--amount', '-a', type=float, help='Monetary amount (if money)')
@click.option('--resource-id', '-r', type=int, help='Resource ID (if material)')
@click.option('--quantity', '-q', type=int, help='Quantity (if material)')
def receive_donation(donor_id, amount, resource_id, quantity):
    """Receive a new donation."""
    if amount:
        query = """
            INSERT INTO Donation (donor_id, donation_type, amount, status)
            VALUES (%s, 'Money', %s, 'Received')
        """
        result = execute_query(query, (donor_id, amount), fetch=False)
    elif resource_id and quantity:
        query = """
            INSERT INTO Donation (donor_id, donation_type, resource_id, quantity, status)
            VALUES (%s, 'Material', %s, %s, 'Received')
        """
        result = execute_query(query, (donor_id, resource_id, quantity), fetch=False)
    else:
        click.echo("❌ Please provide either --amount for Money or both --resource-id and --quantity for Material.")
        return

    if result:
        click.echo(f"✅ Donation received successfully! (ID: {result})")
    else:
        click.echo("❌ Failed to receive donation.")
