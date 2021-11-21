extends Prop
class_name KinematicProp
# NOTE: Prop inherits from Spatial. KinematicProp CANNOT extend KinematicBody and thus cannot access KinematicBody methods directly.
# Fuck the diamond problem.

#var kbody = null
#var mesh = null
#onready var kbody = $KinematicBody
#onready var mesh = $mesh

var nav_correction = Vector3(0, -0.4, 0)
#var kbody_correction = Vector3(0, 0, 0)
var up = Vector3(0, 1, 0)
var hor = Vector3(1, 0, 1)

var dynamics = {
	"position": Vector3(),
	"last_position": Vector3(),
	"delta_position": Vector3(),

	# normalized direction to be used for movement calcs
	"direction": Vector3(),
	"last_direction": Vector3(1, 0, 0),
	"delta_direction": Vector3(1, 0, 0),

	# frame-dependent movement vector
	"movement": Vector3(),
	"last_movement": Vector3(),
	"delta_movement": Vector3(),

	# overall movement (velocity) vector
	"velocity": Vector3(),
	"last_velocity": Vector3(),
	"delta_velocity": Vector3(),

	# rotation angle (horizontal) for mesh transform stuff
	"rotation": -PI * 0.5,

	"speed": 6,
	"turn_speed": 0,
	"turn_friction": 0.2,
	"on_ground": true,
}

###

func prop_interact():
	# TODO
	pass
func check_for_prop_in_range(prop):
	# check for collision list
	if prop in collision_props_list:
		return true

	# check for horizontal distance
	var vec_dist = prop.usage_origin - dynamics.position + nav_correction
	var horizontal_distance = (vec_dist * hor).length()
	if horizontal_distance < prop.distance:
		return true

	# TODO?
#	if navigation.path_total - navigation.path_index > 2 && horizontal_distance < prop.distance * 2:
#		return true

	# failure case
	return false

var action_queue = []
var navigation = null
var last_action_timer = 0
func action_add_to_queue(destination, prop = null, interaction = null):
	action_queue.push_back({
		"destination": destination,
		"prop": prop,
		"interaction": interaction # optional interaction order for the prop
	})

	# reset order timer
	last_action_timer = 0

	# immediately run the next (first) action if it's the only one in queue...
	if navigation == null && action_queue.size() == 1:
		action_advance_queue()
func action_advance_queue():
	if action_queue.size() == 0:
		return action_queue_erase() # nothing in queue. clear the current / cached action's navigation and return.
	var action = action_queue[0] # get the first on in the queue
	var path = Game.get_pathfind(dynamics.position, action.destination)
	if path == null:
		return print("ERROR: no valid navmesh available!") # uh oh
	navigation = {
		"destination": action.destination,
		"prop": action.prop,
		"path": path,
		"path_index": 1, # skip the first point
		"path_total": path.size(),
		"start": dynamics.position # current prop's translation
	}

	# remove previous action from the queue
	action_queue.pop_front()
func action_queue_erase():
	action_queue = []
	navigation = null
	dynamics.direction = Vector3()
func go_to_position(destination, queued = false):
	if !queued:
		action_queue_erase()
	action_add_to_queue(destination, null)
func go_to_prop(prop, queued = false):
	if !queued:
		action_queue_erase()
	action_add_to_queue(prop.usage_origin, prop)

func navigation_update(delta):
	# advance timer
	last_action_timer += delta

	if navigation == null:
		return # no current active action / navigation.

	if navigation.path_index < navigation.path_total: # navigation still not done ("target" index less than or equal to the last point)

		var next_point = navigation.path[navigation.path_index]

		if navigation.prop != null: # needs to reach for a prop to conclude the path -- or at least, attempt to.
			# check for the prop to be in interaction range?
			if check_for_prop_in_range(navigation.prop): # prop has been REACHED (it has collided)
				prop_interact() # interact!!
				return action_advance_queue() # advance to next action
		else:
			var vec_dist = next_point - dynamics.position + nav_correction
			var horizontal_distance = (vec_dist * hor).length()
			if horizontal_distance < 0.1: # check for horizontal distance to the next path point
				navigation.path_index += 1 # advance "target" index to the next point in the path!

		# update the direction vector along the path
		dynamics.direction = (next_point - dynamics.position + nav_correction).normalized()
	else: # navigation is done! index is out of bounds!!
		dynamics.direction = Vector3() # arrival at destination!
		if navigation.prop != null: # alas... prop is unreachable
			pass
		action_advance_queue() # advance to next action
func show_navigation(delta):
	if selected && (navigation != null || action_queue.size() > 0):
		if last_action_timer < 0.5 || selection_timer < 0.5:
			var col = Color(1,1,0)
			var lastpoint = dynamics.position
			if navigation != null:
				col = Color(0,1,0)
				UI.im_no_zbuffer.line(dynamics.position, navigation.destination, col)
				UI.im_no_zbuffer.point(navigation.destination, col)
				lastpoint = navigation.destination
			UI.im_no_zbuffer.point(dynamics.position, col)

			# render the rest of the queued paths (shallow)
			for action in action_queue:
				UI.im_no_zbuffer.line(lastpoint, action.destination, col)
				UI.im_no_zbuffer.point(action.destination, col)
				lastpoint = action.destination

###

func dynamics_update(delta):
	# update previous values
	dynamics.last_position = dynamics.position
	dynamics.last_velocity = dynamics.velocity
	dynamics.last_direction = dynamics.direction
	dynamics.last_movement = dynamics.movement

	dynamics.movement = dynamics.direction * dynamics.speed
	if !dynamics.on_ground:
		dynamics.movement += dynamics.velocity

	# NB: body can NOT be unassigned!
	# it will fail on startup if the node isn't present!
	dynamics.velocity = body.move_and_slide(dynamics.movement)

	# update position...
	dynamics.position = body.translation

	# update delta values
	dynamics.delta_position = dynamics.position - dynamics.last_position
	dynamics.delta_velocity = dynamics.velocity - dynamics.last_velocity
	dynamics.delta_direction = dynamics.direction - dynamics.last_direction
	dynamics.delta_movement = dynamics.movement - dynamics.last_movement

func mesh_update(delta):
	mesh.translation = dynamics.position

###

func _process(delta):
	navigation_update(delta)

	# integrate stuff, update final velocity, position, etc.
	dynamics_update(delta)

	# display / rendering stuff
	show_navigation(delta)

	# debug info
	if navigation != null:
		Debug.navpath(navigation, dynamics.position, nav_correction, Color(0,1,0,1), Color(1,1,0,1), Color(1,0,0,1), true)
		var lastpoint = navigation.destination
		for action in action_queue:
			Debug.line(lastpoint, action.destination, Color(1,0,0,1))
			Debug.point(action.destination, Color(1,0,0,1))
			lastpoint = action.destination

	if selected:
		Debug.loginfo("actions:   ", action_queue.size())
