--[[-------------------------------------------------------------------------
    Notification plugin
    Server broadcasts a message via /notice and clients render it as a
    themed toast in the upper-right corner. Toasts stack, slide in, auto-
    dismiss and pick their colors from evolve:GetTheme().
---------------------------------------------------------------------------]]

local PLUGIN = {}
PLUGIN.Title       = "Notice"
PLUGIN.Description = "Pops up a notification for everyone."
PLUGIN.Author      = "Evolve"
PLUGIN.ChatCommand = "notice"
PLUGIN.Usage       = "<message> [time=10]"
PLUGIN.Privileges  = {"Notice"}

function PLUGIN:Initialize()
    if SERVER then
        util.AddNetworkString("EV_Notify")
    end
end

function PLUGIN:Call(ply, args)
    if ply:EV_HasPrivilege("Notice") then
        local time = tonumber(args[#args]) or 10
        if tonumber(args[#args]) then args[#args] = nil end
        local msg = table.concat(args, " ")

        if #msg > 0 then
            net.Start("EV_Notify")
                net.WriteUInt(time, 8)
                net.WriteString(msg)
                net.WriteString(ply:Nick())
            net.Broadcast()

            evolve:Notify(evolve.colors.white, msg)
        end
    else
        evolve:Notify(ply, evolve.colors.red, evolve.constants.notallowed)
    end
end

--[[-----------------------------------------------------------------------
    Client rendering
-------------------------------------------------------------------------]]
if CLIENT then

    local ACTIVE        = {}    -- stack of active toasts
    local MARGIN_RIGHT  = 20
    local MARGIN_TOP    = 80
    local GAP           = 10
    local TOAST_W       = 340
    local TOAST_H       = 62

    local function theme()
        return evolve:GetTheme()
    end

    local function addToast(title, body, duration, kind)
        kind = kind or "info"
        local now = CurTime()
        table.insert(ACTIVE, {
            Title    = title or "",
            Body     = body or "",
            Kind     = kind,
            Spawn    = now,
            Expire   = now + (duration or 10),
            XOff     = TOAST_W + 40,   -- slide-in target
            YOff     = 0,
            Alpha    = 0,
        })
        surface.PlaySound("buttons/button15.wav")
    end

    -- Publicly-available helper for other plugins/server code to fire
    -- themed toasts, e.g. evolve:Toast("Ban", "Player banned", 8, "danger").
    function evolve:Toast(title, body, time, kind)
        addToast(title, body, time, kind)
    end

    net.Receive("EV_Notify", function()
        local time   = net.ReadUInt(8)
        local msg    = net.ReadString()
        local sender = net.ReadString()
        addToast(sender or "Notice", msg, time, "info")
    end)

    local function drawToast(toast, baseY)
        local t  = theme()
        local x  = ScrW() - TOAST_W - MARGIN_RIGHT - toast.XOff
        local y  = baseY

        -- Accent color varies by kind.
        local accent = t.accent
        if toast.Kind == "danger"  then accent = t.danger  end
        if toast.Kind == "warning" then accent = t.warning end
        if toast.Kind == "success" then accent = t.success end

        local a = toast.Alpha
        -- Shadow
        local sh = t.shadow
        draw.RoundedBox(8, x + 3, y + 4, TOAST_W, TOAST_H,
            Color(sh.r, sh.g, sh.b, sh.a * a / 255))

        -- Body
        draw.RoundedBox(8, x, y, TOAST_W, TOAST_H,
            Color(t.panel.r, t.panel.g, t.panel.b, t.panel.a * a / 255))

        -- Left accent stripe
        surface.SetDrawColor(accent.r, accent.g, accent.b, a)
        surface.DrawRect(x, y, 4, TOAST_H)

        -- Title
        draw.SimpleText(toast.Title, "EV_NotifyTitle",
            x + 16, y + 12,
            Color(t.text.r, t.text.g, t.text.b, a),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- Body (auto-wrap cheaply by truncating)
        local body = toast.Body
        surface.SetFont("EV_NotifyBody")
        local bw = surface.GetTextSize(body)
        if bw > TOAST_W - 32 then
            while bw > TOAST_W - 40 and #body > 4 do
                body = string.sub(body, 1, -2)
                bw = surface.GetTextSize(body .. "...")
            end
            body = body .. "..."
        end
        draw.SimpleText(body, "EV_NotifyBody",
            x + 16, y + 34,
            Color(t.text_dim.r, t.text_dim.g, t.text_dim.b, a),
            TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        -- Progress bar indicating remaining time.
        local total = toast.Expire - toast.Spawn
        local left  = math.max(0, toast.Expire - CurTime())
        local frac  = math.Clamp(left / total, 0, 1)
        surface.SetDrawColor(accent.r, accent.g, accent.b, a * 0.75)
        surface.DrawRect(x + 4, y + TOAST_H - 2, (TOAST_W - 4) * frac, 2)
    end

    hook.Add("HUDPaint", "EV_Toasts", function()
        if #ACTIVE == 0 then return end
        local dt = FrameTime() * 8

        -- Animate and remove expired.
        for i = #ACTIVE, 1, -1 do
            local toast = ACTIVE[i]
            toast.XOff  = Lerp(dt, toast.XOff, 0)
            toast.Alpha = Lerp(dt, toast.Alpha, 255)

            if CurTime() > toast.Expire then
                toast.Alpha = Lerp(dt, toast.Alpha, 0)
                toast.XOff  = Lerp(dt, toast.XOff, TOAST_W + 40)
                if toast.Alpha < 5 then
                    table.remove(ACTIVE, i)
                end
            end
        end

        -- Stack from top, newest at bottom.
        local y = MARGIN_TOP
        for _, toast in ipairs(ACTIVE) do
            drawToast(toast, y)
            y = y + TOAST_H + GAP
        end
    end)

    -- Quick console helper for testing.
    concommand.Add("ev_toast_test", function()
        addToast("Evolve", "Toast system OK! Theme: "
            .. (evolve:GetTheme() and evolve:GetTheme().name or "?"),
            6, "info")
    end)
end

evolve:RegisterPlugin(PLUGIN)
