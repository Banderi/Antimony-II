extends Spatial
class_name Prop

export(String) var itemid = "" #setget id_change
var data = [] # this contains ALL the useful item data -- editable, too.
export(int, 0, 99) var faction = 0 # ok I lied. not ALL of the data...

var bars = null
var meshnodes = []

var highlighted = false # currently highlighted
var selected = false # currently selected

var user = null # actor interacting with prop
var busy = false
var distance = 0.4
var usage_origin = Vector3()
var usage_transform = Transform()

# TODO: rewrite this utter garbage

func highlight(y):
	for n in meshnodes:
		n.get_surface_material(0).next_pass.next_pass.set_shader_param("visible", y)
		pass
	highlighted = y
func select(y):
	selected = y
func can_be_selected(drag):
	if faction == Game.player_faction:
		return true
	elif !drag: # can be selected when not dragging
		return true
	return false

func to_reach(pos):
	return usage_origin
func interact(a):
	if user != null:
		if user == a:
			return -2 # already being used by this actor!
		return -1
	busy = true
	user = a
	rpc("RPC_set_master", a.peer)
	return data.type
func release():
	busy = false
	user = null
	rpc("RPC_release_actor")

func take_hit(hit_data):
	if data.health > 0:
		data.health -= hit_data.ammo_data.damage * hit_data.strength
		if data.health <= 0:
			destroy()
func destroy():
	queue_free()

func init_mesh_array():
	meshnodes = []
	var nodes = Game.get_all_childs(self) # needs to be set beforehand - the "for in" loop evaluates EVERY TIME >:C
	for n in nodes:
		if n is MeshInstance &&\
		n.get_surface_material(0) != null && \
		n.get_surface_material(0).next_pass != null &&\
		n.get_surface_material(0).next_pass.next_pass != null:
			meshnodes.push_back(n)

###

var RPC_to_sync = [] # meshes to sync!
puppet func RPC_sync(packet = []): # called every frame!
	pass # implemented by the inheriting class !!!!!
remotesync func RPC_set_master(peer):
	set_network_master(peer) # unsecure, but works for now....
	if !RPC.am_master(self):
		user = RPC.get_actor(peer)
		if data.type != 1000:
			user.prop_inuse = self
remote func RPC_release_actor():
	if user.prop_inuse == self:
		user.prop_inuse = null
	user = null

###

func show_bars():
	if bars == null:
		return
	if selected || highlighted:
		bars.visible = true
	else:
		bars.visible = false
#	bars.scale = Vector2(40,40) / Game.camera_distance(translation)
	bars.position = Game.to_screen(translation + 2.3 * Vector3(0, scale.y, 0))
func show_selection_boxes():
	if selected:
		UI.box(translation + Vector3(0, scale.y, 0), scale * 2.3, Color(1, 1, 1, 1), true, 0.4)
	elif highlighted:
#		UI.box(translation + Vector3(0, scale.y, 0), scale * 2.3, Color(1, 1, 0, 1), true, 0.4)
		pass

func _process(delta):
	if Engine.editor_hint:
		return
	show_bars()
	show_selection_boxes()

func _ready():
	init_mesh_array()

	usage_origin = get_global_transform().origin
	add_to_group("props")
	add_to_group("rpc_sync")

	###

	# wait for game databases to finish loading
	yield(Game.level, "level_ready")

	# pickup-able item vs interactible/physics room prop
	var item_data = Game.get_item_data(itemid)
	if item_data != null:
		# TODO: redo type variables
		data = item_data.duplicate()
	else:
		data = { # default "dummy" item data
			"type": 999,
			"health" : -1
		}

	# load statbars
	var bar_scn = load("res://scenes/hud/unitbars.tscn")
	if bar_scn != null:
		bars = load("res://scenes/hud/unitbars.tscn").instance()
		self.add_child(bars)
