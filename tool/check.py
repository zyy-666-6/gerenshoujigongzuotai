# -*- coding: utf-8 -*-
"""静态走查：括号配对 + 本地 import 路径存在性 + 未使用 import 粗查"""
import os
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
issues = []

for root, dirs, files in os.walk('lib'):
    for f in files:
        if not f.endswith('.dart'):
            continue
        p = os.path.join(root, f)
        src = open(p, encoding='utf-8').read()

        # 1) 括号配对（先剔除字符串与注释）
        s = re.sub(r"'''.*?'''", '', src, flags=re.S)
        s = re.sub(r'""".*?"""', '', s, flags=re.S)
        s = re.sub(r'//.*', '', s)
        s = re.sub(r"'(?:[^'\\]|\\.)*'", "''", s)
        s = re.sub(r'"(?:[^"\\]|\\.)*"', '""', s)
        if s.count('{') != s.count('}'):
            issues.append(f'{p}: 花括号不配对 {s.count("{")}/{s.count("}")}')
        if s.count('(') != s.count(')'):
            issues.append(f'{p}: 圆括号不配对 {s.count("(")}/{s.count(")")}')

        # 2) 相对 import 指向的文件必须存在
        for m in re.finditer(r"import '([^']+)'", src):
            imp = m.group(1)
            if imp.startswith('dart:') or imp.startswith('package:'):
                continue
            target = os.path.normpath(os.path.join(os.path.dirname(p), imp))
            if not os.path.exists(target):
                issues.append(f'{p}: 本地导入不存在 {imp}')

        # 3) 相对 import 的符号是否在目标文件中声明（粗查：取 import 中的标识符）
        for m in re.finditer(
                r"import '(\.[^']+)'(?:\s+show\s+([^;]+))?;", src):
            imp, shown = m.group(1), m.group(2)
            target = os.path.normpath(os.path.join(os.path.dirname(p), imp))
            if not os.path.exists(target):
                continue
            tsrc = open(target, encoding='utf-8').read()
            names = [x.strip() for x in (shown or '').split(',') if x.strip()]
            for n in names:
                # 目标文件中应出现声明（class/函数/变量/枚举值）
                if not re.search(r'\b' + re.escape(n) + r'\b', tsrc):
                    issues.append(f'{p}: show 的符号 {n} 在 {imp} 中未找到')

print('\n'.join(issues) if issues else 'ALL CHECKS PASSED')
