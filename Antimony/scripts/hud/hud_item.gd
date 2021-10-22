extends Node2D
class_name HUDItem

export var dummy = false

var held = false
var origin = Vector2()
var oldpos = Vector2()

onready var btn = $btn
onready var dbg = $btn/dbg

var hbox = null
var prop = null # always linked to a cached prop w/ rigidbody!

###

func click():
	if dummy:
		return
	if !held:
		oldpos = btn.rect_position
		origin = btn.get_local_mouse_position() + btn.get_global_position() - oldpos
	held = true
	if UI.slot_hover > 3:
		UI.slot_hover = -2
	UI.HUD_dragging = self
func release():
	if dummy:
		return
	btn.rect_position = oldpos
	held = false
	UI.drop_HUDitem(self)
	UI.HUD_dragging = null

###

func _input(event):
	if held && Input.is_action_just_released("shoot"):
		release()
func _process(delta):
	if held:
		btn.rect_position = get_global_mouse_position() - origin
		UI.update_hotbar()

	# update debug info visibility
	match Debug.display:
		1:
			dbg.visible = true
		_:
			dbg.visible = false

func _ready():
	if dummy:
		$btn.texture_normal = load("res:/icon.png")
	pass # Replace with function body.

