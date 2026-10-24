#!/usr/bin/env python3
"""Checks that every localization key used in Swift exists in Localizable.xcstrings (and vice versa).

Keys are recognised by their namespace prefix (e.g. "recipients.", "store."). String interpolations
are normalised to %lld / %@ placeholders the same way Xcode extracts them.
Usage: python3 tools/check_strings.py [--list]
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
APP = ROOT / "AtenaPrint"
CATALOG = APP / "Resources" / "Localizable.xcstrings"
PREFIXES = (
    "a11y", "add", "app", "badge", "common", "contacts", "csv", "detail", "editor", "empty", "filter", "font",
    "groups", "layout", "limit", "offset", "paper", "print", "recipients", "sample", "senders", "settings",
    "sidebar", "sort", "store", "tab", "writing",
)
# Literals that look like keys but are not (SF Symbol names).
EXCLUDED = {"sidebar.left"}
LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')
KEY = re.compile(r"^(%s)\.[A-Za-z0-9]+(\.[A-Za-z0-9]+)*( .*)?$" % "|".join(PREFIXES))
INTERP = re.compile(r"\\\((.*?)\)")

# Interpolations whose value is an integer (rendered as %lld); everything else becomes %@.
INT_HINTS = ("count", "index", "imported", "duplicates", "overLimit", "Limit", "warnings", ".id", "includedCount", "id)")


def placeholder(expr: str) -> str:
    if any(hint in expr for hint in INT_HINTS) or re.fullmatch(r"[a-z]+ ?\+ ?1", expr.strip()):
        return "%lld"
    return "%@"


def used_keys() -> dict[str, set[str]]:
    found: dict[str, set[str]] = {}
    for path in APP.rglob("*.swift"):
        text = path.read_text(encoding="utf-8")
        for match in LITERAL.finditer(text):
            literal = match.group(1)
            if not KEY.match(literal) or literal in EXCLUDED:
                continue
            key = INTERP.sub(lambda m: placeholder(m.group(1)), literal)
            found.setdefault(key, set()).add(str(path.relative_to(ROOT)))
    return found


def main() -> int:
    used = used_keys()
    if "--list" in sys.argv:
        for key in sorted(used):
            print(key)
        return 0
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    defined = set(catalog["strings"].keys())
    missing = sorted(set(used) - defined)
    unused = sorted(defined - set(used))
    empty = sorted(k for k, v in catalog["strings"].items()
                   if not v.get("localizations", {}).get("ja", {}).get("stringUnit", {}).get("value"))
    ok = True
    if missing:
        ok = False
        print("Keys used in code but missing from the catalog:")
        for key in missing:
            print(f"  {key}  ({', '.join(sorted(used[key]))})")
    if unused:
        ok = False
        print("Keys in the catalog that are not used in code:")
        for key in unused:
            print(f"  {key}")
    if empty:
        ok = False
        print("Keys without a Japanese value:")
        for key in empty:
            print(f"  {key}")
    if ok:
        print(f"OK: {len(defined)} keys")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
