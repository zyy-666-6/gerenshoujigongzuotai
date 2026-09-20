# -*- coding: utf-8 -*-
"""输出项目文件树"""
import os
import sys

sys.stdout.reconfigure(encoding='utf-8')
count = 0
for root, dirs, files in os.walk('.'):
    dirs[:] = [d for d in dirs if d not in ('.dart_tool', 'build', '.idea')]
    level = 0 if root == '.' else root.count(os.sep) + 1
    indent = '  ' * level
    name = 'personal_workbench/' if root == '.' else os.path.basename(root) + '/'
    print(indent + name)
    for f in sorted(files):
        print(indent + '  ' + f)
        count += 1
print()
print('共 %d 个文件' % count)
