# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Evolve is a Garry's Mod server administration addon written entirely in Lua (GMod's Lua dialect, which allows both `--` and `//` comments and `!=` in addition to `~=`). It is loaded by the GMod engine as an `addons/` folder; there is no build step, no package manager, and no test suite. Iteration happens by editing `.lua` files and reloading the map (or using the in-game `ev reload`/`ev reloadplugin` commands exposed by `sh_reload.lua` / `sh_reloadplugin.lua`).

Canonical metadata lives in `addon.txt` (name, version). The addon expects to sit at `garrysmod/addons/evolve/` on a GMod server or listen-server client.

## Setup

The repository depends on a git submodule: `lua/includes/ev_von` (Vercas' vON serialization library, used for persisting data files). It MUST be present for the addon to load — `lua/autorun/server/ev_autorun.lua` `include`s `includes/ev_von/von.lua` unconditionally. After cloning:

```
git submodule update --init --recursive
```

If a contributor reports "Evolve not working at all", the vON submodule is the first thing to check (see README Troubleshooting).

SourceBans integration is optional and gated by a `SourceBansEnabled` flag at the top of `lua/ev_sourcebans.lua`. It is off by default; when on, it also requires the `gmsv_mysqloo` binary module and a configured MySQL database.

## Entry points and load order

Everything starts from the two autorun files, which GMod loads automatically:

- `lua/autorun/server/ev_autorun.lua` — creates the global `evolve` table, `AddCSLuaFile`s every client-visible file, includes the vON library (sandboxed via a local backup of `von` so it does not leak into the global namespace — `evolve.von` is the addon-local handle), then includes `ev_framework.lua`, the theme, `ev_sv_init.lua`, the menu server code, and finally `ev_sourcebans.lua`.
- `lua/autorun/client/ev_autorun.lua` — mirror of the above for the client. The theme file is included before anything that draws.

Plugin loading is explicit: `ev_sv_init.lua` and `ev_cl_init.lua` both call `evolve:LoadPlugins()`, which scans `lua/ev_plugins/*.lua` and includes each file based on its filename prefix (see below). The client's `LoadPlugins()` only runs after the server sends the `EV_Init` net message on first spawn.

## File naming convention (critical)

Files under `lua/ev_plugins/` are dispatched by their two-letter prefix. `evolve:LoadPlugins()` inspects the substring before the first `_`:

- `sh_*.lua` — shared; included on both realms. Server additionally calls `AddCSLuaFile`.
- `sv_*.lua` — serverside only; the client never sees it.
- `cl_*.lua` — clientside only; the server `AddCSLuaFile`s it but does not `include` it.

Breaking this convention will silently cause files to load on the wrong realm or not at all. The same convention applies in `lua/ev_theme/` and `lua/ev_menu/`, where it is enforced by the explicit `include`/`AddCSLuaFile` calls in the autorun files.

## Plugin architecture

Every file in `lua/ev_plugins/` follows the same skeleton:

```lua
local PLUGIN = {}
PLUGIN.Title = "Slap"
PLUGIN.ChatCommand = "slap"      -- string or list of aliases
PLUGIN.Privileges = { "Slap" }   -- auto-registered into evolve.privileges

function PLUGIN:Call(ply, args) ... end   -- invoked by chat/console command
function PLUGIN:Menu(arg, players) ... end -- optional right-click menu entry

evolve:RegisterPlugin(PLUGIN)
```

`evolve:RegisterPlugin` puts the plugin in `evolve.stagedPlugins`. After all files load, `evolve:ResolveDependencies()` promotes staged plugins into `evolve.plugins` in dependency order (a plugin may declare `PLUGIN.Dependencies = { "OtherTitle" }`). Unmet dependencies produce a red notification and the plugin is dropped.

Plugins can also define methods named after GMod hooks (`PlayerSay`, `PlayerInitialSpawn`, etc.). The framework monkey-patches `hook.Call` in `ev_framework.lua` to iterate every registered plugin — and on the client, every registered menu tab — and invoke matching methods via `pcall`. A plugin hook that returns a non-nil first value short-circuits GMod's own hook dispatch, so be deliberate about return values. Errors are caught and printed as red chat notifications rather than propagated.

Two meta-plugins route user input into `PLUGIN:Call`:

- `sv_chatcommands.lua` — intercepts `PlayerSay`, detects the `!`/`@`/`/` prefix (`/` only in Sandbox), and dispatches. `@` sets `evolve.SilentNotify` so actions do not broadcast to everyone. Also does Levenshtein fuzzy-matching to suggest the closest command when the user mistypes.
- `sv_consolecommands.lua` — registers the `ev` and `evs` (silent) concommands.

## Core subsystems (all in `lua/ev_framework.lua`)

This one file is the entire framework. Read it end-to-end before making non-trivial framework changes. Sections, in order:

1. **Constants, colors, global tables** — `evolve.ranks`, `evolve.privileges`, `evolve.bans`, `evolve.plugins`, etc. `evolve.version` is the wire-protocol version (currently 179); bump it if you change any net message layout.
2. **Net strings** — all `util.AddNetworkString` calls live in one `if SERVER` block. Any new net message must be registered here.
3. **`evolve:Notify`** — the universal "tell the player something" function; accepts alternating strings and `Color` tables, writes them over the `EV_Notification` net message, and falls back to server console log.
4. **Plugin management** — described above.
5. **Player collections** — `evolve:FindPlayer(name, def, nonum, noimmunity)` resolves a user-supplied target string. It supports `*` (everyone), `@` (admins), `!@` (non-admins), `STEAM_x:y:z`, quoted exact nicks, and case-insensitive substring match. By default it filters to players the caller has equal-or-better immunity over; pass `noimmunity=true` to bypass.
6. **Ranks and privileges** — ranks live in `evolve.ranks` keyed by lowercase id. Each has `Title`, `Icon`, `UserGroup`, `Immunity`, `Color`, `Privileges[]`. Player methods `EV_GetRank`, `EV_HasPrivilege`, `EV_BetterThan`, `EV_BetterThanOrEqual` are added to `_R.Player`. Entity counterparts return permissive defaults so "Console" (a NULL entity) passes every check. The `owner` rank bypasses all privilege checks in `EV_HasPrivilege` — do not change this without also auditing every place that calls it.
7. **Player info persistence** — `evolve.PlayerInfo` is keyed by `UniqueID` and serialized via vON to `data/evolve/playerinfo.txt`. `GetProperty`/`SetProperty` on `_R.Player`, plus non-method variants keyed by uniqueid for offline players. `CommitProperties` writes to disk and auto-prunes guests when the table exceeds 800 entries.
8. **Entity ownership** — hooks on `PlayerSpawned*` tag each entity with `ent.EV_Owner = ply:UniqueID()`. `_R.Player.AddCount` and `cleanup.Add` are also wrapped.
9. **Rank transfer over net** — `EV_Rank`, `EV_RankPrivileges`, `EV_Privilege`, `EV_RemoveRank`, `EV_RenameRank`, `EV_RankPrivilege`, `EV_RankPrivilegeAll`. Privileges are sent by integer id into the `evolve.privileges` array; the array order must be identical on both realms, which is why the server sorts it on registration.
10. **Banning** — `evolve:Ban(uid, length, reason, adminuid)` / `evolve:UnBan` / `evolve:IsBanned`. Delegates to SourceBans if present, otherwise falls back to `banid`/`addip` console commands and a direct `Kick`. Ban entries are replicated to clients with the "Ban menu" privilege via `EV_BanEntry`.
11. **Global vars** — `evolve:SetGlobalVar` / `GetGlobalVar` persisted to `data/evolve/globalvars.txt`.
12. **Logging** — `evolve:Log(str)` appends to `data/ev_logs/<date>.txt`, rotating at 200 KB. `evolve:PlayerLogStr(ply)` is the standard format (`Nick [STEAM_ID|IP]`). Several `hook.Add`s at the bottom of the file log connects/disconnects/deaths/chat automatically.

## Default ranks

`lua/ev_defaultranks.lua` seeds `evolve.ranks` the first time the server runs (if `data/evolve/userranks.txt` does not exist). The five defaults are `guest`, `respected`, `admin`, `superadmin`, `owner`. `owner` is `ReadOnly` and has an empty `Privileges` table — framework code relies on that table existing (even empty) so iteration never errors; see the comment above `evolve.ranks.owner.Privileges = {}`.

## Menu system

`lua/ev_menu/cl_menu.lua` is the clientside menu framework (modernized redesign — sidebar nav, themed panels, Lerp animations). Public API:

- `evolve:RegisterTab(tab)` — tabs must supply `Title`, `Icon`, `Privileges`, and may supply `Width`, `Initialize`, `Update`, `IsAllowed`.
- `evolve.MENU:Show() / Hide() / Toggle()` / `evolve.MENU:GetActiveTab()`
- Concommands `+ev_menu`, `-ev_menu`, `ev_menu`.

Tabs live in `lua/ev_menu/tab_*.lua`. The menu integrates with the `hook.Call` override — a tab method named after a GMod hook will fire, same as a plugin's.

## Theme system

`lua/ev_theme/sh_theme.lua` defines color/font tables keyed by id. Public API: `evolve:GetTheme`, `evolve:SetTheme(name, silent)`, `evolve:ListThemes`, `evolve:IsDarkTheme`. Draw helpers (`ThemedPanel`, `ThemedBorder`, `ThemedAccentLine`, `GradientRect`) are used throughout the menu. The `EV_ThemeChanged` hook fires on every theme switch including the initial load — register redraws against it rather than caching theme values at panel-construction time. Per-player preference is persisted to `data/evolve/theme_preference.txt` client-side; the server broadcasts a default via `EV_ThemeDefault`.

## Data files (created at runtime in `garrysmod/data/`)

- `evolve/playerinfo.txt` — vON; all per-player properties including rank and ban state
- `evolve/userranks.txt` — vON; the authoritative rank table
- `evolve/globalvars.txt` — vON; global key/value store
- `evolve/theme_preference.txt` — client-side theme id
- `ev_logs/<date>.txt` — rotating text logs

None of these should be committed; they are per-server state.

## Things that bite

- The `hook.Call` override is global. Any error thrown outside a `pcall` inside a plugin hook will *not* crash GMod (the framework wraps it), but a plugin that returns an unintended truthy value will silently suppress every subsequent gamemode hook.
- `evolve.pluginFile` is a mutable global set during `LoadPlugins` and read inside `RegisterPlugin`. Do not call `RegisterPlugin` outside the top-level of a plugin file — by the time an async callback fires, the filename will have moved on.
- `evolve.version` must match between server and client; bump it when changing any wire format. Older clients will not get the newer fields.
- `EV_UserGroup` is an Evolve-specific NWString; `UserGroup` (no prefix) is GMod's native one. They are related but not the same — see `evolve:Rank` for how Evolve resolves one into the other exactly once per spawn to avoid triggering a false client-side rank-change detection.
- vON is loaded with a local-backup trick so the global `von` is restored after include; always use `evolve.von.serialize` / `evolve.von.deserialize` from framework code, not a bare `von.*`.
