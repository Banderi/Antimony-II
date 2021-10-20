extends Node

var display

var dbg
var im

var fps
var debug_text = ""
var debugbox
#var t1
#var t2
#var c1
#var c2

var todraw = {
	"points": [],
	"lines": [],
	"paths": {}
}

###

func draw_nav(a):
	for p in a.path:
		point(p + a.nm_corr, Color(0, 0, 1))
		path("nav_" + str(a.peer), p + a.nm_corr, Color(0, 0, 1))
func draw_owner(a):
	var p = a.get_global_transform().origin + Vector3(0, 0, 0)
	point(p, Color(1 - int(RPC.am_master(a)), int(RPC.am_master(a)), 0))

func point(v, c):
	todraw["points"].append([v, c])
func line(v1, v2, c1, c2 = null):
	if c2 == null:
		c2 = c1
	todraw["lines"].append([v1, v2, c1, c2])
func path(p, v, c):
	if !todraw["paths"].has(p):
		todraw["paths"][p] = []
	todraw["paths"][p].append([v, c])
func render():
	if im == null:
		return
	if debug:
#		im.clear()
		im.begin(Mesh.PRIMITIVE_POINTS, null)
		for e in todraw["points"]:
			im.set_color(e[1])
			im.add_vertex(e[0])
		im.end()

		for e in todraw["lines"]:
			im.begin(Mesh.PRIMITIVE_LINE_STRIP, null)
			im.set_color(e[2])
			im.add_vertex(e[0])
			im.set_color(e[3])
			im.add_vertex(e[1])
			im.end()

		for p in todraw["paths"]:
			im.begin(Mesh.PRIMITIVE_LINE_STRIP, null)
			for e in todraw["paths"][p]:
				im.set_color(e[1])
				im.add_vertex(e[0])
			im.end()

		todraw = {
			"points": [],
			"lines": [],
			"paths": {}
		}

func loginfo(txt, txt2 = ""):
	debug_text += str(txt) + str(txt2)
	debug_text += "\n"

###

func clear():
	if im == null:
		return
	im.clear()
	debugbox.text = debug_text
	debug_text = ""

func _process(delta):
	# cycle display mode
	if display > 1:
		display = 0
	if !display:
		dbg.visible = false
	else:
		dbg.visible = true

	# refresh and prepare for next draw
	clear()

	match display:
		1:
			render()
			for p in get_tree().get_nodes_in_group("props"):
				draw_owner(p)
			for a in get_tree().get_nodes_in_group("actors"):
				draw_nav(a)
			for e in get_tree().get_nodes_in_group("emitters"):
				e.draw_trajectory()
				var c = Color(1, 1*int(!e.fail), 1*int(!e.fail))
				point(e.get_global_transform().origin, c)
				point(e.target, c)
				line(e.target, e.get_global_transform().origin, c)

			fps.text = str(Performance.get_monitor(0))

			for i in range(0,7):
				var h = null
				if i < 3:
					h = UI.hh_invbar[i]
					h.dbg.text = str(h.has_items())
				else:
					h = UI.hh_invequip[i-3]
					h.dbg.text = "(%d,%d)" % [h.eyed_slot[0],h.eyed_slot[1]]
				for hi in h.items:
					if hi is HUDItem:
						hi.dbg.text = "%d: %s\n%s" % [hi.hbox.slot, game.items[hi.prop.itemid][0], hi.prop]
		_:
#			im.clear()
			todraw = {
				"points": [],
				"lines": [],
				"paths": {}
			}
