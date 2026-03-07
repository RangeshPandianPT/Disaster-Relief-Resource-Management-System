import docx

def find_chapters(file_path):
    try:
        doc = docx.Document(file_path)
        print(f"Structure of {file_path} (Relevant Chapters):")
        
        print_mode = False
        for i, paragraph in enumerate(doc.paragraphs):
            text = paragraph.text.strip()
            if "CHAPTER 1" in text.upper() or "CHAPTER 2" in text.upper() or "CHAPTER 3" in text.upper():
                print(f"\n--- Found Header: {text} ---")
                print_mode = True
            
            if print_mode:
                if text:
                    print(f"P{i}: {text[:100]}")
                
            if "CHAPTER 3" in text.upper():
                break # Stop after finding Chapter 3 start
            
    except Exception as e:
        print(f"Error reading docx: {e}")

if __name__ == "__main__":
    find_chapters(r"d:\DBMS\DRRMS\Report template.docx")
