extends Node

###

onready var SCENE_ACTOR = preload("res://Antimony/scenes/actor.tscn")

var root

#var player
var controller
var navmesh
var level
var weaps # toolbelt

var space_state
var space_state2D

var raypick_ignore_first = false

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

#var locked = false
var camera_initial_zoom = 10.0
var camera_alt_zoom = 6.0
var camera_max_height = 0.1 * PI
var camera_min_height = - 0.5 * PI
var camera_zoom_delta_speed = 0.9
var camera_zoom_min = 0.5
var camera_zoom_max = 50.0
var camera_tilt_max = Vector3(0.03, 0.03, 0.03)
var camera_3d_coeff = Vector3(1, 1, 1)
var camera_2d_coeff = Vector2(0.15, 0.15) #0.0175
var camera_2d_vertical_compensation = 0.0175
var camera_fov = 70
var camera_fov_scope = 20
var camera_weapon_shake_force = Vector2(0.0015, 0.01)
var camera_near = 0.1
var camera_far = 10000.0

var max_bullet_travel = 100
var max_bullet_lifetime = 10.0

var unlimited_health = false
var unlimited_ammo = true
var unlimited_mags = true

var character = 0
#var hotbar_sel = 0
#var inventory = [null, null, null] # these are HUD_item nodes! they are handled by the UI class!

var cursor_mode = -1
var selection_mode = 0
var custom_cursors = false

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

var settings = {
	"controls": {
		"mouse_sens": 1.0,
		"zoom_sens": 1.2,
		"switch_on_new": true,
		"equip_on_pickup": false,
		"auto_reload": true,
		"aim_toggle": true,
		"always_run": true,
		"fast_weapon_switch": true,
		"equip_empty_weapons": true
	},
	"visual": {
		"max_decals": 50,
	}
}

# database placeholders
var db = {
	"items": {
		# ...
	},
#	"weapons": {
#		# ...
#	},
#	"ammo": {
#		# ...
#	},
	"weap_banks": [
		# ...
	],
	"characters": {
		# ...
	}
}

func get_db_element(database, id):
	if id in database && database[id].size() > 0:
		return database[id]
	else:
		return null
func get_item_data(itemid):
	return get_db_element(db.items, itemid)
func get_weap_data(weapid):
	var item_data = get_item_data(weapid)
	if item_data != null && item_data.has("weapon_data"):
		return item_data.weapon_data
	return null
func get_ammo_data(ammoid):
	var item_data = get_item_data(ammoid)
	if item_data != null && item_data.has("ammo_data"):
		return item_data.ammo_data
	return null
func get_character_data(charid):
	return get_db_element(db.characters, charid)

### GLOBAL HELPER FUNCTIONS

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

func print_dict(dict):
	var text = ""
	for l in dict:
		text += "%s : %s" % [l, dict[l]]
		if (l != dict.keys().back()):
			text += "\n"
	return text
func delta_interpolate(old, new, s, delta):
	delta *= 60
	var delta_factor = delta * s
	if typeof(s) == TYPE_VECTOR3:
		delta_factor.x = min(delta_factor.x, 1.0)
		delta_factor.y = min(delta_factor.y, 1.0)
		delta_factor.z = min(delta_factor.z, 1.0)
#		return Vector3(
#			lerp(old.x, new.x, s.x * delta),
#			lerp(old.y, new.y, s.y * delta),
#			lerp(old.z, new.z, s.z * delta)
#		)
	elif typeof(s) == TYPE_VECTOR2:
		delta_factor.x = min(delta_factor.x, 1.0)
		delta_factor.y = min(delta_factor.y, 1.0)
#		return Vector2(
#			lerp(old.x, new.x, s.x * delta),
#			lerp(old.y, new.y, s.y * delta)
#		)
	elif typeof(s) == TYPE_REAL:
		delta_factor = min(delta_factor, 1.0)
#	return lerp(old, new, s * delta)
#	var delta_factor = 60 / abs(new - old)
	return old + (new - old) * s * delta_factor
func set_death_timeout(node, lifetime):
	var timer = load("res://Antimony/scenes/kill_timer.tscn").instance()
	timer.wait_time = lifetime
	node.add_child(timer)
func correct_look_at(node, pos, normal):
	node.translation = pos
	if normal.angle_to(Vector3(0, 1, 0)) < 0.2:
		node.look_at(pos + normal, Vector3(0, 0, 1))
	else:
		node.look_at(pos + normal, Vector3(0, 1, 0))
func to_screen(pos):
	return controller.cam.unproject_position(pos)
func camera_distance(pos):
	return controller.cam.translation.distance_to(pos)
func camera_distance_sqr(pos):
	return controller.cam.translation.distance_squared_to(pos)
func rect(position, size):
	position.x = min(position.x, position.x + size.x)
	position.y = min(position.y, position.y + size.y)
	size.x  = abs(size.x)
	size.y = abs(size.y)
	return Rect2(position, size)

###

func is_2D():
	match GAMEMODE:
		gm.plat, gm.fighting:
			return true
	return false

func spawn_player(actor_scene):
#	randomize()
#	var rand_name = "[DRONE %04d]" % [rand_range(0,9999)]
#	var rand_color = Color(rand_range(0,1), rand_range(0,1), rand_range(0,1))
#	player = new_actor(1, actor_scene) # OUR (local) peer is always 1!
#	player.ping = 0
#	controller.target = player.pos
	pass

func switch_character(): # switch characters in single player
	return # temporarily disabled
	match Game.character:
		0:
			Game.character = 1
			Game.player = Game.actors[1]
			$"UI/c1/sel".visible = false
			$"UI/c2/sel".visible = true
		1:
			Game.character = 0
			Game.player = Game.actors[0]
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
#	return player.player_name
	return "TEST"

var player_faction = 0 # default = 0
var teams = [0, 1] # default/placeholder teams: one ally (player=0) and one enemy (cpu=1)!
func get_player_team(faction = player_faction):
	if faction > teams.size() + 1:
		return null
	return teams[faction]
func is_ally(faction):
	return get_player_team() == get_player_team(faction)
func is_enemy(faction):
	return !is_ally(faction)

# temporary command order buffer for cursor and queue updates
var cmm_buffer = {
		"units": null,
		"order": null,
		"target": null,
		"pos": null
}
var order_hierarchy = [ # TODO: turn these into enums?
	"attack",
	"convert",
	"use",
#	"select",
	"travel",
	null
]
func compare_valid_order_hierarchy(o1, o2):
	if order_hierarchy.find(o2) < order_hierarchy.find(o1):
		return o2
	return o1
func check_for_valid_order(unit, target):
	if target == null: # no target
		return "travel"
	else:
		if target == unit: # targeting itself
			return "travel"
		else:
			if is_enemy(target.faction):
				return "attack" # TODO
			return null
func check_for_valid_commands(selection, target):
	cmm_buffer = {
		"units": selection,
		"order": null,
		"target": target,
		"pos": null
	}
	if selection == null || selection == []: # empty selection
		if target == null:
			UI.set_cursor(Input.CURSOR_ARROW)
		else:
			UI.set_cursor(Input.CURSOR_CROSS)
	else:
		var most_valid = null
		for unit in selection:
			most_valid = compare_valid_order_hierarchy(most_valid, check_for_valid_order(unit, target))
		cmm_buffer.order = most_valid
		match most_valid:
			null:
				UI.set_cursor(Input.CURSOR_CROSS)
			"attack":
				UI.set_cursor(Input.CURSOR_IBEAM)
var command_order_queue = []
func command_order(units, order, target, point, queued = false): # TODO!!!!
	print("ORDER: %s, %s, %s (%s), %s" % [units, order, target, point, queued])
#	Game.command_pawns(point)
#	Game.player.travel(command_points)
#	Game.player.reach_prop(get_highlight())
	pass
func command_buffered(queued):
	if cmm_buffer.order == null:
		return
	command_order(cmm_buffer.units, cmm_buffer.order, cmm_buffer.target, cmm_buffer.pos, queued)

###

func update_physics_space_state():
	if level == null:
		return
	if is_2D():
		space_state2D = level.get_world_2d().direct_space_state
	else:
		space_state = level.get_world().direct_space_state

func load_level(map):
	# unload current level
	Game.root.remove_child(Game.root.get_node("level"))
	Game.level = null

	# load next level
	var next_level = load(str("res://scenes/", map, ".tscn")).instance()
	next_level.set_name("level")
	Game.level = next_level
	Game.root.add_child(next_level)
	Game.navmesh = Game.level.get_node("navigation")

	# boot level script
	Game.level.start()

	# initialize global space states
	Game.update_physics_space_state()

	if !UI.is_ui_valid():
		print("ERROR: UI could not init! Quitting...")
		Game.quit_game()

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
