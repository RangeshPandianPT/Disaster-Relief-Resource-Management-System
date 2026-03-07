import docx

def verify_report(file_path):
    print(f"Verifying {file_path}...")
    try:
        doc = docx.Document(file_path)
        
        # Check for key content strings
        checks = {
            "Introduction": "Disaster Relief Resource Management System (DRRMS)",
            "Motivation": "rapid response is crucial",
            "Scope": "Disaster Management",
            "Problem Statement": "Current disaster relief efforts often suffer",
            "Project Requirements": "Database Backend",
            "Identification of Entity and Relationships": "DISASTER: The central event",
            "Construction of DB Using ER Model": "The Entity-Relationship (ER) diagram models the logical structure",
            "Design of Relational Schemas": "tables, columns, and foreign key constraints"
        }
        
        found_count = 0
        full_text = "\n".join([p.text for p in doc.paragraphs])
        
        for section, keyword in checks.items():
            if keyword in full_text:
                print(f"[PASS] Section '{section}' content found.")
                found_count += 1
            else:
                print(f"[FAIL] Section '{section}' content NOT found.")
        
        if found_count == len(checks):
            print("\nSUCCESS: All sections verified.")
        else:
            print(f"\nFAILURE: Only {found_count}/{len(checks)} sections verified.")
            
    except Exception as e:
        print(f"Error reading docx: {e}")

if __name__ == "__main__":
    verify_report("DRRMS_Report_v2.docx")
