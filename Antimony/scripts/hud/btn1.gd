extends Button

export(String) var font1 = "font_pixelated"
export(String) var font2 = "font_pixelated_low"

var font = null
var font_pressed = null
var font_loaded = false

func _ready():
	$text.add_color_override("font_color", get_color("font_color"));
	$text.text = text;
	$text.visible = true;
	text = "";

func _process(delta):
	if !font_loaded:
		font = load("res://Antimony/fonts/" + font1 + ".tres")
		font_pressed = load("res://Antimony/fonts/" + font2 + ".tres")
		font_loaded = true

	var p = get_local_mouse_position();
	var s = get_size();
	if (Rect2(Vector2(), s).has_point(p)):
		$text.modulate.a = 1.0;
		if pressed:
			$text.add_font_override("font", font_pressed);
		else:
			$text.add_font_override("font", font);
	else:
		$text.modulate.a = 0.75;
		$text.add_font_override("font", font);
