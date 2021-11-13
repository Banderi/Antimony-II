tool
extends ColorRect

export(int, 10, 500) var length = 50 setget set_length
export(int, 10000000) var maximum = 100 setget set_maximum
export(int, 10000000) var current = 100 setget set_value

func set_length(value):
	length = value
	update()

func set_maximum(value):
	maximum = value
	update()

func set_value(value):
	current = value
	update()

func update():
	length = max(min(length, 500), 10)
	maximum = max(min(maximum, 10000000), 1)
	current = max(min(current, maximum), 0)

	rect_size.x = length
	var rsize = (float(current) / float(maximum) * rect_size.x) - 2
	$bar.rect_size.x = rsize

###

func _ready():
	update()

func _process(delta):
	if Engine.editor_hint:
		update()
