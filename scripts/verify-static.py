#!/usr/bin/env python3
"""Dependency-free current-tree contracts. Never prints credential matches."""
import hashlib
import json
from pathlib import Path
import plistlib
import re
import struct
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def app_settings():
    project = (ROOT / "FiveMinuteExplorer.xcodeproj/project.pbxproj").read_text()
    blocks = re.findall(r"buildSettings = \{(.*?)\n\s*\};", project, re.S)
    app = [b for b in blocks if "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;" in b]
    if len(app) != 2:
        raise ValueError("Expected two app build configurations")
    return [dict(re.findall(r'^\s*(\w+) = "?([^;\n]*?)"?;', b, re.M)) for b in app]


def sensitive_findings(path, data):
    parts = Path(path).parts
    name = parts[-1].lower()
    suffixes = (".p8", ".p12", ".pem", ".key", ".mobileprovision", ".jks", ".keystore", ".ipa", ".xcuserstate")
    if (name == ".env" or name.startswith(".env.") and name != ".env.example"
        or name.endswith(suffixes)
        or any(p.lower() in {"xcuserdata", "deriveddata", "build", ".build", ".ci-artifacts"}
               or p.lower().endswith((".xcarchive", ".xcresult")) for p in parts)):
        yield "sensitive-file"
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        return
    rules = {
        "private-key": r"-----BEGIN (?:RSA |EC |OPENSSH |DSA |ENCRYPTED )?PRIVATE KEY-----",
        "github-token": r"\b(?:gh[pousr]_[A-Za-z0-9]{36,}|github_pat_[A-Za-z0-9_]{60,})\b",
        "aws-access-id": r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b",
        "openai-key": r"\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{40,}\b",
        "slack-token": r"\bxox[baprs]-[A-Za-z0-9-]{20,}\b",
    }
    for rule, pattern in rules.items():
        for match in re.finditer(pattern, text):
            yield f"{rule}:line {text.count(chr(10), 0, match.start()) + 1}"


def verify():
    catalog = json.loads((ROOT / "FiveMinuteExplorer/Resources/quests_v1.json").read_text())
    assert catalog["catalogVersion"] == "v1", "catalog version"
    assert catalog["questCount"] == len(catalog["quests"]) == 580, "catalog count"
    assert len({q["id"] for q in catalog["quests"]}) == 580, "unique IDs"
    config = json.loads((ROOT / "FiveMinuteExplorer/Resources/recommendation_v1.json").read_text())
    assert config["version"] == "v1", "recommendation version"
    icon = ROOT / "FiveMinuteExplorer/Assets.xcassets/AppIcon.appiconset/five_minute_explorer_icon_production_master_1024.png"
    png = icon.read_bytes()
    assert png[:8] == b"\x89PNG\r\n\x1a\n" and png[12:16] == b"IHDR", "PNG header"
    assert struct.unpack(">II", png[16:24]) == (1024, 1024), "icon dimensions"
    assert hashlib.sha256(png).hexdigest() == "0418609e3d90b93f9bf09966c26f343b4f61f87de8e65fc9be3d3d1f5ad42417", "icon hash"
    privacy = plistlib.loads((ROOT / "FiveMinuteExplorer/PrivacyInfo.xcprivacy").read_bytes())
    assert privacy["NSPrivacyTracking"] is False, "tracking"
    assert privacy["NSPrivacyCollectedDataTypes"] == [], "collected data"
    assert any(p["NSPrivacyAccessedAPIType"] == "NSPrivacyAccessedAPICategoryUserDefaults"
               and "CA92.1" in p["NSPrivacyAccessedAPITypeReasons"]
               for p in privacy["NSPrivacyAccessedAPITypes"]), "UserDefaults reason"
    expected = {
        "MARKETING_VERSION": "0.1.0", "CURRENT_PROJECT_VERSION": "1",
        "INFOPLIST_KEY_ITSAppUsesNonExemptEncryption": "NO", "TARGETED_DEVICE_FAMILY": "1",
        "IPHONEOS_DEPLOYMENT_TARGET": "18.0",
        "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
    }
    for settings in app_settings():
        for key, value in expected.items():
            assert settings.get(key) == value, f"app setting {key}"
    tracked = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).decode().split("\0")
    failures = []
    for path in filter(None, tracked):
        full = ROOT / path
        if full.is_symlink():
            failures.append(f"{path}: tracked-symlink (not scanned)")
            continue
        for finding in sensitive_findings(path, full.read_bytes()):
            failures.append(f"{path}: {finding}")
    if failures:
        raise ValueError("\n".join(failures))
    print("PASS: catalog v1 / 580 unique, config, approved icon, privacy, app settings, tracked-file guard")


if __name__ == "__main__":
    try:
        verify()
    except (AssertionError, ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        sys.exit(1)
