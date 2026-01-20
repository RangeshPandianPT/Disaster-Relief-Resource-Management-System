"""
Inventory management CLI commands.
"""

import click
from tabulate import tabulate
from db_connection import execute_query


@click.group()
def inventory():
    """Inventory management commands."""
    pass


@inventory.command('list')
@click.option('--category', '-c', help='Filter by category (Food, Water, Medicine, Shelter, Clothing)')
@click.option('--warehouse', '-w', help='Filter by warehouse location')
@click.option('--low-stock', is_flag=True, help='Show only low stock items')
def list_inventory(category, warehouse, low_stock):
    """List inventory items."""
    query = """
        SELECT i.inventory_id, r.resource_name, r.category, r.unit,
               i.warehouse_location, i.quantity_available, r.min_stock,
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
    
    if warehouse:
        query += " AND i.warehouse_location LIKE %s"
        params.append(f"%{warehouse}%")
    
    if low_stock:
        query += " AND i.quantity_available < r.min_stock"
    
    query += " ORDER BY r.category, r.resource_name"
    
    results = execute_query(query, params if params else None)
    
    if results:
        table_data = []
        for r in results:
            status_icon = {'OUT': '🔴', 'LOW': '🟡', 'OK': '🟢'}.get(r['stock_status'], '⚪')
            table_data.append([
                r['inventory_id'],
                r['resource_name'],
                r['category'],
                r['warehouse_location'][:25] + '...' if len(r['warehouse_location']) > 25 else r['warehouse_location'],
                f"{r['quantity_available']:,} {r['unit']}",
                r['min_stock'],
                f"{status_icon} {r['stock_status']}"
            ])
        
        click.echo("\n📦 Inventory List:")
        click.echo(tabulate(table_data,
                           headers=['ID', 'Resource', 'Category', 'Warehouse', 'Available', 'Min', 'Status'],
                           tablefmt='rounded_grid'))
        click.echo(f"\nTotal: {len(results)} item(s)")
    else:
        click.echo("No inventory items found.")


@inventory.command('check')
@click.option('--resource', '-r', type=int, help='Resource ID to check')
@click.option('--all-resources', is_flag=True, help='Check all resources')
def check_stock(resource, all_resources):
    """Check stock levels for resources."""
    if resource:
        query = """
            SELECT r.resource_name, r.category, r.min_stock,
                   SUM(i.quantity_available) as total_stock,
                   COUNT(DISTINCT i.warehouse_location) as warehouse_count
            FROM Resource r
            LEFT JOIN Inventory i ON r.resource_id = i.resource_id
            WHERE r.resource_id = %s
            GROUP BY r.resource_id, r.resource_name, r.category, r.min_stock
        """
        results = execute_query(query, (resource,))
    elif all_resources:
        query = """
            SELECT r.resource_name, r.category, r.min_stock,
                   COALESCE(SUM(i.quantity_available), 0) as total_stock,
                   COUNT(DISTINCT i.warehouse_location) as warehouse_count
            FROM Resource r
            LEFT JOIN Inventory i ON r.resource_id = i.resource_id
            GROUP BY r.resource_id, r.resource_name, r.category, r.min_stock
            ORDER BY (COALESCE(SUM(i.quantity_available), 0) / NULLIF(r.min_stock, 0))
        """
        results = execute_query(query)
    else:
        click.echo("Please specify --resource <id> or --all-resources")
        return
    
    if results:
        click.echo("\n📊 Stock Level Check:")
        for r in results:
            total = r['total_stock'] or 0
            min_stock = r['min_stock'] or 0
            pct = (total / min_stock * 100) if min_stock > 0 else 100
            
            if pct == 0:
                bar = '░' * 20
                icon = '🔴'
            elif pct < 25:
                bar = '█' * int(pct/5) + '░' * (20 - int(pct/5))
                icon = '🔴'
            elif pct < 50:
                bar = '█' * int(pct/5) + '░' * (20 - int(pct/5))
                icon = '🟠'
            elif pct < 100:
                bar = '█' * int(pct/5) + '░' * (20 - int(pct/5))
                icon = '🟡'
            else:
                bar = '█' * 20
                icon = '🟢'
            
            click.echo(f"\n{icon} {r['resource_name']} ({r['category']})")
            click.echo(f"   [{bar}] {pct:.1f}%")
            click.echo(f"   Stock: {total:,} / Min: {min_stock:,} | Warehouses: {r['warehouse_count']}")


@inventory.command('add')
@click.option('--resource', '-r', type=int, required=True, help='Resource ID')
@click.option('--warehouse', '-w', required=True, help='Warehouse location')
@click.option('--quantity', '-q', type=int, required=True, help='Quantity to add')
def add_stock(resource, warehouse, quantity):
    """Add stock to inventory."""
    # Check if inventory entry exists
    check_query = """
        SELECT inventory_id, quantity_available 
        FROM Inventory 
        WHERE resource_id = %s AND warehouse_location = %s
    """
    existing = execute_query(check_query, (resource, warehouse))
    
    if existing:
        # Update existing
        update_query = """
            UPDATE Inventory 
            SET quantity_available = quantity_available + %s,
                last_updated = CURRENT_TIMESTAMP
            WHERE inventory_id = %s
        """
        execute_query(update_query, (quantity, existing[0]['inventory_id']), fetch=False)
        new_qty = existing[0]['quantity_available'] + quantity
        click.echo(f"✅ Updated inventory. New quantity: {new_qty:,}")
    else:
        # Insert new
        insert_query = """
            INSERT INTO Inventory (resource_id, warehouse_location, quantity_available)
            VALUES (%s, %s, %s)
        """
        result = execute_query(insert_query, (resource, warehouse, quantity), fetch=False)
        click.echo(f"✅ Created new inventory entry (ID: {result})")


@inventory.command('transfer')
@click.option('--resource', '-r', type=int, required=True, help='Resource ID')
@click.option('--from-warehouse', '-f', required=True, help='Source warehouse')
@click.option('--to-warehouse', '-t', required=True, help='Destination warehouse')
@click.option('--quantity', '-q', type=int, required=True, help='Quantity to transfer')
def transfer_stock(resource, from_warehouse, to_warehouse, quantity):
    """Transfer stock between warehouses."""
    # Check source stock
    check_query = """
        SELECT quantity_available FROM Inventory
        WHERE resource_id = %s AND warehouse_location = %s
    """
    source = execute_query(check_query, (resource, from_warehouse))
    
    if not source or source[0]['quantity_available'] < quantity:
        available = source[0]['quantity_available'] if source else 0
        click.echo(f"❌ Insufficient stock. Available: {available:,}")
        return
    
    # Perform transfer
    # Deduct from source
    deduct_query = """
        UPDATE Inventory 
        SET quantity_available = quantity_available - %s
        WHERE resource_id = %s AND warehouse_location = %s
    """
    execute_query(deduct_query, (quantity, resource, from_warehouse), fetch=False)
    
    # Add to destination
    add_query = """
        INSERT INTO Inventory (resource_id, warehouse_location, quantity_available)
        VALUES (%s, %s, %s)
        ON DUPLICATE KEY UPDATE 
            quantity_available = quantity_available + VALUES(quantity_available)
    """
    execute_query(add_query, (resource, to_warehouse, quantity), fetch=False)
    
    click.echo(f"✅ Transferred {quantity:,} units from {from_warehouse} to {to_warehouse}")


@inventory.command('alerts')
def stock_alerts():
    """Show low stock alerts."""
    query = """
        SELECT r.resource_name, r.category, i.warehouse_location,
               i.quantity_available, r.min_stock,
               ROUND((i.quantity_available / r.min_stock) * 100, 1) as stock_pct
        FROM Inventory i
        INNER JOIN Resource r ON i.resource_id = r.resource_id
        WHERE i.quantity_available < r.min_stock
        ORDER BY (i.quantity_available / r.min_stock), r.category
    """
    
    results = execute_query(query)
    
    if results:
        click.echo("\n⚠️  LOW STOCK ALERTS:")
        click.echo("=" * 70)
        
        for r in results:
            if r['quantity_available'] == 0:
                icon = '🔴 OUT OF STOCK'
            elif r['stock_pct'] < 25:
                icon = '🟠 CRITICAL'
            else:
                icon = '🟡 LOW'
            
            click.echo(f"\n{icon}: {r['resource_name']} ({r['category']})")
            click.echo(f"   Warehouse: {r['warehouse_location']}")
            click.echo(f"   Stock: {r['quantity_available']:,} / Min: {r['min_stock']:,} ({r['stock_pct']}%)")
        
        click.echo(f"\n{'=' * 70}")
        click.echo(f"Total alerts: {len(results)}")
    else:
        click.echo("✅ No low stock alerts. All inventory levels are healthy!")
