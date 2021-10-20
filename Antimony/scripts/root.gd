extends Node

###

func _physics_process(delta): # update global space state for access to physics from other nodes
	if game.is_2D():
		game.space_state2D = game.level.get_world_2d().direct_space_state
	else:
		game.space_state = game.level.get_world().direct_space_state

func _input(event):
	if (Input.is_action_just_pressed("debug_quit")):
		game.quit_game()
	if (Input.is_action_just_pressed("debug_reload")):
		get_tree().reload_current_scene()
	if (Input.is_action_just_pressed("debug_draw")):
		debug.display += 1

func _ready():

	# set internal nodes and variables
	OS.set_window_title("Project K (Godot Window)")
	game.root = self

#	# register common UI members
	debug.dbg = $UI/debug
	debug.im = $UI/debug/im
	debug.fps = $UI/debug/text/fps
	debug.debugbox = $UI/debug/text/box
	UI.UI_root = $UI
	UI.m_main = $UI/m_main
	UI.m_pause = $UI/m_pause

	for btn in $UI/m_pause/Panel/vbox.get_children():
		if btn is Button:
			var method = str(btn.name, "_btn")
			btn.connect("pressed", UI, method)

	# level testing!!
	game.init()
#	game.load_level("levels/testing/00")
#	game.load_level("levels/testing/02")
#	game.load_level("levels/plat/test")
#	game.load_level("levels/suitfights/test")
#	game.load_level("levels/shooter/test")

	# pause menu text
	$UI/m_pause/Panel/Label.text = "project k\nv.alpha0.0.2"

	# push chat history (for testing purposes)
	UI.chat_push("testest", OS.get_datetime(), "test")
	UI.clear_chathistory()

	# (colored backdrop used for in-editor UI testing and development)
	$TESTING_COLOR.free()

	# initialize game!!!
	debug.display = 1
	UI.state = UI.ms.ingame
