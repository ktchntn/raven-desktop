
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
