#!/usr/bin/env bash
# RAVEN app theme: GTK3/GTK4 (adw-gtk3-dark + RAVEN colours), RAVEN icons, Qt (qt6ct).
# Usage: apply-theme.sh [path/to/extracted/adw-gtk3-dark]   (theme needed only on first run)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
themes="$HOME/.local/share/themes"

if [ ! -d "$themes/adw-gtk3-dark" ]; then
	src="${1:?first run: pass the extracted adw-gtk3-dark folder (github.com/lassekongo83/adw-gtk3 releases)}"
	mkdir -p "$themes"
	cp -r "$src" "$themes/adw-gtk3-dark"
fi

install -Dm644 "$here/gtk/raven.css" "$HOME/.config/gtk-3.0/gtk.css"
install -Dm644 "$here/gtk/raven.css" "$HOME/.config/gtk-4.0/gtk.css"
install -Dm644 "$here/gtk/settings.ini" "$HOME/.config/gtk-3.0/settings.ini"
install -Dm644 "$here/gtk/settings.ini" "$HOME/.config/gtk-4.0/settings.ini"

python3 -I "$here/gtk/make-icons.py"
[ -d "$HOME/.local/share/icons/Shade-of-Z-White" ] || echo "apply-theme.sh: warning: Shade-of-Z-White icons not installed (copy ~/Icons/'Shade of Z - White' to ~/.local/share/icons/Shade-of-Z-White)" >&2

install -Dm644 "$here/gtk/raven-qt.conf" "$HOME/.config/qt6ct/colors/RAVEN.conf"
mkdir -p "$HOME/.config/qt6ct"
sed "s|@HOME@|$HOME|g" "$here/gtk/qt6ct.conf" > "$HOME/.config/qt6ct/qt6ct.conf"

# GTK apps on Wayland read these (XFCE uses xfconf instead, so it is unaffected).
gs() { gsettings set org.gnome.desktop.interface "$1" "$2" 2>/dev/null; }
gs gtk-theme "adw-gtk3-dark"
gs icon-theme "Shade-of-Z-White"
gs cursor-theme "Bibata-Modern-Classic"
gs cursor-size 24
gs color-scheme "prefer-dark"
gs font-name "Space Grotesk 11"
gs document-font-name "Space Grotesk 11"
gs monospace-font-name "JetBrainsMono Nerd Font 10"
gs accent-color "slate" || true

echo "apply-theme.sh: done. Reopen apps to see the change."
