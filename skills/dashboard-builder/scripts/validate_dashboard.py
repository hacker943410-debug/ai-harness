#!/usr/bin/env python3
"""Lightweight static validation for generated dashboard HTML."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

CHECKS = {
    "html": re.compile(r"<html\b", re.I),
    "viewport": re.compile(r'name=["\']viewport["\']', re.I),
    "script": re.compile(r"<script\b", re.I),
    "error_state": re.compile(r"error|오류|실패", re.I),
    "loading_state": re.compile(r"loading|로딩", re.I),
}

def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("html", nargs="?", default="index.html")
    args = p.parse_args()

    path = Path(args.html)
    if not path.exists():
        print(f"FAIL: file not found: {path}")
        return 2

    text = path.read_text(encoding="utf-8", errors="replace")
    failed = []
    for name, pattern in CHECKS.items():
        ok = bool(pattern.search(text))
        print(f"{'PASS' if ok else 'WARN'}: {name}")
        if not ok and name in {"html", "viewport", "script"}:
            failed.append(name)

    if len(re.findall(r"\{[^{}]{0,160}\}", text)) > 200:
        print("WARN: many object literals; confirm raw dataset was not embedded unnecessarily.")

    if "data.xlsx" in text:
        print("PASS: DATA_URL convention detected" if "DATA_URL" in text else "WARN: data.xlsx referenced without DATA_URL")

    if failed:
        print("FAIL: critical static checks: " + ", ".join(failed))
        return 1

    print("PASS: static validation complete. Browser/runtime verification is still required.")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
