#!/usr/bin/env python3
"""Build the RAVEN icon theme: Papirus-Dark with grey folders.

Only creates symlinks under ~/.local/share/icons/RAVEN; never touches
/usr/share/icons. Re-runnable: it rebuilds into a fresh temp dir and swaps it in.
"""
import configparser
import os
import shutil
import subprocess

PAPIRUS = "/usr/share/icons/Papirus"
home = os.path.expanduser("~")
dest = os.path.join(home, ".local/share/icons/RAVEN")
tmp = dest + ".new"

def trash(path):
    # Never delete outright: move the old copy to the Trash (trash-cli).
    if os.path.lexists(path):
        subprocess.run(["trash-put", path], check=True)


# Skip when the result would be the same: same Papirus, same RAVEN icons, same script.
import hashlib
h = hashlib.sha256(open(os.path.abspath(__file__), "rb").read())
h.update(open(os.path.join(PAPIRUS, "index.theme"), "rb").read())
h.update(str(os.stat(os.path.join(PAPIRUS, "index.theme")).st_mtime).encode())
extra_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "icons")
for name in sorted(os.listdir(extra_dir)) if os.path.isdir(extra_dir) else []:
    h.update(name.encode())
    h.update(open(os.path.join(extra_dir, name), "rb").read())
stamp = h.hexdigest()
stamp_file = os.path.join(dest, ".raven-stamp")
if os.path.exists(stamp_file) and open(stamp_file).read().strip() == stamp:
    print(f"make-icons: {dest} is up to date")
    raise SystemExit(0)

trash(tmp)
os.makedirs(tmp)

index = configparser.ConfigParser(interpolation=None)
index.optionxform = str
index.read(os.path.join(PAPIRUS, "index.theme"))

dirs, count = [], 0
for size in sorted(os.listdir(PAPIRUS)):
    places = os.path.join(PAPIRUS, size, "places")
    if not os.path.isdir(places) or f"{size}/places" not in index:
        continue
    made = False
    for name in os.listdir(places):
        path = os.path.join(places, name)
        if not os.path.islink(path):
            continue
        # Follow chains (folder-videos -> folder-video -> folder-blue-video).
        target = os.path.basename(os.path.realpath(path))
        if "-blue" not in target or "-bluegrey" in target:
            continue
        grey = os.path.join(places, target.replace("-blue", "-grey", 1))
        if not os.path.exists(grey):
            continue
        os.makedirs(os.path.join(tmp, size, "places"), exist_ok=True)
        os.symlink(grey, os.path.join(tmp, size, "places", name))
        made, count = True, count + 1
    if made:
        dirs.append(f"{size}/places")

# RAVEN's own app icons (raven/icons/*.svg), e.g. Warp in the Shade of Z style.
extra = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "icons")
extras = sorted(f for f in os.listdir(extra) if f.endswith(".svg")) if os.path.isdir(extra) else []
if extras:
    os.makedirs(os.path.join(tmp, "scalable/apps"))
    for f in extras:
        shutil.copy(os.path.join(extra, f), os.path.join(tmp, "scalable/apps", f))
    dirs.append("scalable/apps")
    index["scalable/apps"] = {"Size": "64", "MinSize": "8", "MaxSize": "512",
                              "Type": "Scalable", "Context": "Applications"}

out = configparser.ConfigParser(interpolation=None)
out.optionxform = str
out["Icon Theme"] = {
    "Name": "RAVEN",
    "Comment": "Papirus-Dark with grey folders",
    "Inherits": "Papirus-Dark,Papirus,hicolor",
    "Directories": ",".join(dirs),
}
for d in dirs:
    out[d] = dict(index[d])
with open(os.path.join(tmp, "index.theme"), "w") as f:
    out.write(f, space_around_delimiters=False)

open(os.path.join(tmp, ".raven-stamp"), "w").write(stamp + "\n")
trash(dest)
os.rename(tmp, dest)
print(f"make-icons: {count} grey folder icons in {len(dirs)} dirs, {len(extras)} custom app icons -> {dest}")
