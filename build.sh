#!/usr/bin/env bash
# RAVEN: builds ~/.config/quickshell/raven from the upstream NIHIL shell.
# Re-run after changing tokens.json (e.g. the accent) or pulling upstream.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="${RAVEN_SRC:-$HOME/.local/src/Nihil-Shell}"
out="$HOME/.config/quickshell/raven"
# Scratch space, overwritten in place on every build (nothing is deleted).
build="$HOME/.cache/raven-build"; mkdir -p "$build"

need() { command -v "$1" >/dev/null || { echo "build.sh: missing $1" >&2; exit 1; }; }
need qs; need jq

# 1. Shaders (smoked glass) -> .qsb
qsb=$(command -v qsb || ls /usr/lib/qt6/bin/qsb /usr/lib/*/qt6/bin/qsb 2>/dev/null | head -1 || true)
[ -n "$qsb" ] || { echo "build.sh: qsb not found (apt install qt6-shader-baker)" >&2; exit 1; }
mkdir -p "$build/shaders"
# RAVEN's own shaders (qml/shaders) go into the same folder; names must not clash with upstream's.
for s in "$here"/qml/shaders/*.frag; do
	[ ! -e "$src/home/shell/shaders/$(basename "$s")" ] || { echo "build.sh: $(basename "$s") now exists upstream" >&2; exit 1; }
done
for s in "$src"/home/shell/shaders/*.vert "$src"/home/shell/shaders/*.frag "$here"/qml/shaders/*.frag; do
	"$qsb" --glsl "300 es,150" -o "$build/shaders/$(basename "$s").qsb" "$s"
done

# 2. Config.qml values (what upstream's home/shell.nix generated)
p() { command -v "$1" || echo "/usr/bin/$1"; }
bin="$HOME/.local/bin"
mkdir -p "$HOME/.config/raven"
cat > "$build/cava.conf" <<EOF
[general]
bars=24
framerate=30
autosens=1
[input]
method=pipewire
source=auto
[output]
method=raw
raw_target=/dev/stdout
data_format=ascii
ascii_max_range=6
bar_delimiter=59
frame_delimiter=10
[smoothing]
noise_reduction=70
EOF
install -Dm644 "$build/cava.conf" "$HOME/.config/raven/cava.conf"

snd="$HOME/.local/share/raven/sounds"
wallnames=$(find "$HOME/.local/share/raven/wallpapers" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort | jq -R . | jq -s .)
keys='{"launcher":"SUPER + slash","dashboard":"SUPER + D","panel":"SUPER + period","colourPicker":null,"lock":"SUPER + K","nilo":"SUPER + ALT + slash","settings":"SUPER + O","wallpapers":"SUPER + W","copy":"SUPER + C","clipboard":"SUPER + V","close":"SUPER + Q","float":"SUPER + SHIFT + Space","maximize":"SUPER + ALT + F","fullscreen":"SUPER + ALT + SHIFT + F","special":"SUPER + ALT + S","toSpecial":"SUPER + ALT + A","nextWorkspace":"SUPER + ALT + Tab","overview":"SUPER + Tab","screenshot":"PRINT","snip":"XF86SelectiveScreenshot"}'
programs='[{"name":"Terminal","exec":"warp-terminal","keys":"SUPER + Return"},{"name":"Files","exec":"thunar","keys":"SUPER + E"},{"name":"Browser","exec":"firefox-esr","keys":"SUPER + B"}]'
gestures='{"workspaces":3,"close":3,"launcher":3,"maximize":3,"special":4}'

jq -n \
	--arg sh "$(p sh)" --arg nmcli "$(p nmcli)" --arg nmEditor "$(p nm-connection-editor)" \
	--arg notifySend "$(p notify-send)" --arg brightnessctl "$(p brightnessctl)" --arg pwPlay "$(p pw-play)" \
	--arg rfkill "$(command -v rfkill || echo /usr/sbin/rfkill)" --arg hyprsunset "$(p hyprsunset)" \
	--arg ip "$(command -v ip || echo /usr/sbin/ip)" --arg cava "$(p cava)" --arg qalc "$(p qalc)" \
	--arg wlCopy "$(p wl-copy)" --arg systemctl "$(p systemctl)" --arg pavucontrol "$(p pavucontrol)" \
	--arg blueman "$(p blueman-manager)" --arg terminal "$(p warp-terminal)" --arg terminalExec "$(p kitty)" --arg editor "$(p vim)" \
	--arg xdgUserDir "$(p xdg-user-dir)" --arg hyprctl "$(p hyprctl)" --arg sudo "$(p sudo)" \
	--arg timedatectl "$(p timedatectl)" --arg bin "$bin" --arg snd "$snd" \
	--arg cavaConfig "$HOME/.config/raven/cava.conf" --arg wallpaperDir "$HOME/.local/share/raven/wallpapers" \
	--arg niloAgent "$bin/raven-nilo" --arg settingsFile "$HOME/.config/raven/settings.json" --arg user "$(getent passwd "$USER" | cut -d: -f5 | cut -d, -f1)" \
	--argjson wallpapers "$wallnames" --argjson keys "$keys" --argjson programs "$programs" --argjson gestures "$gestures" \
'{
	barOutputs: {type: "var", js: "Quickshell.screens.map(s => s.name)"},
	primaryOutput: {type: "string", js: "Quickshell.screens.length > 0 ? Quickshell.screens[0].name : \"\""},
	persistentWorkspaces: 3,
	widgets: ["clock", "network", "media"],
	trayHidden: ["nm-applet", "blueman"],
	wallpapers: $wallpapers,
	clipboard: 8,
	cavaConfig: $cavaConfig,
	sounds: {menu: "\($snd)/menu.ogg", notify: "\($snd)/notify.ogg", critical: "\($snd)/critical.ogg", charge: "\($snd)/charge.ogg"},
	cmd: {
		sh: $sh, nmcli: $nmcli, nmEditor: $nmEditor, notifySend: $notifySend, brightnessctl: $brightnessctl,
		pwPlay: $pwPlay, rfkill: $rfkill, hyprsunset: $hyprsunset, ip: $ip, cava: $cava, qalc: $qalc,
		wlCopy: $wlCopy, systemctl: $systemctl, uwsm: "\($bin)/raven-session", pavucontrol: $pavucontrol,
		blueman: $blueman, terminal: $terminal, terminalExec: $terminalExec, watch: "\($bin)/raven", editor: $editor,
		lock: "\($bin)/lock-screen", powerOff: "\($bin)/power-off", micLedSync: "\($bin)/mic-led-sync",
		wallpaper: "\($bin)/raven-wallpaper", clipboard: "\($bin)/raven-clipboard", record: "\($bin)/raven-record",
		shot: "\($bin)/raven-shot", xdgUserDir: $xdgUserDir, hyprctl: $hyprctl, sudo: $sudo,
		raven: "\($bin)/raven", timedatectl: $timedatectl
	},
	nilo: {enabled: true, agent: $niloAgent},
	deck: {enabled: false, command: "\($bin)/raven", port: 0},
	settingsFile: $settingsFile,
	wallpaperDir: $wallpaperDir,
	user: (if $user == "" then "kali" else $user end),
	greeting: "",
	binds: $keys,
	bindDefaults: $keys,
	gestureDefaults: $gestures,
	programs: $programs
}' > "$build/config.json"

# 3. Generate the shell
python3 -I "$here/gen.py" --src "$src" --out "$out" --tokens "$here/tokens.json" \
	--config "$build/config.json" --shaders "$build/shaders" --icon-theme Shade-of-Z-White

# 4. Scripts
install -Dm755 "$here"/bin/* -t "$bin"
echo "build.sh: done. Restart the shell with: pkill -x qs; qs -c raven -d"
