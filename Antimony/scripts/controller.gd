extends Node

onready var follow = get_node("follow")
onready var cam = get_node("follow/camera")
onready var cam_secondary = cam.get_node("ViewportContainer/Viewport/cameraChild")
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

var raypicks = []
var highlighted_objects = []
var selected_objects = []
var command_points = []
#var max_height_diff = 0.5

func _get_item(arr, n = 0):
	if arr.empty():
		return null
	if n == -1:
		return arr
	return arr[n]
func _add_item(arr, item):
	if item != null && !arr.has(item):
		arr.push_back(item)
func _rem_item(arr, item):
	if item == null: # unselect ALL
		arr = []
	elif arr.has(item):
		arr.erase(item)

func get_raypick(n = 0):
	return _get_item(raypicks, n)
func get_highlight(n = 0):
	return _get_item(highlighted_objects, n)
func get_selected(n = 0):
	return _get_item(selected_objects, n)

func highlight(item):
	item.highlight(true)
	_add_item(highlighted_objects, item)
func select(item):
	_add_item(selected_objects, item)
func unselect(item):
	_rem_item(selected_objects, item)
func command_point(point):
	Game.player.travel(command_points)
	pass

func update_raycast():
	# reset prop highlight & raypicks
	get_tree().call_group_flags(2, "props", "highlight", false)
	highlighted_objects = []
	raypicks = []
	cursor.visible = false

	if Game.is_2D():
		pass # TODO: 2D raypicking...
	else:
		var masks = 1 + 4 + 8 # todo?
		var proj_origin = cam.project_ray_origin(get_viewport().get_mouse_position())
		var proj_normal = cam.project_ray_normal(get_viewport().get_mouse_position())

		# first raycast - from camera to 1000 in front
		var from = proj_origin
		var checking = true
		while checking:
			var to = from + proj_normal * 1000
			var result = Game.space_state.intersect_ray(from, to, [], masks, true, true)

			# hit!
			if result:
				_add_item(raypicks, result.duplicate())
				var m = result.collider.collision_layer
				match m:
					4, 8:
						highlight(result.collider.get_parent())
#					8:
#						highlight(result.collider)
				from = result.position + proj_normal * 0.001 # advance raycast along -- add EPSILON to avoid infinite loops!
			else:
				checking = false

	# remove first result in special cases
	if Game.raypick_ignore_first:
		raypicks.pop_front()

	# update cursor accordingly
	update_cursor()

	# normalize... normals, and add screen coords
	for pick in raypicks:
		pick["screencoords"] = cam.unproject_position(pick.position)
		Debug.vector(pick.position, pick.normal, Color(1, 1, 0), true)
func update_cursor():
	# no valid raypicking results
	if get_raypick() == null:
		cursor.visible = false
		return
	cursor.visible = true

	var cur_pos = Vector3()
	match Game.cursor_mode:
		-1:
			cursor.visible = false
		0:
			cur_pos = get_raypick().position
		1:
			cur_pos = get_raypick().position.floor() + Vector3(0.5, 0.5, 0.5) - 0.5 * get_raypick().normal
	Game.correct_look_at(cursor, cur_pos, get_raypick().normal)

###

var weap_jerk_force = Vector2()
var weap_jerk_linear = 0
func weap_jerk(strength, charge):
	strength = strength * (1 + 0.35 * (charge - 1)) # additional ammo charge
	weap_jerk_force.x = strength * (2.0 * randf() - 1.0) * Game.camera_weapon_shake_force.x
	weap_jerk_force.y = randf() * Game.camera_weapon_shake_force.y + strength * 0.01
	weap_jerk_linear = 1.0
func jerk_update(delta):
	var weap_jerk_coeff = sin((1.0 - weap_jerk_linear) * PI * 1.2 + PI * 0.2) * weap_jerk_linear

	phi += weap_jerk_force.x * 60 * delta * weap_jerk_coeff
	theta += weap_jerk_force.y * 60 * delta * weap_jerk_coeff
	while phi < 0:
		phi += 2 * PI
	while phi > 2 * PI:
		phi -= 2 * PI
	theta = max(min_height, theta)
	theta = min(max_height, theta)

	weap_jerk_linear = Game.delta_interpolate(weap_jerk_linear, 0, 0.3, delta)

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

var followed_object = null
func center_on(object, lock = false):
	followed_object = object
	locked = lock
func follow_centered_object(): # this is ran continuously -- if it has a locked-on object, the camera will follow/center on it.
	if followed_object == null:
		return
	# center camera on the followed object...
	if Game.is_2D():
		if followed_object is Actor:
			target = followed_object.pos2D
		else:
			target = followed_object.position
	else:
		if followed_object is Actor:
			target = followed_object.pos
		else:
			target = followed_object.translation
func center(): # same as above, but shorthand for centering on the player actor object.
	center_on(Game.player)

###

signal controller_update
func _process(delta):

	# update camera to follow the locked-on object (if there is any)
	follow_centered_object()

	# update certain special physics (camera shakes)
	jerk_update(delta)

	# how do the LookAt and Camera origin behave? (GAME-specific logic)
	var lookat_offset = offset
#	if Game.can_sneak && Game.player.crouching:
#		lookat_offset = crouch_offset
#	smooth_offset = Game.delta_interpolate(smooth_offset, lookat_offset, 0.3, delta)
	var new_lookat = target + smooth_offset
	var new_zoom = zoom_target
	match Game.GAMEMODE:
		Game.gm.fps:
			if Game.can_sneak && Game.player.crouching:
				lookat_offset = crouch_offset
			smooth_offset = Game.delta_interpolate(smooth_offset, lookat_offset, 0.3, delta)
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

	# update 2D camera
	if Game.is_2D():
		cam2D.position = Game.delta_interpolate(cam2D.position, target2D, camera_2d_coeff, delta)
		cam2D.position.y += Game.player.velocity.y * camera_2d_vertical_compensation
		cam2D.zoom = Vector2(0.01 + zoom, 0.01 + zoom)
	# update 3D camera
	else:
		lookat = Game.delta_interpolate(lookat, new_lookat, camera_3d_coeff, delta)
		zoom = Game.delta_interpolate(zoom, new_zoom, zoom_delta_speed, delta)
		zoom_curve = 0.0075 * zoom * zoom
		cam.translation.z = 20.0 * zoom_curve

		# update camera transform
		# for camera tilt:
		# X comes from (+)dir.Z and rotates around the X axis ---> .rotated(Vector3(1, 0, 0),  dir.z)
		# Z comes from (-)dir.X and rotates around the Z axis ---> .rotated(Vector3(0, 0, 1), -dir.x)
		follow.set_transform(Transform(
			Transform(Basis()).rotated(Vector3(1, 0, 0), theta).rotated(
				Vector3(1, 0, 0), camera_tilt.x).rotated(
				Vector3(0, 0, 1), camera_tilt.z).rotated(
#				Vector3(0, 1, 0), camera_tilt.y).rotated(
				up, phi).basis,
			Vector3(0,0,0)))
		follow.global_translate(lookat)

		# update secondary camera
		cam_secondary.global_transform = cam.global_transform

		# update weapon & camera bobbing
		if Game.weaps != null:
			Game.weaps.camera_tilt = camera_tilt * Vector3(-1, -1, 1)

	# refresh global physic space state
	Game.update_physics_space_state()

	# update reycasts & cursors
	if UI.handle_input == 0 && Game.level != null:
		update_raycast()

	# debugging info
	for point in command_points:
		Debug.point(point, Color(0,1,0))

	Debug.logpaddedinfo("camera:     ", true, [10, 10, 34, 20], ["phi:", phi, "theta:", theta, "3D:", cam.get_global_transform().origin, "2D:", cam2D.position, "zoom:", zoom])
	Debug.loginfo("raypicks:   ", raypicks.size())
	Debug.loginfo("highlights: ", highlighted_objects.size())
	Debug.loginfo("selected:   ", selected_objects.size())
	Debug.loginfo("commpoints: ", command_points.size())

	emit_signal("controller_update")

func _ready():
	Game.controller = self

#	cam.set_as_toplevel(true)
	cursor.set_as_toplevel(true)
	cursor.transform = Transform()
