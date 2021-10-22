extends Control

var life = 5
var pos = Vector3()

func _process(delta):
	life -= delta
	modulate.a = life / 5
	if life <= 0:
		queue_free()

	var proj = Game.controller.cam.unproject_position(pos)
	rect_position = proj
