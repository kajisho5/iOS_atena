#!/usr/bin/env python3
"""Fails when a source or resource file is missing from the committed Xcode project.

The project is generated with XcodeGen; this catches forgetting to run `xcodegen generate`
after adding a file. Usage: python3 tools/check_project.py
"""
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PBXPROJ = (ROOT / "AtenaPrint.xcodeproj" / "project.pbxproj").read_text(encoding="utf-8")

missing = []
for folder in ("AtenaPrint", "AtenaPrintTests"):
    for path in sorted((ROOT / folder).rglob("*")):
        if path.suffix not in {".swift", ".xcstrings", ".xcprivacy", ".storekit"}:
            continue
        if f"/* {path.name} */" not in PBXPROJ:
            missing.append(str(path.relative_to(ROOT)))

if missing:
    print("Files missing from AtenaPrint.xcodeproj (run `xcodegen generate`):")
    for item in missing:
        print(f"  {item}")
    sys.exit(1)
print("OK: Xcode project references every source file")
