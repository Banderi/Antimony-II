extends Spatial
class_name Prop
tool

var meshnodes = []

var hl = false # currently highlighted

export(String) var itemid = "" setget id_change

var data = []

#var type = -1 # prop type, for interaction logic
var user = null # actor interacting with prop
var busy = false
var distance = 0.4
#var health = 1.0

var path_origin = Vector3()
var start_tr = Transform()

func id_change(id):
	itemid = id
	if Engine.editor_hint:
		reload_mesh()
func reload_mesh():
	print("loading mesh: <%s>" % [itemid])

	# clear previously existing mesh
	for c in get_children():
		c.free()

	# check if resource exists
	var p = "res://meshes/props/" + itemid + ".dae"
	if itemid == "" || !ResourceLoader.exists(p):
		return

	# load mesh file and add as a node
	var m = load(p).instance()
	add_child(m)

	# only took me 4 hours, I want to die :D
	# --yeahhh scratch that, I'm rewriting it and it's taking even longer
	var meshroot = m.get_child(0)
	var coll = null
	for n in meshroot.get_children():
		if n is RigidBody:
			coll = n
	if coll == null:
		print("ERROR: missing collision body!")
		return

	# reparent rigidbody, rename, copy over data from old one cuz lazy
	meshroot.remove_child(coll)
	add_child(coll)
	coll.remove_child(coll.get_node("mesh"))
	coll.name = "rb"
	coll.collision_layer = 8
	coll.collision_mask = 1 + 4 + 8
	var pm = PhysicsMaterial.new()
	pm.resource_local_to_scene = true
	coll.physics_material_override = pm

	# move meshes to the new rigidbody
	m.remove_child(meshroot)
	coll.add_child(meshroot)
	meshroot.name = "mesh"
	if !Engine.editor_hint:
		init_mesh_array()

func highlight(y):
	hl = false
#	if y == true:
#		print("ha")
	if user != null: # already being used by someone!
		y = false
	for n in meshnodes:
		n.get_surface_material(0).next_pass.next_pass.set_shader_param("visible", y)
		pass
	hl = y

func to_reach(pos):
	return path_origin
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
		if "damage" in hit_data:
			data.health -= hit_data.damage
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

func _ready():
	if Engine.editor_hint:
		return

	init_mesh_array()

	path_origin = get_global_transform().origin
	add_to_group("props")
	add_to_group("rpc_sync")

	###

	reload_mesh()

	# pickup-able item vs interactible/physics room prop
	var item_data = Game.get_item_data(itemid)
	if item_data != null:
#		type = 1000 # <---- TODO: redo type variables
		data = item_data.duplicate()
	else:
		data = { # default "dummy" item data
			"type": 999,
			"health" : -1
		}
#		type = 999

#	custom_item = item_data.duplicate()
