#!/usr/bin/env bash
# RAVEN login screen (lightdm-gtk-greeter). Run with sudo:
#     sudo bash ~/.local/src/raven/login/install-login.sh
#
# The login screen runs before you log in, as its own user, so it cannot read your home
# folder: this copies what it needs to system folders. It deletes nothing and backs up the
# one file it replaces (/etc/lightdm/lightdm-gtk-greeter.conf -> .kali-backup).
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this with sudo: sudo bash $0" >&2
    exit 1
fi
user="${SUDO_USER:-kali}"
home="$(getent passwd "$user" | cut -d: -f6)"
src="$home/.local/src/raven/login"
conf=/etc/lightdm/lightdm-gtk-greeter.conf

echo "1/4  Backing up $conf"
if [ -e "$conf" ] && [ ! -e "$conf.kali-backup" ]; then
    cp -p "$conf" "$conf.kali-backup"
fi

echo "2/4  Copying the background, fonts and adw-gtk3-dark to system folders"
install -d -m755 /usr/share/backgrounds/raven
install -m644 "$src/background.png" /usr/share/backgrounds/raven/login.png
install -d -m755 /usr/local/share/fonts/raven
install -m644 "$home"/.local/share/fonts/raven/*.ttf /usr/local/share/fonts/raven/
fc-cache -f /usr/local/share/fonts/raven >/dev/null
if [ ! -d /usr/share/themes/adw-gtk3-dark ]; then
    cp -r "$home/.local/share/themes/adw-gtk3-dark" /usr/share/themes/adw-gtk3-dark
    chown -R root:root /usr/share/themes/adw-gtk3-dark
    chmod -R u=rwX,go=rX /usr/share/themes/adw-gtk3-dark
fi

echo "3/4  Installing the RAVEN greeter theme"
install -d -m755 /usr/share/themes/RAVEN/gtk-3.0
install -m644 "$src/gtk.css" /usr/share/themes/RAVEN/gtk-3.0/gtk.css
install -m644 "$src/index.theme" /usr/share/themes/RAVEN/index.theme

echo "4/4  Writing $conf"
install -m644 "$src/lightdm-gtk-greeter.conf" "$conf"

echo
echo "Done. You'll see it next time you log out or reboot."
echo "To go back to Kali's login screen:  sudo cp $conf.kali-backup $conf"
