"""
Request management CLI commands.
"""

import click
from tabulate import tabulate
from db_connection import execute_query, call_procedure


@click.group()
def request():
    """Request management commands."""
    pass


@request.command('list')
@click.option('--status', '-s', 
              type=click.Choice(['Pending', 'Approved', 'Fulfilled', 'Partially_Fulfilled', 'Rejected']),
              help='Filter by status')
@click.option('--urgency', '-u', 
              type=click.Choice(['Critical', 'High', 'Medium', 'Low']),
              help='Filter by urgency')
@click.option('--limit', '-l', default=20, help='Number of records')
def list_requests(status, urgency, limit):
    """List resource requests."""
    query = """
        SELECT r.request_id, aa.area_name, res.resource_name, 
               r.quantity_requested, r.urgency, r.status, r.request_date
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
    
    query += f" ORDER BY FIELD(r.urgency, 'Critical', 'High', 'Medium', 'Low'), r.request_date DESC LIMIT {limit}"
    
    results = execute_query(query, params if params else None)
    
    if results:
        table_data = []
        for r in results:
            urgency_icon = {
                'Critical': '🔴', 'High': '🟠', 'Medium': '🟡', 'Low': '🟢'
            }.get(r['urgency'], '⚪')
            status_icon = {
                'Fulfilled': '✅', 'Pending': '⏳', 'Approved': '👍', 
                'Partially_Fulfilled': '🔄', 'Rejected': '❌'
            }.get(r['status'], '❓')
            
            table_data.append([
                r['request_id'],
                r['area_name'][:20],
                r['resource_name'][:15],
                f"{r['quantity_requested']:,}",
                f"{urgency_icon} {r['urgency']}",
                f"{status_icon} {r['status']}",
                r['request_date'].strftime('%m/%d') if r['request_date'] else 'N/A'
            ])
        
        click.echo("\n📋 Request List:")
        click.echo(tabulate(table_data,
                           headers=['ID', 'Area', 'Resource', 'Qty', 'Urgency', 'Status', 'Date'],
                           tablefmt='rounded_grid'))
        click.echo(f"\nShowing {len(results)} request(s)")
    else:
        click.echo("No requests found.")


@request.command('create')
@click.option('--area', '-a', type=int, required=True, help='Area ID')
@click.option('--resource', '-r', type=int, required=True, help='Resource ID')
@click.option('--quantity', '-q', type=int, required=True, help='Quantity needed')
@click.option('--urgency', '-u', default='Medium',
              type=click.Choice(['Critical', 'High', 'Medium', 'Low']),
              help='Urgency level')
@click.option('--remarks', help='Additional remarks')
def create_request(area, resource, quantity, urgency, remarks):
    """Create a new resource request."""
    query = """
        INSERT INTO Request (area_id, resource_id, quantity_requested, urgency, status, remarks)
        VALUES (%s, %s, %s, %s, 'Pending', %s)
    """
    
    result = execute_query(query, (area, resource, quantity, urgency, remarks), fetch=False)
    
    if result:
        click.echo(f"✅ Request created successfully! (ID: {result})")
        click.echo(f"   Area: {area}, Resource: {resource}, Quantity: {quantity:,}")
        click.echo(f"   Urgency: {urgency}, Status: Pending")
    else:
        click.echo("❌ Failed to create request.")


@request.command('approve')
@click.argument('request_id', type=int)
def approve_request(request_id):
    """Approve a pending request."""
    query = "UPDATE Request SET status = 'Approved' WHERE request_id = %s AND status = 'Pending'"
    execute_query(query, (request_id,), fetch=False)
    click.echo(f"✅ Request {request_id} approved!")


@request.command('fulfill')
@click.argument('request_id', type=int)
@click.option('--inventory', '-i', type=int, required=True, help='Inventory ID to allocate from')
@click.option('--quantity', '-q', type=int, required=True, help='Quantity to allocate')
def fulfill_request(request_id, inventory, quantity):
    """Allocate resources to fulfill a request."""
    # Create allocation
    alloc_query = """
        INSERT INTO Allocation (request_id, inventory_id, quantity_allocated, delivery_status)
        VALUES (%s, %s, %s, 'Pending')
    """
    
    result = execute_query(alloc_query, (request_id, inventory, quantity), fetch=False)
    
    if result:
        click.echo(f"✅ Allocation created (ID: {result})")
        click.echo(f"   Request: {request_id}, Quantity: {quantity:,}")
        
        # Note: Triggers will handle inventory deduction and request status update
    else:
        click.echo("❌ Failed to create allocation.")


@request.command('pending')
def pending_summary():
    """Show summary of pending requests."""
    query = """
        SELECT 
            r.urgency,
            COUNT(*) as count,
            SUM(r.quantity_requested) as total_qty,
            MIN(DATEDIFF(CURDATE(), r.request_date)) as min_days,
            MAX(DATEDIFF(CURDATE(), r.request_date)) as max_days
        FROM Request r
        WHERE r.status = 'Pending'
        GROUP BY r.urgency
        ORDER BY FIELD(r.urgency, 'Critical', 'High', 'Medium', 'Low')
    """
    
    results = execute_query(query)
    
    if results:
        click.echo("\n⏳ Pending Request Summary:")
        click.echo("=" * 60)
        
        total_count = 0
        for r in results:
            icon = {'Critical': '🔴', 'High': '🟠', 'Medium': '🟡', 'Low': '🟢'}.get(r['urgency'], '⚪')
            click.echo(f"\n{icon} {r['urgency']}:")
            click.echo(f"   Count: {r['count']} requests")
            click.echo(f"   Total Quantity: {r['total_qty']:,}")
            click.echo(f"   Age: {r['min_days']}-{r['max_days']} days")
            total_count += r['count']
        
        click.echo(f"\n{'=' * 60}")
        click.echo(f"Total Pending: {total_count} requests")
    else:
        click.echo("✅ No pending requests!")


@request.command('stats')
def request_statistics():
    """Show request statistics."""
    query = """
        SELECT 
            status,
            COUNT(*) as count,
            SUM(quantity_requested) as total_qty
        FROM Request
        GROUP BY status
    """
    
    results = execute_query(query)
    
    if results:
        click.echo("\n📊 Request Statistics:")
        
        total = sum(r['count'] for r in results)
        
        for r in results:
            pct = (r['count'] / total * 100) if total > 0 else 0
            bar_len = int(pct / 5)
            bar = '█' * bar_len + '░' * (20 - bar_len)
            
            icon = {
                'Fulfilled': '✅', 'Pending': '⏳', 'Approved': '👍',
                'Partially_Fulfilled': '🔄', 'Rejected': '❌'
            }.get(r['status'], '❓')
            
            click.echo(f"\n{icon} {r['status']}")
            click.echo(f"   [{bar}] {pct:.1f}% ({r['count']} requests)")
            click.echo(f"   Total Quantity: {r['total_qty']:,}")
        
        click.echo(f"\nGrand Total: {total} requests")
