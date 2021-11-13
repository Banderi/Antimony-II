extends Node
class_name HUDControllerMaster

###

func get_raypick(n = 0):
	return Game.controller.get_raypick(n)
func get_highlight(n = 0):
	return Game.controller.get_highlight(n)
func get_selected(n = 0):
	return Game.controller.get_selected(n)

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

###

func _draw():
	if Game.controller.selection_start != null: # Node2D/Control methods can not be called directly from here (script extends Node class!)
		UI.hud.draw_rect(Rect2(Game.controller.selection_start, Game.controller.selection_end - Game.controller.selection_start), Color(1, 1, 1, 1), false)
