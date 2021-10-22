extends Node

###

func _physics_process(delta): # update global space state for access to physics from other nodes
	if Game.is_2D():
		Game.space_state2D = Game.level.get_world_2d().direct_space_state
	else:
		Game.space_state = Game.level.get_world().direct_space_state

func _input(event):
	if (Input.is_action_just_pressed("debug_quit")):
		Game.quit_game()
	if (Input.is_action_just_pressed("debug_reload")):
		get_tree().reload_current_scene()
	if (Input.is_action_just_pressed("debug_draw")):
		Debug.display += 1

func _ready():
	OS.set_window_title("Loading... (Godot Window)")

	# register internal nodes and common UI members
	Game.root = self
	Debug.dbg = $UI/debug
	Debug.im = $UI/debug/im
	Debug.fps = $UI/debug/text/fps
	Debug.debugbox = $UI/debug/text/box
	UI.UI_root = $UI
	UI.m_main = $UI/m_main
	UI.m_pause = $UI/m_pause

	# register pause menu elements
	for btn in $UI/m_pause/Panel/vbox.get_children():
		if btn is Button:
			var method = str(btn.name, "_btn")
			btn.connect("pressed", UI, method)

	# (colored backdrop used for in-editor UI testing and development)
	$TESTING_COLOR.free()

	####

	# load initial level
	Game.load_level("levels/main")
	if !UI.is_ui_valid():
		print("ERROR: UI could not init! Quitting...")
		Game.quit_game()

	# push chat history (for testing purposes)
#	UI.chat_push("testest", OS.get_datetime(), "test")
#	UI.clear_chathistory()

	# start game!!!
	Debug.display = 1
	UI.state = UI.ms.ingame
