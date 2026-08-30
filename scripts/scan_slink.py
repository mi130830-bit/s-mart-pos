import os

def scan_dart_files(path):
    results = []
    for root, dirs, files in os.walk(path):
        for file in files:
            if file.endswith('.dart'):
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        lines = f.readlines()
                        results.append((len(lines), file_path))
                except Exception as e:
                    pass
    
    # Sort by line count descending
    results.sort(key=lambda x: x[0], reverse=True)
    
    print("=== DART FILES BY LINE COUNT IN S-LINK ===")
    for count, fp in results:
        if count >= 100:  # Show files with 100+ lines
            print(f"{count:4d} lines | {fp.replace('C:\\\\s_link\\\\', '')}")

if __name__ == "__main__":
    scan_dart_files(r"C:\s_link\lib")
