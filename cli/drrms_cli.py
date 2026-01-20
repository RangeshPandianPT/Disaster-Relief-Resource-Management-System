#!/usr/bin/env python3
"""
DRRMS Command Line Interface
A comprehensive CLI tool for Disaster Relief Resource Management System.

Usage:
    python drrms_cli.py [COMMAND] [SUBCOMMAND] [OPTIONS]

Examples:
    python drrms_cli.py disaster list
    python drrms_cli.py inventory check --all-resources
    python drrms_cli.py request create --area 1 --resource 1 --quantity 100
    python drrms_cli.py report dashboard
"""

import click
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from db_connection import test_connection
from commands import disaster, inventory, request, report


@click.group()
@click.version_option(version='1.0.0', prog_name='DRRMS CLI')
def cli():
    """
    🌍 DRRMS - Disaster Relief Resource Management System
    
    A command-line interface for managing disasters, resources,
    requests, and generating reports.
    """
    pass


# Add command groups
cli.add_command(disaster)
cli.add_command(inventory)
cli.add_command(request)
cli.add_command(report)


@cli.command()
def status():
    """Check system status and database connection."""
    click.echo("\n🔧 DRRMS System Status")
    click.echo("=" * 40)
    
    # Check database connection
    click.echo("\n📊 Database Connection:", nl=False)
    if test_connection():
        click.echo(" ✅ Connected")
    else:
        click.echo(" ❌ Failed")
        click.echo("\n⚠️  Please check your database configuration in db_connection.py")
        return
    
    # Get quick stats
    from db_connection import execute_query
    
    stats = [
        ("Disasters", "SELECT COUNT(*) as c FROM Disaster"),
        ("Active Disasters", "SELECT COUNT(*) as c FROM Disaster WHERE status = 'Active'"),
        ("Resources", "SELECT COUNT(*) as c FROM Resource"),
        ("Volunteers", "SELECT COUNT(*) as c FROM Volunteer"),
        ("Pending Requests", "SELECT COUNT(*) as c FROM Request WHERE status = 'Pending'"),
    ]
    
    click.echo("\n📈 Quick Stats:")
    for label, query in stats:
        result = execute_query(query)
        count = result[0]['c'] if result else 0
        click.echo(f"   {label}: {count}")
    
    click.echo("\n" + "=" * 40)
    click.echo("✅ System is operational!")


@cli.command()
def interactive():
    """Start interactive mode."""
    click.echo("\n🌍 DRRMS Interactive Mode")
    click.echo("Type 'help' for commands, 'exit' to quit.\n")
    
    while True:
        try:
            cmd = click.prompt('drrms', type=str)
            
            if cmd.lower() in ('exit', 'quit', 'q'):
                click.echo("Goodbye! 👋")
                break
            elif cmd.lower() == 'help':
                click.echo("""
Available commands:
  disaster list       - List all disasters
  inventory list      - List inventory
  inventory alerts    - Show low stock alerts
  request list        - List requests
  request pending     - Show pending summary
  report dashboard    - Main dashboard
  status              - System status
  exit                - Exit interactive mode
                """)
            else:
                # Parse and execute command
                parts = cmd.split()
                if len(parts) >= 2:
                    group = parts[0]
                    subcmd = parts[1]
                    
                    # This is a simplified interactive handler
                    click.echo(f"Try running: python drrms_cli.py {' '.join(parts)}")
                else:
                    click.echo("Invalid command. Type 'help' for options.")
                    
        except (KeyboardInterrupt, EOFError):
            click.echo("\nGoodbye! 👋")
            break


if __name__ == '__main__':
    cli()
