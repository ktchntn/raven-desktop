#!/usr/bin/env bash
# Hides launcher entries that only make sense on other desktops, by writing NoDisplay=true
# copies of them (never touching the originals, never overwriting an existing override):
#   - XScreenSaver demos      -> ~/.local/share/applications/screensavers/  (hidden everywhere;
#                                they are marked MATE-only anyway)
#   - XFCE/LXQt/KDE/GNOME-only -> ~/.local/share/raven/hyprland-only/applications/ (only Hyprland
#                                reads this folder: hyprland.lua puts it first in XDG_DATA_DIRS)
set -euo pipefail
saver="$HOME/.local/share/applications/screensavers"
only="$HOME/.local/share/raven/hyprland-only/applications"
mkdir -p "$saver" "$only"
made=0

for src in /usr/share/applications/screensavers/*.desktop; do
    [ -e "$src" ] || continue
    dst="$saver/$(basename "$src")"
    [ -e "$dst" ] && continue
    { cat "$src"; printf '\n# RAVEN: hidden from the launcher (XScreenSaver demo)\nNoDisplay=true\n'; } > "$dst"
    made=$((made + 1))
done

for src in /usr/share/applications/*.desktop; do
    grep -q '^NoDisplay=true' "$src" && continue
    shown=$(grep -m1 '^OnlyShowIn=' "$src" | cut -d= -f2 || true)
    [ -n "$shown" ] || continue
    dst="$only/$(basename "$src")"
    [ -e "$dst" ] && continue
    { cat "$src"; printf '\n# RAVEN: hidden in Hyprland only (%s-only entry); other sessions never read this folder\nNoDisplay=true\n' "${shown%%;*}"; } > "$dst"
    made=$((made + 1))
done

echo "hide-entries: $made new overrides"
