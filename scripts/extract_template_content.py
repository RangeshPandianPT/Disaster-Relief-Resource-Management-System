import docx

def extract_ch1_to_ch3(file_path):
    try:
        doc = docx.Document(file_path)
        
        start = False
        print(f"--- Content between CHAPTER 1 and CHAPTER 3 in {file_path} ---")
        for p in doc.paragraphs:
            text = p.text.strip()
            if "CHAPTER 1" in text.upper():
                start = True
            if "CHAPTER 3" in text.upper():
                break
            
            if start:
                if text:
                    print(f"Style: {p.style.name} | Text: {text}")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    extract_ch1_to_ch3(r"d:\DBMS\DRRMS\Report template.docx")
