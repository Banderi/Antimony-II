extends RigidBody

var ammoid = null
var original_pos = Vector3()
var normal = Vector3()
var speed = 0.1
var strength_scale = 1.0
var lifetime = 1.0

###

func destroy():
	# THIS FUNCTION IS IMPLEMENTED IN THE GAME'S OWN
	# CHILD SCRIPT INHERITING THIS CLASS.

	queue_free()
	pass

var lifetime_elapsed = 0.0
func _process(delta):
	lifetime_elapsed += delta

	# check for collisions
	var colliding_array = get_colliding_bodies()
	if colliding_array.size() > 0:
		pass
#		var hit_result = {
#			"position": collider.position,
#			"normal": collider.normal,
#			"collider_id": collider.collider_id,
#		}
#		Game.weaps.invoke_hit(hit_result, ammoid, strength_scale)
#		return queue_free()

	# check if past max life
	if lifetime_elapsed >= lifetime:
		destroy()

	visible = true

func _ready():
	original_pos = get_global_transform().origin
	look_at(original_pos + normal, Vector3(0, 1, 0))
	visible = false # wait for a frame to pass to avoid aesthetic collision with muzzle flash

	apply_central_impulse(normal * speed)
