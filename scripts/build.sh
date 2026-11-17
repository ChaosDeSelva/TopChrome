#!/bin/zsh
set -euo pipefail
project_dir="${0:A:h:h}"
cd "$project_dir"
swift build -c release --disable-sandbox --product TopChrome
app_dir="$project_dir/build/TopChrome.app"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp .build/release/TopChrome "$app_dir/Contents/MacOS/TopChrome"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"
if [[ -f Resources/TopChrome.icns ]]; then
    cp Resources/TopChrome.icns "$app_dir/Contents/Resources/TopChrome.icns"
fi
codesign --force --sign - --entitlements Resources/TopChrome.entitlements "$app_dir"
print -r -- "$app_dir"
