import os
import re

def process_dart_files(directory):
    count = 0
    
    # Pattern 1: ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('TEXT')));
    # Allow whitespace and newlines between tokens
    pattern_simple = re.compile(
        r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s+)?SnackBar\(\s*content:\s*Text\((['\"])(.*?)\1\)\s*,?\s*\)\s*,?\s*\);",
        re.DOTALL
    )
    
    # Pattern 2: With backgroundColor
    pattern_error = re.compile(
        r"ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*(?:const\s+)?SnackBar\(\s*content:\s*Text\((['\"])(.*?)\1\)\s*,\s*backgroundColor:\s*Colors\.red(?:\[\d+\]|\.shade\d+)?\s*,?\s*\)\s*,?\s*\);",
        re.DOTALL
    )

    for root, dirs, files in os.walk(directory):
        for file in files:
            if file.endswith('.dart') and file != 'snackbar_utils.dart':
                filepath = os.path.join(root, file)
                with open(filepath, 'r', encoding='utf-8') as f:
                    content = f.read()

                modified = False
                
                # Replace pattern_error first
                new_content, n = pattern_error.subn(r"SnackbarUtils.showLeft(context, \1\2\1, isError: true);", content)
                if n > 0:
                    modified = True
                    content = new_content
                
                # Replace pattern_simple
                def simple_repl(match):
                    quote = match.group(1)
                    text = match.group(2)
                    is_err = "ผิดพลาด" in text or "Error" in text or "ล้มเหลว" in text
                    if is_err:
                        return f"SnackbarUtils.showLeft(context, {quote}{text}{quote}, isError: true);"
                    return f"SnackbarUtils.showLeft(context, {quote}{text}{quote});"
                
                new_content, n = pattern_simple.subn(simple_repl, content)
                if n > 0:
                    modified = True
                    content = new_content
                
                if modified:
                    # Add import if missing
                    import_statement = "import 'package:pos_desktop/utils/snackbar_utils.dart';"
                    if import_statement not in content and "class SnackbarUtils" not in content:
                        lines = content.split('\n')
                        for i, line in enumerate(lines):
                            if line.startswith('import '):
                                lines.insert(i, import_statement)
                                break
                        content = '\n'.join(lines)
                        
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(content)
                    print(f"Modified: {filepath}")
                    count += 1
                    
    print(f"Total files modified: {count}")

if __name__ == '__main__':
    process_dart_files('c:/pos_desktop/lib')
