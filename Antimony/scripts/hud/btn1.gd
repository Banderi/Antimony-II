extends Button

var font = load("res://graphics/font_button.tres")
var font_b = load("res://graphics/font_button2.tres")

func _ready():
	$text.add_color_override("font_color", get_color("font_color"));
	$text.text = text;
	$text.visible = true;
	text = "";

func _process(delta):
	var p = get_local_mouse_position();
	var s = get_size();
	if (Rect2(Vector2(), s).has_point(p) && pressed):
		$text.add_font_override("font", font_b);
	else:
		$text.add_font_override("font", font);
