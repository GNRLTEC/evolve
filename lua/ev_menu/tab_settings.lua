--[[-------------------------------------------------------------------------
    Settings tab
    Theme switcher + display options. Always available to every player; no
    privilege required because the selection is stored client-side.
---------------------------------------------------------------------------]]

local TAB = {}
TAB.Title       = "Settings"
TAB.Description = "Customize the look of the Evolve menu."
TAB.Icon        = "wrench"
TAB.Author      = "Evolve"
TAB.Width       = 420

-- Visible to everyone.
function TAB:IsAllowed() return true end

-- Server-side the file is included only so AddCSLuaFile + the sv RegisterTab
-- can register any privileges (there are none). Nothing below this line is
-- needed on the server.
if SERVER then
    evolve:RegisterTab(TAB)
    return
end

-- Tiny wrapper to keep the local theme table up to date across frames.
local function theme()
    return evolve:GetTheme()
end

--[[-----------------------------------------------------------------------
    Theme preview card VGUI control
-------------------------------------------------------------------------]]
local CARD = {}

function CARD:Init()
    self:SetCursor("hand")
    self.HoverFrac = 0
end

function CARD:SetTheme(id)
    self.ThemeID   = id
    self.ThemeData = evolve.themes[id]
end

function CARD:Paint(w, h)
    if not self.ThemeData then return end
    local t       = self.ThemeData
    local current = evolve:GetTheme()
    local active  = current and current.id == self.ThemeID

    self.HoverFrac = Lerp(FrameTime() * 10, self.HoverFrac,
        (self:IsHovered() or active) and 1 or 0)

    -- Drop the mini preview onto the card.
    draw.RoundedBox(6, 0, 0, w, h, t.bg)

    -- Title bar stripe.
    draw.RoundedBoxEx(6, 0, 0, w, 20, t.bg_alt, true, true, false, false)
    surface.SetDrawColor(t.accent.r, t.accent.g, t.accent.b, 255)
    surface.DrawRect(0, 20, w, 2)

    -- Sidebar stripe.
    surface.SetDrawColor(t.bg_alt.r, t.bg_alt.g, t.bg_alt.b, 255)
    surface.DrawRect(0, 22, 10, h - 22)

    -- Panel body mock.
    draw.RoundedBox(3, 16, 26, w - 22, h - 36, t.panel)

    -- Accent pips to suggest list items.
    for i = 0, 2 do
        local y = 31 + i * 7
        surface.SetDrawColor(t.text_dim.r, t.text_dim.g, t.text_dim.b, 200)
        surface.DrawRect(22, y, 34, 2)
        surface.SetDrawColor(t.accent.r, t.accent.g, t.accent.b, 200)
        surface.DrawRect(w - 32, y, 10, 2)
    end

    -- Name label.
    draw.SimpleText(t.name, "EV_SmallBold",
        w / 2, h - 10, t.text,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Outline + active glow.
    local outline = active and current.accent or theme().border
    local a       = active and 255 or (80 + 120 * self.HoverFrac)
    surface.SetDrawColor(outline.r, outline.g, outline.b, a)
    surface.DrawOutlinedRect(0, 0, w, h)
    if active then
        surface.DrawOutlinedRect(1, 1, w - 2, h - 2)
    end

    -- "active" badge when this is the selected theme.
    if active then
        draw.SimpleText("active", "EV_Tiny",
            w - 6, 10, current.accent,
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
end

function CARD:DoClick()
    if not self.ThemeID then return end
    evolve:SetTheme(self.ThemeID)
    surface.PlaySound("ui/buttonclickrelease.wav")
end

vgui.Register("EVThemeCard", CARD, "DButton")

--[[-----------------------------------------------------------------------
    Tab construction
    Layout budget (TAB.Width = 420, visible height ≈ 406 px):
      y=10   Header
      y=32   Subheader
      y=52   GridScroll (h=226)  ← 3-column theme cards, scrollable
      y=286  "Options" label
      y=308  "Use server default theme" button (h=24)
      y=340  [admin] "Server default" label
      y=358  [admin] DComboBox (h=22)   → total ≈ 380 px ✓
-------------------------------------------------------------------------]]
function TAB:Initialize(pnl)
    -- ── Header ─────────────────────────────────────────────────────────
    self.Header = vgui.Create("DLabel", pnl)
    self.Header:SetText("Appearance")
    self.Header:SetFont("EV_Header")
    self.Header:SetTextColor(theme().text)
    self.Header:SetPos(14, 10)
    self.Header:SizeToContents()

    self.Subheader = vgui.Create("DLabel", pnl)
    self.Subheader:SetText("Pick a theme to make Evolve feel like yours.")
    self.Subheader:SetFont("EV_Small")
    self.Subheader:SetTextColor(theme().text_dim)
    self.Subheader:SetPos(14, 32)
    self.Subheader:SizeToContents()

    -- ── Scrollable theme grid ───────────────────────────────────────────
    -- 3 columns × 120 px cards + 10 px gaps = 380 px → fits in 390 px canvas.
    -- Scroll panel is a fixed 226 px tall; content scrolls if there are many
    -- themes (2 rows of 96 px cards + spacing fits without scrolling at all).
    local CARD_W   = 120
    local CARD_H   = 96
    local GRID_GAP = 8

    self.GridScroll = vgui.Create("DScrollPanel", pnl)
    self.GridScroll:SetPos(10, 52)
    self.GridScroll:SetSize(TAB.Width - 20, 226)
    self.GridScroll.Paint = function() end   -- transparent; container bg handles it

    -- Style the vertical scrollbar.
    local vbar = self.GridScroll:GetVBar()
    vbar:SetWide(6)
    vbar.Paint = function(p, w, h)
        draw.RoundedBox(3, 0, 0, w, h, evolve:GetTheme().panel_alt)
    end
    if vbar.btnUp   then vbar.btnUp.Paint   = function() end end
    if vbar.btnDown then vbar.btnDown.Paint = function() end end
    vbar.btnGrip.Paint = function(p, w, h)
        draw.RoundedBox(3, 1, 2, w - 2, h - 4, evolve:GetTheme().border)
    end

    -- DIconLayout inside the scroll panel (width = scroll panel - scrollbar).
    self.Grid = vgui.Create("DIconLayout", self.GridScroll)
    self.Grid:SetPos(0, 4)
    self.Grid:SetSize(TAB.Width - 20 - 8, 800)  -- height over-allocated; scroll clips
    self.Grid:SetSpaceX(GRID_GAP)
    self.Grid:SetSpaceY(GRID_GAP)

    self.Cards = {}
    for _, id in ipairs(evolve:ListThemes()) do
        local card = self.Grid:Add("EVThemeCard")
        card:SetSize(CARD_W, CARD_H)
        card:SetText("")
        card:SetTheme(id)
        self.Cards[id] = card
    end

    -- ── Options section ─────────────────────────────────────────────────
    self.OptHeader = vgui.Create("DLabel", pnl)
    self.OptHeader:SetText("Options")
    self.OptHeader:SetFont("EV_SubHeader")
    self.OptHeader:SetTextColor(theme().text)
    self.OptHeader:SetPos(14, 286)
    self.OptHeader:SizeToContents()

    -- "Use server default" button — clears the local override and applies
    -- the server's broadcast theme immediately (no rejoin needed).
    self.ResetBtn = vgui.Create("EvolveButton", pnl)
    self.ResetBtn:SetPos(14, 308)
    self.ResetBtn:SetSize(200, 24)
    self.ResetBtn:SetButtonText("Use server default theme")
    self.ResetBtn.DoClick = function()
        RunConsoleCommand("ev_resettheme")
    end

    -- ── Admin-only: choose the server's default theme ───────────────────
    if LocalPlayer():IsSuperAdmin()
        or (LocalPlayer().EV_HasPrivilege and LocalPlayer():EV_HasPrivilege("Rank menu")) then

        self.DefaultLabel = vgui.Create("DLabel", pnl)
        self.DefaultLabel:SetText("Server default for new players:")
        self.DefaultLabel:SetFont("EV_Small")
        self.DefaultLabel:SetTextColor(theme().text_dim)
        self.DefaultLabel:SetPos(14, 340)
        self.DefaultLabel:SizeToContents()

        self.DefaultCombo = vgui.Create("DComboBox", pnl)
        self.DefaultCombo:SetPos(14, 358)
        self.DefaultCombo:SetSize(200, 22)
        for _, id in ipairs(evolve:ListThemes()) do
            self.DefaultCombo:AddChoice(evolve.themes[id].name, id)
        end
        self.DefaultCombo.OnSelect = function(_, _, _, id)
            RunConsoleCommand("ev_settheme", id)
        end
        evolve:StyleComboBox(self.DefaultCombo)
    end
end

function TAB:Update()
    -- Refresh header colors when the theme changes.
    if self.Header      then self.Header:SetTextColor(theme().text)        end
    if self.Subheader   then self.Subheader:SetTextColor(theme().text_dim) end
    if self.OptHeader   then self.OptHeader:SetTextColor(theme().text)     end
    if self.DefaultLabel then self.DefaultLabel:SetTextColor(theme().text_dim) end
    -- Re-style the combo box if it exists.
    if self.DefaultCombo and IsValid(self.DefaultCombo) then
        evolve:StyleComboBox(self.DefaultCombo)
    end
end

hook.Add("EV_ThemeChanged", "EV_SettingsTabRefresh", function()
    if TAB.Update then TAB:Update() end
end)

evolve:RegisterTab(TAB)
