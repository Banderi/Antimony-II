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
func vector(p, v, c, d1 = false, d2 = false):
	line(p, p + v, c)
	if d1:
		point(p, c)
	if d2:
		point(p + v, c)
func path(p, v, c):
	if !todraw["paths"].has(p):
		todraw["paths"][p] = []
	todraw["paths"][p].append([v, c])
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
