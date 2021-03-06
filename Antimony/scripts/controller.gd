extends Node

onready var follow = get_node("follow")
onready var cam = get_node("follow/camera")
onready var cam_secondary = cam.get_node("ViewportContainer/Viewport/cameraChild")
onready var cursor = get_node("cursor")

onready var follow2D = get_node("follow2D")
onready var cam2D = get_node("follow2D/camera2D")
onready var cursor2D = get_node("cursor2D")

var up = Vector3(0, 1, 0)

#var offset = Vector3(0, 1, 0) # height off of the ground
#var crouch_offset = Vector3(0, 0.75, 0) # height off of the ground
var offset = Vector3()
var target = Vector3(0, 0, 0) # interpolation target
var lookat = target + offset
var target2D = Vector2(0, 0) # for 2D camera

var target_velocity = Vector3()
var target_velocity2D = Vector2()

var locked = false
var alt_camera = false

var phi = 0.5
var theta = -0.5
var zoom = 13 # note: zoom works in reverse - lower value means closer to target! yes I know that's not how zoom works
var zoom_interpolated = 1.0
var zoom_target = zoom # zoom's interpolation target

var camera_tilt = Vector3()

var raypicks = []
var highlighted_objects = []
var selected_objects = []

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

var mouse_motion_timer = 0
func highlight(item, drag_sel):
	if !item.has_method("can_be_selected"):
		return
	if !item.can_be_selected(drag_sel):
		return
	item.highlight(true)
	if !drag_sel:
		# tooltips
		if mouse_motion_timer > 0.2:
			if item.data.has("name"):
				UI.tooltip(item.data.name)
	_add_item(highlighted_objects, item)

func select(item):
	item.select(true)
	_add_item(selected_objects, item)
func select_currently_highlighted():
	for item in highlighted_objects:
		select(item)
func unselect_all():
	for item in selected_objects:
		item.select(false) # arrays CANNOT be updated during iteration!!
	selected_objects = []
	locked = false # automatically unlock
	followed_object = null

var selection_start = null
var selection_end = null
var selection_rect = Rect2()
func commence_drag_select(pos):
	selection_start = pos
	update_drag_select(pos)
func update_drag_select(pos):
	selection_end = pos
	selection_rect = Game.rect(selection_start, selection_end - selection_start)
	UI.hud.update()
func confirm_drag_select(booleans):
	if !booleans:
		unselect_all()
	select_currently_highlighted()
	selection_start = null
	selection_end = null
	UI.hud.update()

func update_selection_rect_intersect():
	# ONLY update if there is a current valid selection action
	if selection_start == null:
		return
	match Game.selection_mode:
		0:
			for prop in get_tree().get_nodes_in_group("props"):
#				UI.point(prop.body.translation, Color(1,1,1,1))
				if selection_rect.has_point(Game.to_screen(prop.body.translation)):
					highlight(prop, true)
func update_raycast():
	# reset prop highlight & raypicks
	get_tree().call_group_flags(2, "props", "highlight", false)
	highlighted_objects = []
	raypicks = []
	cursor.visible = false
#	UI.set_cursor(Input.CURSOR_ARROW)

	if Game.is_2D():
		pass # TODO: 2D raypicking...
	else:
		var masks = Masks.LEVEL + Masks.INTERACTABLES + Masks.ACTORS + Masks.PROPS + Masks.STATICS # todo?
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
#				if !Input.is_action_pressed("left_click"): # skip if dragging
				highlight(result.collider.get_parent(), false)
#				var m = result.collider.collision_layer
#				match m:
#					Masks.INTERACTABLES, Masks.PROPS, Masks.ACTORS, Masks.STATICS:
#						highlight(result.collider.get_parent(), false)
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

	# update drag-selectors highlighting
	update_selection_rect_intersect()
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
	theta = max(Game.camera_min_height, theta)
	theta = min(Game.camera_max_height, theta)

	weap_jerk_linear = Game.delta_interpolate(weap_jerk_linear, 0, 0.3, delta)

func zoom(z):
	zoom_target += z
	zoom_target = max(zoom_target, Game.camera_zoom_min)
	zoom_target = min(zoom_target, Game.camera_zoom_max)
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
	theta = max(Game.camera_min_height, theta)
	theta = min(Game.camera_max_height, theta)

# compensate for zoom levels
func move3D(r, s = 1.0):
	target += r * s * (0.75 + zoom_interpolated * 0.95)
func move2D(x, y, s = 100.0):
	target2D += Vector2(x, y) * s * (0.75 + zoom_interpolated * 0.95)

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
		elif followed_object is Array:
			var t = Vector2()
			for f in followed_object:
				t += f.position / followed_object.size()
			target = t
		else:
			target = followed_object.position
	else:
		if followed_object is Actor:
			target = followed_object.pos
		elif followed_object is Array:
			var t = Vector3()
			for f in followed_object:
				t += f.translation / followed_object.size()
			target = t
		else:
			target = followed_object.translation
	if !locked:
		followed_object = null
func center(lock = false): # same as above, but shorthand for centering on the player actor object.
	if get_selected():
		center_on(get_selected(-1), lock)
	else:
		target = Vector3(0,0,0)

###

func update_camera_engine_settings():
	if cam.near != Game.camera_near:
		cam.near = Game.camera_near
	if cam.far != Game.camera_far:
		cam.far = Game.camera_far

var mouse_was_moved = false
func _input(event):
	if UI.paused:
		return

	match Game.GAMEMODE:
		Game.gm.rts:
			# mouse movement
			if event is InputEventMouseMotion:
				if event.relative.x != 0.0 || event.relative.y != 0.0:
					mouse_was_moved = true

				if Input.is_action_pressed("camera_orbit"): # orbit camera
					if Input.is_action_pressed("camera_zoomdrag"): # drag zoom (ctrl + orbit)
						zoom(Game.settings["controls"]["zoom_sens"] * event.relative.y * 0.05)
					elif Input.is_action_pressed("camera_drag") && !Game.controller.locked: # pan camera (shift + orbit)
						move_pan(-event.relative.x * 0.01, -event.relative.y * 0.01)
					else:
						orbit(-event.relative.x, -event.relative.y, Game.settings.controls.mouse_sens * 0.0075)

				# update selections
				if Input.is_action_pressed("left_click"):
					update_drag_select(event.position)

			# zooming only if CTRL is pressed - otherwise use the keybind to scroll items
			if !Game.controller.alt_camera:
				if Input.is_action_pressed("camera_zoomin"):
					zoom(-Game.settings["controls"]["zoom_sens"])
				if Input.is_action_pressed("camera_zoomout"):
					zoom(Game.settings["controls"]["zoom_sens"])

			# drag selection!
			if event is InputEventMouseButton: # to prevent missing "position" value
				if Input.is_action_just_pressed("left_click"):
					commence_drag_select(event.position)
				if Input.is_action_just_released("left_click"):
					confirm_drag_select(Input.is_action_pressed("shift"))

			# camera locking / centering / etc.
			if !Game.controller.alt_camera:
				if Input.is_action_pressed("camera_center"):
					center()
				if Input.is_action_just_pressed("camera_follow"):
#					if locked:
#						locked = false
					if get_selected() && !locked:
						center(true)

signal controller_update
func _process(delta):
	update_camera_engine_settings()

	if UI.paused:
		return

	# update mouse motion timer
	if mouse_was_moved:
		mouse_motion_timer = 0
		mouse_was_moved = false
	else:
		mouse_motion_timer += delta

	# update camera to follow the locked-on object (if there is any)
	follow_centered_object()

	# update certain special physics (camera shakes)
	jerk_update(delta)

	# how do the LookAt and Camera origin behave? (GAME-specific logic)
	var lookat_offset = Game.camera_offset
#	if Game.can_sneak && Game.player.crouching:
#		lookat_offset = crouch_offset
#	offset = Game.delta_interpolate(offset, lookat_offset, 0.3, delta)
	var new_lookat = target + offset
	var new_zoom = zoom_target
#	match Game.GAMEMODE:
#		Game.gm.fps:
#			if Game.can_sneak && Game.player.crouching:
#				lookat_offset = Game.camera_crouch_offset
#			smooth_offset = Game.delta_interpolate(smooth_offset, lookat_offset, 0.3, delta)
#			new_lookat = Game.player.pos + smooth_offset
#			if alt_camera:
#				new_zoom = Game.camera_alt_zoom
#			else:
#				new_zoom = zoom_target
#		_: # default case
#			if alt_camera:
#				new_lookat = Game.player.pos + smooth_offset #Game.player.pos
#				new_zoom = Game.camera_alt_zoom
#			else:
#				new_lookat = target + smooth_offset
#				new_zoom = zoom_target


	# update 2D camera
	if Game.is_2D():
		cam2D.position = Game.delta_interpolate(cam2D.position, target2D, Game.camera_2d_coeff, delta)
		cam2D.position.y += Game.player.velocity.y * Game.camera_2d_vertical_compensation
		cam2D.zoom = Vector2(0.01 + zoom, 0.01 + zoom)
	# update 3D camera
	else:
		lookat = Game.delta_interpolate(lookat, new_lookat, Game.camera_3d_coeff, delta)
		zoom = Game.delta_interpolate(zoom, new_zoom, Game.camera_zoom_delta_speed, delta)
		zoom_interpolated = 0.0075 * zoom * zoom
		cam.translation.z = 20.0 * zoom_interpolated

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

	# unit command buffering
	Game.check_for_valid_commands(selected_objects, get_highlight())

	# debugging info
	Debug.logpaddedinfo("camera:     ", true, [10, 10, 34, 20, 5], ["phi:", phi, "theta:", theta, "3D:", cam.get_global_transform().origin, "2D:", cam2D.position, "zoom:", zoom, "locked:", locked])
	Debug.loginfo("raypicks:   ", raypicks.size())
	Debug.loginfo("highlights: ", highlighted_objects.size())
	Debug.loginfo("selected:   ", selected_objects.size())

	# free floating text (raypick info, actors, etc.)
	var pick = Game.controller.get_raypick()
	if pick != null:
		Debug.floating(Game.print_dict(pick), pick.screencoords + Vector2(30, 0))
	var sel = get_selected(0)
	if sel != null:
		if sel.get("dynamics") != null:
			Debug.floating(Game.print_dict(sel.dynamics), Game.to_screen(sel.dynamics.position) + Vector2(30, -100))

	emit_signal("controller_update")

func _ready():
	Game.controller = self

#	cam.set_as_toplevel(true)
	cursor.set_as_toplevel(true)
	cursor.transform = Transform()

	yield(Game, "level_ready")

	# load in game values
	zoom = min(Game.camera_initial_zoom, Game.camera_zoom_max)
	zoom_target = zoom
