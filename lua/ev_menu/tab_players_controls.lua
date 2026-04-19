--[[-------------------------------------------------------------------------
    Shared VGUI controls used by the admin menu tabs.

    Each of these controls reads from evolve:GetTheme() every frame so the
    UI hot-swaps cleanly when the player changes themes. Public API is
    kept backward-compatible with the original Evolve controls so the rest
    of the tab_* files continue to work without modification.
---------------------------------------------------------------------------]]

if not CLIENT then return end

local function theme()
    return evolve:GetTheme()
end

--[[-----------------------------------------------------------------------
    EvolveButton
    Themed button with smooth hover + optional highlighted-color override
    for legacy callers (SetHighlightedColor/SetNotHighlightedColor used to
    take a single grayscale value; we accept either a number or a Color
    and blend toward the active theme accent when a number is provided).
-------------------------------------------------------------------------]]
local PANEL = {}

function PANEL:Init()
    self:SetText("")
    self:SetCursor("hand")
    self.HoverFrac = 0
    self.Text = ""
end

function PANEL:SetButtonText(txt)
    self.Text = txt or ""
end

function PANEL:GetButtonText()
    return self.Text or ""
end

function PANEL:SetHighlightedColor(c)
    self.HighlightedColor = c
end

function PANEL:SetNotHighlightedColor(c)
    self.NotHighlightedColor = c
end

local function coerceColor(c, fallback)
    if type(c) == "table" and c.r then return c end
    return fallback
end

function PANEL:Paint(w, h)
    local t = theme()
    self.HoverFrac = Lerp(FrameTime() * 10, self.HoverFrac, self:IsHovered() and 1 or 0)

    local base  = coerceColor(self.NotHighlightedColor, t.panel_alt)
    local hover = coerceColor(self.HighlightedColor,    t.hover)

    local r = Lerp(self.HoverFrac, base.r, hover.r)
    local g = Lerp(self.HoverFrac, base.g, hover.g)
    local b = Lerp(self.HoverFrac, base.b, hover.b)
    draw.RoundedBox(4, 0, 0, w, h, Color(r, g, b, 255))

    -- Accent edge that appears on hover.
    if self.HoverFrac > 0.01 then
        local a = t.accent
        surface.SetDrawColor(a.r, a.g, a.b, 255 * self.HoverFrac)
        surface.DrawRect(0, h - 2, w, 2)
    end

    draw.SimpleText(self.Text or "", "EV_Text",
        w / 2, h / 2, t.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

derma.DefineControl("EvolveButton", "Themed Evolve button", PANEL, "DButton")

--[[-----------------------------------------------------------------------
    EvolvePlayerList
    DListView with avatar + themed rows. Kept on top of DListView so that
    callers can still use AddColumn / AddLine / GetLines / GetSelected.
-------------------------------------------------------------------------]]
PANEL = {}

local iconUser = Material("icon16/user.png")

function PANEL:Init()
    -- Hide the gray default border.
    self:SetHideHeaders(false)
    self:SetMultiSelect(false)
    self.Rows = {}
end

function PANEL:Paint(w, h)
    local t = theme()
    draw.RoundedBox(4, 0, 0, w, h, t.panel_alt)
end

function PANEL:PaintOver(w, h)
    local t = theme()
    surface.SetDrawColor(t.border_soft.r, t.border_soft.g, t.border_soft.b, t.border_soft.a)
    surface.DrawOutlinedRect(0, 0, w, h)
end

function PANEL:AddPlayer(ply)
    local item = self:AddLine("")
    item.Player = ply

    item.Avatar = vgui.Create("AvatarImage", item)
    item.Avatar:SetPlayer(ply, 32)
    item.Avatar:SetPos(6, 3)
    item.Avatar:SetSize(18, 18)

    item.Paint = function(line, w, h)
        local t = theme()
        local bg = line:IsSelected() and t.hover or (line:IsHovered() and t.panel_alt or t.panel)
        surface.SetDrawColor(bg.r, bg.g, bg.b, bg.a)
        surface.DrawRect(0, 0, w, h)

        if line:IsSelected() then
            local a = t.accent
            surface.SetDrawColor(a.r, a.g, a.b, a.a)
            surface.DrawRect(0, 0, 3, h)
        end
    end

    item.PaintOver = function(line, w, h)
        if not IsValid(line.Player) then
            if #self:GetSelected() == 0 then self:SelectFirstItem() end
            self:RemoveLine(line:GetID())
            return
        end

        local t = theme()
        local rank = evolve.ranks and evolve.ranks[ply:EV_GetRank()]
        local rankCol = (rank and rank.Color) or t.accent

        -- Rank icon on the right edge.
        if rank and rank.IconTexture then
            surface.SetMaterial(rank.IconTexture)
        else
            surface.SetMaterial(iconUser)
        end
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(w - 22, h / 2 - 8, 16, 16)

        draw.SimpleText(ply:Nick() or "", "EV_Text",
            30, h / 2, t.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Colored rank dot
        surface.SetDrawColor(rankCol.r, rankCol.g, rankCol.b, 255)
        draw.RoundedBox(2, w - 38, h / 2 - 3, 6, 6, rankCol)
    end

    item.OnMousePressedOld = item.OnMousePressed
    item.OnMousePressed = function(self_, button)
        if button == MOUSE_RIGHT then
            local menu = DermaMenu()
            menu:AddOption("Copy SteamID", function() SetClipboardText(ply:SteamID()) end)
            menu:AddOption("Copy Nickname", function() SetClipboardText(ply:Nick()) end)
            menu:Open()
        else
            return item.OnMousePressedOld(self_, button)
        end
    end

    return item
end

function PANEL:SelectFirstItem()
    local first = self:GetLines()[1]
    if first then self:SelectItem(first) end
end

function PANEL:GetSelectedPlayers()
    local plys = {}
    for _, item in pairs(self:GetSelected()) do
        if IsValid(item.Player) then
            table.insert(plys, item.Player:Nick())
        end
    end
    return plys
end

function PANEL:Populate()
    local selectedPlayers = {}
    if #self:GetSelected() > 0 then
        for _, item in ipairs(self:GetSelected()) do
            if IsValid(item.Player) then
                table.insert(selectedPlayers, item.Player)
            end
        end
    end

    self:Clear()

    local players = {}
    for _, pl in ipairs(player.GetAll()) do
        table.insert(players, {Name = pl:Nick(), Ply = pl})
    end
    table.SortByMember(players, "Name", function(a, b) return a > b end)

    for _, pl in ipairs(players) do
        local item = self:AddPlayer(pl.Ply)

        item.DoClick = function()
            if item.LastClick and os.clock() < item.LastClick + 0.3
                and item.LastX == gui.MouseX() and item.LastY == gui.MouseY() then
                self:MoveTo(-self.Parent.Width, 0, 0.1)
                self.Parent.PluginList:MoveTo(0, 0, 0.1)
                self.Parent.ButPlugins:SetButtonText("Players")
            end
            item.LastClick = os.clock()
            item.LastX, item.LastY = gui.MousePos()
        end

        if table.HasValue(selectedPlayers, pl.Ply) then
            self:SelectItem(item)
        end
    end

    if #self:GetSelected() == 0 then
        self:SelectFirstItem()
    end
end

derma.DefineControl("EvolvePlayerList", "Themed player list", PANEL, "DListView")

--[[-----------------------------------------------------------------------
    ToolMenuButton
    The per-plugin clickable row shown inside the plugin categories panel.
    Themed with hover + selected states that read from the current theme.
-------------------------------------------------------------------------]]
local ToolButtons = {}
PANEL = {}

AccessorFunc(PANEL, "m_bAlt",      "Alt")
AccessorFunc(PANEL, "m_bSelected", "Selected")

function PANEL:Init()
    self:SetContentAlignment(4)
    self:SetTextInset(10, 0)
    self:SetTall(22)
    self:SetFont("EV_Text")
    self.HoverFrac = 0
    table.insert(ToolButtons, self)
end

function PANEL:RemoveEx()
    for k, v in pairs(ToolButtons) do
        if v == self then
            table.remove(ToolButtons, k)
            break
        end
    end
    self:Remove()
end

function PANEL:Paint(w, h)
    local t = theme()
    self.HoverFrac = Lerp(FrameTime() * 10, self.HoverFrac, self.m_bSelected and 1 or 0)

    -- Alternating row bg
    if self.m_bAlt then
        surface.SetDrawColor(t.panel_alt.r, t.panel_alt.g, t.panel_alt.b, 100)
        surface.DrawRect(0, 0, w, h)
    end

    if self.HoverFrac > 0.01 then
        local a = t.accent
        surface.SetDrawColor(a.r, a.g, a.b, 255 * self.HoverFrac)
        surface.DrawRect(0, 0, 3, h)

        surface.SetDrawColor(a.r, a.g, a.b, 30 * self.HoverFrac)
        surface.DrawRect(3, 0, w - 3, h)
    end

    self:SetTextColor(t.text)
end

function PANEL:UpdateColours(skin)
    self:SetTextStyleColor(theme().text)
end

function PANEL:OnMousePressed(mcode)
    if mcode == MOUSE_LEFT then self:OnSelect() end
end

function PANEL:OnCursorMoved(x, y)
    for _, b in pairs(ToolButtons) do b.m_bSelected = false end
    self.m_bSelected = true
end

function PANEL:OnSelect() end

function PANEL:PerformLayout()
    if self.Checkbox then
        self.Checkbox:AlignRight(4)
        self.Checkbox:CenterVertical()
    end
end

function PANEL:AddCheckBox(strConVar)
    if not self.Checkbox then
        self.Checkbox = vgui.Create("DCheckBox", self)
    end
    self.Checkbox:SetConVar(strConVar)
    self:InvalidateLayout()
end

vgui.Register("ToolMenuButton", PANEL, "DButton")

--[[-----------------------------------------------------------------------
    EvolvePluginList
    Collapsible category list of admin plugins. Painted with themed
    rounded categories.
-------------------------------------------------------------------------]]
PANEL = {}
PANEL.Buttons = {}

function PANEL:Paint(w, h)
    draw.RoundedBox(4, 0, 0, w, h, theme().panel_alt)
end

function PANEL:Reset()
    if not self.Submenu or not self.Submenu[1] then return end
    for _, b in pairs(self.Submenu[1].Buttons) do
        self.Submenu[1].Container:RemoveItem(b, true)
        b:RemoveEx()
    end
    self.Submenu[1].Buttons = {}

    self.Submenu[1]:SetPos(self:GetWide(), 0)
    self.PluginContainer:SetPos(1, 1)
end

function PANEL:PopulateSubmenu(plugin, submenu, title)
    self.Submenu[1]:SetExpanded(false)
    self.Submenu[1]:Toggle()
    self.Submenu[1]:SetLabel(title or plugin:Menu())

    local alt = true
    for _, value in pairs(submenu) do
        if type(value) ~= "table" then
            value = {value, value}
        elseif #value == 1 then
            value = {value[1], value[1]}
        end

        local button = vgui.Create("ToolMenuButton")
        button:SetText(value[1])
        button.m_bAlt = alt
        alt = not alt

        button.OnSelect = function()
            RunConsoleCommand("ev", plugin.ChatCommand,
                unpack(self:GetParent().Tab.PlayerList:GetSelectedPlayers()),
                value[2])

            self:GetParent().Tab.PlayerList:MoveTo(0, 0, 0.2)
            self:GetParent().Tab.PluginList:MoveTo(self:GetParent():GetWide(), 0, 0.2)
            self:GetParent().Tab.ButPlugins:SetButtonText("Plugins")
            self:Reset()
        end

        table.insert(self.Submenu[1].Buttons, button)
        self.Submenu[1].Container:AddItem(button)
    end
end

function PANEL:OpenPluginMenu(plugin)
    if not plugin then return end
    local title, category, submenu, submenutitle = plugin:Menu()

    if submenu then
        self:PopulateSubmenu(plugin, submenu, submenutitle)
        self.PluginContainer:MoveTo(-self:GetWide(), 0, 0.2)
        self.Submenu[1]:MoveTo(1, 1, 0.2)
    else
        RunConsoleCommand("ev", plugin.ChatCommand,
            unpack(self:GetParent().Tab.PlayerList:GetSelectedPlayers()))

        self:GetParent().Tab.PlayerList:MoveTo(0, 0, 0.2)
        self:GetParent().Tab.PluginList:MoveTo(self:GetParent():GetWide(), 0, 0.2)
        self:GetParent().Tab.ButPlugins:SetButtonText("Plugins")
    end
end

function PANEL:AddButton(plugin, cat, highlight)
    if not plugin.Menu then return highlight end

    local button = vgui.Create("ToolMenuButton")
    button.title, button.category, button.submenu, button.submenutitle = plugin:Menu()

    if button.category ~= cat then
        button:RemoveEx()
        return highlight
    end

    button.plugin  = plugin
    button.m_bAlt  = highlight
    button:SetText(button.title)

    button.OnSelect = function()
        self:OpenPluginMenu(plugin)
    end

    self.Categories[button.category].Container:AddItem(button)
    table.insert(self.Buttons, button)

    return not highlight
end

function PANEL:CreateSubmenu()
    self.Submenu = {}
    self.Submenu[1] = vgui.Create("DCollapsibleCategory", self)
    self.Submenu[1]:SetPos(self:GetWide(), 1)
    self.Submenu[1]:SetSize(self:GetWide() - 2, 22)
    self.Submenu[1]:SetExpanded(false)
    self.Submenu[1]:SetAnimTime(0.0)
    self.Submenu[1].Buttons = {}

    self.Submenu[1].Container = vgui.Create("DPanelList", self.Submenu[1])
    self.Submenu[1].Container:SetAutoSize(true)
    self.Submenu[1].Container:SetSpacing(0)
    self.Submenu[1].Container:EnableHorizontal(false)
    self.Submenu[1].Container:EnableVerticalScrollbar(true)
    self.Submenu[1]:SetContents(self.Submenu[1].Container)
end

function PANEL:CreatePluginsPage()
    self.PluginContainer = vgui.Create("DPanelList", self)
    self.PluginContainer:SetPos(1, 1)
    self.PluginContainer:SetSize(self:GetWide() - 2, self:GetTall() - 2)
    self.PluginContainer:SetPadding(2)
    self.PluginContainer:SetSpacing(3)
    self.PluginContainer:EnableVerticalScrollbar(true)
    self.PluginContainer.Paint = function() end

    -- Style the outer scrollbar to match the theme.
    local outerVBar = self.PluginContainer.VBar
    if outerVBar then
        outerVBar:SetWide(5)
        outerVBar.Paint = function(p, w, h)
            draw.RoundedBox(2, 0, 0, w, h, theme().panel_alt)
        end
        if outerVBar.btnUp   then outerVBar.btnUp.Paint   = function() end end
        if outerVBar.btnDown then outerVBar.btnDown.Paint = function() end end
        if outerVBar.btnGrip then
            outerVBar.btnGrip.Paint = function(p, w, h)
                draw.RoundedBox(2, 1, 2, w - 2, h - 4, theme().border)
            end
        end
    end

    local catNames = {"Administration", "Actions", "Punishment", "Teleportation"}
    self.Categories = {}

    for i = 1, 4 do
        self.Categories[i] = vgui.Create("DCollapsibleCategory", self.PluginContainer)
        self.Categories[i]:SetTall(22)
        self.Categories[i]:SetExpanded(0)
        self.Categories[i]:SetLabel(catNames[i])

        -- Clear the native label text so the C++ Label render path draws nothing.
        -- Our custom Header.Paint below is the sole source of text — no double-render blur.
        if self.Categories[i].Header then
            self.Categories[i].Header:SetText("")
        end

        -- Paint the header with themed colors.
        if self.Categories[i].Header then
            self.Categories[i].Header.Paint = function(hdr, w, h)
                local t   = theme()
                local exp = self.Categories[i]:GetExpanded()
                local col = exp and t.accent_soft or t.panel_alt
                draw.RoundedBox(3, 0, 0, w, h, col)
                draw.SimpleText(catNames[i], "EV_SmallBold",
                    10, h / 2, exp and color_white or t.text,
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(exp and "-" or "+", "EV_TextBold",
                    w - 12, h / 2, exp and color_white or t.text_dim,
                    TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end

        -- Simple independent toggle — each category can be open or closed freely.
        self.Categories[i].Header.OnMousePressed = function()
            self.Categories[i]:Toggle()
        end

        self.Categories[i].Container = vgui.Create("DPanelList", self.Categories[i])
        self.Categories[i].Container:SetAutoSize(true)
        self.Categories[i].Container:SetSpacing(0)
        self.Categories[i].Container:EnableHorizontal(false)
        self.Categories[i].Container:EnableVerticalScrollbar(true)
        self.Categories[i].Container.Paint = function(pnl, w, h)
            surface.SetDrawColor(theme().bg_alt.r, theme().bg_alt.g, theme().bg_alt.b, 160)
            surface.DrawRect(0, 0, w, h)
        end
        self.Categories[i]:SetContents(self.Categories[i].Container)

        local highlight = true
        for _, v in pairs(evolve.plugins) do
            highlight = self:AddButton(v, i, highlight)
        end

        self.PluginContainer:AddItem(self.Categories[i])
    end

    self:CreateSubmenu()
    -- Open Administration by default.
    self.Categories[2]:Toggle()
end

derma.DefineControl("EvolvePluginList", "Themed plugin list", PANEL, "DPanelList")
