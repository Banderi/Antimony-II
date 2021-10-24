extends Prop
class_name PhysProp

export(String) var rbpath = ""

var initial_origin
var rb

###

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
	rb.transform = user.body3D.get_global_transform() * \
		Transform().rotated(Vector3(0,1,0), PI).translated(Vector3(0, 1.6, -0.5))
	.release()

###

func take_hit(hit_data):
	wake()
	rb.apply_impulse(hit_data.position, -hit_data.normal)
	.take_hit(hit_data)

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
	if user != null:
		sleep()
		var pick = $rb.get_node("mesh").get_aabb().position
		rb.transform = user.body3D.get_global_transform() * \
			user.body3D.get_node("mesh/Armature/Skeleton").get_bone_global_pose(5).translated(
				Vector3(0.2, -pick.y - 0.1, pick.z + 0.2))
		rb.rotation.z = 0
	else:
		wake()

	# update pathing origin
	start_tr = rb.get_global_transform()
	path_origin = start_tr.origin

func _ready():

	initial_origin = get_global_transform()
	rb = get_node(rbpath)
	rb.get_node("mesh").layers = 0
	print("setting collision mesh to <%s>" % [rbpath])

	._ready()
