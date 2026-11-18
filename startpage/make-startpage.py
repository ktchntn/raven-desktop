#!/usr/bin/env python3
"""RAVEN startpage: a new-tab extension for Chromium and Firefox, built from src/.

  dist/chromium/         unpacked extension (fixed ID via startpage-key.pub.b64);
                         installed to ~/.local/share/raven/startpage, loaded once with
                         chrome://extensions > Load unpacked
  dist/raven-startpage.xpi   Firefox (id startpage@raven.local, also sets the homepage); install.sh
                         copies it into the profile's extensions/ folder (needs user.js:
                         xpinstall.signatures.required=false, extensions.autoDisableScopes=0)

The palette in src/style.css is replaced with tokens.json's, so it follows RAVEN."""
import json
import os
import re
import shutil
import subprocess
import zipfile

here = os.path.dirname(os.path.abspath(__file__))
src = os.path.join(here, "src")
dist = os.path.join(here, "dist")
pal = json.load(open(os.path.join(here, "..", "tokens.json")))["palette"]

base = {
    "manifest_version": 3,
    "name": "RAVEN Start",
    "version": "1.2",
    "description": "RAVEN new tab: clock, search with !bangs, pentest links",
    "icons": {"128": "icon.png"},
    "chrome_url_overrides": {"newtab": "newtab.html"},
}
chromium = dict(base, key=open(os.path.join(here, "startpage-key.pub.b64")).read().strip())
firefox = dict(base,
               browser_specific_settings={"gecko": {"id": "startpage@raven.local", "strict_min_version": "115.0"}},
               chrome_settings_overrides={"homepage": "newtab.html"})


def build(folder, manifest):
    shutil.rmtree(folder, ignore_errors=True)
    os.makedirs(folder)
    for name in os.listdir(src):
        shutil.copy(os.path.join(src, name), folder)
    css = os.path.join(folder, "style.css")
    text = open(css).read()
    for key, value in pal.items():
        text, n = re.subn(rf"--{key}: #[0-9A-Fa-f]{{6}};", f"--{key}: #{value};", text)
    open(css, "w").write(text)
    subprocess.run(["magick", "-size", "128x128", "xc:none", "-fill", "#" + pal["void"],
                    "-draw", "roundrectangle 0,0 127,127 28,28", "-fill", "#" + pal["accent"],
                    "-draw", "circle 64,64 64,34", os.path.join(folder, "icon.png")], check=True)
    with open(os.path.join(folder, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")


build(os.path.join(dist, "chromium"), chromium)
ff = os.path.join(dist, "firefox")
build(ff, firefox)
xpi = os.path.join(dist, "raven-startpage.xpi")
with zipfile.ZipFile(xpi, "w", zipfile.ZIP_DEFLATED) as z:
    for name in sorted(os.listdir(ff)):
        z.write(os.path.join(ff, name), name)
print("built", os.path.join(dist, "chromium"), "and", xpi)
