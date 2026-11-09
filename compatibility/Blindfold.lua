-- Blindfold v1.0.9's main-menu overlay only walks the vanilla menu boxes. MPAPI's
-- account/back panel is a separate UIBox, so include it alongside the current page.
-- Reuse Blindfold's own collector and widget actions (text input, cycles, toggles,
-- etc.), rather than dispatching G.FUNCS directly or implementing another key map.
local installed_for

function PVP.UI.install_blindfold(blindfold)
	if not blindfold or type(blindfold.require) ~= "function"
		or not blindfold.overlays or type(blindfold.overlays.register) ~= "function" then
		return false
	end
	if installed_for == blindfold then
		return true
	end

	local Mirror = blindfold.require("overlays.menu_mirror")
	local MainMenu = blindfold.require("overlays.main_menu")
	local Id = blindfold.require("overlay.id")
	local Proxies = blindfold.require("ui.proxies")
	local Announce = blindfold.require("ui.announce").A
	if type(Mirror.gather) ~= "function" or type(Mirror.vtable_for) ~= "function" then
		return false
	end

	local function account_box()
		return MPAPI.account_button and MPAPI.account_button:get_uibox()
	end

	local function visible(box)
		return type(box) == "table" and not box.REMOVED and not (box.states and box.states.visible == false)
	end

	local menu = { id = "mp_pvp_menu" }
	function menu:handler()
		local page = MPAPI.pages.current_key()
		if G.STAGE == G.STAGES.MAIN_MENU and not G.OVERLAY_MENU and visible(G.MAIN_MENU_UI)
			and page and page:match("^pvp_") then
			return "active"
		end
		return "inactive"
	end

	-- A different page is a fresh screen, but an in-place Ready/Cancel rebuild
	-- keeps its position. Blindfold reconciles the stable list keys itself.
	function menu:sub_identity()
		return tostring(G.MAIN_MENU_UI)
	end

	local function add_items(builder, nodes, prefix)
		for i, node in ipairs(nodes) do
			local actions = Mirror.vtable_for(node)
			-- The released Blindfold predates config.blindfold hints. Honor our
			-- labels here too; newer versions also read these natively.
			local hint = node.config and node.config.blindfold
			local label = type(hint) == "table" and hint.label or hint
			if type(label) == "string" then
				actions.label = function(ctx) ctx.message:fragment(label) end
			end
			builder:add_item(Id.referenced(node, prefix .. i), actions)
		end
	end

	function menu:build(builder)
		builder:capture_input()
		local sources = {}
		-- Don't use a table literal with optional roots: ipairs stops at a nil
		-- PROFILE_BUTTON, which MPAPI removes when it builds a multiplayer page.
		local function add(box)
			if visible(box) then sources[#sources + 1] = box end
		end
		add(G.MAIN_MENU_UI)
		add(account_box())
		add(G.PROFILE_BUTTON)
		add(G.title_top)
		add_items(builder, Mirror.gather(sources), "mp:")
	end

	-- Keep Blindfold's familiar vanilla main-menu layout. Only append the
	-- missing account panel there, so PvP can be reached without a mouse.
	local build_main_menu = MainMenu.build
	function MainMenu:build(builder)
		build_main_menu(self, builder)
		local box = account_box()
		local nodes = visible(box) and Mirror.gather({ box }) or {}
		if #nodes > 0 then
			builder:start_row()
			add_items(builder, nodes, "mp:account:")
			builder:end_row()
		end
	end

	-- Blindfold's bespoke blind screen deliberately uses a Blind proxy instead
	-- of a generic button. Its semantic "Current" label hides our Ready/Unready
	-- text, so prepend the live action while preserving the blind's details.
	local select_announcements = Proxies.Blind.select_announcements
	function Proxies.Blind:select_announcements()
		local announcements = select_announcements(self)
		if self.node.config and self.node.config.button == "mp_toggle_ready" then
			table.insert(announcements, 1, Announce.label(PVP.GAME.ready_blind_text))
		end
		return announcements
	end

	blindfold.overlays.register(menu)
	installed_for = blindfold
	return true
end

-- Blindfold is Lovely-only in released versions, not an SMODS dependency. It
-- can boot before or after us. Check at update time and leave absent installs
-- untouched; a failed/unsupported integration must not prevent the game running.
local attempted_for
local update = Game.update
function Game:update(dt)
	update(self, dt)
	local blindfold = rawget(_G, "Blindfold")
	if blindfold and blindfold ~= attempted_for and type(blindfold.require) == "function"
		and blindfold.overlays and type(blindfold.overlays.register) == "function" then
		attempted_for = blindfold
		local ok, err = pcall(PVP.UI.install_blindfold, blindfold)
		if not ok then
			sendWarnMessage("Blindfold compatibility unavailable: " .. tostring(err), "MULTIPLAYER")
		end
	end
end
