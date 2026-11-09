-- Run from the repo root: lua tests/unit/blindfold_test.lua
-- No game, speech library, network, or Blindfold installation needed.
local failures = 0
local function check(name, got, want)
	if got ~= want then
		failures = failures + 1
		print(("FAIL %s: got %s, want %s"):format(name, tostring(got), tostring(want)))
	else
		print("ok   " .. name)
	end
end
local noop = function() end
PVP = { UI = {}, UTILS = {}, GAME = {}, LOBBY = { config = {} } }
G = {
	STAGE = "menu", STAGES = { MAIN_MENU = "menu", RUN = "run" }, FUNCS = {},
	UIT = { R = "row", C = "column", T = "text", ROOT = "root" },
	C = { UI = {} },
}
MPAPI = {
	disableable_button = function(args) return { args = args, update = noop } end,
	ReadyTracker = function() return { reset = noop } end,
	VoteTracker = function() return {} end,
	is_connected = function() return true end,
}
local updates = 0
Game = { update = function() updates = updates + 1 end }
local warnings = 0
sendWarnMessage = function() warnings = warnings + 1 end
localize = function(key) return key end

dofile("lib/ui.lua")
dofile("compatibility/Blindfold.lua")
check("Blindfold is not required", PVP.UI.install_blindfold(nil), false)
Game:update(0)
check("ordinary update still runs without Blindfold", updates, 1)
check("absent Blindfold produces no warning", warnings, 0)
check("unsupported Blindfold is ignored", PVP.UI.install_blindfold({}), false)

local args = { button = "test", enabled = false }
local disabled = PVP.UI.disableable_button(args)
check("reactive buttons have explicit focus metadata", type(disabled.args.focus_args), "table")
check("disabled state still belongs to MPAPI", disabled.args.enabled, false)
local focus = { snap_to = true }
check("existing focus metadata is preserved", PVP.UI.disableable_button({ focus_args = focus }).args.focus_args, focus)
local button = PVP.UI.labelled_button({ config = { button = "queue" } }, "Balanced: QUEUE")
check("labelled buttons are hoverable", button.config.hover, true)
check("labelled buttons have focus metadata", type(button.config.focus_args), "table")
check("labelled buttons expose mode context", button.config.blindfold.label, "Balanced: QUEUE")
local unavailable = PVP.UI.labelled_button({ config = {} }, "Unavailable")
check("a disabled pillar is not made focusable", unavailable.config.focus_args, nil)
check("a disabled pillar is not made hoverable", unavailable.config.hover, nil)
check("multiline labels preserve reading order", PVP.UI.label_text({ "Battle", "Royale" }), "Battle Royale")

-- Exercise the actual main-menu and lobby definitions, including their live
-- arguments: Ready/Unready and Find Game/Cancel must not cache a spoken label.
dofile("ui/pvp_main_menu.lua")
PVP.main_menu.create_buttons()
for name, el in pairs(PVP.main_menu.buttons) do
	check("main-menu " .. name .. " is focusable", type(el.args.focus_args), "table")
end
PVP._show_searching_state(true)
check("search action changes", PVP.main_menu.buttons.find_game.args.button, "mp_pvp_cancel_queue")
check("search label changes", PVP.main_menu.buttons.find_game.args.label[1], "b_cancel_search_cap")
PVP._show_searching_state(false)
check("search label resets", PVP.main_menu.buttons.find_game.args.label[1], "b_find_game_cap")

dofile("ui/lobby/_ready.lua")
dofile("ui/lobby/buttons.lua")
PVP.lobby.create_buttons()
for name, el in pairs(PVP.lobby.buttons) do
	if name ~= "ready_args" then
		check("lobby " .. name .. " is focusable", type(el.args.focus_args), "table")
	end
end
PVP.signal_ready = noop
G.FUNCS.mp_pvp_toggle_ready()
check("ready label becomes Unready", PVP.lobby.buttons.ready.args.label[1], "b_unready_cap")
PVP.reset_ready_state()
check("ready label resets", PVP.lobby.buttons.ready.args.label[1], "b_ready_cap")

-- Build the actual mode pages. Repeated action words need their mode's name,
-- including live Queue -> Cancel updates and unavailable/standing-refused modes.
PVP.RulesetKey = { BALANCED = "Balanced", EXPANDED = "Expanded", VANILLA = "Vanilla", SMALLWORLD = "Smallworld", MAJORLEAGUE = "MLBa" }
PVP.MODE_CHIP_ROW, PVP.MODE_COLOUR = {}, {}
PVP.LobbyAccess = { PRIVATE = "private", PARTY = "party", RANKED = "ranked", CASUAL = "casual" }
PVP.ruleset_display_name = function(key) return key end
PVP.ranked_ticket = function(key) return key end
PVP.mode_chip_sprite, PVP.ruleset_chip_sprite = noop, noop
HEX = function(value) return value end
mix_colours = noop
MPAPI.GameModes, MPAPI.QueueKind = {}, { RANKED = "ranked", CASUAL = "casual" }
MPAPI.matchmaking = { group = { MIN_SIZE = 2, MAX_SIZE = 4 } }
MPAPI.LobbyType = { PRIVATE = "private" }
MPAPI.get_current_lobby = noop
MPAPI.ui_pillar_name_plate, MPAPI.ui_pillar_description_box = noop, noop
MPAPI.ui_pillar_stat_box, MPAPI.ui_embossed_box = noop, noop
MPAPI.ui_pillar_select_button = function(spec) return { config = { button = spec.button } } end
local page_items
MPAPI.ui_pillar_row = function(spec)
	page_items = spec.items
	return { row_node = {}, dispose = noop }
end
UIBox_button = function(spec) return { config = spec } end
MPAPI.ui_element = function(build)
	return setmetatable({ update = noop }, { __index = function(_, key)
		if key == "node" then return build().nodes[1] end
	end })
end
local active, allowed = false, true
PVP._active_queue_matches = function() return active end
PVP._is_queue_active = function() return active end
MPAPI.can_queue = function() return allowed, "refused" end
PVP.group_mode_available = function() return allowed, false end

dofile("ui/main_menu/game_select.lua")
PVP.build_game_select_ui("create_lobby")
check("create mode speaks its name", page_items[1].select.config.blindfold.label, "Nemesis: CREATE")
check("multiline create mode speaks its full name", page_items[2].select.config.blindfold.label, "Battle Royale: CREATE")
check("create mode is focusable", type(page_items[1].select.config.focus_args), "table")
PVP.build_game_select_ui("practice")
check("practice speaks the ruleset", page_items[1].select.config.blindfold.label, "Balanced: START")

dofile("ui/main_menu/find_game.lua")
PVP.build_find_game_ui("ranked")
check("ranked queue speaks ruleset and category", page_items[1].select.config.blindfold.label, "Vanilla k_pvp_ranked: QUEUE")
check("ranked queue is focusable", type(page_items[1].select.config.focus_args), "table")
active = true
PVP.build_find_game_ui("ranked")
check("queued mode speaks Cancel", page_items[1].select.config.blindfold.label, "Vanilla k_pvp_ranked: CANCEL")
check("queued mode still cancels", page_items[1].select.config.ref_table.cancel, true)
active, allowed = false, false
PVP.build_find_game_ui("ranked")
check("standing refusal keeps its explanation action", page_items[1].select.config.button, "mp_pvp_find_game_standing_refused")
check("standing refusal is still focusable", type(page_items[1].select.config.focus_args), "table")
PVP.build_find_game_ui("casual", true)
check("unavailable group mode remains disabled", page_items[1].select.config.button, nil)
check("unavailable group mode has no focus metadata", page_items[1].select.config.focus_args, nil)
allowed = true
PVP.build_find_game_ui("casual", true)
check("group queue has mode context", page_items[1].select.config.blindfold.label, "Nemesis: QUEUE")
check("group queue is focusable", type(page_items[1].select.config.focus_args), "table")

-- Blindfold module contracts: discovery receives the current UI roots; actions
-- must go through its widget vtables, not bypass disabled state via G.FUNCS.
local registered, sources, activated = {}, nil, nil
local current_page = "pvp_lobby"
MPAPI.pages = { current_key = function() return current_page end }
local MainMenu = { build = function(_, builder) builder.native_build = true end }
local Proxies = { Blind = { select_announcements = function() return { "blind details" } end } }
local Mirror = {
	gather = function(roots)
		sources = roots
		local out = {}
		for _, root in ipairs(roots) do
			for _, node in ipairs(root.controls or {}) do out[#out + 1] = node end
		end
		return out
	end,
	vtable_for = function(node)
		return {
			label = function(ctx) ctx.message:fragment(node.config.text) end,
			on_click = function() activated = node end,
			on_horizontal_adjust = function() activated = "adjust" end,
		}
	end,
}
local modules = {
	["overlays.menu_mirror"] = Mirror,
	["overlays.main_menu"] = MainMenu,
	["overlay.id"] = { referenced = function(node, key) return { ref = node, key = key } end },
	["ui.proxies"] = Proxies,
	["ui.announce"] = { A = { label = function(text) return text end } },
}
local blindfold = {
	require = function(name) return assert(modules[name], name) end,
	overlays = { register = function(overlay) registered[#registered + 1] = overlay end },
}
Blindfold = blindfold
Game:update(0)
check("late-loaded Blindfold installs on update", #registered, 1)
check("game update runs with Blindfold too", updates, 2)
Game:update(0)
PVP.UI.install_blindfold(blindfold)
check("installation is idempotent", #registered, 1)
local menu = registered[1]
local ready = { config = { text = "Ready" } }
local back = { config = { text = "Back" } }
local account = { controls = { back } }
MPAPI.account_button = { get_uibox = function() return account end }
G.MAIN_MENU_UI = { controls = { ready } }
G.title_top = { controls = {} }
G.PROFILE_BUTTON = nil
check("multiplayer page is navigable", menu:handler(), "active")
local first_identity = menu:sub_identity()
local items = {}
local builder = {
	capture_input = function(self) self.captured = true end,
	start_row = noop, end_row = noop,
	add_item = function(_, id, actions) items[#items + 1] = { id = id, actions = actions } end,
}
menu:build(builder)
check("menu takes navigation input", builder.captured, true)
check("nil profile does not hide account/title sources", #sources, 3)
check("current page is the first source", sources[1], G.MAIN_MENU_UI)
check("separate account panel is included", sources[2], account)
check("both page and Back are reachable", #items, 2)
items[2].actions.on_click()
check("activation uses Blindfold's original vtable", activated, back)
items[1].actions.on_horizontal_adjust()
check("widget adjustment is preserved", activated, "adjust")
local spoken = {}
local ctx = { message = { fragment = function(_, text) spoken[#spoken + 1] = text end } }
items[1].actions.label(ctx)
check("rendered Ready text is read", spoken[#spoken], "Ready")
ready.config.text = "Unready"
items[1].actions.label(ctx)
check("rendered label is read live", spoken[#spoken], "Unready")
ready.config.blindfold = { label = "Balanced: CANCEL" }
items = {}
menu:build(builder)
items[1].actions.label(ctx)
check("mode labels work before Blindfold's hint API", spoken[#spoken], "Balanced: CANCEL")
local stable_key = items[1].id.key
G.MAIN_MENU_UI.controls = { { config = { text = "Ready" } } }
items = {}
menu:build(builder)
check("reactive replacements keep their structural key", items[1].id.key, stable_key)
check("reactive replacements keep the screen identity", menu:sub_identity(), first_identity)
G.MAIN_MENU_UI = { controls = {} }
check("a new page changes screen identity", menu:sub_identity() ~= first_identity, true)
G.OVERLAY_MENU = {}
check("modal menus retain their own navigation", menu:handler(), "inactive")
G.OVERLAY_MENU = nil
G.STAGE = "run"
check("gameplay retains its own navigation", menu:handler(), "inactive")
G.STAGE = "menu"
account.REMOVED = true
menu:build(builder)
check("removed account UI is ignored", #sources, 2)
account.REMOVED = nil
account.states = { visible = false }
menu:build(builder)
check("hidden account UI is ignored", #sources, 2)
account.states = nil
current_page = "vanilla_main_menu"
check("vanilla menu retains its normal layout", menu:handler(), "inactive")
items = {}
MainMenu:build(builder)
check("vanilla menu's original builder still runs", builder.native_build, true)
check("vanilla menu gains the account panel", items[1].id.ref, back)
current_page = "other_mod_menu"
check("other mods retain their normal layout", menu:handler(), "inactive")
current_page = "pvp_lobby"
G.MAIN_MENU_UI.states = { visible = false }
check("hidden main UI is ignored", menu:handler(), "inactive")

local proxy = setmetatable({ node = { config = { button = "mp_toggle_ready" } } }, { __index = Proxies.Blind })
PVP.GAME.ready_blind_text = "Ready"
check("PvP blind speaks Ready", proxy:select_announcements()[1], "Ready")
PVP.GAME.ready_blind_text = "Unready"
check("PvP blind speaks Unready live", proxy:select_announcements()[1], "Unready")
check("PvP blind keeps its details", proxy:select_announcements()[2], "blind details")
proxy.node.config.button = "select_blind"
check("ordinary blinds are unchanged", #proxy:select_announcements(), 1)

-- A broken or changed Blindfold module must warn once, never crash Game:update.
Blindfold = { require = function() error("unavailable module") end, overlays = { register = noop } }
Game:update(0)
Game:update(0)
check("incompatible module reports one warning", warnings, 1)
check("game keeps updating after integration failure", updates, 5)

-- Optionally pass a Blindfold checkout to also exercise its REAL collector,
-- proxies, graph and dispatcher (tested against v1.0.9 and main).
-- lua tests/unit/blindfold_test.lua /path/to/Blindfold
if arg[1] then
	local loaded = {}
	local function bf_require(name)
		if loaded[name] then return loaded[name] end
		local chunk = assert(loadfile(arg[1] .. "/src/" .. name:gsub("%.", "/") .. ".lua"))
		loaded[name] = true
		loaded[name] = chunk(bf_require) or true
		return loaded[name]
	end
	love = { filesystem = { read = noop, write = noop, append = noop } }
	local Message = bf_require("ui.message")
	local en = bf_require("loc.en")
	Message.set_resolver(function(key)
		local value = en
		for part in key:gmatch("[^.]+") do value = type(value) == "table" and value[part] or nil end
		return type(value) == "string" and value or nil
	end)
	local dispatcher = bf_require("overlay.dispatcher")
	dispatcher.register(bf_require("overlays.main_menu"))
	local real_blindfold = { require = bf_require, overlays = dispatcher }
	check("real Blindfold modules install", PVP.UI.install_blindfold(real_blindfold), true)
	local text = { value = "Ready" }
	local clicks = 0
	local function native_button(label, callback)
		local node = {
			UIT = G.UIT.R, config = { button = "mp_pvp_test", focus_args = {} },
			states = { visible = true, hover = { can = true } },
			children = { { UIT = G.UIT.T, config = { text = label } } },
			click = callback or function() clicks = clicks + 1 end,
		}
		return node
	end
	local native_ready = native_button(nil)
	native_ready.children[1].config = { ref_table = text, ref_value = "value" }
	local native_back = native_button("Back")
	local disabled_button = native_button("Disabled")
	disabled_button.config.button = nil
	disabled_button.states.hover.can = false
	local function box(nodes)
		return { states = { visible = true }, UIRoot = { UIT = G.UIT.ROOT, config = {}, children = nodes } }
	end
	G.MAIN_MENU_UI = box({ native_ready, disabled_button })
	G.STAGE, G.OVERLAY_MENU, G.PROFILE_BUTTON, G.title_top = "menu", nil, nil, nil
	account = box({ native_back })
	MPAPI.account_button = { get_uibox = function() return account end }
	local function contains(result, needle)
		return result and type(result.message) == "string" and result.message:find(needle, 1, true) ~= nil or false
	end
	check("real graph announces the Ready button", contains(dispatcher.tick(nil), "Ready"), true)
	check("real graph reaches the separate Back panel", contains(dispatcher.tick({ kind = "move", dir = "down" }), "Back"), true)
	dispatcher.tick({ kind = "confirm" })
	check("real graph activates the native click", clicks, 1)
	check("real collector omits disabled buttons", #bf_require("overlays.menu_mirror").gather({ G.MAIN_MENU_UI, account }), 2)
	dispatcher.tick({ kind = "move", dir = "up" })
	text.value = "Unready"
	check("real graph reads updated Ready state", contains(dispatcher.tick({ kind = "move_to_edge", dir = "left" }), "Unready"), true)
	native_ready = native_button("Replacement")
	native_ready.config.blindfold = { label = "Balanced: CANCEL" }
	G.MAIN_MENU_UI.UIRoot.children = { native_ready }
	-- Reconcile silently keeps the cursor; Home explicitly re-reads its label.
	dispatcher.tick(nil)
	check("real graph speaks contextual pillar labels", contains(dispatcher.tick({ kind = "move_to_edge", dir = "left" }), "Balanced: CANCEL"), true)
	G.MAIN_MENU_UI = box({ native_button("Create Lobby") })
	check("real graph resets for a different page", contains(dispatcher.tick(nil), "Create Lobby"), true)
	G.OVERLAY_MENU = {}
	dispatcher.tick(nil)
	check("real adapter releases modal menus", dispatcher.captures(), false)
	G.OVERLAY_MENU = nil
	G.STAGE = "run"
	dispatcher.tick(nil)
	check("real adapter releases gameplay", dispatcher.captures(), false)
	G.STAGE = "menu"
	current_page = "vanilla_main_menu"
	G.MAIN_MENU_UI = box({ native_button("Play") })
	check("real vanilla menu keeps its own controls", contains(dispatcher.tick(nil), "Play"), true)
	check("real vanilla menu gains account navigation", contains(dispatcher.tick({ kind = "move", dir = "down" }), "Back"), true)
	local real_proxy = bf_require("ui.proxies").Blind.new({ config = { button = "mp_toggle_ready" } })
	PVP.GAME.ready_blind_text = "Ready"
	check("real blind proxy speaks Ready", real_proxy:get_focus_message():resolve():find("Ready", 1, true) ~= nil, true)
	PVP.GAME.ready_blind_text = "Unready"
	check("real blind proxy speaks Unready", real_proxy:get_focus_message():resolve():find("Unready", 1, true) ~= nil, true)
end

if failures > 0 then os.exit(1) end
