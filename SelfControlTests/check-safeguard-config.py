"""Check the actual shipped configuration and nib wiring, without opening the app."""
import plistlib
from pathlib import Path
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parent.parent
info = plistlib.loads((root / "Info.plist").read_bytes())
assert "SUFeedURL" not in info, "Custom app must not download official replacements"
assert info.get("SUEnableAutomaticChecks") is False
assert info.get("SUAutomaticallyUpdate") is False

for name in ("MainMenu", "PreferencesGeneralViewController"):
    tree = ET.parse(root / "Base.lproj" / f"{name}.xib")
    assert not tree.findall(".//*[@customClass='SUUpdater']"), "An updater must never be instantiated"
    assert not tree.findall(".//*[@selector='checkForUpdates:']"), "Manual update route must be removed"
    assert not tree.findall(".//*[@keyPath='automaticallyChecksForUpdates']")

tree = ET.parse(root / "Base.lproj" / "DomainList.xib")
items = tree.findall(".//menu[@id='bundle-menu']/items/menuItem")
assert len(items) == 3
for item in items:
    represented = item.find("string[@key='representedObject']")
    assert represented is not None and represented.text == item.attrib["title"]
    action = item.find("connections/action")
    assert action is not None and action.attrib["selector"] == "importSiteBundle:"
    assert action.attrib["target"] == "48"

project = (root / "SelfControl.xcodeproj/project.pbxproj").read_text()
assert "Sparkle.framework in Frameworks" not in project
assert "Sparkle.framework in Embed Frameworks" not in project
for helper in ("SCBlockClock", "SCSiteBundles", "SCProtectionStatus"):
    # Each target gets one build declaration and one Sources phase entry.
    assert project.count(f"/* {helper}.m in Sources */") == 12, helper

print("PASS: updater disabled, site bundle actions wired, shared helpers linked")
