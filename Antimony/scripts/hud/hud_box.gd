extends ColorRect
tool

enum nt {
	hotbar,		# HUD hotbar slots
	invbar,		# hotbar slots in the inventory menu
	invequip	# equipment slots in the inv. menu
}
export(nt) var kind = nt.hotbar

var slot = -1 # slot it's in - 0-1 is invbar, 3-6 is invequip

onready var sel = $sel
onready var bb = $bb
onready var dbg = $dbg
onready var hi_node = $items
var items = []
var focused = false

var eyed_slot = [0,0]
var eyed_refresh_last = eyed_slot

func change_type():
	match kind:
		nt.hotbar:
			selector(1)
			rect_size = Vector2(80, 80)
		nt.invbar:
			selector(1)
			rect_size = Vector2(70, 70)
		nt.invequip:
			selector(2)
			rect_size = Vector2(70, 70)

func focus(f, d = false): # activated by mouse action on this or linked UI elements
	focused = f
	if f && kind == nt.hotbar:
		selector(1)
	elif !f:
		selector(-1) # hide selector automatically if not focused
	if d: # dragging grabbed item over equipment menu
		pass
func rearrange(): # rearrange items based on layer

	pass
func selector(t, offset = 0):
	if Engine.editor_hint:
		return

	if typeof(t) != 2:
		offset = t[1]
		t = t[0]
	eyed_slot = [t, offset]

	# refresh if changed
	if [t, offset] != eyed_refresh_last:
		if t > -1:
			sel.visible = true
		match t:
			-1: # hidden
				sel.visible = false
			0: # white semi-transparent background
				$sel/bd.visible = true
				$sel/draw.visible = false
			1: # normal white, no arrow
				$sel/bd.visible = false
				$sel/draw.visible = true
				$sel/draw/def.modulate = Color(1,1,1)
				$sel/draw/arrow.visible = false
			2: # green, with arrow
				$sel/bd.visible = false
				$sel/draw.visible = true
				$sel/draw/def.modulate = Color(0,1,0)
				$sel/draw/arrow.visible = true
			3: # red, no arrow
				$sel/bd.visible = false
				$sel/draw.visible = true
				$sel/draw/def.modulate = Color(1,0,0)
				$sel/draw/arrow.visible = false
		eyed_refresh_last = [t, offset]
	if kind == nt.hotbar:
		sel.rect_position.x = 7
	else:
		sel.rect_position.x = 2 + 60 * offset

func add_item(hi):
	hi.hbox = self
	hi_node.add_child(hi)
	items.push_back(hi)
	rearrange()
	if slot > 2:
		game.equip(hi.prop)
func remove_item(hi):
	hi.hbox = null
	hi_node.remove_child(hi)
	items.erase(hi)
	if slot > 2:
		game.unequip(hi.prop)
func has_items():
	return items.size() > 0

###

func _process(delta):
	if Engine.editor_hint:
		change_type()
		return

	# update visuals
	match kind:
		nt.hotbar:
			pass
		nt.invbar:
			pass
		nt.invequip:
			var speed = 30 * delta
			if speed > 1:
				speed = 1
			var cc = items.size()

			var fsize = 60
			var csize = 7

			if focused:
				var x_diff = 10 + (fsize * cc) - bb.rect_size.x
				bb.rect_size.x += speed * x_diff

				# displace items and show colored selector
				for i in range(0, cc):
					var hi = items[i]
					x_diff = 7 + (fsize * i) - hi.btn.rect_position.x
					hi.btn.rect_position.x += speed * x_diff

			else:
				var x_diff = (70 - csize) + (csize * cc) - bb.rect_size.x
				bb.rect_size.x += speed * x_diff

				# displace items
				for i in range(0, cc):
					var hi = items[i]
					x_diff = 7 + (csize * i) - hi.btn.rect_position.x
					hi.btn.rect_position.x += speed * x_diff

			if bb.rect_size.x < 70:
				bb.rect_size.x = 70

	# update debug info visibility
	match debug.display:
		1:
			dbg.visible = true
			bb.modulate.a = 1
		_:
			dbg.visible = false
			bb.modulate.a = 0

func _ready():
	focus(false)
