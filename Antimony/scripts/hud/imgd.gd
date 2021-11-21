extends Node
class_name ImmediateGeometryDisplay

export(bool) var is_self_im = false

var im

func point(v, c, standalone = true):
	if standalone:
		im.begin(Mesh.PRIMITIVE_POINTS, null)
	im.set_color(c)
	im.add_vertex(v)
	if standalone:
		im.end()
func line(v1, v2, c1, c2 = null, standalone = true):
	if c2 == null:
		c2 = c1
	if standalone:
		im.begin(Mesh.PRIMITIVE_LINE_STRIP, null)
	im.set_color(c1)
	im.add_vertex(v1)
	im.set_color(c2)
	im.add_vertex(v2)
	if standalone:
		im.end()
func vector(p, v, c, point_1 = false, point_2 = false):
	line(p, p + v, c)
	if point_1:
		point(p, c)
	if point_2:
		point(p + v, c)
func navpath(nav, pos, corr, c1, c2, c3, points = false):
	var pp = null
	for p in nav.path_total:
		var point = nav.path[p]
		if p == nav.path_index:
			line(pos, point + corr, c2, c2, true)
			if pp != null:
				line(point + corr, pp + corr, c3, c3, true)
		if p > nav.path_index:
			if pp != null:
				line(point + corr, pp + corr, c1, c1, true)
		pp = point # save previous point in cache

	# draw points
	if points:
		for p in nav.path_total:
			point(pos, c2)
			var point = nav.path[p]
			if p == nav.path_index:
				point(point + corr, c2)
			elif p > nav.path_index:
				point(point + corr, c1)
			else:
				point(point + corr, c3)
func box_raw(p, x, y, z, c, centered = true, e = -1, points = false):
	if centered:
		p -= Vector3(x, y, z) * 0.5
	var vrt = [
		p,
		p + Vector3(x, 0, 0),
		p + Vector3(x, 0, z),
		p + Vector3(0, 0, z),

		p + Vector3(0, y, 0),
		p + Vector3(x, y, 0),
		p + Vector3(x, y, z),
		p + Vector3(0, y, z),
	]

	if e == -1:
		# bottom
		line(vrt[0], vrt[1], c)
		line(vrt[1], vrt[2], c)
		line(vrt[2], vrt[3], c)
		line(vrt[3], vrt[0], c)

		# top
		line(vrt[4], vrt[5], c)
		line(vrt[5], vrt[6], c)
		line(vrt[6], vrt[7], c)
		line(vrt[7], vrt[4], c)

		# walls
		line(vrt[0], vrt[4], c)
		line(vrt[1], vrt[5], c)
		line(vrt[2], vrt[6], c)
		line(vrt[3], vrt[7], c)
	else:
		for v in vrt.size():
			var vert = vrt[v]
			var edge = Vector3(e, e, e)
			if v >= 4:
				edge.y = -e
			if v % 4 in [1, 2]:
				edge.x = -e
			if v % 4 >= 2:
				edge.z = -e
			line(vert, vert + edge * Vector3(1, 0, 0), c)
			line(vert, vert + edge * Vector3(0, 1, 0), c)
			line(vert, vert + edge * Vector3(0, 0, 1), c)
	if points:
		for v in vrt:
			point(v, c)
func box(p, s, c, centered = true, e = -1, points = false):
	return box_raw(p, s.x, s.y, s.z, c, centered, e, points)

func _process(delta):
	if im == null:
		return
	im.clear()

func _ready():
	if is_self_im:
		im = self
