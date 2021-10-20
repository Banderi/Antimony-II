extends Spatial
class_name Prop

var meshnodes = []

var hl = false # currently highlighted

var type = -1 # prop type, for interaction logic
var actor = null # actor interacting with prop
var busy = false
var distance = 0.4

var path_origin = Vector3()
var start_tr = Transform()

func highlight(y):
	hl = false
#	if y == true:
#		print("ha")
	if actor != null: # already being used by someone!
		y = false
	for n in meshnodes:
		n.get_surface_material(0).next_pass.next_pass.set_shader_param("visible", y)
		pass
	hl = y

func to_reach(pos):
	return path_origin
func interact(a):
	if actor != null:
		if actor == a:
			return -2 # already being used by this actor!
		return -1
	busy = true
	actor = a
	rpc("RPC_set_master", a.peer)
	return type
func release():
	busy = false
	actor = null
	rpc("RPC_release_actor")

func init_mesh_array():
	meshnodes = []
	var nodes = game.get_all_childs(self) # needs to be set beforehand - the "for in" loop evaluates EVERY TIME >:C
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
		actor = RPC.get_actor(peer)
		if type != 1000:
			actor.prop_inuse = self
remote func RPC_release_actor():
	if actor.prop_inuse == self:
		actor.prop_inuse = null
	actor = null

###

func _ready():
	init_mesh_array()

	path_origin = get_global_transform().origin
	add_to_group("props")
	add_to_group("rpc_sync")
