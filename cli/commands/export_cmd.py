import click
import csv
import json
from db_connection import execute_query

@click.group(name='export')
def export():
    """Export data to CSV or JSON formats."""
    pass

@export.command()
@click.option('--format', '-f', type=click.Choice(['csv', 'json']), default='csv', help='Format to export (csv or json)')
@click.option('--output', '-o', default='disasters_export', help='Output filename without extension')
def disasters(format, output):
    """Export all disasters to a file."""
    query = "SELECT * FROM Disaster"
    results = execute_query(query)
    
    if not results:
        click.echo("No disasters found to export.")
        return
        
    filename = f"{output}.{format}"
    
    if format == 'csv':
        with open(filename, 'w', newline='', encoding='utf-8') as f:
            if results:
                writer = csv.DictWriter(f, fieldnames=results[0].keys())
                writer.writeheader()
                writer.writerows(results)
    else:
        # JSON
        import datetime
        def default_converter(o):
            if isinstance(o, (datetime.date, datetime.datetime)):
                return o.isoformat()
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=4, default=default_converter)
            
    click.echo(f"✅ Successfully exported {len(results)} disasters to {filename}")

@export.command()
@click.option('--format', '-f', type=click.Choice(['csv', 'json']), default='csv', help='Format to export (csv or json)')
@click.option('--output', '-o', default='inventory_export', help='Output filename without extension')
def inventory(format, output):
    """Export inventory resources to a file."""
    query = "SELECT * FROM Resource"
    results = execute_query(query)
    
    if not results:
        click.echo("No inventory found to export.")
        return
        
    filename = f"{output}.{format}"
    
    if format == 'csv':
        with open(filename, 'w', newline='', encoding='utf-8') as f:
            if results:
                writer = csv.DictWriter(f, fieldnames=results[0].keys())
                writer.writeheader()
                writer.writerows(results)
    else:
        import datetime
        def default_converter(o):
            if isinstance(o, (datetime.date, datetime.datetime)):
                return o.isoformat()
        with open(filename, 'w', encoding='utf-8') as f:
            json.dump(results, f, indent=4, default=default_converter)
            
    click.echo(f"✅ Successfully exported inventory to {filename}")
