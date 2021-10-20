extends Prop
class_name PhysProp
tool

export(String) var itemid = "" setget id_change

var custom_item = []

var initial_origin
var rb

###

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

func sleep():
	rb.collision_layer = 0
	rb.collision_mask = 0
	rb.sleeping = true
func wake():
	rb.collision_layer = 8
	rb.collision_mask = 1 + 4 + 8
	rb.sleeping = false

func _on_rb_body_entered(body):
	if body.has("prop_has_collided") && body.prop_to_reach == self:
		body.prop_has_collided = true

func release():
	rb.transform = actor.get_global_transform() * \
		Transform().rotated(Vector3(0,1,0), PI).translated(Vector3(0, 1.6, -0.5))
	.release()

###

var old_transform = Transform()
puppet func RPC_sync(packet = []): # called every frame!
	# owner of this object - start syncing this to other remotes
	if RPC.am_master(self):
		rpc_unreliable("RPC_sync", [
			rb.get_global_transform() if rb.get_global_transform() != old_transform else null
		])
	# not an owner ---> sync packet was received! update this "puppet" accordingly
	elif packet.size() > 0:
		rb.transform = packet[0] if packet[0] != null else rb.transform
		old_transform = rb.transform
puppet func RPC_destroy():
	if RPC.am_master(self):
		rpc("RPC_destroy")
	queue_free()
puppet func RPC_hide():
	if RPC.am_master(self):
		rpc("RPC_hide")
	visible = false
puppet func RPC_show():
	if RPC.am_master(self):
		rpc("RPC_show")
	visible = true

###

func _physics_process(delta):
	if Engine.editor_hint:
		return
	if rb.translation.y < -5:
		rb.transform = initial_origin

	# grabbed by an actor
	if actor != null:
		sleep()
		var pick = $rb.get_node("mesh").get_aabb().position
		rb.transform = actor.get_global_transform() * \
			actor.get_node("mesh/Armature/Skeleton").get_bone_global_pose(5).translated(
				Vector3(0.2, -pick.y - 0.1, pick.z + 0.2))
		rb.rotation.z = 0
	else:
		wake()

	# update pathing origin
	start_tr = rb.get_global_transform()
	path_origin = start_tr.origin

func _ready():
	if Engine.editor_hint:
		return

	reload_mesh()

	initial_origin = get_global_transform()
	rb = $rb

	# set as toplevel because hirerarchy makes me cri
	rb.transform = initial_origin
	transform = Transform()

	# pickup-able item vs interactible/physics room prop
	if game.items.has(itemid) && game.items[itemid].size() > 1:
		type = 1000
	else:
		type = 999

	custom_item = game.items[itemid].duplicate()
