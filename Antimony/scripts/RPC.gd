extends Node

var controller
var initialized = false

#var status = Status.disconnected
var conn = NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED
var hosting
var my_ip = "localhost"
var server_ip = ""
var port = 20001
var my_peer
var peer_list = []

var conn_attempt_clock = -1
var timeout = 2000 # in milliseconds!

var sync_clock = 0
var sync_next_update = 10 # in milliseconds!

### NOTE BECAUSE I'M STUPID: is_network_master() doesn't work here, this node is unique and it's ALWAYS owned by the client!

remote func RPC_receive_player(peer, peer_info): # somebody else is trying to sync their player data with me!
	if !Game.have_actor(peer):
		Game.new_actor(peer, peer_info.actor_scene)

	# TODO: store this stuff (name, color, etc.)
	# >>>> peer_info

	status_refresh()
func RPC_sync_my_player(): # I received a connect signal, so I'm sending OUR player data over!
	# TODO:
#	Game.player.name = "PLAYER_" + str(my_peer)
#	Game.player.peer = my_peer
#	Game.player.set_network_master(my_peer)
	var peer_info = {
		# TODO
	}
	rpc("RPC_receive_player", my_peer, peer_info)
	status_refresh()

func am_connected():
	return controller.get_connection_status() == NetworkedMultiplayerPeer.CONNECTION_CONNECTED
func am_master(n):
	if !am_connected():
		return true
	return n.is_network_master()
func get_actor(peer):
	return Game.level.get_node("PLAYER_" + str(peer))

func print_error(e):
	match e: # it physically hurts to write this
		ERR_TIMEOUT:
			print("ERR_TIMEOUT")
		ERR_CANT_RESOLVE:
			print("ERR_CANT_RESOLVE")
		ERR_CANT_CONNECT:
			print("ERR_CANT_CONNECT")
		ERR_CANT_RESOLVE:
			print("ERR_CANT_RESOLVE")
		ERR_CONNECTION_ERROR:
			print("ERR_CONNECTION_ERROR")

###

remote func RPC_chat_message(message, timestamp = 0, peer = my_peer):
	if peer == my_peer:  # function was called locally, generate timestamp and then RPC
		timestamp = OS.get_datetime()
		rpc("RPC_chat_message", message, timestamp, peer)
	UI.spawn_balloon(message, peer)
	var a = get_actor(peer)
	UI.chat_push(message, timestamp, a.player_name)

func on_client_connect(peer):
	RPC_sync_my_player() # transmit back OUR player data to the friend who just connected!
func on_client_disconnect(peer):
	Game.destroy_actor(peer)
func on_server_connected():
	# hurray!!
	status_refresh()
func on_server_disconnect():
	# closed!
	conn_reset()
	get_tree().quit()
func on_server_failed():
	# boo
	conn_reset()

func status_refresh():
	conn = controller.get_connection_status()
	if Debug.dbg == null:
		return
	Debug.loginfo("hosting: " + str(hosting))
	var t = "" # "Connection: "
	match conn:
		NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED:
			t += "CONNECTION_DISCONNECTED"
		NetworkedMultiplayerPeer.CONNECTION_CONNECTING:
			t += "CONNECTION_CONNECTING"
		NetworkedMultiplayerPeer.CONNECTION_CONNECTED:
			t += "CONNECTION_CONNECTED"
	Debug.loginfo(t)
	if conn != NetworkedMultiplayerPeer.CONNECTION_DISCONNECTED:
		my_peer = get_tree().get_network_unique_id()
		peer_list = get_tree().get_network_connected_peers()
		set_network_master(my_peer)
	else:
		my_peer = ""
		peer_list = []
	UI.update_peers_menu()
func synchronize(): # force periodid updates to sync games all across, and keep-alive
	get_tree().call_group_flags(2, "actors", "RPC_sync")
	get_tree().call_group_flags(2, "props", "RPC_sync")

func conn_reset():
	controller.close_connection()
	get_tree().network_peer = null
	hosting = false
	server_ip = ""
	conn_attempt_clock = -1
	get_tree().call_group_flags(2, "props", "RPC_set_master", 1)
	status_refresh()
func host():
	conn_reset()
	var e = controller.create_server(port)
	if e != 0:
		print_error(e)
		conn_reset()
		return false

	get_tree().network_peer = controller
	hosting = true
	return true
func join(ip):
	conn_reset()
	var e = controller.create_client(ip, port)
	if e != 0:
		print_error(e)
		conn_reset()
		return false

	get_tree().network_peer = controller
	conn_attempt_clock = OS.get_ticks_msec()
	server_ip = ip
	return true # this is only for immediate errors, e.g. dns resolution! the actual connection is async!!

func init():
	if initialized:
		return

	controller = NetworkedMultiplayerENet.new()

	# set up signals!
	get_tree().connect("network_peer_connected", self, "on_client_connect")
	get_tree().connect("network_peer_disconnected", self, "on_client_disconnect")
	get_tree().connect("connected_to_server", self, "on_server_connected")
	get_tree().connect("server_disconnected", self, "on_server_disconnect")
	get_tree().connect("connection_failed", self, "on_server_failed")

	initialized = true
func shutdown():
	controller.close_connection()

func _process(delta): # synchronize everthing!

	# check for connection attempt, time out if necessary
	if conn_attempt_clock > -1:
		if am_connected():
			conn_attempt_clock = -1

			# vv only for debugging
			OS.set_window_size(Vector2(800, 500))
			OS.set_window_title("Project K (test client)")
		elif OS.get_ticks_msec() > conn_attempt_clock + timeout:
			on_server_failed()

			# vv only for debugging
#			host()
			OS.set_window_size(Vector2(1300, 1024))
#			OS.set_window_size(Vector2(1600, 1024))
#			OS.set_window_size(Vector2(1024, 800))
			OS.set_window_title("Project K (Godot Window)")

	###

	if am_connected():
		sync_clock += delta * 1000 # in milliseconds!
		if sync_clock >= sync_next_update:
			synchronize()
			sync_clock = 0
	status_refresh()

func _ready():
	# basic initializations
	init()

	# attempt creating a server first, else connect!
	join("banderi.dynu.net")

	# make all props owned by the server
#	get_tree().call_group_flags(2, "props", "RPC_set_master", 1)
	status_refresh()
