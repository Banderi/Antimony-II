extends Node
class_name Actor

var equipment = [] # only for aesthetics! inventory is stored in Game
var player_name = ""
var player_color
var character = 0
var peer
var ping = 200

onready var body3D = get_node("body3D")
onready var coll_capsule = get_node("body3D/collision_capsule")
onready var coll_cylinder_low = get_node("body3D/collision_cylinder_low")
onready var mesh = body3D.get_node("mesh")
onready var animset = (null if mesh == null else mesh.get_node("AnimationPlayer"))
#onready var animset = mesh.get_node("AnimationPlayer")
onready var animtree = body3D.get_node("AnimationTree")
onready var statemachine = animtree.get("parameters/machine/playback")

onready var body2D = get_node("body2D")
onready var animsprite = body2D.get_node("sprite")
onready var animframes = (null if animsprite == null else animsprite.frames)
#onready var animframes = animsprite.frames

var current_anim = ""

var nm_corr = Vector3(0, -0.4, 0)
var up = Vector3(0, 1, 0)
var hor = Vector3(1, 0, 1)

var up2D = Vector2(0, -1)
var hor2D = Vector2(1, 0)
var pos2D = Vector2()

var pos = Vector3()
var velocity = Vector3()
var dir = Vector3()
var rot = -PI * 0.5
var lookat = Vector3()

var last_dir = Vector3(1, 0, 0)

var speed = 6
var turn_friction = 0.2

var destination = Vector3()
var path = [] # NB: the path is NOT corrected for height! that correction is done real time

###

var hypnotized = false
var detected = false
var oxygen = 0
var mutagen = 0

enum states {
	idle,
	transit,
	stance,
	attacking,

	ladder,
	vent,

	switch,
	terminal,

	turret,
	crane,
	vehicle,

	stuck,
	restrained,
	asleep,

	dying,
	ded
}

var state = states.idle
var crouching = false
var sprinting = false
var dashing = false
var jumping = false
var firing = false
var blocking = false

var busy = false
var stuck_timer = 0
var prop_inuse # prop/node interacting with actor
var prop_to_reach
var prop_has_collided = false

#var available_jumps = 3
var canjump = 1
var jumping_timer = 0
var jump_force = 0
var onground = true
var drag_coeff = Vector2(0, 0)

# TODO: move to more sensible place
var dash_timer = 0
var dash_direction = null

# this is a hack to fix the crouching animation.... egh
var just_crouched = false

func reach_prop(p):
	if !busy:
		prop_to_reach = p
		travel(prop_to_reach.to_reach(pos)) # override normal navigation goal when clicking on props!
func prop_interact():

	# pre-action; it returns back the prop type!
	var r = prop_to_reach.interact(self)

	# for non-grabbable, valid props
	if r >= 0:
		release_prop() # release previous prop, if present
		if r < 999:
			body3D.transform = prop_to_reach.start_tr # align thyself with prop
			busy = true # assume it'll be set to true, at first

	match r:
		-2: # already in use by me!!
			prop_to_reach = false
			return false
		-1: # failure...????
			prop_to_reach = false
			return false
		0: # ladder
			state = states.ladder
			$body3D/collision_capsule.disabled = true
			if prop_to_reach.climb_or_nah(pos): # descending, or ascending?
				body3D.translation.y = pos.y + 1
				path = prop_to_reach.p_up.duplicate()
			else:
				body3D.translation.y = pos.y - 0.1
				path = prop_to_reach.p_down.duplicate()
		1: # cannon / turret
			state = states.turret
		###
		999: # phys. props
			pass
		1000: # item pickup
			# all things considered, I think I'll leave the PhysProp entity
			# present, just hidden. it's better to have them ready at all
			# time in case they are dropped on the ground, and load all the
			# models in for them at the start of the game.

			# pick up item if free slot available - otherwise hold in hand
			if game.giveitem(prop_to_reach):
				prop_to_reach.RPC_hide()
				return release_prop() # super hacky hack jank ( ͡° ͜ʖ ͡°)
			# prop_inuse is't set yet, so the prop won't release the actor -
			# - but the actor will release the prop!

	# we're done here!
	prop_inuse = prop_to_reach # confirm prop
	prop_to_reach = null
	UI.update_hotbar()
	return true
func release_prop(): # detach prop regardless of state
	busy = false
	if prop_inuse != null:
		prop_inuse.release()
		prop_inuse = null
	UI.update_hotbar()
func cancel(become_stuck = false):
	if stuck_timer > 0: # can't cancel yourself out of goop :3c
		return
	if prop_inuse != null:
		match state:
			states.ladder, states.stuck, states.restrained, states.asleep, states.dying, states.ded:
				return
			states.turret:
				get_parent().remove_child(self)
				game.level.add_child(self)
				rot = prop_inuse.phi + prop_inuse.rotation.y - PI * 0.5
				body3D.transform = prop_inuse.transform.translated(Vector3(0,0,-1.35).rotated(up,prop_inuse.phi)) # move back actor to the turret's position
		release_prop()
		prop_to_reach = null

	# reset "busy" in any generic case
	busy = false

	# if being interrupted by stuff like glorp, don't go to "idle"
	if !become_stuck && attack_end():
		state = states.idle
	path = []

func get_angle_from_vector(v, n):
	var base = Vector3(1, 0, 0)
	var angle = v.normalized().angle_to(base)

	var normal = base.cross(v)
	var direction = sign(normal.dot(n))
	if direction == 0:
		direction = 1

	return angle * direction

var dir_tilt = Vector3()
#var angle_tilt = 0
#var angle_normal = 0
var collider = null
var collider_angle = 0
var ground_grip_dist = Vector3()
var tilt_angle = 0
var stairing = false
func travel(d):
	if !busy:
		path = game.navmesh.get_simple_path(pos, d)
		path.remove(0) # no need for current position to be the first path node
		destination = d
func path_update():
	# ignore for now if player controlled
	if self == game.player:
		match game.GAMEMODE:
			game.gm.fps, game.gm.plat, game.gm.fighting:
				return

	match state:
		states.transit, states.idle:
			var reached_prop = false
			if path.size() > 0 && prop_to_reach != null: # check
				var dist = ((prop_to_reach.path_origin - pos) * hor)
				debug.loginfo(str(dist.length()))
				if prop_has_collided || \
						dist.length() < prop_to_reach.distance || \
						(path.size() < 2 && dist.length() < prop_to_reach.distance * 2):
					path = []
					reached_prop = prop_interact() # interact!!
					prop_has_collided = false
			if path.size() > 0:
				dir = (path[0] - pos + nm_corr)
				if (dir * hor).length() < 0.1: # check for horizontal distance to the path node
					path.remove(0)
			if path.size() == 0:
				dir = Vector3() # arrival at destination!
				if prop_to_reach != null && !reached_prop: # alas... prop is unreachable
					prop_to_reach = null
			else:
				dir = (path[0] - pos + nm_corr) # update the movement to keep the motion seamless
		states.ladder:
			if path.size() > 1:
				dir = (path[0] - pos + nm_corr)
				if dir.length() < 0.05:
					path.remove(0)
				if path.size() == 1:
					body3D.translation = path[0] + nm_corr
					dir = Vector3() # arrival at destination!
					path.remove(0)
					state = states.idle
					release_prop()
	dir = dir.normalized() # dir is only used for direction!
func slope_correction():
	if game.is_2D(): # todo
		pass
	else:
		# tilt movement following slopes
		var space_state = body3D.get_world().direct_space_state
		dir_tilt = dir
		var m = Basis()
		collider_angle = -1
		var raypos = pos + up
		var rayend = pos - up
		if velocity.y < -1:
			rayend = pos - up * abs(velocity.y)

		if body3D.get_slide_count() == 0:
			collider = null
		else:
			collider = body3D.get_slide_collision(0)
		stairing = false
		var normal = up

		# default case - follow the ground tilt
		var result = space_state.intersect_ray(raypos, rayend, [body3D])
		if result.has("normal"):
			tilt_angle = result.normal.angle_to(up) # slope angle
			if tilt_angle < game.max_slope_angle: # ignore STEEP slopes
				normal = result.normal
			else:
				var c = up.cross(normal).normalized()
				if normal == up:
					c = Vector3(0, 1, 0)
				normal = up.rotated(c, game.max_slope_angle)

		# collision?
		if collider != null:
			collider_angle = collider.normal.angle_to(up) # slope angle
			ground_grip_dist = (collider.position - pos)
			var coll_dir = ground_grip_dist.normalized()
			debug.line(pos, pos + coll_dir, Color(0, 0, 0))

			if onground:
				if tilt_angle < game.max_slope_angle && ground_grip_dist.y <= game.max_step_height + sin(tilt_angle): # check for stairs & ramps

					# construct raycaster
					var offs = collider.position + coll_dir * 0.05
					raypos = offs + up
					rayend = offs - up
					debug.point(raypos, Color(0, 0, 0))
					debug.point(rayend, Color(0, 0, 0))

					# check the plaftorm's collision, normal and angle
					result = space_state.intersect_ray(raypos, rayend, [body3D])
					var plat_hit = Vector3()
					if (result.has("position")):
						plat_hit = result.position
					var plat_normal = up
					if (result.has("normal") && result.normal != up):
						plat_normal = result.normal
					var plat_angle = plat_normal.angle_to(up) # upcoming slope's normal angle

					# first, exclude edge cases (hehe)
					var nostep = false
					if dir.angle_to(coll_dir) > PI * 0.5:
						nostep = true
					if plat_hit.y < collider.position.y - 0.1:
						nostep = true
					if plat_hit.y - pos.y > game.max_step_height + 0.001:
						nostep = true

					# valid staircase step?
					if !nostep && plat_angle < game.max_slope_angle && dir != Vector3():
						normal = (plat_normal + collider.normal).normalized()
						stairing = true
					else:
						stairing = false


					# debugging
					debug.point(plat_hit, Color(0.5, 1, 0))
					debug.line(plat_hit, plat_hit + plat_normal, Color(0.5, 1, 0))

					debug.point(collider.position, Color(1, 0.5, 0))
					debug.line(collider.position, collider.position + collider.normal, Color(1, 0.5, 0))
					debug.point(pos, Color(1, 0.5, 0))
					debug.line(collider.position, pos, Color(1, 0.5, 0))
				else: # walls/ceiling/etc.
					# debugging
					debug.point(collider.position, Color(1, 0, 0))
					debug.line(collider.position, collider.position + collider.normal, Color(1, 0, 0))
					debug.point(pos, Color(1, 0, 0))
					debug.line(collider.position, pos, Color(1, 0, 0))
		else:
			stairing = false

		var c = up.cross(normal)
		if normal == up:
			c = Vector3(1, 0, 0)
		var a = acos(up.dot(normal))
		m = m.rotated(c.normalized(), a)
		dir_tilt = m.xform(dir) # movement vector but tilted along the ground

func face_direction():
	if game.is_2D():
		return
#	match game.GAMEMODE:
#		game.gm.fps:
#			lookat = (game.controller.follow.get_global_transform().origin - game.controller.cam.get_global_transform().origin).normalized()
#			var lookat_hor = (lookat * Vector3(1, 0, 1))
#			var lookat_rot = get_angle_from_vector(lookat_hor, up)
#			var input_rot = get_angle_from_vector(dir, up)
#			var walk_dir = lookat_hor.rotated(up, input_rot).normalized()
#			var walk_rot = get_angle_from_vector(walk_dir, up) - PI * 0.5
#			dir = walk_dir # set new dir to the correct rotated one

#			if (dir != Vector3()):
#				rot = get_angle_from_vector(dir, up)
#			body3D.look_at(body3D.translation - dir_hor, up)
#		_: # default case
	var target_rot = get_angle_from_vector(dir, up)
#	if (dir.z > 0):
#		target_rot = PI * 2 - target_rot
	if (dir != Vector3()):
		while (target_rot - rot > PI):
			target_rot -= PI * 2
		while (target_rot - rot < -PI):
			target_rot += PI * 2
		rot += (target_rot - rot) * turn_friction
		while (rot > PI * 2):
			rot -= PI * 2
		while (rot < -PI * 2):
			rot += PI * 2

	body3D.rotation = Vector3(0, rot + PI * 0.5, 0) # I dunno why I was rotating the mesh....

	# special cases...
	if state == states.turret:
		body3D.rotation = Vector3()
func touch_ground(): # teleport player to the ground below if below threshold
	# poll space_state for raycasting
	var result
	if game.is_2D():
		if !body2D.is_on_floor():
			return false
	else:
		if jumping && jumping_timer < 0.1:
			return false

		# is it on steer slopes??
		if !stairing && !body3D.is_on_floor():
			if collider_angle < 0 || collider_angle > PI * 0.25:
				return false

	# excluded all other cases. character is on the ground
	if !onground:
		onground = true
		jump(false)
	return true

func move_from_controls(x, y, z):
	if busy || !attack_end(): # can not move!
		return
	move(x, y, z)
func move(x, y, z):
	dir += Vector3(x, y, z)
	dir = dir.normalized()
	state = states.transit
func jump(pressed):
	if pressed && (canjump <= 0 || busy || blocking || stuck_timer > 0 || !attack_end()): # can not jump!
		return
	if pressed:
		if jumping: # prevent accidental jump-spamming in single frame
			return
		velocity.y = 0 # reset falling velocity when in mid-air
		jumping = true
		onground = false
		state = states.transit
		canjump -= 1 # diminish available jumps by one
		print("jump!")

		# reset dashing!
		dashing = false
		busy = false
		dash_timer = 0
		dash_direction = null
	else:
		jumping = false
		jump_force = 0
		jumping_timer = 0
		if onground:
			canjump = game.available_jumps
func dash(v, direction):
	if dash_timer > 0 || blocking || (crouching && !game.can_dash_while_crouching): # can not dash!
		return
	dash_direction = direction
	dashing = true
	busy = true
	move(v.x, v.y, v.z)

var attack_timer = 0.0
var current_attack = -1
var attack_damage_active = false
func get_attack(type): # get attack info from game database

	var attacks_TEMP = [
		############ LIGHT (claws)
		{ # mid
			"name": "claws",
			"anim": "claws_mid",
			"length": 0.27,
			"can_cancel" : false,
			"active_frames": {
				###
			}
		},
		{ # low
			"name": "low claws",
			"anim": "claws_low",
			"length": 0.27,
			"can_cancel" : false,
			"active_frames": {
				###
			}
		},
		{ # high
			"name": "high claws",
			"anim": "claws_high",
			"length": 0.3,
			"can_cancel" : false,
			"active_frames": {
				###
			}
		},
		############ HEAVY (kicks)
		{ # mid
			"name": "kick",
			"anim": "kick_mid",
			"length": 0.38,
			"can_cancel" : false,
			"active_frames": {
				### .... here the magic happens!
			}
		},
		{ # low
			"name": "low kick",
			"anim": "kick_low",
			"length": 0.38,
			"can_cancel" : false,
			"active_frames": {
				###
			}
		},
		{ # high
			"name": "high kick",
			"anim": "kick_high",
			"length": 0.38,
			"can_cancel" : false,
			"active_frames": {
				###
			}
		},
		############ SPECIAL 1 (guitar)
		{ # mid/low
			"name": "guitar smash",
			"anim": "guitar_smash",
			"length": 0.42,
			"can_cancel" : false,
			"active_frames": {
				###
			}
		}, # high
		{
			"name": "golf swing",
			"anim": "guitar_swing",
			"length": 0.52,
			"can_cancel" : false,
			"active_frames": {
				###
			}
		},
		############ GRAB (cord)
		{
			"name": "cord grab",
			"anim": "cord_throw",
			"length": 0.82,
			"can_cancel" : false,
			"active_frames": {
				###
			}
		},
		############ CROUCHED (tail, kicks, etc.)
		{
			"name": "tail sweep",
			"anim": "crouch_tail",
			"length": 0.19,
			"can_cancel" : false,
			"active_frames": {
				###
			}
		},
		{
			"name": "double kick",
			"anim": "crouch_kick",
			"length": 0.40,
			"can_cancel" : false,
			"active_frames": {
				###
			}
		}
	]
	if type != -1 && attacks_TEMP.size() > type:
		return attacks_TEMP[type]
#	if type != -1 && game.characters[character]["attacks"].size() > type:
#		return game.characters[character]["attacks"][type]
	return {
		"name": "none",
		"length": 0.0,
		"can_cancel": true,
		"active_frames": {}
	}
func attack_start(type):
	# can not attack!
	if busy || prop_inuse || blocking || !attack_end():
		return
	var attack_info = get_attack(type)
	if attack_info.size() == 0 || attack_info["length"] == 0 || attack_info["name"] == "none": # invalid attack
		return

	# reset blocking when attacking
	block(false)

	# set current attack and commence the move
	firing = true
	attack_timer = 0.0
	state = states.attacking
	current_attack = type
func attack_end(force = false):
	if current_attack == -1: # already not attacking
		return true
	if !force && current_attack != -1 && !get_attack(current_attack)["can_cancel"]: # can not cancel attack!
		return false
	busy = false
	firing = false
	attack_timer = 0.0
	current_attack = -1
	if onground:
		state = states.idle
	else:
		state = states.transit
	return true
func attack_update(delta):
	block_update(delta) # also update BLOCKING before continuing?
	if current_attack == -1: # not attacking -- return
		return
	# advance timer
	attack_timer += delta

	var attack_info = get_attack(current_attack)
	if attack_timer >= attack_info["length"]:
		attack_end(true)
	else:
		attack_update_active_frames() # oh boy
func attack_update_active_frames(): # here the magic happens!
	pass

var block_timer = 0.0
func block(pressed):
	if busy || crouching || !onground: # can not block!
		return
	if pressed:
		blocking = true
	else:
		blocking = false
		block_timer = 0.0
func block_update(delta):
	# TODO:
	# effects, sounds, counter etc.
	if blocking:
		block_timer += delta

func crouch(pressed):
	if !game.can_crouch:
		crouching = false
		return
	if blocking: # can not crouch!
		return
	if pressed:
		if !crouching:
			just_crouched = true # ugh!!
		crouching = true
	else:
		crouching = false

	if crouching:
		coll_capsule.shape.height = 1.0 - game.crouch_height_diff
		if onground:
			coll_capsule.translation.y = 0.904 - 0.5 * game.crouch_height_diff
	else:
		coll_capsule.shape.height = 1.0
		coll_capsule.translation.y = 0.904
func sprint(pressed):
	if pressed:
		sprinting = true
	else:
		sprinting = false

func state_update(delta): # neverending headache
	match state:
		states.ladder:
			body3D.collision_mask = 0

	# update "stuck"
	var _stuck = stuck_timer
	if stuck_timer > 0:
		stuck_timer -= delta
		cancel(true)
	if stuck_timer <= 0 && _stuck != stuck_timer:
		stuck_timer = 0
		if has_node("particles_drops"):
			$particles_drops.emitting = false
		state = states.idle

	# update "busy"
	if busy == false: # if "busy" is set to -1, it won't ever stop being locked until manually freed
		match state:
			states.switch,\
			states.terminal:
				state = states.idle

	# update animation playback speed blending? (for 3D animation)
	var mov_speed = velocity.length()
	if !game.is_2D():
		animset.playback_default_blend_time = 0.1

	# if attacking while mid-air, counter gravity a bit?
	if state == states.attacking && !onground:
		drag_coeff = Vector2(1, 1) - game.midair_attack_float_drag
	elif dashing && !onground:
		drag_coeff = Vector2(1, 0)
	else:
		drag_coeff = Vector2(1, 1)

	# if I'm freely moving, then reset to "transit" - ultimately, reset to "idle"
	if mov_speed == 0 && state == states.transit && !jumping && !dashing && touch_ground(): # keep adhered to the ground when idle!
		state = states.idle
		jump(false)
func anim_update():
	# the lesser spaghetti of animation
	var mov_speed = velocity.length()
	match state:
		states.idle:
			if crouching:
				if just_crouched:
					setAnimation("crouching")
				elif !("crouching" in current_anim):
					setAnimation("crouch")
			elif blocking:
				setAnimation("block")
			else:
				setAnimation("idle")
		states.transit:
			if dashing:
				match dash_direction:
					1: setAnimation("dash", 1.0)
					-1: setAnimation("backstep", 1.0)
					2: setAnimation("frontflip", 1.0)
					-2: setAnimation("backflip", 1.0)
			elif !onground:
				if jump_force > 1.0:
					setAnimation("jump", 1.0)
				elif velocity.y < 0:
					setAnimation("jump2", 1.0)
				else:
					setAnimation("jump3", 1.0)
			elif crouching:
				setAnimation("sneak", 0.26 * mov_speed)
			elif sprinting:
				setAnimation("sprint", 0.42 * mov_speed)
			else:
				setAnimation("run", 0.3 * mov_speed)
		states.attacking:
			if current_attack != -1:
				var attack_info = get_attack(current_attack)
				setAnimation(attack_info["anim"])
			pass
		states.ladder:
			setAnimation("climb", 1.5)
		states.vent:
			setAnimation("vent")
		states.switch:
			setAnimation("switch")
		states.terminal:
			setAnimation("terminal")
		states.turret:
			if RPC.am_master(self):
				body3D.transform = prop_inuse.get_player_transform()
			if firing:
				setAnimation("cannon_fire")
			else:
				setAnimation("20_cannon")
		states.stuck:
			setAnimation("stuck", 1 / (1 + stuck_timer))
		states.restrained:
			setAnimation("restr")
		states.detected:
			setAnimation("detect")
		states.ded:
			setAnimation("death")

	# prop anims
	if prop_inuse != null && prop_inuse is PhysProp:
		animtree.set("parameters/blender/blend_amount", 1)
	else:
		animtree.set("parameters/blender/blend_amount", 0)

	# 2D sprite mirroring
	if game.is_2D():
		if last_dir.x > 0:
			animsprite.flip_h = true
		if last_dir.x < 0:
			animsprite.flip_h = false

	# reset animation hack...
	just_crouched = false

func setAnimation(anim, speed = 1.0): # smart select animation based on name

	# 2D animations
	if game.is_2D():
		for a in animframes.get_animation_names():
			if anim in a:
				anim = a
				break
		if current_anim != anim:
			animsprite.play(anim)
			current_anim = anim
			print("setting animation to %s (speed %.2f)" % [anim, speed])
		return

	# 3D animations
	var found = false
	for a in animset.get_animation_list():
		if anim in a:
			anim = a
			found = true
			break
	if !found:
		return
	animset.playback_speed = abs(speed) # unnecessary?
	if current_anim != anim:
		animset.play(anim) # I don't wanna bother fixing this
#		animtree.set("parameters/speed/scale", speed)
#		statemachine.start(anim)
		current_anim = anim #animset.current_animation

###

func set_name(n):
	player_name = n
func set_color(color):
	player_color = color
	var nodes = game.get_all_childs($body3D/mesh) # this fires before _ready so we can't poll the "mesh" var
	for n in nodes:
		if n is MeshInstance && n.get_surface_material(0):
			n.get_surface_material(0).albedo_color = color

func refresh_equip():
	# only in 3D for now!
	if !game.is_2D():
		for m in game.items:
			var n = mesh.get_node("Armature/Skeleton/" + m)
			if n != null:
				n.visible = false
		for m in equipment:
			mesh.get_node("Armature/Skeleton/" + m).visible = true

###

var old_transform = Transform()
puppet func RPC_sync(packet = []): # called every frame!

	return #TEMPORARY!!!

	# owner of this object - start syncing this to other remotes
	if RPC.am_master(self):
		rpc_unreliable("RPC_sync", [
			body3D.get_global_transform() if body3D && body3D.get_global_transform() != old_transform else null,
			state,
			velocity,
			[stuck_timer, detected, hypnotized]
		])
	# not an owner ---> sync packet was received! update this "puppet" accordingly
	elif packet.size() > 0:
		body3D.transform = packet[0] if packet[0] != null else body3D.transform
		old_transform = body3D.transform
		state = packet[1]
		velocity = packet[2]
		# flags/additional data array
		stuck_timer = packet[3][0]
		detected = packet[3][1]
		hypnotized = packet[3][2]
remotesync func RPC_equip(equip, on):
	# sync equipment data for this actor
	if on:
		if equipment.has(equip):
			return
		equipment.append(equip)
	else:
		equipment.erase(equip)
	refresh_equip()

###

func _process(delta):
	if game.controller.zoom <= 0.1:
		body3D.visible = false
	else:
		body3D.visible = true

	# debugging info
	debug.loginfo("pos:        3D:" + str(pos) + " 2D:" + str(pos2D))
	debug.loginfo("lookat:     ", lookat)
	debug.loginfo("dir:        " + str(dir) + "     lastdir: " + str(last_dir))
	debug.loginfo("rot:        ", rot)
	if collider == null:
		debug.loginfo("collision:  object: ", collider)
	else:
		debug.logpaddedinfo("collision:  ", true, [28, 34], ["object:", collider, "pos:", collider.position, "normal:", collider.normal])
	debug.loginfo("grip_dist:  ", ground_grip_dist)
	debug.loginfo("coll_angle: ", collider_angle)
	debug.loginfo("tilt_angle: ", tilt_angle)
	debug.loginfo("velocity:   ", velocity)
	debug.loginfo("ups:        ", velocity.length())

	debug.loginfo("")

	if game.is_2D():
		debug.loginfo("anim:       " + str(current_anim) + " (speed: " + str(animsprite.speed_scale) + " mirror: " + str(animsprite.flip_h) + ")")
	else:
		debug.loginfo("anim:       " + str(current_anim) + " (speed: " + str(animset.playback_speed) + " blending: " + str(animset.playback_default_blend_time) + ")")
	debug.loginfo("state:      ", states.keys()[state])
	debug.loginfo("jumping:    ", jumping)
	debug.loginfo("dashing:    ", dashing)
	debug.loginfo("sprinting:  ", sprinting)
	debug.loginfo("crouching:  ", crouching)
	debug.loginfo("onground:   ", onground)
	debug.loginfo("stairing:   ", stairing)
	debug.loginfo("busy:       ", busy)
	debug.loginfo("stuck:      ", stuck_timer)

	debug.loginfo("")

	debug.loginfo("canjump:    ", canjump)
	debug.loginfo("jump_timer: ", jumping_timer)
	debug.loginfo("jump_force: ", jump_force)
	debug.loginfo("dash_timer: ", dash_timer)
	debug.loginfo("dash_dir:   ", dash_direction)

	debug.loginfo("")

	var attack_info = get_attack(current_attack)
	debug.loginfo("attack:     " + str(current_attack) + " (" + attack_info["name"] + ")")
	debug.loginfo("cancancel:  ", attack_info["can_cancel"])
	debug.loginfo("att_timer:  " + str(attack_timer) + "/" + str(attack_info["length"]))
	debug.loginfo("att_active: ", attack_damage_active)
	debug.loginfo("firing:     ", firing)
	debug.loginfo("blocking:   ", blocking)
	debug.loginfo("blck_timer: ", block_timer)

	debug.loginfo("")

func _physics_process(delta):
	body3D.collision_mask = 1 # collision is set to "disabled" by certain props

	# only perform basic animation updates if puppet (node controlled by other players remotely)
	if !RPC.am_master(self):
		anim_update()
		return

	if game.is_2D():
		pos2D = body2D.get_global_transform().origin
	else:
		pos = body3D.get_global_transform().origin
	attack_update(delta)
	state_update(delta)
	anim_update()

	# reset certain states after animation
	game.player.firing = false

#	if !busy || state == states.ladder:
	path_update() # P A T H F I N D I N G

	# actual movement vector scaled with speed
	var movement = Vector3()

	# game-specific logic (gravity, jumping etc.)
	match game.GAMEMODE:
		game.gm.plat, game.gm.fighting:
			speed = game.walk_speed # normal moving speed

			# SNEAKING
			if !dashing && !jumping && crouching && !game.can_sneak:
				speed = game.sneak_speed

			# BLOCKING
			if blocking:
				speed = game.block_walk_speed

			# JUMP
			if jumping:
				jumping_timer += delta # update jumping timer

				# start at full force, then reduce to zero
				var j_max = game.gravity + game.jump_strength
				jump_force = max(0, j_max - sqrt(jumping_timer) * game.jump_falloff) # gets smaller and smaller
				if jump_force > 0 && velocity.y > 0:
					velocity.y = 0

			# DASHING
			if dashing:
				dash_timer += delta # update dashing timer
				var max_dash_timer
				match dash_direction:
					1: max_dash_timer = game.dash_length
					-1: max_dash_timer = game.dash_length
					2: max_dash_timer = game.flips_length
					-2: max_dash_timer = game.flips_length
				if dash_timer <= max_dash_timer:
					dir = last_dir
					match dash_direction:
						1: speed = game.dash_speed
						-1: speed = game.backstep_speed
						2: speed = game.frontflip_speed
						-2: speed = game.backflip_speed
				else:
					# reset dashing
					dashing = false
					busy = false
					dash_timer = 0
					dash_direction = null
					if onground:
						state = states.idle
				if !onground:
					speed *= 4;

			movement = dir * speed # actual movement vector scaled with speed
			if !onground:
				movement *= game.air_speed_coeff
				if abs(velocity.x) > game.air_speed_max:
					movement.x = 0

			var max_fall_speed_falloff = (velocity.y / (game.max_fall_speed * max(drag_coeff.y, 0.1))) + 1 # caps falling speed
			movement += up * (max_fall_speed_falloff * game.gravity - jump_force) # add gravity / jumping force
		game.gm.fps:
			speed = game.walk_speed # normal moving speed
			if game.always_run:
				speed = game.run_speed

			# SNEAKING
			if !dashing && !jumping && crouching && game.can_sneak:
				speed = game.sneak_speed

			# SPRINTING
			if !dashing && !crouching && sprinting && game.can_sprint:
				speed = game.run_speed
				if game.always_run:
					speed = game.walk_speed

			# BLOCKING
			if blocking:
				speed = game.block_walk_speed

			# JUMP
			if jumping:
				jumping_timer += delta # update jumping timer

				# start at full force, then reduce to zero
				var j_max = game.gravity + game.jump_strength
				jump_force = max(0, j_max - sqrt(jumping_timer) * game.jump_falloff) # gets smaller and smaller
				if jump_force > 0 && velocity.y > 0:
					velocity.y = 0

			slope_correction()
			face_direction() # rotates the mesh accordingly
			movement = dir_tilt * speed # actual movement vector scaled with speed

#			movement = dir * speed # actual movement vector scaled with speed
			if !touch_ground():
				movement *= game.air_speed_coeff
				if abs(velocity.x) > game.air_speed_max:
					movement.x = 0
				if abs(velocity.z) > game.air_speed_max:
					movement.z = 0

			var max_fall_speed_falloff = (velocity.y / (game.max_fall_speed * max(drag_coeff.y, 0.1))) + 1 # caps falling speed
			movement += -up * (max_fall_speed_falloff * game.gravity - jump_force) # add gravity / jumping force
		game.gm.ludcorp:
			# speed calc
			if state != states.ladder:
				speed = 6
				slope_correction()
				face_direction() # rotates the mesh accordingly
			else:
				speed = 1.5
			movement = dir_tilt * speed
#			print(movement)
			if (tilt_angle > PI * 0.2): # for climbing, max angle was 1
				movement = Vector3() # fix walking on ripid slopes
			if (!body3D.is_on_floor() && velocity.y <= 0):
				movement = movement + up * (velocity.y - 50 * delta) # add gravity if falling

	# finalize the movement!
	if game.is_2D():
		if body2D.is_on_floor():
			velocity = Vector3() # infinite friction while on floor -- do this before calculations
								 # to maintain instant velocity later for state updates and checks
		var mov2D = Vector2(movement.x, movement.y)
		var vel2D = Vector2(velocity.x, velocity.y)
		velocity = body2D.move_and_slide(vel2D + mov2D, up2D)
		velocity *= drag_coeff # add optional drag due to floating / etc.

#		if body2D.is_on_floor():
		if !touch_ground(): # update ground check
			onground = false
			velocity = (-velocity * up2D) + (game.air_drag * velocity * hor2D) # air drag
			if canjump == game.available_jumps: # if fell off platform, remove first jump!
				canjump -= 1
	else:
		if touch_ground():
			velocity = Vector3() # infinite friction while on floor -- do this before calculations
								 # to maintain instant velocity later for state updates and checks

		velocity = body3D.move_and_slide(velocity + movement, up) # mid-air movement
		var drag_coeff3D = Vector3(drag_coeff.x, drag_coeff.y, drag_coeff.x)
		velocity *= drag_coeff3D # add optional drag due to floating / etc.

#		if body3D.is_on_floor():
		if !touch_ground(): # update ground check
			onground = false
			velocity = (velocity * up) + ((1.0 - game.air_drag) * velocity * hor)
			if canjump == game.available_jumps: # if fell off platform, remove first jump!
				canjump -= 1

	# value below epsilon threshold
	if velocity.length_squared() < 0.001:
		velocity = Vector3()

	# reset directional vector
	if dir != Vector3():
		last_dir = dir
	if !dashing:
		dir = Vector3()

func _ready():
	if !game.is_2D():
		for a in animset.get_animation_list():
			animset.animation_set_next(a,a)
		animset.animation_set_next("08_roll","06_crouch")
		animset.animation_set_next("10_jump","11_fall")
		animset.animation_set_next("12_land","02_idle")
		animset.animation_set_next("15_hland","02_idle")
		animset.animation_set_next("16_death","17_ded")
#		animset.animation_set_next("30_detected","02_idle")

		animset.playback_default_blend_time = 0.1
		animset.play("02_idle")

#		pos = body3D.get_global_transform().origin
	touch_ground()

	add_to_group("actors")
	add_to_group("rpc_sync")

	refresh_equip()

	$body3D/lights.free() # for testing purposes in editor
