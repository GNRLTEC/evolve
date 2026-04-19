--[[-------------------------------------------------------------------------
    Evolve Scoreboard (modernized)

    Replaces the classic textured scoreboard with a themed, vector-drawn
    panel that reads from evolve:GetTheme(). Players are grouped by rank
    and each row shows avatar, name, playtime, ping, kills, deaths and
    prop count. The whole scoreboard is one HUDDrawScoreBoard pass — no
    VGUI panel is created for it, keeping it friction-free in all
    gamemodes.
---------------------------------------------------------------------------]]

-- Keep the legacy texture files bundled so players who still have the old
-- version of the scoreboard installed aren't missing textures. The new
-- scoreboard doesn't draw them.
resource.AddFile("materials/gui/scoreboard_header.vtf")
resource.AddFile("materials/gui/scoreboard_header.vmt")
resource.AddFile("materials/gui/scoreboard_middle.vtf")
resource.AddFile("materials/gui/scoreboard_middle.vmt")
resource.AddFile("materials/gui/scoreboard_bottom.vtf")
resource.AddFile("materials/gui/scoreboard_bottom.vmt")
resource.AddFile("materials/gui/scoreboard_ping.vtf")
resource.AddFile("materials/gui/scoreboard_ping.vmt")
resource.AddFile("materials/gui/scoreboard_frags.vtf")
resource.AddFile("materials/gui/scoreboard_frags.vmt")
resource.AddFile("materials/gui/scoreboard_skull.vtf")
resource.AddFile("materials/gui/scoreboard_skull.vmt")
resource.AddFile("materials/gui/scoreboard_playtime.vtf")
resource.AddFile("materials/gui/scoreboard_playtime.vmt")
resource.AddFile("materials/gui/scoreboard_propbrick.vtf")
resource.AddFile("materials/gui/scoreboard_propbrick.vmt")

local PLUGIN = {}
PLUGIN.Title       = "Scoreboard"
PLUGIN.Description = "Modern themed scoreboard for Evolve."
PLUGIN.Author      = "Evolve"

if CLIENT then
    PLUGIN.Width      = 720
    PLUGIN.RowHeight  = 26
    PLUGIN.HeaderH    = 78
    PLUGIN.GroupHead  = 28

    PLUGIN.Avatars    = {}  -- SteamID -> AvatarImage VGUI (reused across frames)
end

if SERVER then
    -- Preserve the legacy prop count hook; the new UI uses it.
    timer.Simple(1, function()
        PLUGIN.GetCount = _R.Player.GetCount
        function _R.Player:GetCount(limit, minus)
            if limit == "props" then
                timer.Simple(.1, function() PLUGIN.GetCount(self, limit, 0) end)
            end
            return PLUGIN.GetCount(self, limit, minus)
        end
    end)
end

--[[-----------------------------------------------------------------------
    Show / Hide
-------------------------------------------------------------------------]]
function PLUGIN:ScoreboardShow()
    if GAMEMODE.IsSandboxDerived and evolve.installed then
        self.DrawScoreboard = true
        return true
    end
end

function PLUGIN:ScoreboardHide()
    if self.DrawScoreboard then
        self.DrawScoreboard = false

        -- Hide every cached avatar so they don't draw over the world after
        -- the scoreboard disappears.
        for _, av in pairs(self.Avatars or {}) do
            if IsValid(av) then av:SetVisible(false) end
        end
        return true
    end
end

if not CLIENT then
    evolve:RegisterPlugin(PLUGIN)
    return
end

--[[-----------------------------------------------------------------------
    Helpers
-------------------------------------------------------------------------]]
function PLUGIN:FormatTime(raw)
    raw = raw or 0
    if raw < 60 then
        return math.floor(raw) .. "s"
    elseif raw < 3600 then
        return math.floor(raw / 60) .. "m"
    elseif raw < 86400 then
        return math.floor(raw / 3600) .. "h"
    else
        return math.floor(raw / 86400) .. "d"
    end
end

function PLUGIN:EnsureAvatar(ply)
    local key = ply:SteamID64() or tostring(ply)
    local av  = self.Avatars[key]
    if not IsValid(av) then
        av = vgui.Create("AvatarImage")
        av:SetSize(20, 20)
        av:SetPlayer(ply, 32)
        av:SetMouseInputEnabled(false)
        av:SetKeyboardInputEnabled(false)
        self.Avatars[key] = av
    end
    return av
end

function PLUGIN:GatherPlayers()
    local info = {}
    for _, v in ipairs(player.GetAll()) do
        local playTime = 0
        if v.GetNWInt then
            playTime = (evolve:Time() or os.time())
                - v:GetNWInt("EV_JoinTime", 0) + v:GetNWInt("EV_PlayTime", 0)
        end
        table.insert(info, {
            Ply      = v,
            Nick     = v:Nick(),
            Rank     = v.EV_GetRank and v:EV_GetRank() or "guest",
            Frags    = v:Frags(),
            Deaths   = v:Deaths(),
            Ping     = v:Ping(),
            PlayTime = playTime,
            Props    = v.GetNetworkedInt and v:GetNetworkedInt("Count.props") or 0,
        })
    end
    table.SortByMember(info, "Frags", false)
    return info
end

--[[-----------------------------------------------------------------------
    Draw
-------------------------------------------------------------------------]]
function PLUGIN:DrawHeader(x, y, w)
    local t = evolve:GetTheme()

    -- Title surface
    draw.RoundedBoxEx(8, x, y, w, self.HeaderH, t.bg_alt, true, true, false, false)

    -- Accent underline
    surface.SetDrawColor(t.accent.r, t.accent.g, t.accent.b, 255)
    surface.DrawRect(x, y + self.HeaderH - 2, w, 2)

    draw.SimpleText(GetHostName(), "EV_ScoreBig",
        x + 18, y + 16, t.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    local info = string.format(
        "%s  |  %s  |  %d / %d players",
        GAMEMODE.Name or "Garry's Mod",
        game.GetMap(),
        #player.GetAll(),
        game.MaxPlayers()
    )
    draw.SimpleText(info, "EV_Text",
        x + 18, y + 50, t.text_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    draw.SimpleText(os.date("%H:%M"), "EV_Header",
        x + w - 18, y + self.HeaderH / 2, t.accent,
        TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
end

function PLUGIN:DrawColumnHeaders(x, y, w)
    local t = evolve:GetTheme()
    surface.SetDrawColor(t.panel_alt.r, t.panel_alt.g, t.panel_alt.b, t.panel_alt.a)
    surface.DrawRect(x, y, w, 22)

    local function col(text, rx)
        draw.SimpleText(text, "EV_Small", rx, y + 11,
            t.text_dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    draw.SimpleText("Player", "EV_SmallBold",
        x + 44, y + 11, t.text_dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- Right-aligned columns
    col("Props",    x + w - 250)
    col("Kills",    x + w - 195)
    col("Deaths",   x + w - 140)
    col("Playtime", x + w -  80)
    col("Ping",     x + w -  18)
end

function PLUGIN:DrawGroupHeader(x, y, w, title, rankColor)
    local t = evolve:GetTheme()

    surface.SetDrawColor(t.bg_alt.r, t.bg_alt.g, t.bg_alt.b, 255)
    surface.DrawRect(x, y, w, self.GroupHead)

    -- Colored rank bar
    surface.SetDrawColor(rankColor.r, rankColor.g, rankColor.b, 255)
    surface.DrawRect(x, y, 4, self.GroupHead)

    draw.SimpleText(title, "EV_ScoreHeader",
        x + 14, y + self.GroupHead / 2, t.text,
        TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

function PLUGIN:DrawRow(x, y, w, pl, zebra)
    local t    = evolve:GetTheme()
    local rank = evolve.ranks[pl.Rank]
    local rcol = (rank and rank.Color) or t.accent

    -- Zebra stripe
    if zebra then
        surface.SetDrawColor(t.panel_alt.r, t.panel_alt.g, t.panel_alt.b, 80)
        surface.DrawRect(x, y, w, self.RowHeight)
    end

    -- Hover highlight when mouse is over the row (scoreboard is shown under
    -- the gamemode's input so we use gui.MousePos). Nice-to-have polish.
    local mx, my = gui.MousePos()
    if mx >= x and mx <= x + w and my >= y and my <= y + self.RowHeight
        and input.IsMouseDown(0) == false then
        local a = t.accent_glow
        surface.SetDrawColor(a.r, a.g, a.b, a.a)
        surface.DrawRect(x, y, w, self.RowHeight)
    end

    -- Avatar
    if IsValid(pl.Ply) then
        local av = self:EnsureAvatar(pl.Ply)
        av:SetPos(x + 12, y + 3)
        av:SetVisible(true)
        av:PaintManual()
    end

    -- Name
    draw.SimpleText(pl.Nick, "EV_Text",
        x + 44, y + self.RowHeight / 2,
        t.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    -- Right-aligned stats
    local function col(text, rx)
        draw.SimpleText(tostring(text), "EV_Text",
            rx, y + self.RowHeight / 2,
            t.text_dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    col(pl.Props,                     x + w - 250)
    col(pl.Frags,                     x + w - 195)
    col(pl.Deaths,                    x + w - 140)
    col(self:FormatTime(pl.PlayTime), x + w -  80)

    -- Ping gets color-coded (green/yellow/red) for quick read.
    local pingCol = t.success
    if pl.Ping > 120 then pingCol = t.warning end
    if pl.Ping > 250 then pingCol = t.danger  end
    draw.SimpleText(pl.Ping, "EV_Text",
        x + w - 18, y + self.RowHeight / 2,
        pingCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

    -- Rank dot on the right edge of the name
    surface.SetDrawColor(rcol.r, rcol.g, rcol.b, 255)
    draw.RoundedBox(2, x + 36, y + self.RowHeight / 2 - 2, 4, 4, rcol)
end

function PLUGIN:DrawGroup(x, y, w, title, rankColor, players)
    if #players == 0 then return y end

    self:DrawGroupHeader(x, y, w, title, rankColor)
    y = y + self.GroupHead

    local zebra = false
    for _, pl in ipairs(players) do
        self:DrawRow(x, y, w, pl, zebra)
        zebra = not zebra
        y = y + self.RowHeight
    end

    return y + 6
end

function PLUGIN:HUDDrawScoreBoard()
    if not self.DrawScoreboard then return end

    local t       = evolve:GetTheme()
    local info    = self:GatherPlayers()

    -- Sort ranks by immunity descending so owners/admins appear first.
    local ranks = {}
    for id, r in pairs(evolve.ranks or {}) do
        table.insert(ranks, {
            ID       = id,
            Title    = r.Title or id,
            Immunity = r.Immunity or 0,
            Color    = r.Color or t.accent,
        })
    end
    table.sort(ranks, function(a, b) return a.Immunity > b.Immunity end)

    -- Measure total height first so we can vertically center.
    local totalRows = 0
    for _, rank in ipairs(ranks) do
        local count = 0
        for _, pl in ipairs(info) do
            if pl.Rank == rank.ID then count = count + 1 end
        end
        if count > 0 then
            totalRows = totalRows + 1          -- group header
            totalRows = totalRows + count       -- rows
        end
    end

    local height = self.HeaderH + 22 + 8
        + totalRows * self.RowHeight
        + self.GroupHead * 3   -- approximate group header overhead
        + 12

    -- Minimum sensible size.
    if height < 220 then height = 220 end

    local x = ScrW() / 2 - self.Width / 2
    local y = ScrH() / 2 - height / 2

    -- Shadow
    local sh = t.shadow
    surface.SetDrawColor(sh.r, sh.g, sh.b, sh.a)
    draw.RoundedBox(10, x + 4, y + 6, self.Width, height, Color(sh.r, sh.g, sh.b, sh.a))

    -- Background
    draw.RoundedBox(8, x, y, self.Width, height, t.bg)

    -- Header
    self:DrawHeader(x, y, self.Width)

    -- Column header strip
    self:DrawColumnHeaders(x, y + self.HeaderH, self.Width)

    -- Body
    local cy = y + self.HeaderH + 22 + 4
    for _, rank in ipairs(ranks) do
        local group = {}
        for _, pl in ipairs(info) do
            if pl.Rank == rank.ID then table.insert(group, pl) end
        end
        cy = self:DrawGroup(x, cy, self.Width,
            rank.Title, rank.Color, group)
    end

    -- Outer border
    surface.SetDrawColor(t.border.r, t.border.g, t.border.b, t.border.a)
    surface.DrawOutlinedRect(x, y, self.Width, height)
end

evolve:RegisterPlugin(PLUGIN)
