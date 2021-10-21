extends Node

onready var follow = get_node("follow")
onready var cam = get_node("follow/camera")
onready var cursor = get_node("cursor")

onready var follow2D = get_node("follow2D")
onready var cam2D = get_node("follow2D/camera2D")
onready var cursor2D = get_node("cursor2D")

var up = Vector3(0, 1, 0)

var offset = Vector3(0, 1, 0) # height off of the ground
var crouch_offset = Vector3(0, 0.75, 0) # height off of the ground
var target = Vector3(0, 0, 0) # interpolation target
var lookat = target + offset

var target2D = Vector2(0, 0) # for 2D camera

var locked = false
var alt_camera = false
var alt_camera_zoom = 6.0

var max_height = 0.1 * PI
var min_height = - 0.5 * PI
var phi = 0.5
var theta = -0.5

var zoom = 13 # note: zoom works in reverse - lower value means closer to target! yes I know that's not how zoom works
var zoom_curve = 1
var zoom_target = zoom # zoom's interpolation target
var zoom_delta_speed = 0.9
var min_zoom = 0.5
var max_zoom = 50.0

var camera_tilt = 0.0
var camera_tilt_max = 0.03

var camera_3d_coeff = Vector3(1, 1, 1)
var camera_2d_coeff = Vector2(0.15, 0.15) #0.0175
var camera_2d_vertical_compensation = 0.0175

#var mouse_on_ui = false

var pick = [
	{}, {}, {}
]
var hl_prop = null
var command_point = Vector3()
var max_height_diff = 0.5

func zoom(z):
	zoom_target += z
	zoom_target = max(zoom_target, min_zoom)
	zoom_target = min(zoom_target, max_zoom)
func init_zoom(minz, maxz, curz):
	min_zoom = minz
	max_zoom = maxz
	zoom = curz
	zoom_target = curz
func move_naive(x, y, s = 1.0):
	move3D(Vector3(x, 0, y).rotated(up, phi), s)
	move2D(x, y, s * 100)
func move_pan(x, y, s = 1.0):
	move3D(Vector3(x, 0, y).rotated(Vector3(1, 0, 0), theta+0.5*PI).rotated(up, phi), s)
	move2D(x, y, s * 100)
func orbit(x, y, s = 1.0):
	phi += x * s
	theta += y * s
	while phi < 0:
		phi += 2 * PI
	while phi > 2 * PI:
		phi -= 2 * PI
	theta = max(min_height, theta)
	theta = min(max_height, theta)

func delta_interpolate(old, new, s = 1.0):
	return old + (new - old) * s

# compensate for zoom levels
func move3D(r, s = 1.0):
	target += r * s * (0.75 + zoom_curve * 0.95)
func move2D(x, y, s = 100.0):
	target2D += Vector2(x, y) * s * (0.75 + zoom_curve * 0.95)

func center():
	if game.is_2D():
		match game.GAMEMODE:
			game.gm.plat:
				target2D = game.player.pos2D
			game.gm.fighting:
				target2D = game.player.pos2D # temp
	else:
		target = game.player.pos

func update_raycast():
	if game.is_2D():
		cursor.visible = false
	else:
		var masks = 1 + 4 + 8
		var proj_origin = cam.project_ray_origin(get_viewport().get_mouse_position())
		var proj_normal = cam.project_ray_normal(get_viewport().get_mouse_position())

		match game.GAMEMODE:
			game.gm.fps:

				# first raycast - from camera to 1000 in front
				var from = proj_origin
				var to = from + proj_normal * 1000
				var result = game.space_state.intersect_ray(from, to, [], masks, true, true)

				# hit!
				if result:
					pick[0] = result.duplicate()
					update_cursor(false)
				else:
					pick = [{},{},{}]
					cursor.visible = false

			game.gm.rts, game.gm.ludcorp:
				# first raycast - from 1000 units behind camera to 1000 in front
				var from = proj_origin - proj_normal * 1000
				var to = from + proj_normal * 2000
				var result = game.space_state.intersect_ray(from, to, [], masks, true, true)

				# raycast twice because Godot is too cool to recognize collision normals, even for concave shapes >:(
				if result:
					if ((proj_origin - result.position).normalized() - proj_normal).length() < 1:
						from = proj_origin # if collision was behind camera, do again from the camera
					else:
						from = result.position + proj_normal * 0.1 # if not, do from the first collision point onwards
					to = from + proj_normal * 1000
					var result2 = game.space_state.intersect_ray(from, to, [], masks, true, true)

					# final, correct collision point!
					if result2:
						pick[0] = result2.duplicate()
					else:
						pick[0] = result.duplicate()
						pick[1] = result2.duplicate()

					# mouse hover over props
					get_tree().call_group_flags(2, "props", "highlight", false)
					hl_prop = null
					var m = pick[0].collider.collision_layer
		#			debug.loginfo(str(m))
					match m:
						4, 8:
							hl_prop = pick[0].collider.get_parent()
							hl_prop.highlight(true)
		#				8:
		#					hl_prop = pick[0].collider
		#					pick[0].collider.highlight(true)
					update_cursor(false)
				else:
					pick = [{},{},{}]
					cursor.visible = false
func update_cursor(snap):
	match game.GAMEMODE:
		game.gm.fps:
			cursor.visible = false
			return
	cursor.visible = true

	var cur_pos = Vector3()

	if snap:
		cur_pos = pick[0].position.floor() + Vector3(0.5, 0.5, 0.5) - 0.5 * pick[0].normal
	else:
		cur_pos = pick[0].position
	cursor.translation = cur_pos

	if pick[0].normal != Vector3(0, 1, 0) && pick[0].normal != Vector3(0, -1, 0):
		cursor.look_at(cur_pos + pick[0].normal, Vector3(0, 1, 0))
	else:
		cursor.look_at(cur_pos + pick[0].normal, Vector3(1, 0, 0))

func _input(event):
	if UI.paused:
		return

	# GAME-specific logic
	match game.GAMEMODE:
		game.gm.fps:
			if UI.state <= 0: # not in menus
				# mouse movement
				if event is InputEventMouseMotion:
	#				if Input.is_action_pressed("camera_zoomdrag"): # drag zoom (ctrl + orbit)
	#					zoom(game.settings["controls"]["zoom_sens"] * event.relative.y * 0.05)
	#				if Input.is_action_pressed("camera_drag") && !locked: # pan camera (shift + orbit)
	#					move_pan(-event.relative.x * 0.01, -event.relative.y * 0.01)
	#				else:
					orbit(-event.relative.x, -event.relative.y, game.settings["controls"]["mouse_sens"] * 0.0035)
	#			if Input.is_action_pressed("camera_zoomin"):
	#				zoom(-game.settings["controls"]["zoom_sens"])
	#			if Input.is_action_pressed("camera_zoomout"):
	#				zoom(game.settings["controls"]["zoom_sens"])
				# crouching
				if Input.is_action_pressed("crouch"):
					game.player.crouch(true)
				if Input.is_action_just_released("crouch"):
					game.player.crouch(false)
				# sprinting
				if Input.is_action_just_pressed("sprint"):
					game.player.sprint(true)
				if Input.is_action_just_released("sprint"):
					game.player.sprint(false)

				# camera
				if Input.is_action_just_pressed("camera_thirdperson"):
					alt_camera = !alt_camera
		game.gm.rts, game.gm.ludcorp:
			# mouse movement
			if event is InputEventMouseMotion:
				if Input.is_action_pressed("camera_orbit"): # orbit camera
					if Input.is_action_pressed("camera_zoomdrag"): # drag zoom (ctrl + orbit)
						zoom(game.settings["controls"]["zoom_sens"] * event.relative.y * 0.05)
					elif Input.is_action_pressed("camera_drag") && !locked: # pan camera (shift + orbit)
						move_pan(-event.relative.x * 0.01, -event.relative.y * 0.01)
					else:
						orbit(-event.relative.x, -event.relative.y, game.settings["controls"]["mouse_sens"] * 0.0075)

			# zooming only if CTRL is pressed - otherwise use the keybind to scroll items
			if !alt_camera:
				if Input.is_action_pressed("camera_zoomin"):
					zoom(-game.settings["controls"]["zoom_sens"])
				if Input.is_action_pressed("camera_zoomout"):
					zoom(game.settings["controls"]["zoom_sens"])
			# only if mouse is NOT on inv. panels
			if UI.handle_input <= 0:
				if Input.is_action_just_released("player_command") && !pick[0].empty(): # send actor on an adventure!
					if hl_prop != null:
						game.player.reach_prop(hl_prop)
					else:
						command_point = pick[0].position
						command_point += pick[0].normal * 0.2 # offset by normal
						game.player.travel(command_point)
				if Input.is_action_just_released("player_cancel"): # cancel adventure....
					game.player.cancel()
				if Input.is_action_just_pressed("character_switch"): # switch available character
					game.switch_character()
					center()
				if !alt_camera: # camera locking / centering / etc.
					if Input.is_action_pressed("camera_center"):
						center()
					if Input.is_action_just_pressed("camera_follow"):
						locked = !locked
		game.gm.fighting:
			# crouching
			if Input.is_action_pressed("crouch"):
				game.player.crouch(true)
			if Input.is_action_just_released("crouch"):
				game.player.crouch(false)
			# blocking
			if Input.is_action_just_pressed("block"):
				game.player.block(true)
			if Input.is_action_just_released("block"):
				game.player.block(false)
			# attacks
			if game.player.crouching: # crouched attacks
				if Input.is_action_just_pressed("attack_0"): # light attack (tail sweep)
					game.player.attack_start(9)
				if Input.is_action_just_pressed("attack_1"): # heavy attack (double kick)
					game.player.attack_start(10)
			elif game.player.onground: # standing attacks
				if Input.is_action_just_pressed("attack_0"): # light attacks (claws)
					if Input.is_action_pressed("move_up"):
						game.player.attack_start(2) # high claws
					elif Input.is_action_pressed("move_down"):
						game.player.attack_start(1) # low claws
					else:
						game.player.attack_start(0) # mid claws
				if Input.is_action_just_pressed("attack_1"): # heavy attacks (kicks)
					if Input.is_action_pressed("move_up"):
						game.player.attack_start(5) # high kick
					elif Input.is_action_pressed("move_down"):
						game.player.attack_start(4) # low kick
					else:
						game.player.attack_start(3) # mid kick
				if Input.is_action_just_pressed("attack_2"): # special attacks
					if Input.is_action_pressed("move_up"):
						game.player.attack_start(7) # guitar golf swing
					else:
						game.player.attack_start(6) # guitar smash
				if Input.is_action_just_pressed("attack_3"): # grabs
					game.player.attack_start(8) # cord grab
			else: # mid-air attacks
				if Input.is_action_just_pressed("attack_2"): # special attacks
					game.player.attack_start(6) # guitar smash

func _process(delta):
	if !UI.paused:

		if UI.handle_input == 0:
			update_raycast()

		# GAME-specific logic
		match game.GAMEMODE:
			game.gm.fps:
				if UI.state <= 0: # not in menus
					# movement
					var dir = Vector3()
					if Input.is_action_pressed("move_up"):
						dir += Vector3(0, 0, -1)
					if Input.is_action_pressed("move_down"):
						dir += Vector3(0, 0, 1)
					if Input.is_action_pressed("move_left"):
						dir += Vector3(-1, 0, 0)
					if Input.is_action_pressed("move_right"):
						dir += Vector3(1, 0, 0)
					var speed_coeff = game.player.velocity.length() / game.sprint_speed
					camera_tilt = delta_interpolate(camera_tilt, -dir.x * camera_tilt_max * speed_coeff, 0.25)
					if dir != Vector3():
						dir = dir.rotated(Vector3(0, 1, 0), phi)
						game.player.move_from_controls(dir.x, dir.y, dir.z)

					# jumping
					if (Input.is_action_pressed("jump") && game.jump_spam) || Input.is_action_just_pressed("jump"):
						game.player.jump(true)
					if Input.is_action_just_released("jump"):
						game.player.jump(false)
			game.gm.ludcorp:
				if Input.is_action_pressed("shoot"):
					match game.player.state:
						Actor.states.turret:
							game.player.prop_inuse.fire()

				var s = 0.25 # TODO: camera sensitivity
				if !locked:
					if Input.is_action_pressed("move_up"):
						move_naive(0, -s)
					if Input.is_action_pressed("move_down"):
						move_naive(0, s)
					if Input.is_action_pressed("move_left"):
						move_naive(-s, 0)
					if Input.is_action_pressed("move_right"):
						move_naive(s, 0)
			game.gm.plat, game.gm.fighting:
				# movement
				if Input.is_action_pressed("move_left"):
					game.player.move_from_controls(-1, 0, 0)
				if Input.is_action_pressed("move_right"):
					game.player.move_from_controls(1, 0, 0)
				# jumping
				if (Input.is_action_pressed("jump") && game.jump_spam) || Input.is_action_just_pressed("jump"):
					game.player.jump(true)
				if Input.is_action_just_released("jump"):
					game.player.jump(false)
				# dash
				if Input.is_action_just_pressed("dash"):
					match game.player.state:
						Actor.states.idle:
							if Input.is_action_pressed("move_up"):
								game.player.dash(game.player.last_dir, -2) # backflip (cartwheel)
							else:
								game.player.dash(game.player.last_dir, -1) # back-step
						Actor.states.transit:
							if Input.is_action_pressed("move_up"):
#								game.player.dash(game.player.last_dir, 2) # frontflip while sneaking?
								pass
							else:
								game.player.dash(game.player.last_dir, 1) # forward dash

		if locked: # follow player
			center()

	# how do the LookAt and Camera origin behave? (GAME-specific logic)
	var lookat_offset = offset
	if game.can_sneak && game.player.crouching:
		lookat_offset = crouch_offset
	var new_lookat = target + lookat_offset
	var new_zoom = zoom_target
	match game.GAMEMODE:
		game.gm.fps:
			new_lookat = game.player.pos + lookat_offset
			if alt_camera:
				new_zoom = alt_camera_zoom
			else:
				new_zoom = zoom_target
		_: # default case
			if alt_camera:
				new_lookat = game.player.pos + lookat_offset #game.player.pos
				new_zoom = alt_camera_zoom
			else:
				new_lookat = target + lookat_offset
				new_zoom = zoom_target

	lookat = delta_interpolate(lookat, new_lookat, camera_3d_coeff)
	zoom = delta_interpolate(zoom, new_zoom, zoom_delta_speed)
	zoom_curve = 0.0075 * zoom * zoom
	cam.translation.z = 20.0 * zoom_curve

	# update camera transform
	follow.set_transform(Transform(
		Transform(Basis()).rotated(Vector3(1, 0, 0), theta).rotated(Vector3(0, 0, 1), camera_tilt).rotated(up, phi).basis,
		Vector3(0,0,0)))
	follow.global_translate(lookat)

	# update 2D camera
	cam2D.position = delta_interpolate(cam2D.position, target2D, camera_2d_coeff)
	cam2D.position.y += game.player.velocity.y * camera_2d_vertical_compensation
	cam2D.zoom = Vector2(0.01 + zoom, 0.01 + zoom)

	# debugging info
	match game.GAMEMODE:
		game.gm.fps, game.gm.ludcorp:
			if !pick[0].empty():
				debug.point(pick[0].position, Color(1, 1, 0))
				debug.line(pick[0].position, pick[0].position + pick[0].normal, Color(1, 1, 0))
			if !pick[1].empty():
				debug.point(pick[1].position, Color(1, 0, 0))
				debug.line(pick[1].position, pick[1].position + pick[1].normal, Color(1, 0, 0))
			debug.point(command_point, Color(0,1,0))

	debug.logpaddedinfo("camera:     ", true, [10, 10, 34, 20], ["phi:", phi, "theta:", theta, "3D:", cam.get_global_transform().origin, "2D:", cam2D.position, "zoom:", zoom])
	debug.loginfo("colliders:  ", pick[0])
	debug.loginfo("            ", pick[1])
	debug.loginfo("            ", pick[2])

func _ready():
	game.controller = self

#	cam.set_as_toplevel(true)
	cursor.set_as_toplevel(true)
	cursor.transform = Transform()
