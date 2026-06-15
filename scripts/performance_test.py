#!/usr/bin/env python3
"""
Performance Testing Script for DRRMS Database.
Tests query performance with and without indexes.
"""

import time
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'cli'))

try:
    from db_connection import execute_query, test_connection
except ImportError:
    print("Could not import db_connection. Please run from project root.")
    sys.exit(1)

def run_stress_test():
    print("🚀 Starting Database Stress & Performance Test")
    print("=" * 50)
    
    if not test_connection():
        print("❌ Failed to connect to database.")
        return
        
    queries_to_test = [
        ("Complex Join (Disaster + Resources + Requests)", """
            SELECT d.title, r.name, req.quantity 
            FROM Disaster d
            JOIN Request req ON d.disaster_id = req.disaster_id
            JOIN Resource r ON req.resource_id = r.resource_id
            WHERE d.status = 'Active'
            LIMIT 100
        """),
        ("Aggregation (Inventory Levels by Category)", """
            SELECT category, SUM(quantity) as total_qty, AVG(unit_cost) as avg_cost
            FROM Resource
            GROUP BY category
            HAVING total_qty < 1000
        """),
        ("Subquery (Volunteers in High-Severity Disasters)", """
            SELECT v.first_name, v.last_name, v.skills
            FROM Volunteer v
            WHERE v.assigned_disaster_id IN (
                SELECT disaster_id FROM Disaster WHERE severity_level IN ('High', 'Extreme')
            )
        """)
    ]
    
    for name, query in queries_to_test:
        print(f"\nTesting: {name}")
        start_time = time.time()
        
        # Run 50 times to simulate load
        iterations = 50
        for _ in range(iterations):
            try:
                execute_query(query)
            except Exception as e:
                print(f"Error executing query: {e}")
                break
            
        end_time = time.time()
        duration = end_time - start_time
        avg_time = (duration / iterations) * 1000
        
        print(f"Total Time ({iterations} runs): {duration:.4f} seconds")
        print(f"Average Time per query: {avg_time:.2f} ms")
        
        if avg_time > 50:
            print("⚠️ Performance Warning: Consider adding indexes for this query.")
        else:
            print("✅ Performance Optimal.")

if __name__ == '__main__':
    run_stress_test()
