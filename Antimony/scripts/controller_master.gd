extends Node
class_name HUDControllerMaster

###

#func has_raypick():
#	return Game.controller.has_raypick()
func get_raypick(n = 0):
	return Game.controller.get_raypick()

func get_highlight(n = 0):
	return Game.controller.hl_prop

func command_point(point):
	Game.controller.command_point(point)

###

func camera_shake(strength, charge):
	Game.controller.camera_shake(strength, charge)

func zoom(z):
	Game.controller.zoom(z)
func move_naive(x, y, s = 1.0):
	Game.controller.move_naive(x, y, s)
func move_pan(x, y, s = 1.0):
	Game.controller.move_pan(x, y, s)
func orbit(x, y, s = 1.0):
	Game.controller.orbit(x, y, s)

# compensate for zoom levels
func move3D(r, s = 1.0):
	Game.controller.target += r * s * (0.75 + Game.controller.zoom_curve * 0.95)
func move2D(x, y, s = 100.0):
	Game.controller.target2D += Vector2(x, y) * s * (0.75 + Game.controller.zoom_curve * 0.95)

func center_on(object, lock = false):
	Game.controller.center_on(object, lock)
func center(): # same as above, but shorthand for centering on the player actor object.
	Game.controller.center()
