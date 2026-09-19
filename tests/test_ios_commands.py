"""Exercise native command routing with isolated projects and mocked Apple/Godot tools."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


MOCK_TOOL = '''#!/usr/bin/env python3
import json, os, pathlib, platform, plistlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
if name == "godot" and "--version" in args:
    print("4.7.stable.test")
    sys.exit(0)
with open(os.environ["TOOL_LOG"], "a") as log:
    log.write(json.dumps([name, *args]) + "\\n")
if name == "godot" and "--export-debug" in args:
    if os.environ.get("FAIL_EXPORT"):
        sys.exit(41)
    output = pathlib.Path(args[-1])
    output.with_suffix(".xcodeproj").mkdir(parents=True, exist_ok=True)
    framework = output.parent / (output.stem + ".xcframework")
    (output.with_suffix(".xcodeproj") / "project.pbxproj").write_text(framework.name)
    library = framework / "ios-simulator" / "libgodot.a"
    library.parent.mkdir(parents=True, exist_ok=True)
    library.touch()
    unrelated = output.parent / "visionos.xcframework"
    unrelated.mkdir(exist_ok=True)
    (unrelated / "Info.plist").write_bytes(plistlib.dumps({"AvailableLibraries": [{"SupportedPlatform": "xros"}]}))
    (framework / "Info.plist").write_bytes(plistlib.dumps({"AvailableLibraries": [{
        "SupportedPlatform": "ios", "SupportedPlatformVariant": "simulator",
        "SupportedArchitectures": [platform.machine()], "LibraryIdentifier": "ios-simulator",
        "LibraryPath": "libgodot.a"}]}))
elif name == "lipo" and os.environ.get("MISSING_ARCH"):
    sys.exit(1)
elif name == "xcodebuild":
    pathlib.Path(os.environ["IOS_APP_PATH"]).mkdir(parents=True, exist_ok=True)
elif name == "xcrun" and args[:3] == ["simctl", "list", "devices"]:
    print(json.dumps({"devices": {"iOS": [
        {"name": "iPhone Test", "udid": "SIM-ID", "state": "Booted", "isAvailable": True}]}}))
'''


class IOSCommands(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        source = Path(__file__).resolve().parents[1]
        shutil.copytree(source / "scripts", self.root / "scripts")
        shutil.copy(source / "package.json", self.root / "package.json")
        project = source / "godot" if (source / "godot/project.godot").exists() else source
        self.project = self.root / "godot" if project != source else self.root
        self.project.mkdir(exist_ok=True)
        for name in ["project.godot", "export_presets.cfg"]:
            shutil.copy(project / name, self.project / name)
        self.original = (self.project / "export_presets.cfg").read_bytes()
        self.original_project = (self.project / "project.godot").read_bytes()
        bin_path = self.root / "bin"
        bin_path.mkdir()
        for name in ["godot", "xcrun", "xcodebuild", "lipo", "open"]:
            path = bin_path / name
            path.write_text(MOCK_TOOL)
            path.chmod(0o755)
        self.log = self.root / "tools.jsonl"
        self.env = {key: value for key, value in os.environ.items()
                    if not key.startswith(("IOS_", "GODOT_", "APPLE_", "VITE_SUPABASE_"))}
        self.env.update(PATH=str(bin_path) + os.pathsep + os.environ["PATH"],
                        GODOT_BIN=str(bin_path / "godot"), APPLE_TEAM_ID="ABCDE12345",
                        GODOT_IOS_TEAM_ID="ABCDE12345", IOS_DEVICE_ID="PHONE-ID",
                        IOS_APP_PATH=str(self.root / "app.app"), IOS_SKIP_OPEN="1",
                        TOOL_LOG=str(self.log))

    def run_command(self, command, **env):
        result = subprocess.run(["bun", "run", command], cwd=self.root,
                                env=self.env | env, text=True, capture_output=True)
        self.assertEqual((self.project / "export_presets.cfg").read_bytes(), self.original)
        self.assertEqual((self.project / "project.godot").read_bytes(), self.original_project)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        return result, calls

    def test_simulator_builds_installs_and_relaunches_without_signing(self):
        self.env.pop("APPLE_TEAM_ID")
        self.env.pop("GODOT_IOS_TEAM_ID")
        result, calls = self.run_command("ios")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        build = next(call for call in calls if call[0] == "xcodebuild")
        self.assertEqual(build[build.index("-sdk") + 1], "iphonesimulator")
        self.assertIn("CODE_SIGNING_ALLOWED=NO", build)
        self.assertTrue(any(call[1:3] == ["simctl", "install"] for call in calls))
        self.assertTrue(any(call[1:4] == ["simctl", "launch", "--terminate-running-process"] for call in calls))
        self.assertFalse(any("devicectl" in call for call in calls))

    def test_iphone_updates_in_place_and_relaunches(self):
        result, calls = self.run_command("iphone")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        build = next(call for call in calls if call[0] == "xcodebuild")
        self.assertEqual(build[build.index("-sdk") + 1], "iphoneos")
        self.assertTrue(any(call[1:5] == ["devicectl", "device", "install", "app"] for call in calls))
        self.assertTrue(any(call[1:5] == ["devicectl", "device", "process", "launch"] for call in calls))
        self.assertFalse(any("uninstall" in call or "simctl" in call for call in calls))

    def test_export_failure_restores_presets_and_stops_build(self):
        result, calls = self.run_command("ios", FAIL_EXPORT="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call[0] == "xcodebuild" for call in calls))

    def test_missing_simulator_architecture_stops_before_install(self):
        result, calls = self.run_command("ios", MISSING_ARCH="1")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("simulator-capable Godot templates", result.stderr)
        self.assertFalse(any(call[0] == "xcodebuild" or "install" in call for call in calls))

    def test_skip_launch_still_installs(self):
        result, calls = self.run_command("ios", IOS_SKIP_LAUNCH="1")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(any(call[1:3] == ["simctl", "install"] for call in calls))
        self.assertFalse(any("launch" in call for call in calls))


if __name__ == "__main__":
    unittest.main()
