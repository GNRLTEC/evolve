--[[-------------------------------------------------------------------------
    Evolve Theme System
    ---------------------------------------------------------------------------
    Shared module providing modern, themeable colors, fonts and draw helpers
    for the Evolve admin UI. Supports multiple themes (dark + light variants),
    per-player client preference persistence, and a server-side default
    broadcast via the EV_ThemeDefault net message.

    Public API (client or shared unless noted):
        evolve:GetTheme()                -> active theme table
        evolve:SetTheme(name, silent)    -> switch theme + fire hook
        evolve:ListThemes()              -> sorted array of theme ids
        evolve:IsDarkTheme()             -> bool
        evolve.theme                     -> alias of evolve:GetTheme()

    Draw helpers (client):
        evolve:ThemedPanel(x, y, w, h, alpha)
        evolve:ThemedBorder(x, y, w, h, color, thickness)
        evolve:ThemedAccentLine(x, y, w, h)
        evolve:GradientRect(x, y, w, h, col_top, col_bottom)

    Hooks:
        EV_ThemeChanged(theme)           -> fires whenever the active theme
                                            changes, including initial load.
---------------------------------------------------------------------------]]

evolve = evolve or {}
evolve.themes = evolve.themes or {}

local THEME_FILE = "evolve/theme_preference.txt"
local DEFAULT_THEME = "dark_cyan"

--[[-----------------------------------------------------------------------
    Theme definitions
    Each theme is a plain table of colors + meta. New themes only need to
    be added here; the settings tab and draw helpers will pick them up.
-------------------------------------------------------------------------]]

local function registerTheme(id, t)
    t.id = id
    evolve.themes[id] = t
end

registerTheme("dark_cyan", {
    name        = "Midnight Cyan",
    description = "Deep navy background with electric cyan highlights.",
    is_dark     = true,
    accent      = Color(  0, 210, 255, 255),
    accent_soft = Color(  0, 130, 170, 255),
    accent_glow = Color(  0, 210, 255,  60),
    bg          = Color( 14,  18,  26, 245),
    bg_alt      = Color( 22,  28,  38, 245),
    panel       = Color( 26,  33,  46, 250),
    panel_alt   = Color( 32,  40,  55, 250),
    hover       = Color( 44,  56,  74, 255),
    border      = Color( 50,  70,  95, 255),
    border_soft = Color( 40,  55,  75, 180),
    text        = Color(230, 238, 248, 255),
    text_dim    = Color(150, 165, 185, 255),
    text_mute   = Color(100, 115, 135, 255),
    success     = Color( 80, 220, 140, 255),
    warning     = Color(255, 195,  75, 255),
    danger      = Color(255,  85, 105, 255),
    shadow      = Color(  0,   0,   0, 160),
})

registerTheme("light_cyan", {
    name        = "Frost Cyan",
    description = "Clean white panels with a cyan accent.",
    is_dark     = false,
    accent      = Color(  0, 160, 220, 255),
    accent_soft = Color(  0, 130, 180, 255),
    accent_glow = Color(  0, 160, 220,  50),
    bg          = Color(238, 242, 248, 245),
    bg_alt      = Color(228, 234, 242, 245),
    panel       = Color(252, 253, 255, 250),
    panel_alt   = Color(240, 244, 250, 250),
    hover       = Color(218, 232, 244, 255),
    border      = Color(200, 212, 225, 255),
    border_soft = Color(215, 225, 235, 180),
    text        = Color( 28,  38,  52, 255),
    text_dim    = Color( 90, 105, 125, 255),
    text_mute   = Color(120, 130, 150, 255),
    success     = Color( 40, 170,  95, 255),
    warning     = Color(220, 155,  45, 255),
    danger      = Color(210,  55,  75, 255),
    shadow      = Color(  0,   0,   0,  60),
})

registerTheme("dark_purple", {
    name        = "Neon Violet",
    description = "Cyberpunk dark with a magenta glow.",
    is_dark     = true,
    accent      = Color(195,  85, 255, 255),
    accent_soft = Color(160,  70, 215, 255),
    accent_glow = Color(195,  85, 255,  60),
    bg          = Color( 16,  14,  24, 245),
    bg_alt      = Color( 24,  20,  36, 245),
    panel       = Color( 30,  25,  44, 250),
    panel_alt   = Color( 38,  32,  56, 250),
    hover       = Color( 54,  44,  78, 255),
    border      = Color( 80,  60, 110, 255),
    border_soft = Color( 60,  50,  85, 180),
    text        = Color(236, 232, 248, 255),
    text_dim    = Color(170, 158, 195, 255),
    text_mute   = Color(118, 108, 140, 255),
    success     = Color( 95, 220, 155, 255),
    warning     = Color(255, 185,  80, 255),
    danger      = Color(255,  90, 120, 255),
    shadow      = Color(  0,   0,   0, 160),
})

registerTheme("dark_green", {
    name        = "Matrix Green",
    description = "Terminal-inspired dark with phosphor green.",
    is_dark     = true,
    accent      = Color( 90, 240, 140, 255),
    accent_soft = Color( 35, 140,  80, 255),
    accent_glow = Color( 90, 240, 140,  60),
    bg          = Color( 10,  16,  12, 245),
    bg_alt      = Color( 16,  24,  18, 245),
    panel       = Color( 20,  30,  22, 250),
    panel_alt   = Color( 26,  38,  28, 250),
    hover       = Color( 36,  56,  42, 255),
    border      = Color( 55,  90,  65, 255),
    border_soft = Color( 45,  75,  55, 180),
    text        = Color(224, 248, 228, 255),
    text_dim    = Color(150, 180, 158, 255),
    text_mute   = Color(100, 125, 108, 255),
    success     = Color( 95, 230, 140, 255),
    warning     = Color(240, 200,  70, 255),
    danger      = Color(240,  95, 110, 255),
    shadow      = Color(  0,   0,   0, 160),
})

registerTheme("dark_amber", {
    name        = "HUD Amber",
    description = "Dark plate steel with warm amber highlights.",
    is_dark     = true,
    accent      = Color(255, 170,  45, 255),
    accent_soft = Color(165,  95,  20, 255),
    accent_glow = Color(255, 170,  45,  60),
    bg          = Color( 18,  16,  14, 245),
    bg_alt      = Color( 26,  23,  20, 245),
    panel       = Color( 32,  28,  24, 250),
    panel_alt   = Color( 42,  36,  30, 250),
    hover       = Color( 60,  50,  38, 255),
    border      = Color( 92,  72,  45, 255),
    border_soft = Color( 70,  56,  36, 180),
    text        = Color(248, 238, 225, 255),
    text_dim    = Color(185, 168, 142, 255),
    text_mute   = Color(135, 120, 100, 255),
    success     = Color( 95, 220, 140, 255),
    warning     = Color(255, 200,  80, 255),
    danger      = Color(250,  90, 100, 255),
    shadow      = Color(  0,   0,   0, 160),
})

registerTheme("light_slate", {
    name        = "Slate Light",
    description = "Neutral light theme for high-contrast daytime use.",
    is_dark     = false,
    accent      = Color( 60, 120, 210, 255),
    accent_soft = Color( 45,  95, 170, 255),
    accent_glow = Color( 60, 120, 210,  55),
    bg          = Color(244, 246, 250, 245),
    bg_alt      = Color(232, 236, 242, 245),
    panel       = Color(255, 255, 255, 250),
    panel_alt   = Color(240, 244, 250, 250),
    hover       = Color(220, 230, 244, 255),
    border      = Color(205, 214, 226, 255),
    border_soft = Color(220, 228, 238, 180),
    text        = Color( 30,  40,  56, 255),
    text_dim    = Color( 95, 108, 128, 255),
    text_mute   = Color(120, 130, 150, 255),
    success     = Color( 45, 170, 100, 255),
    warning     = Color(215, 145,  30, 255),
    danger      = Color(210,  60,  75, 255),
    shadow      = Color(  0,   0,   0,  60),
})

--[[-----------------------------------------------------------------------
    Fonts
-------------------------------------------------------------------------]]

if CLIENT then
    local function createFont(name, size, weight, shadow)
        surface.CreateFont(name, {
            font      = "Roboto",
            extended  = true,
            size      = size,
            weight    = weight or 500,
            antialias = true,
            shadow    = shadow or false,
        })
    end

    -- Primary UI fonts (used by the menu, scoreboard and notifications).
    createFont("EV_Title",       22, 700)
    createFont("EV_Header",      18, 600)
    createFont("EV_SubHeader",   15, 600)
    createFont("EV_Text",        14, 500)
    createFont("EV_TextBold",    14, 700)
    createFont("EV_Small",       12, 500)
    createFont("EV_SmallBold",   12, 700)
    createFont("EV_Tiny",        11, 500)
    createFont("EV_ScoreBig",    26, 700, true)
    createFont("EV_ScoreHeader", 16, 700)
    createFont("EV_NotifyTitle", 16, 700)
    createFont("EV_NotifyBody",  13, 500)
    createFont("EV_TabLabel",    14, 600)

    -- Fallback compatibility aliases for older Evolve plugins that still
    -- reference the legacy font names. These are recreated here so that
    -- nothing breaks if a plugin asks for them before the rest of the UI
    -- loads.
    surface.CreateFont("MenuItem", {
        font = "Roboto", size = 13, weight = 500, antialias = true
    })
    surface.CreateFont("EvolvePlayerListEntry", {
        font = "Roboto", size = 13, weight = 500, antialias = true
    })
    surface.CreateFont("ScoreboardText", {
        font = "Roboto", size = 13, weight = 500, antialias = true
    })
    surface.CreateFont("EvolveScoreboardHeader", {
        font = "Roboto", size = 22, weight = 700, antialias = true
    })
end

--[[-----------------------------------------------------------------------
    Active theme management
-------------------------------------------------------------------------]]

evolve.theme = evolve.themes[DEFAULT_THEME]

function evolve:ListThemes()
    local out = {}
    for id, _ in pairs(self.themes) do table.insert(out, id) end
    table.sort(out)
    return out
end

function evolve:GetTheme()
    return self.theme or self.themes[DEFAULT_THEME]
end

function evolve:IsDarkTheme()
    local t = self:GetTheme()
    return t and t.is_dark or false
end

function evolve:SetTheme(id, silent)
    local t = self.themes[id]
    if not t then return false end
    self.theme = t

    if CLIENT and not silent then
        file.Write(THEME_FILE, id)
    end

    hook.Run("EV_ThemeChanged", t)
    return true
end

--[[-----------------------------------------------------------------------
    Server-side default theme
    Server owners can set ev_default_theme "<id>" and new clients will get
    this pushed to them on join. Clients still keep their local override
    if they have explicitly chosen one.
-------------------------------------------------------------------------]]

if SERVER then
    util.AddNetworkString("EV_ThemeDefault")

    CreateConVar("ev_default_theme", DEFAULT_THEME,
        {FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY},
        "The default Evolve UI theme for players who have not chosen one."
    )

    local function broadcastTheme(ply)
        local id = GetConVar("ev_default_theme"):GetString()
        net.Start("EV_ThemeDefault")
            net.WriteString(id or DEFAULT_THEME)
        if IsValid(ply) then net.Send(ply) else net.Broadcast() end
    end

    hook.Add("PlayerInitialSpawn", "EV_ThemeSend", function(ply)
        timer.Simple(2, function()
            if IsValid(ply) then broadcastTheme(ply) end
        end)
    end)

    cvars.AddChangeCallback("ev_default_theme", function(_, _, new)
        broadcastTheme()
    end, "EV_ThemeDefaultBroadcast")

    -- Console helper so owners can change the default without remembering
    -- the convar name. Mirrors the "ev_*" naming of other admin commands.
    concommand.Add("ev_settheme", function(ply, _, args)
        if IsValid(ply) and not ply:IsSuperAdmin() then
            if ply.EV_HasPrivilege and not ply:EV_HasPrivilege("Rank menu") then
                return
            end
        end
        local id = args[1]
        if not id or not evolve.themes[id] then
            if IsValid(ply) then
                ply:ChatPrint("[Evolve] Unknown theme. Available: "
                    .. table.concat(evolve:ListThemes(), ", "))
            else
                print("[Evolve] Unknown theme. Available: "
                    .. table.concat(evolve:ListThemes(), ", "))
            end
            return
        end
        RunConsoleCommand("ev_default_theme", id)
    end)
end

--[[-----------------------------------------------------------------------
    Draw helpers
    Small wrappers that keep theme references out of every tab file.
    IMPORTANT: this block must stay ABOVE the client preference-loading
    block below.  If preference loading throws a Lua error the include()
    call aborts and any code after the error is never reached.  By
    defining the helpers first we guarantee they are always available to
    the menu and tab files regardless of what happens during init.
-------------------------------------------------------------------------]]

if CLIENT then
    function evolve:ThemedPanel(x, y, w, h, alpha)
        local t = self:GetTheme()
        local c = t.panel
        surface.SetDrawColor(c.r, c.g, c.b, alpha or c.a)
        surface.DrawRect(x, y, w, h)
    end

    function evolve:ThemedBorder(x, y, w, h, color, thickness)
        thickness = thickness or 1
        local c = color or self:GetTheme().border
        surface.SetDrawColor(c.r, c.g, c.b, c.a)
        for i = 0, thickness - 1 do
            surface.DrawOutlinedRect(x + i, y + i, w - i * 2, h - i * 2)
        end
    end

    function evolve:ThemedAccentLine(x, y, w, h)
        local c = self:GetTheme().accent
        surface.SetDrawColor(c.r, c.g, c.b, c.a)
        surface.DrawRect(x, y, w, h)
    end

    function evolve:GradientRect(x, y, w, h, topCol, botCol)
        -- Vertical two-color gradient. Cheap — rows are drawn as 1px lines.
        local steps = h
        for i = 0, steps - 1 do
            local t = i / math.max(steps - 1, 1)
            local r = topCol.r + (botCol.r - topCol.r) * t
            local g = topCol.g + (botCol.g - topCol.g) * t
            local b = topCol.b + (botCol.b - topCol.b) * t
            local a = topCol.a + (botCol.a - topCol.a) * t
            surface.SetDrawColor(r, g, b, a)
            surface.DrawRect(x, y + i, w, 1)
        end
    end

    -- Rounded box convenience that always uses the current panel color.
    function evolve:ThemedRoundedBox(r, x, y, w, h, col)
        col = col or self:GetTheme().panel
        draw.RoundedBox(r, x, y, w, h, col)
    end

    --[[---------------------------------------------------------------------
        Widget styling helpers
        Built to handle the stock Derma controls that don't have native
        theming support. Each takes a VGUI instance and patches its Paint
        functions so the control repaints with the current theme every
        frame. Safe to call multiple times on the same widget.
    -----------------------------------------------------------------------]]

    local function styleScrollBar(sb)
        if not IsValid(sb) then return end
        sb.Paint = function(_, w, h)
            local t = evolve:GetTheme()
            surface.SetDrawColor(t.bg.r, t.bg.g, t.bg.b, 180)
            surface.DrawRect(0, 0, w, h)
        end
        if IsValid(sb.btnUp) then
            sb.btnUp.Paint = function(_, w, h)
                local t = evolve:GetTheme()
                draw.RoundedBox(2, 2, 2, w - 4, h - 4, t.panel_alt)
            end
        end
        if IsValid(sb.btnDown) then
            sb.btnDown.Paint = function(_, w, h)
                local t = evolve:GetTheme()
                draw.RoundedBox(2, 2, 2, w - 4, h - 4, t.panel_alt)
            end
        end
        if IsValid(sb.btnGrip) then
            sb.btnGrip.Paint = function(pnl, w, h)
                local t = evolve:GetTheme()
                local c = pnl:IsHovered() and t.accent or t.accent_soft
                draw.RoundedBox(2, 2, 2, w - 4, h - 4, c)
            end
        end
    end

    evolve.StyleScrollBar = function(_, sb) styleScrollBar(sb) end

    -- Returns the text color that should be used to draw content on top of
    -- a DListView_Line. Selected rows use white to stay readable against the
    -- accent background; other rows fall back to the theme's body text color.
    function evolve:LineTextColor(line)
        if IsValid(line) and line.IsSelected and line:IsSelected() then
            return color_white
        end
        return self:GetTheme().text
    end

    -- Paint for an individual DListView_Line. Called via line.Paint override.
    local function paintListLine(line, w, h)
        local t  = evolve:GetTheme()
        local bg
        if line:IsSelected() then
            bg = t.accent_soft
        elseif line:IsHovered() then
            bg = t.hover
        elseif line:GetID() % 2 == 0 then
            bg = t.panel_alt
        else
            bg = t.panel
        end
        surface.SetDrawColor(bg.r, bg.g, bg.b, bg.a)
        surface.DrawRect(0, 0, w, h)

        -- Default line text color (only applies when the line has column
        -- text; custom PaintOver callers can override).
        for i = 1, #line.Columns do
            local col = line.Columns[i]
            if IsValid(col) then
                col:SetTextColor(line:IsSelected() and color_white or t.text)
            end
        end
    end

    function evolve:StyleListView(list)
        if not IsValid(list) then return end
        local t = self:GetTheme()

        list.Paint = function(pnl, w, h)
            local th = evolve:GetTheme()
            draw.RoundedBox(4, 0, 0, w, h, th.panel_alt)
        end
        list.PaintOver = function(pnl, w, h)
            local th = evolve:GetTheme()
            surface.SetDrawColor(th.border_soft.r, th.border_soft.g,
                                 th.border_soft.b, th.border_soft.a)
            surface.DrawOutlinedRect(0, 0, w, h)
        end

        -- Column header strip.
        if list.Columns then
            for _, col in ipairs(list.Columns) do
                col.Header.Paint = function(hdr, w, h)
                    local th = evolve:GetTheme()
                    surface.SetDrawColor(th.bg_alt.r, th.bg_alt.g,
                                         th.bg_alt.b, 255)
                    surface.DrawRect(0, 0, w, h)
                    surface.SetDrawColor(th.accent.r, th.accent.g,
                                         th.accent.b, 255)
                    surface.DrawRect(0, h - 2, w, 2)
                end
                col.Header:SetTextColor(evolve:GetTheme().text)
            end
        end

        -- Patch AddLine so every future row is themed. Existing rows are
        -- patched below.
        if not list._EV_Themed then
            list._EV_Themed = true
            local origAddLine = list.AddLine
            function list:AddLine(...)
                local line = origAddLine(self, ...)
                if IsValid(line) then
                    line.Paint = paintListLine
                end
                return line
            end
        end

        -- Patch any rows that already exist.
        for _, line in ipairs(list:GetLines()) do
            line.Paint = paintListLine
        end

        styleScrollBar(list.VBar)
    end

    function evolve:StyleComboBox(combo)
        if not IsValid(combo) then return end

        combo.Paint = function(pnl, w, h)
            local th = evolve:GetTheme()
            local bg = pnl:IsHovered() and th.hover or th.panel_alt
            draw.RoundedBox(3, 0, 0, w, h, bg)
            surface.SetDrawColor(th.border.r, th.border.g, th.border.b, 120)
            surface.DrawOutlinedRect(0, 0, w, h)

            -- Little chevron on the right.
            surface.SetDrawColor(th.text_dim.r, th.text_dim.g,
                                 th.text_dim.b, 255)
            surface.SetFont("EV_Small")
            surface.SetTextPos(w - 16, h / 2 - 8)
            surface.SetTextColor(th.text_dim)
            surface.DrawText("v")
        end
        combo:SetTextColor(evolve:GetTheme().text)

        -- When the dropdown opens, style its menu.
        combo.OpenMenuOld = combo.OpenMenuOld or combo.OpenMenu
        combo.OpenMenu = function(self_, ...)
            self_:OpenMenuOld(...)
            if IsValid(self_.Menu) then
                self_.Menu.Paint = function(pnl, w, h)
                    local th = evolve:GetTheme()
                    draw.RoundedBox(3, 0, 0, w, h, th.panel_alt)
                end
                for _, option in ipairs(self_.Menu:GetChildren()) do
                    if option.SetTextColor then
                        option:SetTextColor(evolve:GetTheme().text)
                    end
                    option.Paint = function(pnl, w, h)
                        local th = evolve:GetTheme()
                        local bg = pnl:IsHovered() and th.accent_soft
                                                    or th.panel_alt
                        surface.SetDrawColor(bg.r, bg.g, bg.b, bg.a)
                        surface.DrawRect(0, 0, w, h)
                    end
                end
            end
        end
    end

    function evolve:StyleNumSlider(slider)
        if not IsValid(slider) then return end

        -- Root panel: fully transparent so the tab surface shows through.
        slider.Paint = function() end

        -- The DLabel sub-panel draws a white box via GMod's skin system even
        -- when its .Paint is overridden (the skin's SkinPaint path still fires).
        -- Strategy: blank out every non-slider, non-textentry child panel so
        -- nothing draws a box, then re-draw the label text ourselves in
        -- PaintOver — which runs AFTER every child has painted and therefore
        -- always wins.
        for _, child in ipairs(slider:GetChildren()) do
            local cn = child:GetClassName()
            if cn ~= "DSlider" and cn ~= "DTextEntry" then
                child.Paint     = function() end
                child.PaintOver = function() end
            end
        end

        -- PaintOver on the root slider: renders the label text above everything.
        slider.PaintOver = function(pnl, w, h)
            local th  = evolve:GetTheme()
            -- Prefer the text stored directly on the DLabel; fall back to the
            -- slider's own GetText() in case the sub-panel structure differs.
            local txt = ""
            if IsValid(slider.Label) then
                txt = slider.Label:GetText()
            end
            if txt == "" then txt = pnl:GetText() end
            if txt ~= "" then
                draw.SimpleText(txt, "DermaDefault", 4, h / 2,
                    th.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end

        -- Number entry box (Scratch / TextArea).
        local textArea = IsValid(slider.Scratch)  and slider.Scratch
                      or IsValid(slider.TextArea) and slider.TextArea
        if textArea then
            textArea.Paint = function(pnl, w, h)
                local th = evolve:GetTheme()
                draw.RoundedBox(2, 0, 0, w, h, th.panel_alt)
                surface.SetDrawColor(th.border.r, th.border.g, th.border.b, 120)
                surface.DrawOutlinedRect(0, 0, w, h)
                pnl:DrawTextEntryText(th.text, th.accent, th.text)
            end
        end

        -- Slider track + filled accent bar + knob.
        if IsValid(slider.Slider) then
            slider.Slider.Paint = function(pnl, w, h)
                local th     = evolve:GetTheme()
                local trackY = h / 2 - 2
                local trackH = 4
                local trackX = 8
                local trackW = pnl:GetWide() - 16

                surface.SetDrawColor(th.border.r, th.border.g, th.border.b, 255)
                surface.DrawRect(trackX, trackY, trackW, trackH)

                local knob = pnl.Knob
                if IsValid(knob) then
                    local fillW = knob:GetX() + knob:GetWide() / 2 - trackX
                    if fillW > 0 then
                        local ac = th.accent
                        surface.SetDrawColor(ac.r, ac.g, ac.b, 200)
                        surface.DrawRect(trackX, trackY,
                                         math.min(fillW, trackW), trackH)
                    end
                end
            end

            if IsValid(slider.Slider.Knob) then
                slider.Slider.Knob.Paint = function(pnl, w, h)
                    local th = evolve:GetTheme()
                    draw.RoundedBox(4, 1, 1, w - 2, h - 2, th.accent)
                    surface.SetDrawColor(th.border.r, th.border.g,
                                         th.border.b, 180)
                    surface.DrawOutlinedRect(0, 0, w, h)
                end
            end
        end
    end

    function evolve:StyleCheckBoxLabel(cb)
        if not IsValid(cb) then return end

        -- Style the checkbox button.
        if IsValid(cb.Button) then
            cb.Button.Paint = function(pnl, w, h)
                local th = evolve:GetTheme()
                draw.RoundedBox(2, 0, 0, w, h, th.panel_alt)
                if pnl:GetChecked() then
                    draw.RoundedBox(2, 3, 3, w - 6, h - 6, th.accent)
                end
                surface.SetDrawColor(th.border.r, th.border.g, th.border.b, 180)
                surface.DrawOutlinedRect(0, 0, w, h)
            end
        end

        -- Set the label text color.
        -- NOTE: DLabel uses :SetColor(), NOT :SetTextColor() — SetTextColor is
        -- a DTextEntry method and silently does nothing on DLabel, which is why
        -- earlier attempts left text invisible on light themes.
        -- We do NOT override Paint or use PaintOver here because those approaches
        -- cause double-rendering blur (DLabel renders text once natively; any
        -- additional draw.SimpleText on top creates the blurry ghost effect).
        if IsValid(cb.Label) then
            cb.Label:SetColor(evolve:GetTheme().text)
        end
    end

    function evolve:StylePanel(pnl, roundedCorners)
        if not IsValid(pnl) then return end
        pnl.Paint = function(p, w, h)
            local th = evolve:GetTheme()
            if roundedCorners then
                draw.RoundedBox(6, 0, 0, w, h, th.panel_alt)
            else
                surface.SetDrawColor(th.panel_alt.r, th.panel_alt.g,
                                     th.panel_alt.b, th.panel_alt.a)
                surface.DrawRect(0, 0, w, h)
            end
        end
    end
end

--[[-----------------------------------------------------------------------
    Client preference loading
    Reads the player's saved theme choice and wires up the net receiver
    for the server-broadcast default.  This block intentionally comes
    AFTER the draw-helper definitions above so that a Lua error here
    (e.g. from a duplicate concommand registration on reload) does not
    prevent those helpers from being available.
-------------------------------------------------------------------------]]

if CLIENT then
    -- Load the player's saved preference (if any) on startup.
    local saved = file.Read(THEME_FILE, "DATA")
    if saved and evolve.themes[saved] then
        evolve:SetTheme(saved, true)
    end

    -- Remember the last theme the server broadcast so we can restore it
    -- immediately when the player clears their personal override.
    local serverBroadcastTheme = DEFAULT_THEME

    net.Receive("EV_ThemeDefault", function()
        local id = net.ReadString()
        serverBroadcastTheme = id
        -- Only apply the server default if the player hasn't chosen a theme
        -- themselves. Once they do, the local file exists and wins.
        local hasLocal = file.Exists(THEME_FILE, "DATA")
        if not hasLocal and evolve.themes[id] then
            evolve:SetTheme(id, true)
        end
    end)

    -- Let players clear their override and fall back to the server default.
    -- This now takes effect immediately — no rejoin required.
    concommand.Add("ev_resettheme", function()
        if file.Exists(THEME_FILE, "DATA") then
            file.Delete(THEME_FILE)
        end
        local fallback = (evolve.themes[serverBroadcastTheme] and serverBroadcastTheme)
                      or DEFAULT_THEME
        evolve:SetTheme(fallback)
        chat.AddText(Color(0, 210, 255),
            "[Evolve] ", color_white,
            "Theme preference cleared — server default applied."
        )
    end)
end
