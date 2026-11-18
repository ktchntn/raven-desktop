-- RAVEN: Hyprland config (ported from NIHIL's home/hyprland.nix by poligle, MIT)
-- Palette: void 000000 · line 2A2A2A · muted 7A7A7A · ink F2F2F2 · accent C6FF00

local HOME = os.getenv("HOME")
local sounds = HOME .. "/.local/share/raven/sounds/"
local function play(name)
    return "pw-play --volume 0.4 " .. sounds .. name .. ".ogg"
end
local function ipc(args)
    return hl.dsp.exec_cmd("raven-ipc " .. args)
end
local function withSound(name, dispatcher)
    return function()
        hl.exec_cmd(play(name))
        hl.dispatch(dispatcher)
    end
end

-- Fixed size for the Mac's full-screen VM window (MacBook Pro 14", "scaled"). It used to be
-- "preferred", fed by Parallels' dynamic resolution, but since the Parallels update of
-- 2026-11-17 the host sends no size, and the VM fell back to 1096x796 (narrow, stretched).
hl.monitor({ output = "Virtual-1", mode = "1512x949@60", position = "0x0", scale = 1 })

hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
hl.env("QT_STYLE_OVERRIDE", "Fusion")
hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")
-- Warp natively on Wayland: via XWayland (+ GL on virgl) a window could stop repainting after
-- fullscreen (frosted, ignoring close). Class stays dev.warp.Warp, so window rules still apply.
hl.env("WARP_ENABLE_WAYLAND", "1")
-- Personal additions (e.g. export TZ=Area/City) from ~/.config/raven/env.local, kept out of the repo;
-- ~/.config/uwsm/env reads the same file for the UWSM session.
do
    local f = io.open((os.getenv("HOME") or "") .. "/.config/raven/env.local")
    if f then
        for line in f:lines() do
            local name, value = line:match("^%s*export%s+([%w_]+)=[\"']?(.-)[\"']?%s*$")
            if name then hl.env(name, value) end
        end
        f:close()
    end
end
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("PATH", HOME .. "/.local/bin:" .. (os.getenv("PATH") or "/usr/local/bin:/usr/bin:/bin"))
-- App entries hidden only in this session (XFCE-only tools): XFCE never reads this folder.
do
    local only = HOME .. "/.local/share/raven/hyprland-only"
    local dirs = os.getenv("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    if not dirs:find(only, 1, true) then
        hl.env("XDG_DATA_DIRS", only .. ":" .. dirs)
    end
end

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 1,
        col = {
            active_border = "rgb(C6FF00)",
            inactive_border = "rgb(2A2A2A)",
        },
        resize_on_border = true,
        allow_tearing = false,
        layout = "master",
    },
    decoration = {
        rounding = 12,
        active_opacity = 1.0,
        inactive_opacity = 0.85,
        fullscreen_opacity = 1.0,
        shadow = { enabled = false },
        blur = {
            enabled = true,
            size = 4,
            passes = 2,
            brightness = 0.5,
            contrast = 1.0,
            noise = 0,
            xray = false,
            popups = false,
        },
    },
    dwindle = { preserve_split = true },
    master = { new_status = "master" },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        -- the shell's lock (services/Lock.qml) can take a lock back over after a shell restart
        allow_session_lock_restore = true,
    },
    cursor = {
        -- virtio-gpu in a VM: software cursor avoids an invisible pointer
        no_hardware_cursors = true,
    },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = { natural_scroll = false },
    },
})

-- Preferences (keyboard, screens): written by `raven apply`; optional.
do
    local ok, err = pcall(dofile, HOME .. "/.config/hypr/raven-settings.lua")
    if not ok and not tostring(err):find("No such file") then print("raven-settings.lua: " .. tostring(err)) end
end

hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("ravenOut", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1.0 } } })
hl.curve("ravenInOut", { type = "bezier", points = { { 0.4, 0.0 }, { 0.2, 1.0 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 2.6, bezier = "ravenOut", style = "popin 94%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.4, bezier = "ravenOut", style = "slide" })
hl.animation({ leaf = "border", enabled = true, speed = 4, bezier = "linear" })
hl.animation({ leaf = "fade", enabled = true, speed = 2, bezier = "ravenOut" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 3, bezier = "ravenInOut", style = "slide" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 3, direction = "down", action = "close" })
hl.gesture({ fingers = 3, direction = "up", action = function() hl.exec_cmd("raven-ipc drawers toggle launcher") end })

-- Windows
hl.window_rule({ name = "suppress-maximize", match = { class = ".*" }, suppress_event = "maximize" })
hl.window_rule({ name = "kitty-float", match = { class = "kitty" }, float = true, size = "900 560", center = true })
hl.window_rule({ name = "warp-float", match = { class = "dev.warp.Warp" }, float = true, size = "1000 640", center = true })
hl.window_rule({ name = "flameshot-overlay", match = { class = "flameshot" }, float = true, pin = true, move = "0 0", no_anim = true, rounding = 0, border_size = 0 })
-- prlcc's clipboard helper (prlcp), if ever run in Wayland mode, maps a classless window on every VM
-- focus change and must take keyboard focus (no_focus breaks it). Draw nothing (it showed as a frosted
-- overlay). RAVEN runs it on X11 instead (see autostart), where it maps no window.
hl.window_rule({ name = "prl-clipboard", match = { title = "^Parallels Shared Clipboard$" }, float = true, border_size = 0, no_blur = true, no_shadow = true, no_dim = true, no_anim = true, opacity = "0" })
-- Obsidian is a drop-down (⌘⌥O, bin/raven-obsidian): all its windows live on special:obsidian
hl.window_rule({ name = "obsidian-dropdown", match = { class = "md.obsidian.Obsidian" }, workspace = "special:obsidian silent", float = true, size = "1240 820", center = true })
hl.window_rule({ name = "thunar-float", match = { class = "thunar" }, float = true, center = true })
hl.window_rule({ name = "thunar-size", match = { class = "thunar", title = ".+ - Thunar" }, size = "1000 700" })
for _, panel in ipairs({ { "wifi", "nm-connection-editor" }, { "bluetooth", ".*blueman-manager.*" }, { "vol", "org.pulseaudio.pavucontrol" } }) do
    hl.window_rule({ name = panel[1] .. "-float", match = { class = panel[2] }, float = true, size = "640 400", center = true })
end
hl.layer_rule({ name = "raven-shell", match = { namespace = "^raven-.*$" }, no_anim = true })

-- Keys (NIHIL's defaults; terminal on SUPER + Return)
local bind = hl.bind
bind("SUPER + slash", ipc("drawers toggle launcher"), { description = "Shell | App launcher" })
-- ⌘Space reaches the VM since Parallels sends macOS system shortcuts to it (2026-11-17)
bind("SUPER + Space", ipc("drawers toggle launcher"), { description = "Shell | App launcher" })
bind("SUPER + D", ipc("drawers toggle dashboard"), { description = "Shell | Dashboard" })
bind("SUPER + period", ipc("drawers toggle panel"), { description = "Shell | Quick settings" })
bind("SUPER + W", ipc("drawers toggle wallpapers"), { description = "Shell | Wallpapers" })
bind("SUPER + O", ipc("settings toggle"), { description = "Shell | Preferences" })
bind("SUPER + H", ipc("clipboard browse"), { description = "Clipboard | Clipboard history" })
bind("SUPER + ALT + O", withSound("special", hl.dsp.exec_cmd("raven-obsidian")), { description = "Apps | Obsidian drop-down (show / hide)" })
bind("SUPER + ALT + N", ipc("notes capture"), { description = "Shell | Quick note (to today's Obsidian daily note)" })
bind("SUPER + ALT + slash", ipc("nilo toggle"), { description = "Shell | Huginn: Claude Code assistant (also ? in the launcher)" })
bind("SUPER + ALT + X", hl.dsp.exec_cmd("raven-explain"), { description = "Shell | Huginn: explain the copied output (what stands out, what next)" })
bind("SUPER + K", hl.dsp.exec_cmd("lock-screen"), { description = "Session | Lock screen" })
bind("SUPER + Q", hl.dsp.window.close(), { description = "Windows | Close window" })
bind("ALT + F4", hl.dsp.window.close(), { description = "Windows | Close window" })
bind("SUPER + SHIFT + Space", hl.dsp.window.float({ action = "toggle" }), { description = "Windows | Float / tile" })
bind("SUPER + ALT + F", withSound("fullscreen", hl.dsp.window.fullscreen({ mode = "maximized" })), { description = "Windows | Maximize" })
bind("SUPER + ALT + SHIFT + F", withSound("fullscreen", hl.dsp.window.fullscreen({ mode = "fullscreen" })), { description = "Windows | Fullscreen" })
-- Scratchpad: SUPER + ALT + S shows/hides it (macOS/Parallels turns SUPER + Escape into a plain Escape).
bind("SUPER + ALT + S", withSound("special", hl.dsp.workspace.toggle_special()), { description = "Scratchpad | Show / hide the scratchpad" })
-- SUPER + ALT + A: the focused window into the scratchpad (hidden at once), or,
-- if it is already there, back out onto the current workspace. Replaces NIHIL's
-- SUPER + Control_L, which fired whenever Ctrl was pressed with SUPER held.
function RAVEN_SCRATCH()
    local win = hl.get_active_window()
    if not win then return end
    if win.workspace and win.workspace.special then
        local m = hl.get_active_monitor()
        local ws = m and m.active_workspace
        if ws then
            hl.dispatch(hl.dsp.window.move({ workspace = tostring(ws.id) }))
        end
    else
        hl.exec_cmd(play("special"))
        hl.dispatch(hl.dsp.window.move({ workspace = "special", follow = false }))
    end
end
bind("SUPER + ALT + A", RAVEN_SCRATCH, { description = "Scratchpad | Park the window, or bring it back" })
-- Next workspace (macOS keeps SUPER + Tab for its app switcher).
bind("SUPER + ALT + Tab", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces | Next workspace" })
bind("SUPER + Return", hl.dsp.exec_cmd("warp-terminal"), { description = "Apps | Terminal (Warp)" })
bind("SUPER + E", hl.dsp.exec_cmd("thunar"), { description = "Apps | Files (Thunar)" })
bind("SUPER + B", hl.dsp.exec_cmd("firefox-esr"), { description = "Apps | Browser (Firefox)" })
-- through its desktop entry: that sets XDG_CURRENT_DESKTOP=Hyprland:GNOME so the Burp tile's proxy applies
bind("SUPER + ALT + B", hl.dsp.exec_cmd("gtk-launch chromium"), { description = "Apps | Browser (Chromium)" })
bind("SUPER + SHIFT + M", hl.dsp.exit(), { description = "Session | Log out of Hyprland" })

bind("PRINT", hl.dsp.exec_cmd("raven-shot screen"), { description = "Capture | Screenshot of the screen", locked = true })
bind("SHIFT + PRINT", hl.dsp.exec_cmd("raven-record toggle screen"), { description = "Capture | Record the screen (start / stop)" })
bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("flameshot gui"), { description = "Capture | Screenshot of an area (Flameshot)" })
bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("raven-record toggle region"), { description = "Capture | Record an area (start / stop)" })

bind("SUPER + left", hl.dsp.focus({ direction = "left" }))
bind("SUPER + right", hl.dsp.focus({ direction = "right" }))
bind("SUPER + up", hl.dsp.focus({ direction = "up" }))
bind("SUPER + down", hl.dsp.focus({ direction = "down" }))
for i = 1, 10 do
    local key = tostring(i % 10)
    bind("SUPER + " .. key, hl.dsp.focus({ workspace = tostring(i) }), { description = "Workspaces | Go to workspace 1–10" })
    -- ⌘⌥ + number, not ⌘⇧: macOS keeps ⌘⇧3/4/5 for screenshots (CleanShot)
    bind("SUPER + ALT + " .. key, hl.dsp.window.move({ workspace = tostring(i) }), { description = "Workspaces | Send the window to workspace 1–10" })
end

bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("osd-volume up"), { description = "Media | Volume up", locked = true, repeating = true })
bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("osd-volume down"), { description = "Media | Volume down", locked = true, repeating = true })
bind("XF86AudioMute", hl.dsp.exec_cmd("osd-volume mute"), { description = "Media | Mute", locked = true })
bind("XF86AudioMicMute", hl.dsp.exec_cmd("osd-mic"), { description = "Media | Mute microphone", locked = true })
bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("osd-brightness up"), { description = "Media | Brightness up", locked = true, repeating = true })
bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("osd-brightness down"), { description = "Media | Brightness down", locked = true, repeating = true })
bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { description = "Media | Next track", locked = true })
bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { description = "Media | Play / pause", locked = true })
bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { description = "Media | Play / pause", locked = true })
bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { description = "Media | Previous track", locked = true })

bind("mouse:275", hl.dsp.focus({ workspace = "e-1" }), { description = "Workspaces | Previous workspace (mouse back button)" })
bind("mouse:276", hl.dsp.focus({ workspace = "e+1" }), { description = "Workspaces | Next workspace (mouse forward button)" })
bind("SUPER + mouse:272", hl.dsp.window.drag(), { description = "Windows | Move with the mouse (drag)", drag = true })
bind("SUPER + mouse:273", hl.dsp.window.resize(), { description = "Windows | Resize with the mouse (right-drag)", drag = true })

-- Window placement and size from the keyboard (RAVEN).
--   SUPER + SHIFT + arrows  move: tiled -> along the layout, floating -> nudge 40px
--   SUPER + ALT + arrows    resize: right/down grow, left/up shrink (40px, repeats)
--   SUPER + [  /  ]         snap to the left / right half (floats the window)
--   SUPER + \               fill the screen inside the frame (floating)
--   SUPER + SHIFT + C       center at a comfortable size (floating)
RAVEN_WIN = {}
do
    local GAP, STEP = 8, 40

    -- Usable area of the focused monitor: minus the bar/frame (reserved) and the outer gap.
    local function area()
        local m = hl.get_active_monitor()
        if not m then return nil end
        local r = m.reserved or {}
        local left, top = r.left or r[1] or 0, r.top or r[2] or 0
        local right, bottom = r.right or r[3] or 0, r.bottom or r[4] or 0
        local s = m.scale or 1
        local w, h = math.floor(m.width / s), math.floor(m.height / s)
        return { x = m.x + left + GAP, y = m.y + top + GAP,
                 w = w - left - right - 2 * GAP, h = h - top - bottom - 2 * GAP }
    end

    local function place(rect)
        return function()
            local win, a = hl.get_active_window(), area()
            if not win or not a or (win.fullscreen or 0) ~= 0 then return end
            if not win.floating then
                hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
            end
            local x, y, w, h = rect(a)
            hl.dispatch(hl.dsp.window.resize({ x = math.floor(w), y = math.floor(h) }))
            hl.dispatch(hl.dsp.window.move({ x = math.floor(x), y = math.floor(y) }))
        end
    end

    RAVEN_WIN.left = place(function(a) return a.x, a.y, (a.w - GAP) / 2, a.h end)
    RAVEN_WIN.right = place(function(a) return a.x + (a.w + GAP) / 2, a.y, (a.w - GAP) / 2, a.h end)
    RAVEN_WIN.fill = place(function(a) return a.x, a.y, a.w, a.h end)
    RAVEN_WIN.center = place(function(a)
        local w, h = a.w * 0.62, a.h * 0.70
        return a.x + (a.w - w) / 2, a.y + (a.h - h) / 2, w, h
    end)

    local function move(dir, dx, dy)
        return function()
            local win = hl.get_active_window()
            if not win then return end
            if win.floating then
                hl.dispatch(hl.dsp.window.move({ x = dx, y = dy, relative = true }))
            else
                hl.dispatch(hl.dsp.window.move({ direction = dir }))
            end
        end
    end
    RAVEN_WIN.move = {
        left = move("left", -STEP, 0), right = move("right", STEP, 0),
        up = move("up", 0, -STEP), down = move("down", 0, STEP),
    }

    local function resize(dx, dy)
        return function()
            local win = hl.get_active_window()
            if not win then return end
            hl.dispatch(hl.dsp.window.resize({ x = dx, y = dy, relative = true }))
            -- Floating windows resize around their centre: shift back so the
            -- top-left corner stays put and only the right/bottom edge moves.
            if win.floating then
                hl.dispatch(hl.dsp.window.move({ x = math.floor(dx / 2), y = math.floor(dy / 2), relative = true }))
            end
        end
    end
    RAVEN_WIN.grow = {
        left = resize(-STEP, 0), right = resize(STEP, 0),
        up = resize(0, -STEP), down = resize(0, STEP),
    }

    for _, d in ipairs({ "left", "right", "up", "down" }) do
        hl.bind("SUPER + SHIFT + " .. d, RAVEN_WIN.move[d], { description = "Windows | Move (nudge when floating)", repeating = true })
        hl.bind("SUPER + ALT + " .. d, RAVEN_WIN.grow[d], { description = "Windows | Resize (→ ↓ grow, ← ↑ shrink)", repeating = true })
    end
    hl.bind("SUPER + bracketleft", RAVEN_WIN.left, { description = "Windows | Snap to the left half" })
    hl.bind("SUPER + bracketright", RAVEN_WIN.right, { description = "Windows | Snap to the right half" })
    hl.bind("SUPER + backslash", RAVEN_WIN.fill, { description = "Windows | Fill the screen" })
    hl.bind("SUPER + SHIFT + C", RAVEN_WIN.center, { description = "Windows | Center" })
end

-- SUPER + C copies (as CTRL + Insert); SUPER + V pastes, held: clipboard history.
-- SUPER + A held: overview. Ported from NIHIL's hold submaps.
bind("SUPER + C", function()
    hl.dispatch(hl.dsp.send_key_state({ mods = "CTRL", key = "Insert", state = "down" }))
    hl.dispatch(hl.dsp.send_key_state({ mods = "CTRL", key = "Insert", state = "up" }))
end, { description = "Clipboard | Copy" })
do
    local function say(name)
        hl.dispatch(hl.dsp.global("quickshell:raven-" .. name))
    end
    hl.bind("SUPER + V", function()
        say("clipboard")
        hl.dispatch(hl.dsp.submap("raven-clipboard"))
    end, { description = "Clipboard | Paste (hold ⌘ for the history)" })
    -- Overview / workspace switcher on SUPER + Tab (⌘Tab, one hand): Parallels sends macOS system
    -- shortcuts to the VM since 2026-11-17. Was SUPER + ALT + E (awkward); SUPER + A never arrived.
    bind("SUPER + Tab", hl.dsp.global("quickshell:raven-overview"), { description = "Shell | Workspace switcher (hold ⌘, tap Tab to step, release to go)" })

    local function watcher()
        say("super")
        local now = hl.get_current_submap()
        if now == "raven-clipboard" or now == "raven-overview" then
            hl.dispatch(hl.dsp.submap("reset"))
        end
    end
    local watch = { ignore_mods = true, transparent = true, non_consuming = true, dont_inhibit = true, locked = true }
    local function watchSuper()
        for _, sym in ipairs({ "Super_L", "Super_R" }) do hl.bind(sym, watcher, watch) end
    end
    watchSuper()

    local function keys(prefix, list)
        for _, k in ipairs(list) do
            hl.bind(k[1], function()
                say(prefix .. "-" .. k[2])
                if k[3] then hl.dispatch(hl.dsp.submap("reset")) end
            end)
        end
    end

    hl.define_submap("raven-clipboard", function()
        keys("clipboard", {
            { "SUPER + V", "next" }, { "SUPER + Tab", "next" }, { "SUPER + Down", "next" }, { "SUPER + Right", "next" },
            { "SUPER + SHIFT + V", "back" }, { "SUPER + SHIFT + Tab", "back" }, { "SUPER + Up", "back" }, { "SUPER + Left", "back" },
            { "SUPER + Delete", "forget" }, { "SUPER + BackSpace", "forget" },
            { "SUPER + Return", "paste", true }, { "SUPER + KP_Enter", "paste", true },
            { "SUPER + Escape", "cancel", true },
        })
        watchSuper()
    end)

    hl.define_submap("raven-overview", function()
        keys("overview", {
            { "SUPER + Tab", "next" }, { "SUPER + Right", "next" },
            { "SUPER + SHIFT + Tab", "back" }, { "SUPER + Left", "back" },
            { "SUPER + Return", "go", true }, { "SUPER + KP_Enter", "go", true },
            { "SUPER + Escape", "cancel", true }, { "Escape", "cancel", true },
        })
        watchSuper()
    end)
end

-- Autostart and interface sounds
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE PATH QT_QPA_PLATFORM")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Classic 24")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("sleep 1; raven-wallpaper restore")
    hl.exec_cmd("qs -c raven")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("wl-paste --watch raven-clipboard store")
    hl.exec_cmd("lxqt-policykit-agent")
    hl.exec_cmd("nm-applet --indicator")
    -- Parallels Tools user agent (clipboard sharing etc.); XFCE starts it from /etc/xdg/autostart, Hyprland does not.
    -- raven-clipsync runs prlcc on a private headless X server (Xvfb) and bridges its clipboard to
    -- Wayland: prlcc misbehaves both natively on Wayland and on Hyprland's XWayland (see its header).
    hl.exec_cmd("raven-clipsync")
    -- "Connection on :PORT" alert (double lime frame sweep) when something connects to a listener
    hl.exec_cmd("raven-catch")
    -- "Cracked: N new" alert when hashcat / john add to their potfiles
    hl.exec_cmd("raven-cracked")
    -- Keep this session's Hyprland log across reboots ($XDG_RUNTIME_DIR is wiped): the last
    -- session's log is ~/.cache/raven/hyprland-prev.log (for "it broke and I had to restart").
    -- Same for the RAVEN shell's own log (lock screen, bar...): ~/.cache/raven/shell-{last,prev}.log
    hl.exec_cmd("raven-shell-log")
    hl.exec_cmd([[sh -c 'mkdir -p ~/.cache/raven; [ -f ~/.cache/raven/hyprland-last.log ] && mv -f ~/.cache/raven/hyprland-last.log ~/.cache/raven/hyprland-prev.log; exec tail -n +1 -F "$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log" > ~/.cache/raven/hyprland-last.log 2>/dev/null']])
end)
hl.on("monitor.added", function() hl.exec_cmd("raven-render-wallpapers; raven-wallpaper restore") end)
hl.on("workspace.active", function() hl.exec_cmd(play("switch")) end)
-- No open/close sound for prlcc's clipboard window (it flashes on every VM focus change).
local function silentWindow(w)
    local ok, title = pcall(function() return w and w.title end)
    return ok and title == "Parallels Shared Clipboard"
end
hl.on("window.open", function(w) if not silentWindow(w) then hl.exec_cmd(play("open")) end end)
hl.on("window.close", function(w) if not silentWindow(w) then hl.exec_cmd(play("close")) end end)
