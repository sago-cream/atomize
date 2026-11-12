#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/godot/load-local-env.sh"

if [[ "${1:-}" == "--help" ]]; then
    echo "Usage: bun run ios"
    echo "Export, build, install, and launch Atomize in an iPhone simulator."
    echo "Set IOS_SIMULATOR_ID or IOS_SIMULATOR_NAME to select a simulator."
    echo "Requires matching Godot export templates with native simulator support."
    exit 0
fi
[[ $# -eq 0 ]] || { echo "Usage: bun run ios" >&2; exit 1; }

DEVICE_ID="${IOS_SIMULATOR_ID:-}"
if [[ -z "$DEVICE_ID" ]]; then
    DEVICE_ID="$(xcrun simctl list devices available --json | python3 -c '
import json, os, sys
name = os.environ.get("IOS_SIMULATOR_NAME")
devices = [d for group in json.load(sys.stdin)["devices"].values() for d in group
           if d.get("isAvailable") and (d["name"] == name if name else "iPhone" in d["name"])]
devices.sort(key=lambda d: d["state"] != "Booted")
if not devices:
    sys.exit("No available iPhone simulator. Set IOS_SIMULATOR_ID or IOS_SIMULATOR_NAME.")
print(devices[0]["udid"])
')"
fi

EXPORT_DIR="$ROOT_DIR/godot/build/ios-simulator"
export IOS_EXPORT_PATH="$EXPORT_DIR/atomize-ios.zip"
IOS_EXPORT_PROJECT_ONLY=1 GODOT_IOS_TEAM_ID="${GODOT_IOS_TEAM_ID:-${APPLE_TEAM_ID:-0000000000}}" \
    bun run "$ROOT_DIR/scripts/godot/export-mobile.ts" ios

python3 - "$EXPORT_DIR" <<'PY'
import pathlib, platform, plistlib, subprocess, sys
architecture = platform.machine()
directory = pathlib.Path(sys.argv[1])
project = next(directory.glob("*.xcodeproj/project.pbxproj")).read_text()
for framework in directory.glob("*.xcframework"):
    if framework.name not in project:
        continue
    info = plistlib.loads((framework / "Info.plist").read_bytes())
    if not any(item.get("SupportedPlatform") == "ios" for item in info["AvailableLibraries"]):
        continue
    libraries = [item for item in info["AvailableLibraries"]
                 if item.get("SupportedPlatformVariant") == "simulator"
                 and item.get("SupportedPlatform") == "ios"
                 and architecture in item["SupportedArchitectures"]]
    if not libraries or subprocess.run(
        ["lipo", "-verify_arch", architecture, str(framework / libraries[0]["LibraryIdentifier"] / libraries[0]["LibraryPath"])],
        capture_output=True,
    ).returncode:
        sys.exit(f"{framework.name} lacks {architecture} iOS simulator code. Install matching simulator-capable Godot templates or set GODOT_IOS_TEMPLATE_DEBUG. Use bun run iphone for a physical device.")
PY

CONFIGURATION="${IOS_CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${IOS_DERIVED_DATA_PATH:-$EXPORT_DIR/DerivedData}"
APP_PATH="${IOS_APP_PATH:-$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION-iphonesimulator/atomize-ios.app}"
BUNDLE_ID="${IOS_BUNDLE_ID:-dev.hsichen.atomize}"
xcrun simctl boot "$DEVICE_ID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$DEVICE_ID" -b
if [[ "${IOS_SKIP_OPEN:-0}" != "1" ]]; then open -a Simulator; fi
xcodebuild -project "$EXPORT_DIR/atomize-ios.xcodeproj" -scheme atomize-ios \
    -configuration "$CONFIGURATION" -sdk iphonesimulator -destination "id=$DEVICE_ID" \
    -derivedDataPath "$DERIVED_DATA_PATH" CODE_SIGNING_ALLOWED=NO build
[[ -d "$APP_PATH" ]] || { echo "Built app not found: $APP_PATH" >&2; exit 1; }
xcrun simctl install "$DEVICE_ID" "$APP_PATH"
if [[ "${IOS_SKIP_LAUNCH:-0}" != "1" ]]; then
    xcrun simctl launch --terminate-running-process "$DEVICE_ID" "$BUNDLE_ID"
fi
