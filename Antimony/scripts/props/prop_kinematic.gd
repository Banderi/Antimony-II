extends Prop
class_name KinematicProp


var nm_corr = Vector3(0, -0.4, 0)
var up = Vector3(0, 1, 0)
var hor = Vector3(1, 0, 1)

var pos = Vector3()
var last_pos = Vector3()
var velocity = Vector3() # do NOT use this for checking the player "current" velocity externally!
var last_velocity = Vector3()
var dir = Vector3()
var rot = -PI * 0.5
var lookat = Vector3()

var last_dir = Vector3(1, 0, 0)

var speed = 6
var turn_friction = 0.2

###

#var prop_to_reach = null
#var prop_has_collided = false
func prop_interact():
	# TODO
	pass

var action_queue = []
var navigation = null
func action_add_to_queue(destination, prop = null, interaction = null):
	action_queue.push_back({
		"destination": destination,
		"prop": prop,
		"interaction": interaction # optional interaction order for the prop
	})

	# immediately run the next (first) action if it's the only one in queue...
	if action_queue.size() == 1:
		action_advance_queue()
func action_advance_queue():
	if action_queue.size() == 0:
		return action_queue_erase() # nothing in queue. clear the current / cached action's navigation and return.
	var action = action_queue[0] # get the first on in the queue
	var path = Game.get_pathfind(pos, action.destination)
	if path == null:
		return print("ERROR: no valid navmesh available!") # uh oh
	navigation = {
		"destination": action.destination,
		"prop": action.prop,
		"path": path,
		"path_index": 1, # skip the first point
		"path_total": path.size(),
		"start": pos # current prop's translation
	}
#	navigation.destination = action[0]
#	navigation.prop = action[1]
#	navigation.path = Game.navmesh.get_simple_path(pos, action[0])
#	navigation.path_index = 1 # skip the first point
#	navigation.path_total = navigation.path.size()
#	navigation.start = pos

	# remove previous action from the queue
	action_queue.pop_front()
func action_queue_erase():
	action_queue = []
	navigation = null
func go_to_position(destination, queued = false):
	if !queued:
		action_queue_erase()
	action_add_to_queue(destination, null)
func go_to_prop(prop, queued = false):
	if !queued:
		action_queue_erase()
	action_add_to_queue(prop.usage_origin, prop)

func check_for_prop_in_range(prop):
	# check for collision list
	if prop in collision_props_list:
		return true

	# check for horizontal distance
	var vec_dist = prop.usage_origin - pos + nm_corr
	var horizontal_distance = (vec_dist * hor).length()
	if horizontal_distance < prop.distance:
		return true

	# TODO?
#	if navigation.path_total - navigation.path_index > 2 && horizontal_distance < prop.distance * 2:
#		return true

	# failure case
	return false

func navigation_update():
#	# ignore for now if player controlled
#	if self == Game.player:
#		match Game.GAMEMODE:
#			Game.gm.fps, Game.gm.plat, Game.gm.fighting:
#				return
#
#	match state:
#		states.transit, states.idle:
#			var reached_prop = false
#			if path.size() > 0 && prop_to_reach != null: # check
#				var dist = ((prop_to_reach.path_origin - pos) * hor)
#				Debug.loginfo(str(dist.length()))
#				if prop_has_collided || \
#						dist.length() < prop_to_reach.distance || \
#						(path.size() < 2 && dist.length() < prop_to_reach.distance * 2):
#					path = []
#					reached_prop = prop_interact() # interact!!
#					prop_has_collided = false
#			if path.size() > 0:
#				dir = (path[0] - pos + nm_corr)
#				if (dir * hor).length() < 0.1: # check for horizontal distance to the path node
#					path.remove(0)
#			if path.size() == 0:
#				dir = Vector3() # arrival at destination!
#				if prop_to_reach != null && !reached_prop: # alas... prop is unreachable
#					prop_to_reach = null
#			else:
#				dir = (path[0] - pos + nm_corr) # update the movement to keep the motion seamless
#		states.ladder:
#			if path.size() > 1:
#				dir = (path[0] - pos + nm_corr)
#				if dir.length() < 0.05:
#					path.remove(0)
#				if path.size() == 1:
#					body3D.translation = path[0] + nm_corr
#					dir = Vector3() # arrival at destination!
#					path.remove(0)
#					state = states.idle
#					release_prop()
#	dir = dir.normalized() # dir is only used for direction!


#	if nav_path.size() > 0 && prop_to_reach != null: # check
#		var dist = ((prop_to_reach.path_origin - pos) * hor)
#		Debug.loginfo(str(dist.length()))
#		if prop_has_collided || \
#				dist.length() < prop_to_reach.distance || \
#				(nav_path.size() < 2 && dist.length() < prop_to_reach.distance * 2):
#			nav_path = []
#			reached_prop = prop_interact() # interact!!
#			prop_has_collided = false
##			path_advance() # TODO
#		pass
#	if nav_path.size() > 0:
#		dir = (nav_path[0] - pos + nm_corr)
#		if (dir * hor).length() < 0.1: # check for horizontal distance to the path node
#			nav_path.remove(0)
#	if nav_path.size() == 0:
#		dir = Vector3() # arrival at destination!
#		if prop_to_reach != null && !reached_prop: # alas... prop is unreachable
#			prop_to_reach = null
#		path_advance()
#	else:
#		dir = (nav_path[0] - pos + nm_corr) # update the movement to keep the motion seamless

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
			var vec_dist = next_point - pos + nm_corr
			var horizontal_distance = (vec_dist * hor).length()
			if horizontal_distance < 0.1: # check for horizontal distance to the next path point
				navigation.path_index += 1 # advance "target" index to the next point in the path!

		# update the direction vector along the path
		dir = (next_point - pos + nm_corr)
	else: # navigation is done! index is out of bounds!!
		dir = Vector3() # arrival at destination!
		if navigation.prop != null: # alas... prop is unreachable
			pass
		action_advance_queue() # advance to next action

func _process(delta):
	navigation_update()

	if navigation != null:
		for p in navigation.path:
			Debug.path(name, p, Color(0,1,0,1), true)

func _ready():
	pos = translation
