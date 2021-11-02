extends RigidBody
class_name RigidBullet

export(String) var ammoid = null
export(float) var health = 1.0
export(float) var speed = 0.1
export(float) var lifetime = 1.0
export(bool) var explode_on_contact = true
export(bool) var gravity = false
export(int, 1, 100) var max_contacts = 10

var owner_actor = null
var original_pos = Vector3()
var normal = Vector3()
var strength_scale = 1.0


###

func take_hit(hit_data):
	if health > 0:
		health -= hit_data.ammo_data.damage * hit_data.strength
		if health <= 0:
			destroy()
func destroy():
	# THIS FUNCTION IS IMPLEMENTED IN THE GAME'S OWN
	# CHILD SCRIPT INHERITING THIS CLASS.
	queue_free()
func on_hit(hit_result):
	# THIS FUNCTION IS IMPLEMENTED IN THE GAME'S OWN
	# CHILD SCRIPT INHERITING THIS CLASS.

	# default:
	Game.weaps.invoke_hit(hit_result, ammoid, Game.get_ammo_data(ammoid), strength_scale)

	if explode_on_contact:
		destroy()

###

# necessary to manually detect contacts & normals
func _integrate_forces(state):
	if state != null:
		for c in state.get_contact_count():
			var coll = instance_from_id(state.get_contact_collider_id(c))
			if coll != null:
	#			if coll.get_parent() != owner_actor: # disregard collisions with parent actor
				var hit_result = {
					"position": state.get_contact_collider_position(c),
					"normal": state.get_contact_local_normal(c),
					"collider_id": state.get_contact_collider_id(c),
				}
				var det = hit_result.normal.dot(normal)
	#			print(ammoid + " collided with " + str(hit_result.collider_id))
				if det > 0.0:
					if coll.get_parent() != owner_actor:
						hit_result.normal = -hit_result.normal
	#					print(str(hit_result.collider_id) + " !! " + str(hit_result.normal) + " " + str(hit_result.normal.dot(normal)))
						on_hit(hit_result)
	#				else:
	#					print("faulty collision with player!")
				else:
	#				if coll.get_parent() != owner_actor:
	#					print(str(hit_result.collider_id) + " -- " + str(hit_result.normal) + " " + str(hit_result.normal.dot(normal)))
	#				else:
	#					print("forward collision with player!")
					on_hit(hit_result)

var lifetime_elapsed = 0.0
func _process(delta):
	lifetime_elapsed += delta

	# check if past max life
	if lifetime_elapsed >= lifetime:
		return destroy()

	visible = true

func _ready():
	original_pos = get_global_transform().origin
	look_at(original_pos + normal, Vector3(0, 1, 0))
	visible = false # wait for a frame to pass to avoid aesthetic collision with muzzle flash

	# bullet physics settings
	set_contact_monitor(true)
	set_max_contacts_reported(max_contacts)
	if !gravity:
		gravity_scale = 0

	# coll. masks
	collision_layer = Masks.LEVEL + Masks.ACTORS + Masks.BULLETS
	collision_mask = Masks.PROPS + Masks.BULLETS

	apply_central_impulse(normal * speed) # start moving!
