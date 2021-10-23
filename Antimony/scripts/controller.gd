extends Node

onready var follow = get_node("follow")
onready var cam = get_node("follow/camera")
onready var cam_secondary = get_node("follow/camera/ViewportContainer/Viewport/cameraChild")
onready var cursor = get_node("cursor")

onready var follow2D = get_node("follow2D")
onready var cam2D = get_node("follow2D/camera2D")
onready var cursor2D = get_node("cursor2D")

var up = Vector3(0, 1, 0)

var offset = Vector3(0, 1, 0) # height off of the ground
var crouch_offset = Vector3(0, 0.75, 0) # height off of the ground
var smooth_offset = offset
var target = Vector3(0, 0, 0) # interpolation target
var lookat = target + smooth_offset

var target2D = Vector2(0, 0) # for 2D camera

var locked = false
var alt_camera = false
var alt_camera_zoom = 6.0

var max_height = 0.1 * PI
var min_height = - 0.5 * PI
var phi = 0.5
var theta = -0.5

var global_normal = Vector3(0, 0, 1)

var zoom = 13 # note: zoom works in reverse - lower value means closer to target! yes I know that's not how zoom works
var zoom_curve = 1
var zoom_target = zoom # zoom's interpolation target
var zoom_delta_speed = 0.9
var min_zoom = 0.5
var max_zoom = 50.0

var camera_tilt = Vector3()
var camera_tilt_max = Vector3(0.03, 0.03, 0.03)

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

var camera_shake_force = Vector2()
func weapon_shake(strength):
	camera_shake_force.x = strength * (2.0 * randf() - 1.0) * Game.camera_weapon_shake_force.x
	camera_shake_force.y = strength * randf() * Game.camera_weapon_shake_force.y
func shake_update(delta):
	phi += camera_shake_force.x * 60 * delta
	theta += camera_shake_force.y * 60 * delta
	while phi < 0:
		phi += 2 * PI
	while phi > 2 * PI:
		phi -= 2 * PI
	theta = max(min_height, theta)
	theta = min(max_height, theta)

	camera_shake_force.x = Game.delta_interpolate(camera_shake_force.x, 0, 0.5, delta)
	camera_shake_force.y = Game.delta_interpolate(camera_shake_force.y, 0, 0.5, delta)

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
	# adjust sensitivity by camera FOV
	s *= cam.fov / Game.camera_fov
	phi += x * s
	theta += y * s
	while phi < 0:
		phi += 2 * PI
	while phi > 2 * PI:
		phi -= 2 * PI
	theta = max(min_height, theta)
	theta = min(max_height, theta)

# compensate for zoom levels
func move3D(r, s = 1.0):
	target += r * s * (0.75 + zoom_curve * 0.95)
func move2D(x, y, s = 100.0):
	target2D += Vector2(x, y) * s * (0.75 + zoom_curve * 0.95)

func center():
	if Game.is_2D():
		match Game.GAMEMODE:
			Game.gm.plat:
				target2D = Game.player.pos2D
			Game.gm.fighting:
				target2D = Game.player.pos2D # temp
	else:
		target = Game.player.pos

func update_raycast():
	if Game.is_2D():
		cursor.visible = false
	else:
		var masks = 1 + 4 + 8
#		var proj_origin = cam.project_ray_origin(get_viewport().get_mouse_position())
#		var proj_normal = cam.project_ray_normal(get_viewport().get_mouse_position())
		var proj_origin = cam.global_transform.origin
		var proj_normal = global_normal

		match Game.GAMEMODE:
			Game.gm.fps:

				# first raycast - from camera to 1000 in front
				var from = proj_origin
				var to = from + proj_normal * 1000
				var result = Game.space_state.intersect_ray(from, to, [], masks, true, true)

				# hit!
				if result:
					pick[0] = result.duplicate()
					update_cursor(false)
				else:
					pick = [{},{},{}]
					cursor.visible = false

			Game.gm.rts, Game.gm.ludcorp:
				# first raycast - from 1000 units behind camera to 1000 in front
				var from = proj_origin - proj_normal * 1000
				var to = from + proj_normal * 2000
				var result = Game.space_state.intersect_ray(from, to, [], masks, true, true)

				# raycast twice because Godot is too cool to recognize collision normals, even for concave shapes >:(
				if result:
					if ((proj_origin - result.position).normalized() - proj_normal).length() < 1:
						from = proj_origin # if collision was behind camera, do again from the camera
					else:
						from = result.position + proj_normal * 0.1 # if not, do from the first collision point onwards
					to = from + proj_normal * 1000
					var result2 = Game.space_state.intersect_ray(from, to, [], masks, true, true)

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
		#			Debug.loginfo(str(m))
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
	match Game.GAMEMODE:
		Game.gm.fps:
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
	match Game.GAMEMODE:
		Game.gm.fps:
			if UI.state <= 0: # not in menus
				# mouse movement
				if event is InputEventMouseMotion:
	#				if Input.is_action_pressed("camera_zoomdrag"): # drag zoom (ctrl + orbit)
	#					zoom(Game.settings["controls"]["zoom_sens"] * event.relative.y * 0.05)
	#				if Input.is_action_pressed("camera_drag") && !locked: # pan camera (shift + orbit)
	#					move_pan(-event.relative.x * 0.01, -event.relative.y * 0.01)
	#				else:
					orbit(-event.relative.x, -event.relative.y, Game.settings["controls"]["mouse_sens"] * 0.0035)
	#			if Input.is_action_pressed("camera_zoomin"):
	#				zoom(-Game.settings["controls"]["zoom_sens"])
	#			if Input.is_action_pressed("camera_zoomout"):
	#				zoom(Game.settings["controls"]["zoom_sens"])

				# fire action
				if Input.is_action_just_pressed("shoot"):
					Game.weaps.press_trigger(0, true)
				elif Input.is_action_just_released("shoot"):
					Game.weaps.press_trigger(0, false)
				if Input.is_action_just_pressed("shoot_secondary"):
					Game.weaps.press_trigger(1, true)
				elif Input.is_action_just_released("shoot_secondary"):
					Game.weaps.press_trigger(1, false)
				if Input.is_action_just_pressed("shoot_tertiary"):
					Game.weaps.press_trigger(2, true)
				elif Input.is_action_just_released("shoot_tertiary"):
					Game.weaps.press_trigger(2, false)

				# reloading
				if Input.is_action_just_pressed("weap_reload"):
					Game.weaps.reload(false)

				# use items
				# TODO

				# fire selection
				# TODO

				# weapon selection
				# TODO

				# item selection
				# TODO

				# crouching
				if Input.is_action_pressed("crouch"):
					Game.player.crouch(true)
				if Input.is_action_just_released("crouch"):
					Game.player.crouch(false)
				# sprinting
				if Input.is_action_just_pressed("sprint"):
					Game.player.sprint(true)
				if Input.is_action_just_released("sprint"):
					Game.player.sprint(false)

				# camera
				if Input.is_action_just_pressed("camera_thirdperson"):
					alt_camera = !alt_camera
		Game.gm.rts, Game.gm.ludcorp:
			# mouse movement
			if event is InputEventMouseMotion:
				if Input.is_action_pressed("camera_orbit"): # orbit camera
					if Input.is_action_pressed("camera_zoomdrag"): # drag zoom (ctrl + orbit)
						zoom(Game.settings["controls"]["zoom_sens"] * event.relative.y * 0.05)
					elif Input.is_action_pressed("camera_drag") && !locked: # pan camera (shift + orbit)
						move_pan(-event.relative.x * 0.01, -event.relative.y * 0.01)
					else:
						orbit(-event.relative.x, -event.relative.y, Game.settings["controls"]["mouse_sens"] * 0.0075)

			# zooming only if CTRL is pressed - otherwise use the keybind to scroll items
			if !alt_camera:
				if Input.is_action_pressed("camera_zoomin"):
					zoom(-Game.settings["controls"]["zoom_sens"])
				if Input.is_action_pressed("camera_zoomout"):
					zoom(Game.settings["controls"]["zoom_sens"])
			# only if mouse is NOT on inv. panels
			if UI.handle_input <= 0:
				if Input.is_action_just_released("player_command") && !pick[0].empty(): # send actor on an adventure!
					if hl_prop != null:
						Game.player.reach_prop(hl_prop)
					else:
						command_point = pick[0].position
						command_point += pick[0].normal * 0.2 # offset by normal
						Game.player.travel(command_point)
				if Input.is_action_just_released("player_cancel"): # cancel adventure....
					Game.player.cancel()
				if Input.is_action_just_pressed("character_switch"): # switch available character
					Game.switch_character()
					center()
				if !alt_camera: # camera locking / centering / etc.
					if Input.is_action_pressed("camera_center"):
						center()
					if Input.is_action_just_pressed("camera_follow"):
						locked = !locked
		Game.gm.fighting:
			# crouching
			if Input.is_action_pressed("crouch"):
				Game.player.crouch(true)
			if Input.is_action_just_released("crouch"):
				Game.player.crouch(false)
			# blocking
			if Input.is_action_just_pressed("block"):
				Game.player.block(true)
			if Input.is_action_just_released("block"):
				Game.player.block(false)
			# attacks
			if Game.player.crouching: # crouched attacks
				if Input.is_action_just_pressed("attack_0"): # light attack (tail sweep)
					Game.player.attack_start(9)
				if Input.is_action_just_pressed("attack_1"): # heavy attack (double kick)
					Game.player.attack_start(10)
			elif Game.player.onground: # standing attacks
				if Input.is_action_just_pressed("attack_0"): # light attacks (claws)
					if Input.is_action_pressed("move_up"):
						Game.player.attack_start(2) # high claws
					elif Input.is_action_pressed("move_down"):
						Game.player.attack_start(1) # low claws
					else:
						Game.player.attack_start(0) # mid claws
				if Input.is_action_just_pressed("attack_1"): # heavy attacks (kicks)
					if Input.is_action_pressed("move_up"):
						Game.player.attack_start(5) # high kick
					elif Input.is_action_pressed("move_down"):
						Game.player.attack_start(4) # low kick
					else:
						Game.player.attack_start(3) # mid kick
				if Input.is_action_just_pressed("attack_2"): # special attacks
					if Input.is_action_pressed("move_up"):
						Game.player.attack_start(7) # guitar golf swing
					else:
						Game.player.attack_start(6) # guitar smash
				if Input.is_action_just_pressed("attack_3"): # grabs
					Game.player.attack_start(8) # cord grab
			else: # mid-air attacks
				if Input.is_action_just_pressed("attack_2"): # special attacks
					Game.player.attack_start(6) # guitar smash

func _process(delta):
	if !UI.paused:

#		if UI.handle_input == 0:
#			update_raycast()

		# GAME-specific logic
		match Game.GAMEMODE:
			Game.gm.fps:
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

					# update camera tilt
					var speed_coeff = Game.player.last_velocity.length() / Game.run_speed
					camera_tilt.x = Game.delta_interpolate(camera_tilt.x, dir.z * camera_tilt_max.x * speed_coeff, 0.25, delta)
					camera_tilt.y = Game.delta_interpolate(camera_tilt.y, dir.x * camera_tilt_max.y * speed_coeff, 0.25, delta)
					camera_tilt.z = Game.delta_interpolate(camera_tilt.z, -dir.x * camera_tilt_max.z * speed_coeff, 0.25, delta)

#					if is_nan(camera_tilt.x):
#						var a = 2

					# final movement calc
					if dir != Vector3():
						dir = dir.rotated(Vector3(0, 1, 0), phi)
						Game.player.move_from_controls(dir.x, dir.y, dir.z)

					# jumping
					if (Input.is_action_pressed("jump") && Game.jump_spam) || Input.is_action_just_pressed("jump"):
						Game.player.jump(true)
					if Input.is_action_just_released("jump"):
						Game.player.jump(false)
			Game.gm.ludcorp:
				if Input.is_action_pressed("shoot"):
					match Game.player.state:
						Actor.states.turret:
							Game.player.prop_inuse.fire()

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
			Game.gm.plat, Game.gm.fighting:
				# movement
				if Input.is_action_pressed("move_left"):
					Game.player.move_from_controls(-1, 0, 0)
				if Input.is_action_pressed("move_right"):
					Game.player.move_from_controls(1, 0, 0)
				# jumping
				if (Input.is_action_pressed("jump") && Game.jump_spam) || Input.is_action_just_pressed("jump"):
					Game.player.jump(true)
				if Input.is_action_just_released("jump"):
					Game.player.jump(false)
				# dash
				if Input.is_action_just_pressed("dash"):
					match Game.player.state:
						Actor.states.idle:
							if Input.is_action_pressed("move_up"):
								Game.player.dash(Game.player.last_dir, -2) # backflip (cartwheel)
							else:
								Game.player.dash(Game.player.last_dir, -1) # back-step
						Actor.states.transit:
							if Input.is_action_pressed("move_up"):
#								Game.player.dash(Game.player.last_dir, 2) # frontflip while sneaking?
								pass
							else:
								Game.player.dash(Game.player.last_dir, 1) # forward dash

		if locked: # follow player
			center()

	# update certain special physics (camera shakes)
	shake_update(delta)

	# how do the LookAt and Camera origin behave? (GAME-specific logic)
	var lookat_offset = offset
	if Game.can_sneak && Game.player.crouching:
		lookat_offset = crouch_offset
	smooth_offset = Game.delta_interpolate(smooth_offset, lookat_offset, 0.3, delta)
	var new_lookat = target + smooth_offset
	var new_zoom = zoom_target
	match Game.GAMEMODE:
		Game.gm.fps:
			new_lookat = Game.player.pos + smooth_offset
			if alt_camera:
				new_zoom = alt_camera_zoom
			else:
				new_zoom = zoom_target
		_: # default case
			if alt_camera:
				new_lookat = Game.player.pos + smooth_offset #Game.player.pos
				new_zoom = alt_camera_zoom
			else:
				new_lookat = target + smooth_offset
				new_zoom = zoom_target

	lookat = Game.delta_interpolate(lookat, new_lookat, camera_3d_coeff, delta)
	zoom = Game.delta_interpolate(zoom, new_zoom, zoom_delta_speed, delta)
	zoom_curve = 0.0075 * zoom * zoom
	cam.translation.z = 20.0 * zoom_curve

	# update camera transform
	# for camera tilt:
	# X comes from dir.Z and rotates around the Y axis ---> .rotated(Vector3(1, 0, 0),  dir.z)
	# Z comes from dir.X and rotates around the Z axis ---> .rotated(Vector3(0, 0, 1), -dir.x)
	follow.set_transform(Transform(
		Transform(Basis()).rotated(Vector3(1, 0, 0), theta).rotated(
			Vector3(1, 0, 0), camera_tilt.x).rotated(
			Vector3(0, 0, 1), camera_tilt.z).rotated(
#			Vector3(0, 1, 0), camera_tilt.y).rotated(
			up, phi).basis,
		Vector3(0,0,0)))
	follow.global_translate(lookat)

	# update secondary camera
	cam_secondary.global_transform = cam.global_transform

	# update 2D camera
	cam2D.position = Game.delta_interpolate(cam2D.position, target2D, camera_2d_coeff, delta)
	cam2D.position.y += Game.player.velocity.y * camera_2d_vertical_compensation
	cam2D.zoom = Vector2(0.01 + zoom, 0.01 + zoom)

	# update weapon & camera bobbing
	Game.weaps.camera_tilt = camera_tilt * Vector3(-1, -1, 1)

	# update quick camera normal
	var cam_origin = cam.get_global_transform().origin
	var cam_lookat_transformed = cam.get_global_transform().xform(Vector3(0, 0, -1))
	global_normal = (cam_lookat_transformed - cam_origin).normalized()

	# refresh global physic space state
	Game.update_physics_space_state()

	# update reycasts & cursors
	if UI.handle_input == 0:
		update_raycast()

	# debugging info
	match Game.GAMEMODE:
		Game.gm.fps, Game.gm.ludcorp:
			if !pick[0].empty():
				Debug.point(pick[0].position, Color(1, 1, 0))
				Debug.line(pick[0].position, pick[0].position + pick[0].normal, Color(1, 1, 0))
			if !pick[1].empty():
				Debug.point(pick[1].position, Color(1, 0, 0))
				Debug.line(pick[1].position, pick[1].position + pick[1].normal, Color(1, 0, 0))
			Debug.point(command_point, Color(0,1,0))

	Debug.logpaddedinfo("camera:     ", true, [10, 10, 34, 20], ["phi:", phi, "theta:", theta, "3D:", cam.get_global_transform().origin, "2D:", cam2D.position, "zoom:", zoom])
	Debug.loginfo("colliders:  ", pick[0])
	Debug.loginfo("            ", pick[1])
	Debug.loginfo("            ", pick[2])

func _ready():
	Game.controller = self

#	cam.set_as_toplevel(true)
	cursor.set_as_toplevel(true)
	cursor.transform = Transform()
