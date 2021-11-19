extends ImmediateGeometryDisplay

var display = 0

var dbg

var fps
var debug_text = ""
var debugbox
var ff

###

func draw_nav(a):
#	for p in a.path:
#		point(p + a.nm_corr, Color(0, 0, 1))
#		path("nav_" + str(a.peer), p + a.nm_corr, Color(0, 0, 1))
	if a.navigation != null:
		for p in a.navigation.path_total:
			var point = a.navigation.path[p]
			if p == a.navigation.path_index:
				path(name, a.dynamics.position, Color(0,1,0,1), true)
				path(name, point + a.nav_correction, Color(0,1,0,1), true)
			elif p > a.navigation.path_index:
				path(name, point + a.nav_correction, Color(1,0,0,1), true)
func draw_owner(a):
	var p = a.body.get_global_transform().origin + Vector3(0, 0, 0)
	point(p, Color(1 - int(RPC.am_master(a)), int(RPC.am_master(a)), 0))

func padinfo(paired, paddings, values):
	var txt = ""
	for i in values.size():
		var s = str(values[i])
		var p = 0 # default: 0

		var pad_i = i # default
		if paired:
			pad_i = (i - 1) / 2

		if paddings.size() > pad_i && (!paired || i % 2 != 0): # to make sure the first array is long enough
			p = paddings[pad_i]
		var string_length = s.length()

		# add text to buffer!
		txt += s
		for w in range(0, p - string_length):
			txt += " "
		txt += " " # add a trailing space as default
	return txt
func logpaddedinfo(txt, paired, paddings, values):
	debug_text += str(txt) + padinfo(paired, paddings, values)
	debug_text += "\n"
func loginfo(txt, txt2 = ""):
	debug_text += str(txt) + str(txt2)
	debug_text += "\n"
var floating = []
func floating(txt, pos):
	floating.append([txt, pos])

###

func _process(delta):
	# cycle display mode
	if display > 1:
		display = 0
	if !display:
		dbg.visible = false
	else:
		dbg.visible = true

	# refresh and prepare for next draw
	debugbox.text = debug_text
	debug_text = ""

	match display:
		1:
			# render immediate geometry
			render()

			# render game elements
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

			# render free-floating text
			for label in ff.get_children():
				label.text = ""
			for f in floating.size():
				if f < 20:
					var label = ff.get_child(f)
					label.text = floating[f][0]
					label.rect_position = floating[f][1]
			floating = []

			# FPS
			fps.text = str(Performance.get_monitor(0))

			# inventory box debug draws
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
						hi.dbg.text = "%d: %s\n%s" % [hi.hbox.slot, Game.items[hi.prop.itemid][0], hi.prop]
		_:
			im.clear()
			todraw = {
				"points": [],
				"lines": [],
				"paths": {}
			}
