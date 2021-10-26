extends KinematicBody

var ammoid = null
var original_pos = Vector3()
var normal = Vector3()
var speed = 0.1
var strength_scale = 1.0

###

func _process(delta):
	# check for collisions
	var collider = move_and_collide(normal * speed, false)
	if collider != null:
		var hit_result = {
			"position": collider.position,
			"normal": collider.normal,
			"collider_id": collider.collider_id,
		}
		Game.weaps.invoke_hit(hit_result, ammoid, strength_scale)
		return queue_free()

	# check if past max life
	var pos = get_global_transform().origin
	if pos.distance_to(original_pos) >= Game.max_bullet_travel:
		queue_free()

	visible = true

func _ready():
	original_pos = get_global_transform().origin
	look_at(original_pos + normal, Vector3(0, 1, 0))
	visible = false # wait for a frame to pass to avoid aesthetic collision with muzzle flash
