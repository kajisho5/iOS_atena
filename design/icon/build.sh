#!/bin/sh
# Builds AtenaPrint/Resources/AppIcon.icon from spec.json with fresnel (https://github.com/kajisho5/fresnel),
# adds the Tinted variant, validates strictly and writes previews and exports to docs/icon.
set -eu
cd "$(dirname "$0")"
F="npx -y fresnel-icon@0.2.2"
OUT=../../AtenaPrint/Resources/AppIcon.icon
rm -rf "$OUT"
$F build spec.json -o "$OUT"
$F set "$OUT" --target Card/Postcard --props '{"opacity":0.9}' --appearance tinted > /dev/null
$F validate "$OUT" --strict
$F render "$OUT" --sheet -o ../../docs/icon/appearances.png
rm -rf ../../docs/icon/AppIcon.appiconset ../../docs/icon/png
$F export "$OUT" -o ../../docs/icon --formats appiconset,png --force
