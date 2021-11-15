extends Prop
class_name KinematicProp

var nav_points_queue = []
var nav_path = []
var nav_destination = Vector3()
var prop_to_reach = null
var prop_has_collided = false

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

func prop_interact():
	pass

func path_add(dest):
	nav_points_queue.push_back(dest)
	if nav_points_queue.size() == 1:
		path_advance()
func path_advance():
	if nav_points_queue.size() == 0:
		return # nothing else in queue.
	path_set(nav_points_queue[0])
	nav_points_queue.pop_front()
func path_set(dest):
	nav_path = Game.navmesh.get_simple_path(pos, dest)
	nav_path.remove(0) # no need for current position to be the first path node
	nav_destination = dest
func path_update():
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
	var reached_prop = false
	if nav_path.size() > 0 && prop_to_reach != null: # check
		var dist = ((prop_to_reach.path_origin - pos) * hor)
		Debug.loginfo(str(dist.length()))
		if prop_has_collided || \
				dist.length() < prop_to_reach.distance || \
				(nav_path.size() < 2 && dist.length() < prop_to_reach.distance * 2):
			nav_path = []
			reached_prop = prop_interact() # interact!!
			prop_has_collided = false
#			path_advance() # TODO
		pass
	if nav_path.size() > 0:
		dir = (nav_path[0] - pos + nm_corr)
		if (dir * hor).length() < 0.1: # check for horizontal distance to the path node
			nav_path.remove(0)
	if nav_path.size() == 0:
		dir = Vector3() # arrival at destination!
		if prop_to_reach != null && !reached_prop: # alas... prop is unreachable
			prop_to_reach = null
		path_advance()
	else:
		dir = (nav_path[0] - pos + nm_corr) # update the movement to keep the motion seamless
