extends ImmediateGeometryDisplay

onready var HUD_item_scene = preload("res://Antimony/scenes/hud/hud_item.tscn")
var HUD_dragging = null # dragged item
var HUD_hover = null
var slot_hover = -2 # the slot the dragged item will fall into
var hotbar_sel = 0

var handle_input = 0 # for when cursor is over panels - pause player controls

var state = -1
var prevstate = -1
var paused = false

var menus = {}

var UI_root
var hud
var im_no_zbuffer = null

var m_main
var m_pause
var m_inv
var m_gestures
var m_scoreboard
var m_chat

var mm_connect
var mm_saveload
var mm_settings
var mm_credits
var mm_about

var u_player
var u_hotbar

var h_playername
var h_avatar
var h_effects
var h_itemname
var h_propicon

var h_ammoname
var h_mag
var h_tot
var h_mag_slash

var u_crosshairs
var u_scopes

var h_invpanel
var h_invdroparea

var hh_hotbar = []
var hh_invbar = []
var hh_invequip = []

var h_chatpanel
var h_chatbox
var h_chatscroll
var h_chatlist

var h_tooltip

var sb_peers = []

###
# main menu buttons

# pause/game menu buttons
func resume_btn():
	menu(ms.pause, false)

func newgame_btn():
	pass
func savegame_btn():
	pass
func loadgame_btn():
	pass

func multiplayer_btn():
	menu(ms.multiplayer)
func connect_btn():
	if RPC.join("banderi.dynu.net"):
		$UI/Panel/connect.disabled = true

func settings_btn():
	menu(ms.settings)
func about_btn():
	return # TODO
	menu(ms.about)
func credits_btn():
	menu(ms.credits)
func quit_btn():
	Game.quit_game()
func chat_enter(txt):
	if txt.strip_edges(true, true) == "":
		return
	h_chatbox.text = ""
	RPC.RPC_chat_message(txt)
var inchat = false
func _on_chat_enter():
	inchat = true
func _on_chat_exit():
	inchat = false

func _on_auto_equip_toggled(button_pressed):
	Game.settings["controls"]["equip_on_pickup"] = button_pressed

###

# self-explanatory
func check_mouse_within(node, margin = 0):
	var cc = node.get_local_mouse_position()
	if cc.x < -margin || cc.x > node.rect_size.x + margin \
		|| cc.y < -margin || cc.y > node.rect_size.y + margin:
			return false
	return true

# these operate over the menu NODES
func toggle(n):
	n.visible = !n.visible
func show(n):
	n.visible = true
func hide(n):
	n.visible = false
	if n == m_chat:
		h_chatbox.release_focus()
		h_chatbox.text = ""

enum ms { # technically not just "menu" states, but are really only needed here?
	ingame,
	loading,
	gameover,

	main,
	pause,
	inv,
	gestures,
	scoreboard,
	chat,

	connection,
	saveload,
	settings,
	credits
}
# this operates over the menu INDEX ID
func menu(m, open = true):	# toggle menu visibility and update state correctly
	var arr = menus[m]		# based on an overly complicated moronic system
	var _m = arr[0]
	if open:
		show(_m)
		state = m
		if arr[5]:
			Game.controller.alt_camera = true
	else:
		hide(_m)
		if arr[1] != null:
			state = arr[1] # if submenu, new state is the upper menu
		else:
			state = prevstate # ms.ingame # else, return to normal "ingame" state
		if arr[5]:
			Game.controller.alt_camera = false
func buildmenustruct(): # ...the overly complicated moronic system
	#					 0: linked menu node							3: hold key to keep menu open
	#							1: upper menu this will only work in		   4: can only be closed with escape
	#										2: hotkey								  5: camera close-up on player
	menus = {
		ms.main :		[m_main, null],
		ms.pause :		[m_pause, ms.ingame, "menu_pause",				false, false, false],
		ms.inv :		[m_inv, ms.ingame, "menu_inv",					false, false, true],
		ms.gestures :	[m_gestures, ms.ingame, "menu_gestures",		true,  false, false],
		ms.scoreboard :	[m_scoreboard, ms.ingame, "menu_scoreboard",	true,  false, false],
		ms.chat :		[m_chat, ms.ingame, "menu_chat",				false, true,  false]
	}

# this returns inventory slot BOX NODES (hbox) from slot INDEX VALUE (s)
func hbox(s):
	# return inventory box NODE from INDEX
	return hh_invbar[s] if s < 3 else hh_invequip[s - 3]

# these operate over HUD_item_scene NODES (hi)
func insert_HUDitem(prop, s):
	# translate PROP into HUD_item_scene NODE and add to inventory slot
	var hi = HUD_item_scene.instance()
	hi.prop = prop
	hbox(s).add_item(hi)

	# update hotbar element icon for slots within hotbar
	if s < 3:
		if s == -3: # -3 is ammo!
			Game.equip(hi.prop)
			return Game.despawn(hi)
		hh_hotbar[s].get_node("icon").visible = true
	return hi
func pop_HUDitem(hi):
	if HUD_dragging == hi:
		HUD_dragging = null

	# release prop (make visible again)
	var prop = hi.prop
	prop.RPC_show()
	prop.release()

	# delete HUD_item instance
	hi.hbox.remove_item(hi)
	hi.queue_free()
	update_hotbar()
func drop_HUDitem(hi, s = slot_hover):
	handle_input = 2
	if s == -3: # adding ammo to store and nothing else
		Game.equip(hi.prop)
		return Game.despawn(hi)
	if s < -1 || s > 6:
		return # uhhhh this is wrong.
	if s == -1: # outside inventory -- drop item!
		return Game.dropitem(hi)

	var hbox = hbox(s)
	if s < 3:
		hi.oldpos.x = 7 # reset button display offset
		hi.btn.rect_position.x = 7
		if hbox.has_items():
			if hi.hbox.slot < 3:
				move_HUDitem(hbox.items[0], hi.hbox.slot) # swap items in invbar
			else:
				return # can't drop on a full invbar slot from invequip!! (for now)

	for h in hh_invequip:
		if !check_mouse_within(h.bb):
			h.focus(false)

	move_HUDitem(hi, s)
	update_hotbar()
func move_HUDitem(hi, s):
	hi.get_parent().get_parent().remove_item(hi)
	hbox(s).add_item(hi)

func spawn_balloon(message, peer):
	var b = preload("res://Antimony/scenes/hud/balloon.tscn").instance()
	b.get_node("txt").text = message
	b.pos = Game.level.get_node("PLAYER_" + str(peer)).get_global_transform().origin + Vector3(0, 2, 0)
	UI_root.add_child(b)
func chat_push(message, timestamp, player):
	var b = preload("res://Antimony/scenes/hud/chat_msg.tscn").instance()
	b.player = player
	b.msg = message
	b.timestamp = timestamp
	b.set_text()
	h_chatlist.add_child(b)

	yield(get_tree().create_timer(.1), "timeout") # wait till next frame to update scroll because frontend is fun
	h_chatscroll.scroll_vertical = h_chatscroll.get_v_scrollbar().max_value
func clear_chathistory():
	for m in h_chatlist.get_children():
		m.queue_free()
func resize_chatbox():
	h_chatlist.rect_min_size.y = h_chatscroll.rect_size.y

func inv_items_update():
	# reset slot_hover
	slot_hover = -2

	# update HUD_hover
	HUD_hover = null
	for s in range(0,7):
		var hbox = hbox(s)
		hbox.focus(false)
		if check_mouse_within(hbox.bb):
			slot_hover = s
			hbox.focus(true)
			for hi in hbox.items:
				if HUD_dragging != hi && check_mouse_within(hi.btn, 7):
					HUD_hover = hi
					break

	# update selectors
	if slot_hover > -1:
		var hbox = hbox(slot_hover)
		if HUD_hover == null:
			hbox.selector(0,0) # semi-transparent backdrop
		else:
			hbox.selector(1, hbox.items.find(HUD_hover))

	# update drag_drop for held item based on cursor position
	if !check_mouse_within(h_invpanel) && slot_hover < 3:
		slot_hover = -1

	# dragging an item
	if HUD_dragging != null:

		# dragging an item from invbar
		if HUD_dragging.hbox.slot > 2:
			for s in range(3,4):
				hbox(s).focus(true)
				hbox(s).selector(-1)
			if check_mouse_within(h_invdroparea):
				slot_hover = -2

		# hovering over the invequip drop area
		if check_mouse_within(h_invdroparea) || slot_hover > 2:

			for s in range(3,4):
				hbox(s).focus(true)

			if HUD_dragging.hbox.slot < 3: # dragging an item from invbar
				var item_data = Game.get_item_data(HUD_dragging.prop.itemid)
				slot_hover = item_data.slot[0] + 3
				hbox(slot_hover).selector(Game.eyed_slot(item_data))
				if !Game.can_equip(item_data):
					slot_hover = -2
					if item_data.quantity > -1: # has ammo value - add to the ammo store!
						slot_hover = -3

		if Input.is_action_just_pressed("item_drop"):
			pop_HUDitem(HUD_dragging)
		elif Input.is_action_just_released("shoot"):
			HUD_dragging.release()

	# not dragging an item, hovering over an item
	elif HUD_hover != null:

		if Input.is_action_pressed("item_quickequip"):
			var s = Game.first_free_invslot()
			var item_data = Game.get_item_data(HUD_hover.prop.itemid)
			if HUD_hover.hbox.slot < 3:
				s = item_data.slot[0] + 3
			if s > -1:
				hbox(s).focus(true)
				if s < 3:
					hbox(s).selector(1)
				else:
					hbox(s).selector(Game.eyed_slot(item_data))
					if !Game.can_equip(item_data):
						s = -2
				slot_hover = s

		if Input.is_action_just_pressed("item_drop"):
			pop_HUDitem(HUD_hover)
		elif Input.is_action_just_pressed("shoot"):
			HUD_hover.click()
			if Input.is_action_pressed("item_quickequip") && slot_hover > -2:
				HUD_hover.release()

	# not hovering over items
	else:
		if Input.is_action_just_pressed("item_drop"):
			var hbox = hbox(hotbar_sel)
			if hbox.has_items():
				pop_HUDitem(hbox.items[0])

	# refresh graphics of the hotbar
	update_hotbar()
func update_peers_menu():
	return # TODO
	for p in sb_peers:
		hide(p)

	for i in len(get_tree().get_nodes_in_group("actors")):
		var a = get_tree().get_nodes_in_group("actors")[i]
		var pn = sb_peers[i]
		pn.get_node("name").text = a.player_name
		pn.get_node("ping").text = str(a.ping)
		show(pn)
func update_hotbar():

	# reset focus/highlight
	for h in hh_hotbar:
		h.focus(false)

	# update item name label & focus
	var itemid = ""
	var p = Game.player.prop_inuse
	var hbox = hh_invbar[hotbar_sel]
	if p == null: # player is not interacting with a prop
		h_propicon.visible = false
		if hbox.has_items():
			itemid = hbox.items[0].prop.itemid
		hh_hotbar[hotbar_sel].focus(true)
	else:
		h_propicon.visible = true
		if p.type == -1 || p.type >= 999:
			itemid = p.itemid # use itemid in the general case
		else:
			itemid = str(p.type) # use "type" of base prop class - really hacky, but eh

	# get item/prop name, if it exists in database
	var item_data = Game.get_item_data(itemid)
	if item_data != null:
		h_itemname.text = item_data.name
	else:
		h_itemname.text = ""
		h_propicon.visible = false

	# update hotbar icons
	for s in range(0,3):
		if hh_invbar[s].has_items():
			hh_hotbar[s].get_node("icon").visible = true
			if hotbar_sel == s && Game.player.prop_inuse == null:
				hh_invbar[s].items[0].prop.RPC_show()
			else:
				hh_invbar[s].items[0].prop.RPC_hide()
		else:
			hh_hotbar[s].get_node("icon").visible = false
func update_status_icons():
	for i in h_effects:
		i.visible = false

	if Game.controller.locked || Game.controller.alt_camera:
		h_effects[0].visible = true
	if Game.player.oxygen > 0:
		h_effects[1].visible = true
		h_effects[1].get_node("Label").text = "%d" % [Game.player.oxygen]
#	if Game.player.busy:
#		h_effects[2].visible = true
	if Game.player.mutagen > 0:
		h_effects[6].visible = true
	if Game.player.hypnotized:
		h_effects[7].visible = true

	match Game.player.state:
		Actor.states.ladder:
			h_effects[2].visible = true
		Actor.states.stuck:
			h_effects[2].visible = true
			h_effects[3].visible = true
			h_effects[5].visible = true
			h_effects[5].get_node("Label").text = "%d" % [Game.player.stuck_timer]
		Actor.states.restrained:
			h_effects[3].visible = true
		Actor.states.asleep:
			h_effects[8].visible = true

# weapon system!
func update_weap_hud():
	# reset first
	for n in u_crosshairs.get_children():
		n.visible = false
	for n in u_scopes.get_children():
		n.visible = false

	# crosshair
	if "crosshair" in Game.weaps.weap_data:
		u_crosshairs.get_node(Game.weaps.weap_data.crosshair).visible = true

	# sniper scope
	Game.weaps.visible = true
	Game.controller.cam.fov = Game.camera_fov
	if "scope" in Game.weaps.weap_data && Game.weaps.scope_enabled:
		u_scopes.get_node(Game.weaps.weap_data.scope).visible = true
		Game.weaps.visible = false
		Game.controller.cam.fov = Game.camera_fov_scope
func update_weap_ammo_counters(counters_only = false):
	if !counters_only:
		h_itemname.text = Game.weaps.item_data.name

	# ammo!
	if Game.weaps.ammoid != null:
		if !counters_only: # no need to update these every frame
			h_ammoname.visible = true
			h_ammoname.text = Game.get_item_data(Game.weaps.ammoid).name
			h_tot.visible = true
			h_mag.visible = true
			h_mag_slash.visible = true

		# ammo count color
		var color = Color(1, 1, 1)
		if Game.weaps.time_since_trigger == 0.0:
#			color = Color(1, 0, 1)
			if Game.weaps.charge.missing > 0: # charge choke
				color = Color(1, 0.5, 0.5) + Color(0, 0.5, 0.5) * sin(cum_delta * 4)
			elif Game.weaps.charging && Game.weaps.charge.consuming > 0: # cumulation
				color = Color(0.8, 0.8, 1) + Color(0.2, 0.2, 0) * sin(cum_delta * 4)
		elif Game.weaps.time_since_trigger <= 0.1:
			if Game.weaps.charge.missing > 0:
				color = Color(1, 0.5, 0.5)
			else:
				color = Color(0.8, 0.8, 1)
		color.a = 1.0

		# ammo in total storage
		var displ_amount = Inventory.in_inv(Game.weaps.ammoid)
		if Game.weaps.charging:
			displ_amount = Inventory.in_inv(Game.weaps.ammoid) - Game.weaps.charge.consuming
		if !Game.weaps.weap_data.infinite_ammo:
			if Game.weaps.weap_data.use_mag:
				h_tot.text = str(displ_amount)
			else:
				h_tot.text = str(displ_amount)
				h_tot.modulate = color
		else:
			h_tot.text = "inf"

		# ammo in magazine
		displ_amount = Inventory.ammo_in_mag(Game.weaps.weapid)
		if Game.weaps.charging:
			displ_amount = Inventory.ammo_in_mag(Game.weaps.weapid) - Game.weaps.charge.consuming
		if Game.weaps.weap_data.use_mag:
#			h_mag.visible = true
			h_mag.get_parent().visible = true
			h_mag_slash.visible = true
			h_mag.text = str(displ_amount)
			h_mag.modulate = color
		else:
#			h_mag.visible = false
			h_mag.get_parent().visible = false
			h_mag_slash.visible = false
	else:
		if !counters_only: # no need to update these every frame
			h_ammoname.visible = false
			h_tot.visible = false
			h_mag.visible = false
			h_mag_slash.visible = false

# tooltip
var tooltip_visible = false
func update_tooltip(delta):
	if h_tooltip == null:
		return
	h_tooltip.rect_size.x = 0
	h_tooltip.text = ""
	h_tooltip.rect_position = hud.get_global_mouse_position() + Vector2(20, 0)
	if tooltip_visible:
		tooltip_visible = false
	else:
		h_tooltip.visible = false
func tooltip(text):
	if h_tooltip == null:
		return
	h_tooltip.text = text
	h_tooltip.visible = true
	tooltip_visible = true

# cursors
var cursors = {
	Input.CURSOR_ARROW: [0, 0, "Antimony/graphics/cursor/cur_arrow.png"],
	Input.CURSOR_IBEAM: null,
	Input.CURSOR_POINTING_HAND: [4, 1, "Antimony/graphics/cursor/cur_point.png"],
	Input.CURSOR_CROSS: [8, 8, "Antimony/graphics/cursor/cur_select.png"],
	Input.CURSOR_WAIT: null,
	Input.CURSOR_BUSY: null,
	Input.CURSOR_DRAG: [8, 8, "Antimony/graphics/cursor/cur_hand.png"],
	Input.CURSOR_CAN_DROP: [8, 8, "Antimony/graphics/cursor/cur_hand2.png"],
	Input.CURSOR_FORBIDDEN: null,
	Input.CURSOR_VSIZE: null,
	Input.CURSOR_HSIZE: null,
	Input.CURSOR_BDIAGSIZE: null,
	Input.CURSOR_FDIAGSIZE: null,
	Input.CURSOR_MOVE: [8, 8, "Antimony/graphics/cursor/cur_purse.png"],
	Input.CURSOR_VSPLIT: null,
	Input.CURSOR_HSPLIT: null,
	Input.CURSOR_HELP: null,
}
var current_cursor_shape = Input.CURSOR_ARROW
func load_cursor_pix(s):
	 # invalid/unassigned cursor shape
	var shape_data = cursors[s]
	if shape_data == null || shape_data.size() == 0:
		return

	# load cursor shape
	var pix = load("res://" + shape_data[2])
	var coords = Vector2(shape_data[0], shape_data[1])
	Input.set_custom_mouse_cursor(pix, s, coords);
func init_cursors():
	for s in cursors:
		load_cursor_pix(s)
func set_cursor(s, refresh = false):
	# assert valid range
	if s == null:
		s = Input.CURSOR_ARROW
	s = max(min(Input.CURSOR_HELP, s), Input.CURSOR_ARROW)

	# update cursor if there's any change
	current_cursor_shape = s
#	if refresh:
#		update_cursor()
func update_cursor():
	# BUG:
	# the cursor changes to the highest custom cursor available (max #16) when reloading the tree
	# with the debug command. it then prompty switches back to the correct cursor shape on move.
	# ...I don't even. not a big issue though.

	Debug.loginfo("")
	Debug.logpaddedinfo("cursor:     ", false, [0, 0], [current_cursor_shape, Input.get_current_cursor_shape()])

	if Input.get_current_cursor_shape() != current_cursor_shape:
		Input.set_default_cursor_shape(current_cursor_shape)
#		get_viewport().warp_mouse(get_viewport().get_mouse_position()); # refresh mouse input to update the frickin' cursor
#		print("cursor updated!")
	current_cursor_shape = Input.CURSOR_ARROW

###

func init(node, gm): # load hud scene node and set UI mode
	# delete previously loaded hud, first
	UI_root.remove_child($hud)
	var hud_node = load("res://scenes/hud/" + str(node) + ".tscn").instance()
	hud_node.set_name("hud")
	UI_root.add_child(hud_node)
	UI_root.move_child(hud_node, 0)

	# set ENGINE mode and build the node struct for toggling
	Game.GAMEMODE = gm
	buildmenustruct()

	# close all menus when starting the game
	menu(ms.pause, false)
	menu(ms.inv, false)
	menu(ms.gestures, false)
	menu(ms.scoreboard, false)
	menu(ms.chat, false)

	# load custom cursors
	if Game.custom_cursors:
		init_cursors()
		set_cursor(Input.CURSOR_ARROW)

func is_ui_valid():
	if hud == null || Game.GAMEMODE == Game.gm.none:
		return false
	return true
func register_inv_hotbar_slots(tot_slots, hbar_slots): # register hotbar slots
	for i in range(0,tot_slots):
		if i < hbar_slots:
			hh_hotbar[i].slot = i
			hh_invbar[i].slot = i
		else:
			hh_invequip[i - hbar_slots].slot = i
func game_text_set(wname, pmenu, sub = ""):
	OS.set_window_title(wname)
	m_pause.get_node("Panel/Label").text = pmenu
func load_3D_weaps(scene = "weaps"):
	var weaps = load("res://scenes/hud/" + scene + ".tscn").instance()
	weaps.name = "weaps"
	Game.controller.cam.get_node("ViewportContainer/Viewport/cameraChild").add_child(weaps)
	Game.weaps = weaps

###

func _input(event):
	if !is_ui_valid():
		return

	# refresh input fall-through to the actor controller
	if handle_input > 0:
		handle_input -= 1

	# GAME_mode-specific logic
	match Game.GAMEMODE:
		Game.gm.fps:
			# keep mouse centered when menus aren't open
			if state <= 0:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		Game.gm.ludcorp:
			# update hotbar selection
			if Game.player.prop_inuse == null && !paused: # player is not interacting with a prop
				if Input.is_action_just_pressed("item_prev"):
					hotbar_sel -= 1
				elif Input.is_action_just_pressed("item_next"):
					hotbar_sel += 1
				if hotbar_sel < 0:
					hotbar_sel = 2
				if hotbar_sel > 2:
					hotbar_sel = 0
			### m_inv ###
			inv_items_update()
			Debug.loginfo(str(slot_hover))

	# to future, sober deri:
	# do not touch this, or I will kill you
	# - sincerely, drunk deri ???
	for s in menus:
		var arr = menus[s] # array data of menu
		if len(arr) > 2: # menu has a hotkey!
			var k = arr[2]
			if arr[1] == null || state == arr[1] || state == s: # check if we are in the right menu for this... menu to be available

				if arr[3] == false: # to be activated once tapped
					if Input.is_action_just_pressed(k):
						if state == s:
							if !arr[4]: # only to be closed with escape
								return menu(s, false)
							else:
								return
						else:
							return menu(s, true)
				elif arr[3] == true && Input.is_action_pressed(k): # to be activated if held
					return menu(s, true)
				elif state == s:
					if !arr[4]: # only to be closed with escape
						return menu(s, false)
					else:
						return

	# alternatively - close currently open menu with
	# escape (works in all menus that aren't handled)
	if Input.is_action_just_pressed("ui_cancel"):
		if menus.has(state):
			var arr = menus[state]
			if arr[1] != null:
				return menu(state, false)

	# grab input focus if opening chat
	if Input.is_action_just_released("menu_chat") && m_chat.visible:
		h_chatbox.grab_focus()

	if check_mouse_within(h_invpanel) && m_inv.visible:
		handle_input += 1

var cum_delta = 0
func _process(delta):
	if !is_ui_valid():
		return

	# increase cumulative counter for interpolations
	cum_delta += delta

	# refresh chatbox size
	resize_chatbox()

	# pause controls / game when certain menus are open
	paused = m_main.visible || m_pause.visible || m_gestures.visible || h_chatbox.has_focus()

	# GAME_mode-specific logic
#	match Game.GAMEMODE:
#		Game.gm.ludcorp:
#			# update status icons

	# update chat menu transparency
	if inchat:
		h_chatpanel.modulate.a += (1 - h_chatpanel.modulate.a) * delta * 10
	else:
		h_chatpanel.modulate.a += (0.5 - h_chatpanel.modulate.a) * delta * 10

	# tooltips & cursors
	update_tooltip(delta)
	update_cursor()
