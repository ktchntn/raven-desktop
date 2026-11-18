#!/usr/bin/env python3
"""RAVEN theme for Chromium: writes theme/manifest.json from ../tokens.json (same palette as
the shell, Firefox and VS Code). A Chromium theme is an extension with colours only; the active
tab always takes the toolbar colour, so: frame/tab strip = void, toolbar + active tab = surface,
address bar = raised. Lime: the active tab's title, a 2 px line along the top of the active tab
(the toolbar image starts at the top of the active tab, like Firefox's tab line), New Tab links.
The New Tab page shows the current RAVEN wallpaper, dimmed (--wallpaper FILE, or none).

Focus rings, toggles and spinners can't be themed: Chromium derives them itself."""
import argparse
import json
import os
import subprocess

here = os.path.dirname(os.path.abspath(__file__))
state = os.path.expanduser("~/.local/state/raven")
ap = argparse.ArgumentParser()
ap.add_argument("--wallpaper", default=os.path.join(state, "wallpaper-current", "Virtual-1.png"),
                help="New Tab background ('' for none)")
args = ap.parse_args()
pal = json.load(open(os.path.join(here, "..", "tokens.json")))["palette"]


def rgb(name):
    h = pal[name]
    return [int(h[i:i + 2], 16) for i in (0, 2, 4)]


colors = {
    "frame": rgb("void"),
    "frame_inactive": rgb("void"),
    "frame_incognito": rgb("void"),
    "frame_incognito_inactive": rgb("void"),
    "background_tab": rgb("void"),
    "background_tab_inactive": rgb("void"),
    "background_tab_incognito": rgb("void"),
    "background_tab_incognito_inactive": rgb("void"),
    "toolbar": rgb("surface"),
    "toolbar_text": rgb("ink"),
    "toolbar_button_icon": rgb("dim"),
    "tab_text": rgb("accent"),
    "tab_background_text": rgb("dim"),
    "tab_background_text_inactive": rgb("muted"),
    "tab_background_text_incognito": rgb("dim"),
    "tab_background_text_incognito_inactive": rgb("muted"),
    "bookmark_text": rgb("dim"),
    "omnibox_background": rgb("raised"),
    "omnibox_text": rgb("ink"),
    "ntp_background": rgb("void"),
    "ntp_text": rgb("ink"),
    "ntp_link": rgb("accent"),
    "ntp_header": rgb("accent"),
}
theme_dir = os.path.join(here, "theme")
os.makedirs(os.path.join(theme_dir, "images"), exist_ok=True)


def hexc(name):
    return "#" + pal[name]


# Toolbar (and active tab) background: surface with a 2 px lime line along the active tab's top edge.
# Measured with a row-coded test image (Chromium 138, tiled window): image row = window row + 16,
# and the active tab's top edge is window row 6, so the line goes in image rows 22-23.
TAB_TOP = 22
subprocess.run(["magick", "-size", "64x260", "xc:" + hexc("surface"), "-fill", hexc("accent"),
                "-draw", f"rectangle 0,{TAB_TOP} 63,{TAB_TOP + 1}", os.path.join(theme_dir, "images", "toolbar.png")],
               check=True)
images = {"theme_toolbar": "images/toolbar.png"}
properties = {}
ntp = os.path.join(theme_dir, "images", "ntp.png")
if args.wallpaper and os.path.exists(args.wallpaper):
    subprocess.run(["magick", args.wallpaper, "-modulate", "70", ntp], check=True)
    images["theme_ntp_background"] = "images/ntp.png"
    properties = {"ntp_background_alignment": "center", "ntp_background_repeat": "no-repeat"}
elif os.path.exists(ntp):
    os.remove(ntp)

manifest = {
    "manifest_version": 3,
    "name": "RAVEN",
    "version": "2.2",
    # Fixed extension ID (public key only, no private key needed for an unpacked theme): without it the
    # ID comes from the folder path, and a theme once disabled there (by switching to another theme)
    # stays disabled on Load unpacked.
    "key": open(os.path.join(here, "theme-key.pub.b64")).read().strip(),
    "description": "RAVEN: void black, lime #C6FF00 (matches the Hyprland shell)",
    "theme": {"colors": colors, "images": images, **({"properties": properties} if properties else {})},
}
out = os.path.join(here, "theme", "manifest.json")
with open(out, "w") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")
print("wrote", out)
