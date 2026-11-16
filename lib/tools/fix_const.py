#!/usr/bin/env python3
"""
fix_const.py — بعد از پویا شدن AppColors (getter به جای const)، همهٔ `const`هایی
را که روی عبارت‌های حاوی AppColors مانده برمی‌دارد.

استفاده (از ریشهٔ پروژه):
    python3 tools/fix_const.py lib            # اعمال تغییر
    python3 tools/fix_const.py lib --dry-run  # فقط گزارش

کارها:
  1) `static const Color x = AppColors.y;`  →  `static Color get x => AppColors.y;`
  2) `const Color x = AppColors.y;` (محلی)  →  `final Color x = AppColors.y;`
  3) `const Foo(... AppColors.x ...)` / `const [ ... ]` / `const {...}`  →  بدون const
     (const بیرونی هم برداشته می‌شود چون متنش شامل AppColors است)
  4) پارامتر پیش‌فرض `this.c = AppColors.x` را فقط گزارش می‌دهد (باید دستی
     به nullable تبدیل شود: `Color? c` و `c ?? AppColors.x`).
"""
import os, re, sys

def skip_string(s, i):
    q = s[i]
    triple = s[i:i+3] == q*3
    raw = i > 0 and s[i-1] == 'r'
    if triple:
        j = i + 3
        while j < len(s) and s[j:j+3] != q*3:
            j += 2 if (s[j] == '\\' and not raw) else 1
        return j + 3
    j = i + 1
    while j < len(s) and s[j] != q:
        if s[j] == '\\' and not raw:
            j += 2
        elif s[j] == '$' and s[j+1:j+2] == '{':   # interpolation
            depth, j = 1, j + 2
            while j < len(s) and depth:
                if s[j] in '\'"':
                    j = skip_string(s, j); continue
                depth += (s[j] == '{') - (s[j] == '}')
                j += 1
        else:
            j += 1
    return j + 1

def skip_comment(s, i):
    if s.startswith('//', i):
        j = s.find('\n', i)
        return len(s) if j < 0 else j
    if s.startswith('/*', i):
        j = s.find('*/', i)
        return len(s) if j < 0 else j + 2
    return i

def match_close(s, i):
    """i روی ( [ { است؛ اندیس بعد از بستهٔ متناظر را می‌دهد."""
    pairs = {'(': ')', '[': ']', '{': '}'}
    stack = [pairs[s[i]]]
    j = i + 1
    while j < len(s) and stack:
        c = s[j]
        if c in '\'"':
            j = skip_string(s, j); continue
        if c == '/' and s[j+1:j+2] in '/*':
            j = skip_comment(s, j); continue
        if c in pairs:
            stack.append(pairs[c])
        elif c == stack[-1]:
            stack.pop()
        j += 1
    return j

CONST_RE = re.compile(r'\bconst\s+')

def expr_end(s, i):
    """از بعد از `const ` تا انتهای عبارت (نام/جنریک + بدنهٔ پرانتز یا براکت)."""
    j = i
    # نام و نقطه (Foo.named)
    while j < len(s) and (s[j].isalnum() or s[j] in '_.$'):
        j += 1
    if j < len(s) and s[j] == '<':             # جنریک
        depth = 0
        while j < len(s):
            depth += (s[j] == '<') - (s[j] == '>')
            j += 1
            if depth == 0: break
    while j < len(s) and s[j] in ' \t\n': j += 1
    if j < len(s) and s[j] in '([{':
        j = match_close(s, j)
        # زنجیره‌ی بعدی (.copyWith(...)) جزو عبارت const نیست؛ همین‌جا تمام
        return j
    return j

def fix_text(t, report, path):
    # ۱) تعریف‌های const که مستقیم AppColors هستند
    def static_getter(m):
        return f"{m.group(1)}Color get {m.group(2)} => {m.group(3)};"
    t = re.sub(r'(static\s+)const\s+Color\s+(\w+)\s*=\s*(AppColors\.[^;]+);', static_getter, t)
    # سطح بالای فایل: باید getter باشد (final سراسری فقط یک بار مقدار می‌گیرد)
    t = re.sub(r'(?m)^const\s+Color\s+(\w+)\s*=\s*(AppColors\.[^;]+);', r'Color get \1 => \2;', t)
    t = re.sub(r'\bconst\s+Color\s+(\w+)\s*=\s*(AppColors\.[^;]+);', r'final Color \1 = \2;', t)
    t = re.sub(r'\bconst\s+(List<Color>|Map<[^>]+>)\s+(\w+)\s*=\s*([^;]*AppColors\.[^;]*);',
               r'final \1 \2 = \3;', t)

    # ۲) const روی عبارت‌هایی که AppColors دارند (از آخر به اول)
    spans = []
    for m in CONST_RE.finditer(t):
        # داخل رشته/کامنت نباشد (تقریبی: خط‌های کامنت)
        ls = t.rfind('\n', 0, m.start()) + 1
        if t[ls:m.start()].lstrip().startswith('//'):
            continue
        end = expr_end(t, m.end())
        body = t[m.end():end]
        if re.search(r'AppColors\.|CargoSheets\.|IntercitySheets\.', body):
            spans.append((m.start(), m.end()))
    for a, b in reversed(spans):
        t = t[:a] + t[b:]

    # ۳) پارامتر پیش‌فرض
    for m in re.finditer(r'^\s{2}(?:late\s+)?final\s+\w+\s+\w+\s*=\s*AppColors\.\w+.*$', t, re.M):
        report.append(f"  ⚠ {path}: فیلد کلاس فقط یک بار مقدار می‌گیرد ← «{m.group(0).strip()}» به getter تبدیل شود")
    for m in re.finditer(r'(this\.\w+)\s*=\s*AppColors\.\w+', t):
        report.append(f"  ⚠ {path}: پارامتر پیش‌فرض ← «{m.group(0)}» دستی nullable شود")
    return t, len(spans)

def main():
    root = sys.argv[1] if len(sys.argv) > 1 else 'lib'
    dry = '--dry-run' in sys.argv
    total = 0
    report = []
    for dp, _, fs in os.walk(root):
        for f in fs:
            if not f.endswith('.dart') or f == 'app_colors.dart':
                continue
            p = os.path.join(dp, f)
            s = open(p, encoding='utf-8').read()
            if 'AppColors' not in s:
                continue
            n, c = fix_text(s, report, p)
            if n != s:
                total += 1
                print(f"{'~' if dry else '✔'} {p}  ({c} const برداشته شد)")
                if not dry:
                    open(p, 'w', encoding='utf-8').write(n)
    print(f"\n{total} فایل {'نیاز به تغییر دارد' if dry else 'اصلاح شد'}.")
    for r in report: print(r)

if __name__ == '__main__':
    main()
