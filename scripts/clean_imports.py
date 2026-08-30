import os

list_view_file = r"c:\pos_desktop\lib\screens\products\product_list_view.dart"
dialog_file = r"c:\pos_desktop\lib\screens\products\dialogs\product_form\product_form_dialog.dart"

def remove_lines(file_path, line_numbers):
    with open(file_path, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Sort line numbers descending to avoid shifting issues when deleting
    for i in sorted(line_numbers, reverse=True):
        if i - 1 < len(lines):
            del lines[i - 1]
            
    with open(file_path, 'w', encoding='utf-8') as f:
        f.writelines(lines)

remove_lines(list_view_file, [1, 5, 7, 9, 10, 11, 13, 15, 16, 18, 19, 23, 27, 32, 33, 34, 36, 37, 38])
remove_lines(dialog_file, [22, 26])

print("Removed unused imports")
