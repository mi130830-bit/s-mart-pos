import re

with open('lib/screens/hr/tabs/hr_payroll_tab.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r"_showToast\s*\(\s*('.*?'),[^)]*backgroundColor:.*?,[^)]*icon:.*?\);", r"SnackbarUtils.showLeft(context, \1);", content, flags=re.DOTALL)

# Fix the broken ones from the previous bad multi-replace
content = content.replace("backgroundColor: const Color(0xFF546E7A),", "")
content = content.replace("icon: Icons.info_outline);", "")

with open('lib/screens/hr/tabs/hr_payroll_tab.dart', 'w', encoding='utf-8') as f:
    f.write(content)
