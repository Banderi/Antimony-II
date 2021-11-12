extends Node
class_name ImmediateGeometryDisplay

var im

var todraw = {
	"points": [],
	"lines": [],
	"paths": {}
}

func point(v, c):
	todraw["points"].append([v, c])
func line(v1, v2, c1, c2 = null):
	if c2 == null:
		c2 = c1
	todraw["lines"].append([v1, v2, c1, c2])
func vector(p, v, c, point_1 = false, point_2 = false):
	line(p, p + v, c)
	if point_1:
		point(p, c)
	if point_2:
		point(p + v, c)
func path(p, v, c):
	if !todraw["paths"].has(p):
		todraw["paths"][p] = []
	todraw["paths"][p].append([v, c])
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

func render():
	if im == null:
		return
	im.clear()
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
