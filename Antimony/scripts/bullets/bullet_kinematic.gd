extends KinematicBody
class_name KinematicBullet

export(String) var ammoid = null
export(float) var health = 1.0
export(float) var speed = 0.1
export(float) var lifetime = 1.0
export(bool) var explode_on_contact = true
#export(bool) var slide_on_contact = true
export(bool) var maintain_normal = false
export(Vector3) var gravity = Vector3(0, -0.98, 0)
export(float) var mass = 1.0
export(float) var bounce = 0.5
export(float) var friction = 0.9
export(float) var damping = 0.003
#export(int, 1, 100) var max_contacts = 10

var owner_actor = null
var original_pos = Vector3()
var normal = Vector3()
var strength_scale = 1.0
#var ammoid = null
#var original_pos = Vector3()
#var normal = Vector3()
#var speed = 0.1
#var strength_scale = 1.0


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

func inverse_cross(A, C):
	return -A.cross(C) / A.length_squared()

func handle_collision_slide(data, slide):
	# record the collision's normal
	data.overall_coll_normal += slide.normal

	# grab some initial values & components...
	var local_normal_force = velocity_0.project(slide.normal)
	var radius = slide.position - translation
	var velocity_at_point_magnitude = vectorial_angular_velocity.length() * radius.length()
	var velocity_at_point_dir = vectorial_angular_velocity.cross(radius).normalized()
	var velocity_at_point = velocity_at_point_magnitude * velocity_at_point_dir
	velocity_at_point += velocity

	# friction at collision point
	var local_friction_magnitude = local_normal_force.length() * friction
	var local_friction_bound_magnitude = min(local_friction_magnitude, velocity_at_point.length())
	var local_friction_vector = -(velocity_0 - local_normal_force).normalized() * local_friction_bound_magnitude
	data.overall_ang_friction += local_friction_vector

	# NOTE: THIS ASSUMES THE CENTER OF MASS / COLLISION FIXED ON THE ORIGIN OF THE KINEMATIC BODY.
	var local_torque = radius.cross(local_friction_vector)
	data.overall_torque += local_torque

	# bounces!
	var bounce_vector = -velocity_0.dot(slide.normal) * slide.normal * bounce
	data.bouncing_forces += bounce_vector

	# redirection
	var redirect_vector = -radius.dot(slide.normal) * slide.normal * 1
#	data.redirect_forces += redirect_vector

	Debug.vector(slide.position, slide.normal, Color(1,0,1), true)
	Debug.vector(slide.position, local_normal_force, Color(1,1,0))
	Debug.vector(slide.position, velocity_at_point, Color(0,1,0))
#	Debug.vector(slide.position, local_friction_vector, Color(0,0,0))
#	Debug.vector(slide.position, bounce_vector, Color(0,0,1))
#	Debug.vector(slide.position, redirect_vector, Color(0,1,1))
#		print("%d %s @ %s" % [slide.collider_id, slide.normal, slide.position])
	var hit_result = {
		"position": slide.position,
		"normal": slide.normal,
		"collider_id": slide.collider_id,
	}
	on_hit(hit_result)
	return data
func handle_collision_kinematic(data, cc):
	# record the collision's normal
	data.overall_coll_normal += cc.normal

	# grab some initial values & components...
	var local_normal_force = velocity_0.project(cc.normal)
	var radius = cc.position - translation
	var velocity_at_point_magnitude = vectorial_angular_velocity.length() * radius.length()
	var velocity_at_point_dir = vectorial_angular_velocity.cross(radius).normalized()
	var velocity_at_point = velocity_at_point_magnitude * velocity_at_point_dir
	velocity_at_point += velocity

	# friction at collision point
	var local_friction_magnitude = local_normal_force.length() * friction
	var local_friction_bound_magnitude = min(local_friction_magnitude, velocity_at_point.length())
	var local_friction_vector = -(velocity_0 - local_normal_force).normalized() * local_friction_bound_magnitude
#	data.overall_ang_friction += local_friction_vector

	# NOTE: THIS ASSUMES THE CENTER OF MASS / COLLISION FIXED ON THE ORIGIN OF THE KINEMATIC BODY.
	var local_torque = radius.cross(local_friction_vector)
#	data.overall_torque += local_torque

	# bounces!
	var bounce_vector = -velocity_0.dot(cc.normal) * cc.normal * bounce
	data.bouncing_forces += bounce_vector

	# redirection
#	var redirect_vector = -radius.dot(cc.normal) * velocity_0 * 1
	var redirect_vector = -local_normal_force
	data.redirect_forces += redirect_vector

	Debug.vector(cc.position, cc.normal, Color(1,0,1), true)
	Debug.vector(cc.position, local_normal_force, Color(1,1,0))
	Debug.vector(cc.position, velocity_at_point, Color(0,1,0))
	Debug.vector(cc.position, local_friction_vector, Color(0,0,0))
	Debug.vector(cc.position, bounce_vector, Color(0,0,1))
	Debug.vector(cc.position, redirect_vector, Color(1,0,0))
#		print("%d %s @ %s" % [slide.collider_id, slide.normal, slide.position])
#		var hit_result = {
#			"position": collider.position,
#			"normal": collider.normal,
#			"collider_id": collider.collider_id,
#		}
#		on_hit(hit_result)
	return data

var velocity = Vector3()
var velocity_0 = Vector3()
#var velocity_1 = Vector3()
var vectorial_angular_velocity = Vector3()
func custom_collision_integration(delta):

	velocity_0 = velocity # prev velocity

	# add gravity
	velocity_0 = (velocity_0 + gravity * 0.9) * (1.0 - damping)

	# linear force integration
#	velocity = move_and_slide(velocity_0, Vector3(), false, 4, 0.785398, false) # add to previous velocities
#	var cc
#	var cc = move_and_collide(velocity_0 * delta, false)
#	velocity = velocity_0

	var data = {
		"overall_friction": Vector3(),
		"overall_ang_friction": Vector3(),
		"overall_torque": Vector3(),
		"overall_coll_normal": Vector3(),

		"bouncing_forces": Vector3(),
		"redirect_forces": Vector3()
	}

	if true:
		velocity = move_and_slide(velocity_0, Vector3(), false, 4, 0.785398, false) # add to previous velocities
		# iterate over slides
		for c in get_slide_count():
#			print(c)
			data = handle_collision_slide(data, get_slide_collision(c))
	else:
		var cc = move_and_collide(velocity_0 * delta, false)
		velocity = velocity_0
		# iterate over kinematic collisions
		if cc != null:
#			print(cc.collider_id)
			data = handle_collision_kinematic(data, cc)

	# TODO: overall_friction

	velocity += data.bouncing_forces + data.redirect_forces

#
#	# linear force integration
#	velocity = move_and_slide(velocity_0) # add to previous velocities

#	# bounce!
#	if overall_coll_normal != Vector3():
#		overall_coll_normal = overall_coll_normal.normalized()
#		velocity = velocity_0 - 2 * (velocity_0.dot(overall_coll_normal)) * overall_coll_normal * bounce

	# angular acceleration from torque
	if !maintain_normal:
		if data.overall_torque != Vector3():
			vectorial_angular_velocity = Game.delta_interpolate(vectorial_angular_velocity, data.overall_torque, 1.0 / mass, delta)
#		vectorial_angular_velocity = data.overall_torque # TODO: mass ("moment of inertia")
		if vectorial_angular_velocity != Vector3():
			var ang_axis = vectorial_angular_velocity.normalized()
			var ang_magnitude = vectorial_angular_velocity.length()
			rotate(ang_axis, ang_magnitude)

#	var ddd = overall_coll_normal.dot(Vector3(0,1,0))
#	if ddd < 0:
#	print("%d %s" % [get_slide_count(), ddd])
	Debug.vector(translation, velocity_0, Color(0,1,0), true)
#	Debug.vector(translation, overall_ang_friction * 100, Color(0,0,0))
	Debug.vector(translation, data.overall_torque * 10, Color(1,0,0))

func _physics_process(delta):
	# hoooooooo boy.
	custom_collision_integration(delta)
	velocity -= gravity
	custom_collision_integration(delta)

var lifetime_elapsed = 0.0
func _process(delta):
	lifetime_elapsed += delta

	# check if past max life
	var pos = get_global_transform().origin
	if pos.distance_to(original_pos) >= Game.max_bullet_travel:
		queue_free()

	# check if past max life
	if lifetime_elapsed >= lifetime:
		return destroy()

	visible = true

func _ready():
	original_pos = get_global_transform().origin
	look_at(original_pos + normal, Vector3(0, 1, 0))
	visible = false # wait for a frame to pass to avoid aesthetic collision with muzzle flash

	# initial velocity!
	velocity = normal * speed * 0.5 #move_and_slide(normal * speed)

	# coll. masks
	collision_layer = Masks.LEVEL + Masks.ACTORS + Masks.BULLETS
	collision_mask = Masks.PROPS + Masks.BULLETS
