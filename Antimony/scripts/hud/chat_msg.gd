extends HBoxContainer
tool

export(String) var player = "Banderi"
export(String, MULTILINE) var msg = "Hey DORK\nhaha\nu smell"
var timestamp

###

func set_text():
	var t = timestamp #OS.get_datetime()
	$head.text = "%s:\n%d:%d:%d" % [player, t["hour"], t["minute"], t["second"]]
	$body.text = msg

func _process(delta):
	if Engine.editor_hint:
		timestamp = OS.get_datetime()
		set_text()
		get_parent().rect_min_size.y = get_parent().get_parent().rect_size.y
