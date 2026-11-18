#!/usr/bin/env bash
# RAVEN installer for Kali + Hyprland. Safe to re-run.
#
#   ./install.sh               install / update everything for this user (no sudo)
#   ./install.sh --dry-run     only show what would change
#   ./install.sh --packages    first install the apt packages (asks for sudo)
#   ./install.sh --login       also install the login screen (asks for sudo)
#
# Every file is compared before it is written: identical files are skipped, and a file
# that differs is first copied to ~/.local/state/raven/backups/<time>/. Nothing is deleted.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
upstream="$HOME/.local/src/Nihil-Shell"
upstream_url="https://github.com/poligle/Nihil-Shell.git"
upstream_commit="5c170b9550075df4efcd3d1d3d97590cc8325be3"
adw_version="v6.5"
backups="$HOME/.local/state/raven/backups/$(date +%Y-%m-%d_%H.%M.%S)"
scratch="$HOME/.cache/raven-build/install"    # reused and overwritten each run, never deleted
mkdir -p "$scratch"

dry=0 packages=0 login=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) dry=1 ;;
        --packages) packages=1 ;;
        --login) login=1 ;;
        -h|--help) sed -n '2,11p' "$0"; exit 0 ;;
        *) echo "install.sh: unknown option $arg (see --help)" >&2; exit 2 ;;
    esac
done

PACKAGES=(hyprland quickshell hyprlock hypridle hyprpaper hyprsunset hyprland-qtutils
    xdg-desktop-portal-hyprland uwsm kitty fastfetch cliphist wl-clipboard wtype grim slurp
    wf-recorder brightnessctl playerctl lxqt-policykit cava qalc qt6-shader-baker btop trash-cli jq
    papirus-icon-theme bibata-cursor-theme flameshot imagemagick python3-numpy python3-pil
    qml6-module-qtquick-shapes qml6-module-qtquick-effects qml6-module-qt-labs-folderlistmodel
    qml6-module-qtquick-controls qml6-module-qtquick-layouts qml6-module-qtquick-templates
    qml6-module-qtqml-workerscript qml6-module-qtquick-window)

changed=0
step() { printf '\n\033[38;2;198;255;0m●\033[0m %s\n' "$*"; }
note() { printf '  %s\n' "$*"; }
run() {
    if [ "$dry" = 1 ]; then printf '  would run: %s\n' "$*"; else "$@"; fi
}
backup() {   # backup PATH: copy an existing file into this run's backup folder
    local rel="${1#"$HOME"/}"
    run mkdir -p "$backups/$(dirname "$rel")"
    run cp -pP "$1" "$backups/$rel"
}
place() {    # place SRC DST [MODE]: install SRC at DST unless identical; back up a different DST
    local src="$1" dst="$2" mode="${3:-644}"
    if [ -e "$dst" ] && cmp -s "$src" "$dst"; then
        return 0
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        note "update  ${dst/#$HOME/\~} (old copy kept in the backup folder)"
        backup "$dst"
    else
        note "new     ${dst/#$HOME/\~}"
    fi
    run install -D -m "$mode" "$src" "$dst"
    changed=$((changed + 1))
}
have_display() {
    if command -v hyprctl >/dev/null && hyprctl -j monitors >/dev/null 2>&1; then return 0; fi
    if command -v xrandr >/dev/null && xrandr --query >/dev/null 2>&1; then return 0; fi
    return 1
}

# ---------------------------------------------------------------------------------------
step "Packages"
missing=()
for p in "${PACKAGES[@]}"; do
    dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -q 'ok installed' || missing+=("$p")
done
if [ ${#missing[@]} -eq 0 ]; then
    note "all ${#PACKAGES[@]} packages installed"
elif [ "$packages" = 1 ]; then
    run sudo apt-get update
    run sudo apt-get install -y "${missing[@]}"
else
    note "missing: ${missing[*]}"
    note "install them with:  ./install.sh --packages   (or: sudo apt install ${missing[*]})"
    [ "$dry" = 1 ] || { echo; echo "Install the packages first, then run this again." >&2; exit 1; }
fi

# ---------------------------------------------------------------------------------------
step "NIHIL shell source (upstream, pinned)"
if [ ! -d "$upstream/.git" ]; then
    run git clone "$upstream_url" "$upstream"
    run git -C "$upstream" checkout --quiet "$upstream_commit"
else
    have="$(git -C "$upstream" rev-parse HEAD)"
    if [ "$have" = "$upstream_commit" ]; then
        note "at the pinned commit ${upstream_commit:0:7}"
    else
        note "checkout is at ${have:0:7}, RAVEN is built for ${upstream_commit:0:7}: leaving it as it is"
    fi
fi

# ---------------------------------------------------------------------------------------
step "Fonts (Doto, Space Grotesk, Space Mono, JetBrains Mono Nerd Font)"
fonts="$HOME/.local/share/fonts/raven"
if ls "$fonts"/Doto*.ttf "$fonts"/SpaceGrotesk*.ttf "$fonts"/SpaceMono-Regular.ttf "$fonts"/JetBrainsMonoNerdFont-Regular.ttf >/dev/null 2>&1; then
    note "installed"
else
    dl="$scratch/fonts"; mkdir -p "$dl"
    for f in "ofl/doto/Doto%5BROND,wght%5D.ttf" "ofl/spacegrotesk/SpaceGrotesk%5Bwght%5D.ttf" \
             "ofl/spacemono/SpaceMono-Regular.ttf" "ofl/spacemono/SpaceMono-Bold.ttf" \
             "ofl/spacemono/SpaceMono-Italic.ttf" "ofl/spacemono/SpaceMono-BoldItalic.ttf"; do
        name="$(basename "$f" | sed 's/%5B/[/g; s/%5D/]/g')"
        run curl -fsSL -o "$dl/$name" "https://github.com/google/fonts/raw/main/$f"
    done
    run curl -fsSL -o "$dl/jbm.tar.xz" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz
    if [ "$dry" = 0 ]; then
        mkdir -p "$dl/jbm" "$fonts"
        tar -xJf "$dl/jbm.tar.xz" -C "$dl/jbm"
        cp "$dl"/*.ttf "$dl"/jbm/JetBrainsMonoNerdFont-*.ttf "$fonts/"
        fc-cache -f "$fonts" >/dev/null
    fi
    changed=$((changed + 1))
fi

# ---------------------------------------------------------------------------------------
step "GTK theme (adw-gtk3 $adw_version) and icons"
if [ -d "$HOME/.local/share/themes/adw-gtk3-dark" ]; then
    note "adw-gtk3-dark installed"
else
    dl="$scratch/adw-gtk3"; mkdir -p "$dl"
    run curl -fsSL -o "$dl/adw.tar.xz" "https://github.com/lassekongo83/adw-gtk3/releases/download/$adw_version/adw-gtk3${adw_version}.tar.xz"
    if [ "$dry" = 0 ]; then
        mkdir -p "$dl/x" "$HOME/.local/share/themes"
        tar -xJf "$dl/adw.tar.xz" -C "$dl/x"
        cp -r "$dl/x/adw-gtk3-dark" "$HOME/.local/share/themes/"
    fi
    changed=$((changed + 1))
fi
shade="$HOME/.local/share/icons/Shade-of-Z-White"
if [ -d "$shade" ]; then
    note "Shade of Z - White icons installed"
elif [ -d "$HOME/Icons/Shade of Z - White" ]; then
    note "installing Shade of Z - White from ~/Icons"
    run cp -r "$HOME/Icons/Shade of Z - White" "$shade"
    run sed -i 's/^Inherits=.*/Inherits=RAVEN,Papirus-Dark,Adwaita,hicolor/' "$shade/index.theme"
    changed=$((changed + 1))
else
    note "Shade of Z - White not found (put it in ~/Icons): apps fall back to the RAVEN/Papirus icons"
fi

# ---------------------------------------------------------------------------------------
step "Config files"
for f in hyprland.lua hypridle.conf hyprpaper.conf; do
    place "$here/hypr/$f" "$HOME/.config/hypr/$f"
done
sed "s|@HOME@|$HOME|g" "$here/hypr/hyprlock.conf" > "$scratch/hyprlock.conf"
place "$scratch/hyprlock.conf" "$HOME/.config/hypr/hyprlock.conf"
place "$here/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf"
place "$here/kitty/kitty-glass.sh" "$HOME/.config/kitty/kitty-glass.sh" 755
sed "s|@HOME@|$HOME|g" "$here/fastfetch/config.jsonc" > "$scratch/fastfetch-config.jsonc"
place "$scratch/fastfetch-config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
place "$here/fastfetch/logo.txt" "$HOME/.config/fastfetch/logo.txt"
place "$here/btop/raven.theme" "$HOME/.config/btop/themes/raven.theme"
[ -e "$HOME/.config/btop/btop.conf" ] || place "$here/btop/btop.conf" "$HOME/.config/btop/btop.conf"
sed "s|@HOME@|$HOME|g" "$here/flameshot/flameshot.ini" > "$scratch/flameshot.ini"
place "$scratch/flameshot.ini" "$HOME/.config/flameshot/flameshot.ini"
place "$here/warp/raven.yaml" "$HOME/.local/share/warp-terminal/themes/raven.yaml"
place "$here/xfce/helpers.rc" "$HOME/.config/xfce4/helpers.rc"
place "$here/xfce/warp.desktop" "$HOME/.local/share/xfce4/helpers/warp.desktop"
place "$here/apps/code-oss.desktop" "$HOME/.local/share/applications/code-oss.desktop"
# tldr (tealdeer, apt): offline command cheat sheets in RAVEN colours.
place "$here/shell/tealdeer.toml" "$HOME/.config/tealdeer/config.toml"

# Hyprland (UWSM) session: RAVEN's environment for every app (uwsm/env), and the system's XDG
# autostart apps that RAVEN replaces or that do nothing here kept out of Hyprland (NotShowIn), not
# disabled, since the XFCE session reads the same folder. prlcc above all: raven-clipsync runs it.
place "$here/uwsm/env" "$HOME/.config/uwsm/env"
for n in prlcc blueman print-applet xiccd geoclue-demo-agent polkit-mate-authentication-agent-1; do
    src="/etc/xdg/autostart/$n.desktop"
    [ -f "$src" ] || continue
    python3 - "$src" "$scratch/autostart-$n.desktop" <<'PY'
import sys
src, dst = sys.argv[1:]
out, seen = [], False
for l in open(src).read().splitlines():
    if l.startswith("NotShowIn="):
        vals = [v for v in l.split("=", 1)[1].split(";") if v]
        if "Hyprland" not in vals:
            vals.append("Hyprland")
        l = "NotShowIn=" + ";".join(vals) + ";"
        seen = True
    out.append(l)
if not seen:
    out.insert(out.index("[Desktop Entry]") + 1, "NotShowIn=Hyprland;")
out.insert(0, "# RAVEN: copy of %s, not started in Hyprland (UWSM runs XDG autostart; RAVEN does its own)." % src)
open(dst, "w").write("\n".join(out) + "\n")
PY
    place "$scratch/autostart-$n.desktop" "$HOME/.config/autostart/$n.desktop"
done

# Chromium follows the system (GNOME) proxy only when it thinks it's on GNOME: the Burp tile
# (bin/raven-burp) switches that proxy, so Chromium's launcher says GNOME for Chromium alone.
if [ -f /usr/share/applications/chromium.desktop ]; then
    sed 's|^Exec=/usr/bin/chromium|Exec=env XDG_CURRENT_DESKTOP=Hyprland:GNOME /usr/bin/chromium|' \
        /usr/share/applications/chromium.desktop > "$scratch/chromium.desktop"
    place "$scratch/chromium.desktop" "$HOME/.local/share/applications/chromium.desktop"
fi
place "$here/vscode/settings.json" "$HOME/.config/Code - OSS/User/settings.json"
for f in "$here"/bin/*; do
    place "$f" "$HOME/.local/bin/$(basename "$f")" 755
done

# ---------------------------------------------------------------------------------------
step "Terminal prompt and session header"
place "$here/shell/prompt.bash" "$HOME/.config/raven/prompt.bash"
place "$here/shell/rec-bashrc" "$HOME/.local/share/raven/rec-bashrc"   # raven-rec: Warpified recorded shell
if ! grep -q 'raven/prompt.bash' "$HOME/.bashrc" 2>/dev/null; then
    [ -e "$HOME/.bashrc.kali-backup" ] || run cp -p "$HOME/.bashrc" "$HOME/.bashrc.kali-backup"
    note "adding one line to ~/.bashrc (original kept as ~/.bashrc.kali-backup)"
    if [ "$dry" = 0 ]; then
        printf '\n# RAVEN prompt (remove this line for Kali'"'"'s prompt; original in ~/.bashrc.kali-backup)\n[ -f ~/.config/raven/prompt.bash ] && . ~/.config/raven/prompt.bash\n' >> "$HOME/.bashrc"
    fi
    changed=$((changed + 1))
fi
[ -e "$HOME/.hushlogin" ] || { note "new     ~/.hushlogin (Warp then skips /etc/motd)"; run touch "$HOME/.hushlogin"; }

# ---------------------------------------------------------------------------------------
step "Startpage"
run python3 "$here/startpage/make-startpage.py"

# ---------------------------------------------------------------------------------------
step "Firefox"
profile=""
ini="$HOME/.mozilla/firefox/profiles.ini"
if [ -r "$ini" ]; then
    profile="$(awk -F= '/^\[Install/{i=1} i && /^Default=/{print $2; exit}' "$ini")"
fi
if [ -n "$profile" ] && [ -d "$HOME/.mozilla/firefox/$profile" ]; then
    p="$HOME/.mozilla/firefox/$profile"
    place "$here/firefox/user.js" "$p/user.js"
    place "$here/firefox/chrome/userChrome.css" "$p/chrome/userChrome.css"
    place "$here/firefox/chrome/userContent.css" "$p/chrome/userContent.css"
    # RAVEN startpage add-on (new tab + homepage); user.js above allows it unsigned
    [ -e "$here/startpage/dist/raven-startpage.xpi" ] && place "$here/startpage/dist/raven-startpage.xpi" "$p/extensions/startpage@raven.local.xpi"
else
    note "no Firefox profile yet: open Firefox once, then run this again"
fi

# ---------------------------------------------------------------------------------------
step "Chromium"
# RAVEN startpage (new tab), loaded once like the theme: Load unpacked > ~/.local/share/raven/startpage
for f in "$here"/startpage/dist/chromium/*; do
    [ -e "$f" ] && place "$f" "$HOME/.local/share/raven/startpage/$(basename "$f")"
done
# A theme extension (colours only, from tokens.json via chromium/make-theme.py). Chromium only
# loads it by hand, once: chrome://extensions > Developer mode > Load unpacked > this folder.
for f in manifest.json images/toolbar.png images/ntp.png; do
    [ -e "$here/chromium/theme/$f" ] && place "$here/chromium/theme/$f" "$HOME/.local/share/raven/chromium-theme/$f"
done

# ---------------------------------------------------------------------------------------
step "Wallpapers and sounds"
sources="$HOME/.local/share/raven/wallpaper-sources"
run mkdir -p "$sources" "$HOME/.local/share/raven/sounds"
for f in "$upstream"/wallpapers/* "$here"/wallpapers/*; do
    [ -e "$f" ] || continue
    [ -e "$sources/$(basename "$f")" ] || { note "new     wallpaper $(basename "$f")"; run cp -p "$f" "$sources/"; }
done
for f in "$upstream"/sounds/nihil/*.ogg; do
    [ -e "$f" ] || continue
    [ -e "$HOME/.local/share/raven/sounds/$(basename "$f")" ] || run cp -p "$f" "$HOME/.local/share/raven/sounds/"
done
if have_display; then
    run "$HOME/.local/bin/raven-render-wallpapers"
else
    note "no display found: run raven-render-wallpapers from the desktop later"
fi

# ---------------------------------------------------------------------------------------
step "Shell, app theme, launcher clean-up"
run "$here/build.sh"
run "$here/apply-theme.sh"
run "$here/apps/hide-entries.sh"
if command -v code-oss >/dev/null && [ ! -d "$HOME/.vscode-oss/extensions/raven.raven-theme-1.0.0" ]; then
    note "installing the RAVEN theme in VS Code"
    run python3 -I "$here/vscode/make-theme.py"
    run python3 -I "$here/vscode/pack.py"
    run env ELECTRON_RUN_AS_NODE=1 /usr/lib/code-oss/code-oss /usr/lib/code-oss/resources/app/out/cli.js \
        --install-extension "$here/vscode/raven-theme-1.0.0.vsix"
fi

# ---------------------------------------------------------------------------------------
if [ "$login" = 1 ]; then
    step "Login screen (sudo)"
    run sudo bash "$here/login/install-login.sh"
fi

if [ "$dry" = 0 ] && [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
    step "Reloading the running session"
    hyprctl reload >/dev/null
    pkill -x qs || true
    hyprctl dispatch 'hl.dsp.exec_cmd("qs -c raven")' >/dev/null
    note "Hyprland reloaded and the shell restarted"
fi

echo
if [ "$dry" = 1 ]; then
    echo "Dry run: nothing was changed."
else
    echo "RAVEN installed ($changed file(s) changed)."
    [ "$changed" -gt 0 ] && [ -d "$backups" ] && echo "Replaced files were backed up in ${backups/#$HOME/\~}"
fi
echo 'Log in with the "Hyprland (uwsm-managed)" session to use it.'
