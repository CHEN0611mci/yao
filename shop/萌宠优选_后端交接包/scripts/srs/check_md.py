# -*- coding: utf-8 -*-
"""Sanity-check the design document markdown (fences, headings, tables, images)."""
import io
import os
import re
import sys

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DOC_DIR = os.path.join(BASE, "docs", "02-设计文档")
DEFAULT = os.path.join(DOC_DIR, "宠物商城系统_企业级设计文档_v1.0.md")


def cells(line):
    s = line.strip()
    if s.startswith("|"):
        s = s[1:]
    if s.endswith("|"):
        s = s[:-1]
    return [c.strip() for c in s.split("|")]


def main(path):
    text = io.open(path, encoding="utf-8").read()
    lines = text.split("\n")
    print("file:", path)
    print("bytes:", len(text.encode("utf-8")), "lines:", len(lines))

    fences = [(i + 1, lines[i].strip()) for i in range(len(lines))
              if lines[i].strip().startswith("```")]
    ok = len(fences) % 2 == 0
    print("code fences:", len(fences), "balanced:", ok)
    for k in range(0, len(fences) - 1, 2):
        a, b = fences[k], fences[k + 1]
        if b[0] - a[0] > 90 or b[0] - a[0] < 2:
            print("  SUSPICIOUS pair", a[0], a[1], "->", b[0], b[1])
    if not ok:
        print("  last unpaired:", fences[-1])

    inside = False
    h1, h2, h3 = [], 0, 0
    for line in lines:
        if line.strip().startswith("```"):
            inside = not inside
            continue
        if inside:
            continue
        if line.startswith("# "):
            h1.append(line[2:].strip())
        elif line.startswith("## "):
            h2 += 1
        elif line.startswith("### "):
            h3 += 1
    print("h1:", len(h1), "h2:", h2, "h3:", h3)
    for h in h1:
        print("  #", h)

    imgs = re.findall(r"!\[[^\]]*\]\(([^)]+)\)", text)
    for rel in imgs:
        p = os.path.join(DOC_DIR, rel.replace("/", os.sep))
        print("image", rel, "OK" if os.path.exists(p) else "MISSING")

    bad = 0
    i = 0
    while i < len(lines):
        if lines[i].strip().startswith("|"):
            block = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                block.append((i + 1, lines[i]))
                i += 1
            rows = [(n, cells(t)) for n, t in block
                    if not all(re.fullmatch(r":?-{2,}:?", c) for c in cells(t) if c)]
            if rows:
                width = len(rows[0][1])
                for n, cs in rows:
                    if len(cs) != width:
                        bad += 1
                        print("  TABLE MISMATCH line", n, "expected", width,
                              "got", len(cs), "::", lines[n - 1][:80])
        else:
            i += 1
    print("table column mismatches:", bad)

    if "<!-- COVER -->" in text and "<!-- /COVER -->" in text:
        print("cover block: OK")
    else:
        print("cover block: MISSING")
    print("toc marker:", "OK" if "<!-- TOC -->" in text else "MISSING")

    # empty heading check
    for i, line in enumerate(lines):
        if re.fullmatch(r"#{1,6}\s*", line):
            print("  EMPTY HEADING at line", i + 1)
    return 0 if ok and bad == 0 else 1


if __name__ == "__main__":
    target = sys.argv[1] if len(sys.argv) > 1 else DEFAULT
    sys.exit(main(target))
