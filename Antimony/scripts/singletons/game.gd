extends Node

###

onready var SCENE_ACTOR = preload("res://Antimony/scenes/actor.tscn")

var root

var player
var controller
var navmesh
var level
var weaps # toolbelt

var space_state
var space_state2D

var gravity = 100
var air_drag = 0.99
var max_fall_speed = -5000

var jump_strength = 300
var jump_falloff = 750
var dash_strength = 100
var walk_speed = 1.0
#var run_speed = 2.0
var run_speed = 4.0
var dash_speed = 30
var backstep_speed = 20
var frontflip_speed = 0
var backflip_speed = 4
var dash_length = 0.25
var flips_length = 0.35
var air_speed_max = 0.7
var air_speed_coeff = 0.1
var available_jumps = 1
var jump_spam = false
var always_run = false
var midair_attack_float_drag = Vector2(0, 0)
var block_walk_speed = 0.0
var sneak_speed = 0.25
var can_crouch = true
var can_sneak = true
var can_sprint = true
var can_dash_while_crouching = false
var max_step_height = 0.5
var max_slope_angle = 0.2 * PI
var crouch_height_diff = 0.75

var camera_fov = 70
var camera_fov_scope = 20
var camera_weapon_shake_force = Vector2(0.0015, 0.01)

var character = 0
#var hotbar_sel = 0
#var inventory = [null, null, null] # these are HUD_item nodes! they are handled by the UI class!

###

enum gm { # "game mode" for different sub-engines
	none,

	rts,		# third person
	fps,		# first person
	ludcorp,	# third person

	plat		# platformer (hollow knight)
	fighting	# fighting game
}
var GAMEMODE = gm.none

onready var settings = {
	"controls": {
		"mouse_sens": 1.0,
		"zoom_sens": 1.2,
		"switch_on_new": true,
		"equip_on_pickup": false,
		"auto_reload": true,
		"aim_toggle": true
	}
}

var items = {
	# ...
}

var weapons = {
	# ...
}

var characters = {
	# ...
}

var gamestate = {
	# ...
}

enum ivs {
	simple,		# bog standard dictionary stored above, ez pz
	rpg			# used in games like Project K - has a fixed inventory menu and a hotbar/toolbelt that receives the props
}
var invsystem = ivs.simple

func in_inv(item): # return -1 if not in invequip - return parent's item array index if so
	var r = -1
	var items = UI.hh_invequip[item.slot[0]].items # check in slot
	for i in items.size(): # still, use first slot for now
		var hi = items[i]
		if game.items[hi.prop.itemid].layer == item.layer:
			r = i
	return r
func can_equip(item):
	var s = in_inv(item)
	if !item.stackable && s > -1: # cannot be equip! (not stackable)
		return false
	return true
func eyed_slot(item): # return the would-be slot offset index of the new item, or 0 if cannot equip
	var s = in_inv(item) + 1 # no item defaults to -1, so minimum is 0
	if s > 0 && !item.stackable: # cannot be stacked!
		return [3, s - 1] # e.g. item is at slot 4 --> return -5
	return [2, s]
func first_free_invslot():
	for s in range(0,3):
		if !UI.hh_invbar[s].has_items():
			return s
	return -1
func equip(prop): # updates stats, actor equipment slots (3d models) etc.
	prop.RPC_hide() # easier to put this call here? hacky, but it's fine...
	var item = items[prop.itemid]
	if item.slot != null:
		game.player.rpc("RPC_equip", prop.itemid, true)
	match item.ammo:
		1: # lockable gear
			pass
		2: # gasmask/oxygen tank
			var diff = 1000 - game.player.oxygen
			var accept = min(diff, prop.custom_item.quantity)
			game.player.oxygen += accept # add ammo quantity to store
			prop.custom_item.quantity -= accept
			pass
		3: # goo gun/canister
			pass
		4: # energy gear/cell
			pass
func unequip(prop):
	var item = items[prop.itemid]
	if item.slot != null:
		game.player.rpc("RPC_equip", prop.itemid, false)
func giveitem(prop):
	var item = game.items[prop.itemid]

	match invsystem:
		ivs.simple:
			pass
		ivs.rpg:
			var s = first_free_invslot()
			if settings["controls"]["equip_on_pickup"]: # autoequip
				if can_equip(item):
					s = item.slot[0] + 3
				elif item.magazine > -1: # has ammo value - add to the ammo store!
					s = -3
			if s == -1:
				return false

			var hi = UI.insert_HUDitem(prop, s)

	return true
func dropitem(hi):
	UI.pop_HUDitem(hi)
func despawn(hi):
	hi.get_parent().get_parent().remove_item(hi)
	hi.prop.queue_free()
	hi.queue_free()

func reload_amount(weapid, amount):
	match invsystem:
		ivs.simple:
			var available_space = weapons[weapid].mag_max - gamestate.magazines[weapid]
			var accepted = min(available_space, amount)
			var refused = amount - available_space
			gamestate.magazines[weapid] += accepted
			return refused
func give_amount(itemid, amount):
	match invsystem:
		ivs.simple:
			var available_space = items[itemid].quantity_max - gamestate.inventory[itemid]
			var accepted = min(available_space, amount)
			var refused = amount - available_space
			gamestate.inventory[itemid] += accepted
			return refused
func consume_weapon_ammo(weapid, amount):
	match invsystem:
		ivs.simple:
			var weap_data = weapons[weapid]
			var missing = 0
			if weap_data.use_mag:
				var available = min(gamestate.magazines[weapid], amount)
				missing = amount - available
				if missing == 0: # do not fire if not enough ammo "rounds" are available
					gamestate.magazines[weapid] -= available
			else:
				missing = consume_amount(weap_data.ammo, amount, false)
			return missing
func consume_amount(itemid, amount, consume_if_missing = true):
	match invsystem:
		ivs.simple:
			var available = min(gamestate.inventory[itemid], amount)
			var missing = amount - available
			if missing == 0 || consume_if_missing:
				gamestate.inventory[itemid] -= available
			return missing

###

func get_all_childs(node):
	var nodes = []
	for n in node.get_children():
		nodes.append(n)
		if n.get_child_count() > 0:
			nodes += get_all_childs(n)
	return nodes
func get_type(t):
	match typeof(t):
		0:
			return "nil"
		1:
			return "bool"
		2:
			return "int"
		3:
			return "float"
		4:
			return "string"

###

func is_2D():
	match GAMEMODE:
		gm.plat, gm.fighting:
			return true
	return false

func spawn_player(actor_scene):
	randomize()
	var rand_name = "[DRONE %04d]" % [rand_range(0,9999)]
	var rand_color = Color(rand_range(0,1), rand_range(0,1), rand_range(0,1))
	player = new_actor(1, actor_scene) # OUR (local) peer is always 1!
	player.ping = 0
	controller.target = player.pos

func switch_character(): # switch characters in single player
	return # temporarily disabled
	match game.character:
		0:
			game.character = 1
			game.player = game.actors[1]
			$"UI/c1/sel".visible = false
			$"UI/c2/sel".visible = true
		1:
			game.character = 0
			game.player = game.actors[0]
			$"UI/c2/sel".visible = false
			$"UI/c1/sel".visible = true
func new_actor(peer, actor_scene): # this will ONLY spawn a new actor on a this machine
	var a = SCENE_ACTOR.instance()
#	a.set_name(player_name)
#	a.set_color(color)
	a.name = "PLAYER_" + str(peer) # <--- this is the NODE's name, not the player's name!
	a.peer = peer
	if peer:
		a.set_network_master(peer)

	# load the actor assets
	var ass = load("res://scenes/actors/" + actor_scene).instance()
	if is_2D() && ass is AnimatedSprite:
		ass.name = "sprite"
#		a.remove_child(a.body3D)
		a.get_node("body2D").add_child(ass)
	elif !is_2D() && ass is Spatial:
		ass.name = "mesh"
#		a.remove_child(a.body2D)
		a.get_node("body3D").add_child(ass)
	else:
		print("ERROR: Could not load actor!")
		a.free()
		return

	while level == null: # wait for the game level to be ready and loaded!
		pass
	level.add_child(a)

	# move to spawn point!
	if is_2D():
		a.body2D.position = level.get_node("player_spawner").position
	else:
		a.body3D.translation = level.get_node("player_spawner").translation
	return a
func have_actor(peer):
	return level.has_node("PLAYER_" + str(peer))
func destroy_actor(peer):
	var a = level.get_node("PLAYER_" + str(peer))
	if a.prop_inuse:
		a.release_prop()
	a.remove_from_group("actors")
	a.queue_free()

func get_playername():
	return "TEST"
#	return player.player_name

###

func load_level(map):
	# unload current level
	game.root.remove_child(game.root.get_node("level"))
	game.level = null

	# load next level
	var next_level = load(str("res://scenes/", map, ".tscn")).instance()
	next_level.set_name("level")
	game.root.add_child(next_level)

	# set level nodes
	game.level = game.root.get_node("level")
	game.navmesh = game.level.get_node("navigation")

	# boot level script
	game.level.start()

func new_game():
	pass
func quit_game():

	# temp, till I have a main menu
	RPC.shutdown()
	get_tree().quit()

func save_game(slot):
	var file = File.new()
	file.open("user://s" + slot + ".sav", File.WRITE)
	var data = {
#		"health" : health
	}
	file.store_line(to_json(data))
	file.close()
func load_game(slot):
	var file = File.new()
	if not file.file_exists("user://s" + slot + ".sav"):
		return

	file.open("user://s" + slot + ".sav", File.READ)
	while not file.eof_reached():
		var current_line = parse_json(file.get_line())

		for i in current_line.keys():
			self.set(i, current_line[i])
	file.close()
