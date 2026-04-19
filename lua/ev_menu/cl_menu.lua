--[[-------------------------------------------------------------------------
    Clientside menu framework

    Modern redesign of the Evolve admin menu. Replaces the classic gray
    DFrame + DPropertySheet with a themed panel featuring:

      * A sidebar icon navigation (replaces stock tab strip)
      * Rounded panel surfaces pulled from evolve:GetTheme()
      * Lerp-based slide animation driven by HUDPaint timing
      * Live theme hot-swap via the EV_ThemeChanged hook

    Public API kept intact so existing tabs keep working:

        evolve:RegisterTab(tab)          -- tabs supply Title/Icon/Privileges
                                         -- /Width/Initialize/Update/IsAllowed
        evolve.MENU:Show() / Hide() / Toggle()
        evolve.MENU:GetActiveTab()
        concommands: +ev_menu, -ev_menu, ev_menu
---------------------------------------------------------------------------]]

evolve.MENU         = evolve.MENU or {}
local MENU          = evolve.MENU
MENU.Tabs           = {}
MENU.Privileges     = {}

-- Layout constants. These are the single source of truth for menu sizing;
-- previously they were scattered across magic numbers in every tab file.
local SIDEBAR_W     = 68
local TITLEBAR_H    = 44
local FOOTER_H      = 34
local MIN_CONTENT_W = 260
local CONTENT_H     = 500
local PANEL_MARGIN  = 12
local ANIM_SPEED    = 10    -- higher = snappier open/close

--[[-----------------------------------------------------------------------
    Sidebar nav button — themed, animated hover glow and selection bar.
-------------------------------------------------------------------------]]
local NAV_BUTTON = {}

function NAV_BUTTON:Init()
    self:SetText("")
    self:SetCursor("hand")
    self.HoverFrac    = 0
    self.SelectedFrac = 0
end

function NAV_BUTTON:SetTab(tab)
    self.Tab  = tab
    self.Icon = Material("icon16/" .. (tab.Icon or "bullet_blue") .. ".png")
end

function NAV_BUTTON:IsSelected()
    return MENU:GetActiveTab() == self.Tab
end

function NAV_BUTTON:Paint(w, h)
    local theme = evolve:GetTheme()
    local dt    = FrameTime() * 8

    local hovered  = self:IsHovered()
    self.HoverFrac    = Lerp(dt, self.HoverFrac,    hovered and 1 or 0)
    self.SelectedFrac = Lerp(dt, self.SelectedFrac, self:IsSelected() and 1 or 0)

    -- Selection highlight bar (left edge).
    if self.SelectedFrac > 0.01 then
        local a = theme.accent
        surface.SetDrawColor(a.r, a.g, a.b, 255 * self.SelectedFrac)
        surface.DrawRect(0, 4, 3, h - 8)
    end

    -- Subtle hover fill.
    if self.HoverFrac > 0.01 then
        local hov = theme.hover
        surface.SetDrawColor(hov.r, hov.g, hov.b, hov.a * self.HoverFrac)
        surface.DrawRect(4, 2, w - 6, h - 4)
    end

    -- Icon, tinted toward accent when selected.
    if self.Icon then
        local base  = theme.text_dim
        local acc   = theme.accent
        local r = Lerp(self.SelectedFrac, base.r, acc.r)
        local g = Lerp(self.SelectedFrac, base.g, acc.g)
        local b = Lerp(self.SelectedFrac, base.b, acc.b)
        surface.SetDrawColor(r, g, b, 255)
        surface.SetMaterial(self.Icon)
        surface.DrawTexturedRect(w / 2 - 12, h / 2 - 16, 24, 24)
    end

    -- Tab label below the icon.
    draw.SimpleText(
        self.Tab and self.Tab.Title or "", "EV_Tiny",
        w / 2, h - 10,
        theme.text_dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
    )
end

function NAV_BUTTON:DoClick()
    if not self.Tab then return end
    MENU:SelectTab(self.Tab)
end

vgui.Register("EVNavButton", NAV_BUTTON, "DButton")

--[[-----------------------------------------------------------------------
    evolve:RegisterTab
    Registers a tab table. Panel child hierarchy:

        MENU.Panel (DFrame)
         |-- TitleBar
         |-- Sidebar (nav buttons)
         |-- TabContainer    <- tabs' pnl:GetParent() resolves here
              |-- tab.Panel  <- tab:Initialize(tab.Panel) receives this
-------------------------------------------------------------------------]]
function evolve:RegisterTab(tab)
    if tab.IsAllowed and not tab:IsAllowed() then return false end

    table.Add(MENU.Privileges, tab.Privileges or {})

    tab.Panel = vgui.Create("DPanel", MENU.TabContainer)
    tab.Panel.Tab = tab
    tab.Panel:SetSize(tab.Width or MIN_CONTENT_W, CONTENT_H - TITLEBAR_H - FOOTER_H)

    -- Transparent — theme is painted by the TabContainer beneath it so the
    -- rounded edges of the menu never get covered by gray panels.
    tab.Panel.Paint = function() end

    tab:Initialize(tab.Panel)
    if tab.Update then tab:Update() end

    table.insert(MENU.Tabs, tab)

    -- Keep the legacy .Items shape so any plugin that walks it still works.
    MENU.TabContainer.Items = MENU.TabContainer.Items or {}
    table.insert(MENU.TabContainer.Items, {
        Tab   = tab,
        Panel = tab.Panel,
        Name  = tab.Title,
    })

    if MENU.Sidebar then MENU:BuildSidebar() end
    if not MENU.ActiveTab then MENU:SelectTab(tab) end
end

function MENU:BuildSidebar()
    if not IsValid(self.Sidebar) then return end

    for _, child in ipairs(self.Sidebar:GetChildren()) do child:Remove() end

    local y = 10
    for _, tab in ipairs(self.Tabs) do
        local btn = vgui.Create("EVNavButton", self.Sidebar)
        btn:SetTab(tab)
        btn:SetTooltip(tab.Description or tab.Title)
        btn:SetPos(0, y)
        btn:SetSize(SIDEBAR_W, 58)
        y = y + 60
    end
end

function MENU:GetActiveTab()
    return self.ActiveTab
end

function MENU:TabSelected(tab)
    if tab and tab.Update then tab:Update() end
end

function MENU:SelectTab(tab)
    if not tab or self.ActiveTab == tab then return end

    for _, other in ipairs(self.Tabs) do
        if other.Panel and IsValid(other.Panel) then
            other.Panel:SetVisible(other == tab)
        end
    end

    self.ActiveTab = tab
    self.TargetWidth = SIDEBAR_W + (tab.Width or MIN_CONTENT_W) + PANEL_MARGIN * 2
    self:TabSelected(tab)
end

--[[-----------------------------------------------------------------------
    Menu construction
-------------------------------------------------------------------------]]
function MENU:Initialize()
    self.IsVisible   = false
    self.XPos        = -600
    self.TargetX     = -600
    self.TargetWidth = SIDEBAR_W + MIN_CONTENT_W + PANEL_MARGIN * 2

    self.Panel = vgui.Create("DFrame")
    self.Panel:SetSize(self.TargetWidth, CONTENT_H)
    self.Panel:SetPos(self.XPos, ScrH() / 2 - CONTENT_H / 2)
    self.Panel:ShowCloseButton(false)
    self.Panel:SetDraggable(false)
    self.Panel:SetTitle("")
    self.Panel.Paint = function(pnl, w, h)
        local theme = evolve:GetTheme()

        -- Drop shadow so the menu lifts off the HUD.
        local sh = theme.shadow
        surface.SetDrawColor(sh.r, sh.g, sh.b, sh.a)
        draw.RoundedBox(10, 4, 6, w, h, Color(sh.r, sh.g, sh.b, sh.a))

        draw.RoundedBox(8, 0, 0, w, h, theme.bg)

        -- Title bar strip with accent underline.
        draw.RoundedBoxEx(8, 0, 0, w, TITLEBAR_H, theme.bg_alt, true, true, false, false)
        local a = theme.accent
        surface.SetDrawColor(a.r, a.g, a.b, a.a)
        surface.DrawRect(0, TITLEBAR_H - 2, w, 2)

        -- Title
        draw.SimpleText("EVOLVE",
            "EV_Title", 18, TITLEBAR_H / 2,
            theme.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("admin suite",
            "EV_Small", 100, TITLEBAR_H / 2 + 2,
            theme.text_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Sidebar background.
        surface.SetDrawColor(theme.bg_alt.r, theme.bg_alt.g, theme.bg_alt.b, 255)
        surface.DrawRect(0, TITLEBAR_H, SIDEBAR_W, h - TITLEBAR_H - FOOTER_H)

        -- Footer bar
        surface.SetDrawColor(theme.bg_alt.r, theme.bg_alt.g, theme.bg_alt.b, 255)
        surface.DrawRect(0, h - FOOTER_H, w, FOOTER_H)

        -- Footer status text — current rank + theme.
        local rankId = LocalPlayer().EV_GetRank and LocalPlayer():EV_GetRank() or "guest"
        local rank   = evolve.ranks[rankId]
        local title  = rank and rank.Title or "Guest"
        local rcol   = (rank and rank.Color) or theme.accent

        draw.SimpleText("You are signed in as ",
            "EV_Small", 18, h - FOOTER_H / 2,
            theme.text_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        surface.SetFont("EV_Small")
        local px = surface.GetTextSize("You are signed in as ") + 18

        draw.SimpleText(title,
            "EV_SmallBold", px, h - FOOTER_H / 2,
            rcol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        local themeLabel = (evolve:GetTheme() and evolve:GetTheme().name) or "Default"
        draw.SimpleText("theme: " .. themeLabel,
            "EV_Small", w - 14, h - FOOTER_H / 2,
            theme.text_mute, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- Close button (themed).
    self.CloseBtn = vgui.Create("DButton", self.Panel)
    self.CloseBtn:SetText("")
    self.CloseBtn:SetSize(26, 26)
    self.CloseBtn.Paint = function(pnl, w, h)
        local theme = evolve:GetTheme()
        local col   = pnl:IsHovered() and theme.danger or theme.text_dim
        draw.SimpleText("X", "EV_TextBold", w / 2, h / 2,
            col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    self.CloseBtn.DoClick = function() MENU:Hide() end

    -- Sidebar container.
    self.Sidebar = vgui.Create("DPanel", self.Panel)
    self.Sidebar:SetPos(0, TITLEBAR_H)
    self.Sidebar:SetSize(SIDEBAR_W, CONTENT_H - TITLEBAR_H - FOOTER_H)
    self.Sidebar.Paint = function() end

    -- Tab container (holds every tab.Panel, only active one is visible).
    self.TabContainer = vgui.Create("DPanel", self.Panel)
    self.TabContainer:SetPos(SIDEBAR_W + PANEL_MARGIN, TITLEBAR_H + 8)
    self.TabContainer:SetSize(MIN_CONTENT_W, CONTENT_H - TITLEBAR_H - FOOTER_H - 16)
    self.TabContainer.Paint = function(pnl, w, h)
        -- Rounded content surface under whichever tab is active.
        evolve:ThemedRoundedBox(6, 0, 0, w, h, evolve:GetTheme().panel)
    end

    -- Load tab files. Each tab calls evolve:RegisterTab() which pushes
    -- itself into MENU.Tabs and onto the sidebar.
    local tabs = file.Find("ev_menu/tab_*.lua", "LUA")
    for _, f in ipairs(tabs) do
        include("ev_menu/" .. f)
    end

    self:BuildSidebar()

    self.Panel:MakePopup()
    self.Panel:SetKeyboardInputEnabled(false)

    -- Hide every tab except the one we start on.
    for _, tab in ipairs(self.Tabs) do
        if tab.Panel and IsValid(tab.Panel) then
            tab.Panel:SetVisible(tab == self.ActiveTab)
        end
    end

    timer.Create("EV_MenuThink", 1 / 60, 0, function() MENU:Think() end)
end

function MENU:Destroy()
    if not self.Panel then return end
    self.Panel:Remove()
    self.Panel   = nil
    self.Tabs    = {}
    self.ActiveTab = nil
end

--[[-----------------------------------------------------------------------
    Per-frame layout + slide animation
-------------------------------------------------------------------------]]
function MENU:Think()
    if self.LastRank and LocalPlayer().EV_GetRank
        and self.LastRank ~= LocalPlayer():EV_GetRank() then
        -- Rank changed — tear down the old menu so tabs are re-filtered.
        -- If the menu was visible, bring it back immediately with the new rank
        -- so the player doesn't have to manually reopen it.
        local wasVisible = self.IsVisible
        self:Destroy()
        self.LastRank = LocalPlayer():EV_GetRank()
        if wasVisible then
            self:Show()
        end
        return
    elseif LocalPlayer().EV_GetRank then
        self.LastRank = LocalPlayer():EV_GetRank()
    end

    if not self.Panel then return end

    local dt    = FrameTime() * ANIM_SPEED
    local targetW = self.TargetWidth or (SIDEBAR_W + MIN_CONTENT_W + PANEL_MARGIN * 2)
    local curW  = self.Panel:GetWide()
    local newW  = Lerp(dt, curW, targetW)
    if math.abs(newW - targetW) < 0.5 then newW = targetW end
    self.Panel:SetSize(newW, CONTENT_H)

    -- Resize the content surface to match the active tab's desired width.
    if self.TabContainer and IsValid(self.TabContainer) and self.ActiveTab then
        self.TabContainer:SetSize(
            (self.ActiveTab.Width or MIN_CONTENT_W),
            CONTENT_H - TITLEBAR_H - FOOTER_H - 16
        )
    end

    -- Position the close button relative to the current width.
    if IsValid(self.CloseBtn) then
        self.CloseBtn:SetPos(self.Panel:GetWide() - 32, 9)
    end

    -- Slide animation.
    local newX = Lerp(dt, self.XPos, self.TargetX)
    if math.abs(newX - self.TargetX) < 0.5 then newX = self.TargetX end
    self.XPos = newX
    self.Panel:SetPos(newX, ScrH() / 2 - CONTENT_H / 2)

    if not self.IsVisible and self.XPos <= self.TargetX + 1 then
        self.Panel:SetVisible(false)
    end
end

--[[-----------------------------------------------------------------------
    Show / hide / toggle
-------------------------------------------------------------------------]]
function MENU:Show()
    if LocalPlayer().EV_HasPrivilege
        and not LocalPlayer():EV_HasPrivilege("Menu") then return end
    if not self.Panel then self:Initialize() end

    for _, tab in ipairs(self.Tabs) do
        if tab.Update then tab:Update() end
    end

    self.Panel:SetVisible(true)
    self.Panel:SetKeyboardInputEnabled(false)
    self.Panel:SetMouseInputEnabled(true)

    self.TargetX = 80
    self.IsVisible = true

    input.SetCursorPos(
        80 + self.Panel:GetWide() / 2,
        ScrH() / 2
    )
end

function MENU:Hide()
    if not self.Panel then return end

    -- Walk the entire panel tree and close any open DComboBox dropdowns.
    -- The dropdown (combo.Menu) is reparented to the world panel when it
    -- opens, so it survives independently of the EV menu unless we close it.
    local function closeOpenCombos(pnl)
        if not IsValid(pnl) then return end
        if pnl:GetClassName() == "DComboBox" and IsValid(pnl.Menu) then
            pnl.Menu:Remove()
            pnl.Menu = nil
        end
        for _, child in ipairs(pnl:GetChildren()) do
            closeOpenCombos(child)
        end
    end
    closeOpenCombos(self.Panel)

    self.Panel:SetKeyboardInputEnabled(false)
    self.Panel:SetMouseInputEnabled(false)

    self.TargetX   = -self.Panel:GetWide() - 20
    self.IsVisible = false
end

function MENU:Toggle()
    if self.IsVisible then self:Hide() else self:Show() end
end

--[[-----------------------------------------------------------------------
    Hooks & concommands
-------------------------------------------------------------------------]]
hook.Add("EV_RankPrivilegeChange", "EV_MenuPrivUpdate", function(rank, privilege)
    if LocalPlayer().EV_GetRank and rank == LocalPlayer():EV_GetRank()
        and table.HasValue(MENU.Privileges, privilege) then
        MENU:Destroy()
    end
end)

-- Rebuild when the theme changes so every sub-panel repaints fresh.
hook.Add("EV_ThemeChanged", "EV_MenuRepaint", function()
    if MENU.Panel and IsValid(MENU.Panel) then
        MENU.Panel:InvalidateLayout(true)
        for _, tab in ipairs(MENU.Tabs) do
            if tab.Panel and IsValid(tab.Panel) then
                tab.Panel:InvalidateLayout(true)
            end
        end
    end
end)

concommand.Add("+ev_menu", function() MENU:Show() end)
concommand.Add("-ev_menu", function() MENU:Hide() end)
concommand.Add("ev_menu",  function() MENU:Toggle() end)
