extends Spatial
class_name WeaponSystem

# cached data because it's barbaric to fetch this every time!
var weapid = null
var ammoid = null
var item_data = null
var weap_data = null
var ammo_data = null

func update_weapon_data_cache():
	# update cached data
	weapid = Inventory.curr_weapon
	item_data = Game.get_item_data(weapid)
	weap_data = Game.get_weap_data(weapid)
	ammoid = weap_data.ammoid
	ammo_data = Game.get_ammo_data(ammoid)

var camera_tilt = Vector3()
var animation_offset = Vector3()
var animation_tilt = Vector3()

var rof_cooldown = 0.0
var reload_timer = 0.0

var triggers = [0, 0, 0]
var trigger_timers = [0, 0, 0]

var scope_enabled = false
var scope_zoom = 0.0
func scope(enabled):
	scope_enabled = enabled
	UI.update_weap_hud()
func scope_trigger(tstate):
	if Game.settings.controls.aim_toggle:
		if tstate.state == 1:
			scope(!scope_enabled)
	else:
		if tstate.state == 1:
			scope(true)
		elif tstate.state == 3:
			scope(false)
func scope_zoom(z):
	pass # TODO

func alt_fire_selector(tstate):
	if tstate.state == 1:
		# update alt_fire flag
		if !weap_data.has("alt_fire_selection"):
			weap_data["alt_fire_selection"] = 1
		else:
			weap_data.alt_fire_selection = !weap_data.alt_fire_selection

		# swap ammoid's
		var new_ammoid = weap_data.alt_ammoid
		weap_data.alt_ammoid = weap_data.ammoid
		weap_data.ammoid = new_ammoid
		ammoid = new_ammoid

		update_weapon_data_cache()

		# update HUD
		UI.update_weap_ammo_counters()

var hits_history = []
func decals_update():
	# remove old decals
	if hits_history.size() > Game.settings.visual.max_decals:
		var old = hits_history[0]
		# TODO: potential bug?
		# the node sometimes becomes invalid before
		# this line is called...
		if old.has("node") && weakref(old.node).get_ref() != null:
			old.node.queue_free()
		hits_history.pop_front()
func invoke_hit(hit_result, b_ammoid, b_ammo_data, strength_scale):
	# give damage to object hit
	var victim = instance_from_id(hit_result.collider_id)
	if victim != null:
		var local_hit_position = victim.to_local(hit_result.position)
		var local_normal = victim.to_local(hit_result.position + hit_result.normal) - local_hit_position
		if victim.has_method("take_hit"):
			victim.take_hit({
				"ammo_data": b_ammo_data,
				"position": local_hit_position,
				"normal": local_normal,
				"strength": strength_scale,
			})
		var victim_parent = victim.get_parent() # also check the parent
		if victim_parent.has_method("take_hit"):
			victim_parent.take_hit({
				"ammo_data": b_ammo_data,
				"position": local_hit_position,
				"normal": local_normal,
				"strength": strength_scale,
			})

		# add decals
		match b_ammo_data.decal_type:
			0: # standard bullet decal
				var decal = load("res://scenes/decals/" + b_ammoid + ".tscn").instance()

				var rand_decal_index = randi() % b_ammo_data.decal_files_max
				decal.get_node("mesh").get("material/0").albedo_texture = load("res://textures/decals/" + b_ammoid + "/" + str(rand_decal_index) + ".png")
				decal.get_node("mesh").rotation.z = randf() * 2 * PI
				victim.add_child(decal) # add to the tree before facing the normal to avoid having the engine scream at me
				decal.look_at_from_position(hit_result.position, hit_result.position + hit_result.normal, Vector3(1, 1, 1))
				hit_result["node"] = decal

		# sparkles
		if b_ammo_data.has("sparkles"):
			var sparkles
			match b_ammo_data.sparkles.type:
				1: # classic simple sparks -- metal on metal
					sparkles = load("res://Antimony/scenes/particles/sparkles_fast.tscn").instance()
			sparkles.emitting = true
			for param in b_ammo_data.sparkles:
				if param != "type":
					sparkles.set(param, b_ammo_data.sparkles[param] * strength_scale)
					sparkles.process_material.set(param, b_ammo_data.sparkles[param] * strength_scale) # cheating, but it works ;)
				if param == "size":
					sparkles.draw_pass_1.size *= b_ammo_data.sparkles[param] * strength_scale
			sparkles.translation = hit_result.position
			Game.level.add_child(sparkles)
			Game.set_death_timeout(sparkles, 1)

	# add hit to history
	hits_history.push_back(hit_result)

func common_scene_bullet(actor, npath):
	# bullet scene
	var bullet = load("res://scenes/bullets/" + npath + ".tscn").instance()

	# variable bullet data
	bullet.owner_actor = actor
	bullet.strength_scale = max(1.0, charge.consuming) # by default, scale per the cumulated ammo charge!
#	bullet.ammoid = ammoid
#	bullet.speed = ammo_data.speed

	# bullet position and rotation
	var emitter_position = get_node(Inventory.curr_weapon).get_node("emitter").get_global_transform().origin
	var goal = Vector3()
	if Game.controller.pick[0].has("position"):
		goal = Game.controller.pick[0].position
	else:
		var proj_origin = Game.controller.cam.project_ray_origin(get_viewport().get_mouse_position())
		var proj_normal = Game.controller.cam.project_ray_normal(get_viewport().get_mouse_position())
		goal = proj_origin + proj_normal * 20.0
	var normal = (goal - emitter_position).normalized()
	bullet.normal = normal
	bullet.translation = emitter_position

	# pass the new node back for handling
	return bullet
#func kinematic_bullet(ammoid, npath):
#	# common bullet scene
#	var bullet = common_scene_bullet(ammoid, npath)
#
#	# get bullet travel's normal
#	var emitter_position = get_node(Inventory.curr_weapon).get_node("emitter").get_global_transform().origin
#	var goal = Vector3()
#	if Game.controller.pick[0].has("position"):
#		goal = Game.controller.pick[0].position
#	else:
#		var proj_origin = Game.controller.cam.project_ray_origin(get_viewport().get_mouse_position())
#		var proj_normal = Game.controller.cam.project_ray_normal(get_viewport().get_mouse_position())
#		goal = proj_origin + proj_normal * 20.0
#	var normal = (goal - emitter_position).normalized()
#	bullet.normal = normal
#	bullet.translation = emitter_position
#
#	# pass the new node back for handling
#	return bullet
#func physics_bullet(ammoid, npath):
#	# common bullet scene
#	var bullet = common_scene_bullet(ammoid, npath)
#
#	# bullet data
#	var emitter = get_node(Inventory.curr_weapon).get_node("emitter")
#	var normal = ammo_data.normal.normalized() # just to be safe!
#	bullet.translation = emitter.get_global_transform().origin
#	bullet.normal = emitter.get_global_transform().xform(normal) - bullet.translation
#	bullet.explode_on_contact = ammo_data.explode_on_contact
#	if ammo_data.has("lifetime"):
#		bullet.lifetime = ammo_data.lifetime
#	else:
#		bullet.lifetime = Game.max_bullet_lifetime
#	if ammo_data.has("bounce"):
#		bullet.physics_material_override.bounce = ammo_data.bounce
#
#	# pass the new node back for handling
#	return bullet
func fire_bullet(ammoid, tstate):
	# THIS FUNCTION IS IMPLEMENTED IN THE GAME'S OWN
	# CHILD SCRIPT INHERITING THIS CLASS.

	# default cases:
	# 	- instantaneous (hitscan)
	#	- kinematic bullet
	#	- rigid bullet
	if ammo_data.has("bullet"):
		if ammo_data.bullet == null: # no bullet: instantaneous
			var hit_result = Game.controller.pick[0]
			if hit_result.size() != 0 && hit_result.has("position"):
				invoke_hit(hit_result, ammoid, ammo_data, 1.0)
			return
		else: # custom bullet scene name
			Game.level.add_child(common_scene_bullet(Game.player, ammo_data.bullet))
	else:
		Game.level.add_child(common_scene_bullet(Game.player, ammoid))
#			match ammo_data.type:
#				"rigid":
#					Game.level.add_child(physics_bullet(ammoid, ammoid))
#				"kinematic", _:
#					Game.level.add_child(kinematic_bullet(ammoid, ammoid))

func lerp_charge_amount(ammo_data, duration):
	# for now, only linear!
	var coeff = min(ammo_data.max_charge_duration, duration) / ammo_data.max_charge_duration
	return ammo_data.min_charge + floor((ammo_data.max_charge - ammo_data.min_charge) * coeff)

enum fa {
	none,
	semi,
	auto,
	burst,
	chunk,
	charge
}
var frames_since_firing = 1
var time_since_trigger = 1
var firing = false
var charging = false
var charge = { # ammo charge state
	"requesting": 0,
	"consuming": 0,
	"missing": 0
}
func fire_action(action, tstate, ammoid, q, rof):
	# no matter the action or weapon - do not fire while reloading or on cooldown
	if busy():
		return

	# first, check if there's enough ammo, reload if not,
	# otherwise store the cumulative charge (for special cases)
	var missing = max(q - Inventory.ammo_in_mag(weapid), 0)
	var consuming = q - missing
	if missing == q:
		if reload_timer <= 0 && Game.settings.controls.auto_reload:
			charge = {
				"requesting": q,
				"consuming": consuming,
				"missing": missing
			}
			time_since_trigger = 0.0 # timer for special uses
			reload(false)
		return

	# specific conditional logic for different firing actions
	firing = false
	charging = false
	match action:
		fa.semi:
			if tstate.state == 1:
				firing = true # fire on first press
				time_since_trigger = 0.0 # timer for special uses
		fa.auto:
			firing = true # fire on any press detection
			time_since_trigger = 0.0 # timer for special uses
		fa.charge:
			if tstate.state == 2:
				charging = true
				time_since_trigger = 0.0 # timer for special uses
			if tstate.state == 3:
				firing = true # fire on release
				time_since_trigger = 0.0 # timer for special uses

	# fire...??
	if firing:
		fire_bullet(ammoid, tstate) # F I R E !!!!!!

		# add weapon shake, recoil animation, cooldown etc.
		Game.controller.weapon_shake(weap_data.shake_strength, consuming)
		rof_cooldown = rof
		anim_weapon_firing = 0.1
		frames_since_firing = 0

		# consume ammo and reset the charge counter
		if !Game.unlimited_mags && !(!weap_data.use_mag && Game.unlimited_ammo):
			Inventory.consume_ammo(weapid, consuming)

	# reset ammo charge state
	if charging:
		charge = {
			"requesting": q,
			"consuming": consuming,
			"missing": missing
		}
	else:
		charge = {
			"requesting": 0,
			"consuming": 0,
			"missing": 0
		}
func trigger_action(tstate):
	# THIS FUNCTION IS IMPLEMENTED IN THE GAME'S OWN
	# CHILD SCRIPT INHERITING THIS CLASS.
	pass

func busy():
	if frames_since_firing == 0 || reload_timer > 0 || rof_cooldown > 0:
		return true

func reload(finished):
	if !finished && busy():
		return

	# cannot reload weapons that have no mag
	if !weap_data.use_mag:
		return

	var curr_mag = Inventory.ammo_in_mag(weapid)
	var curr_tot = -1
	if !weap_data.infinite_ammo:
		curr_tot = Inventory.in_inv(ammoid)
	var max_mag = weap_data.mag_max

	###

	if !weap_data.use_mag || curr_mag >= max_mag || curr_tot == 0:
		return

	scope(false) # reset scope while reloading

	if !finished:
		var cooldown = float(weap_data.reload_cooldown)
		reload_timer = cooldown
#		$sfx/audio_gun_reload.play()
	else:
		var requesting = max_mag - curr_mag
		var missing = 0
		if !weap_data.infinite_ammo && !Game.unlimited_ammo:
			missing = Inventory.consume_amount(ammoid, requesting) # naughty!!! consuming amounts BEFORE figuring out how much to take!
		var given = requesting - missing
		Inventory.reload_ammo(weapid, given)
func update_weapon_selection():
	update_weapon_data_cache()

	# switching animation
	anim_weapon_switching = 0.5
	for n in get_children():
		if n.has_node("muzzle_flash"):
			n.get_node("muzzle_flash").visible = false # just to be safe
		if n.name == weapid:
			n.visible = true
		else:
			n.visible = false

var anim_weapon_firing = 0
var anim_weapon_switching = 0
func update_anims(delta):
	# THIS FUNCTION IS IMPLEMENTED IN THE GAME'S OWN
	# CHILD SCRIPT INHERITING THIS CLASS.

	# weapon switching anim
	anim_weapon_switching = Game.delta_interpolate(anim_weapon_switching, 0, 0.5, delta)
	animation_offset.y += 0.3 * anim_weapon_switching
	animation_tilt.x -= 3 * anim_weapon_switching
	animation_tilt.z -= 5 * anim_weapon_switching
	animation_tilt.y += 5 * anim_weapon_switching

	# player's vertical speed sway
	animation_offset.y += 1 * (Game.player.velocity.y / Game.max_fall_speed)

	# BUG: the first shot fired after reloading, if it hits something,
	# will not display a muzzle flash *SOMETIMES*.
	# I have no idea how to fix this!!!!!
	# update muzzle flash
	if get_node(weapid).has_node("muzzle_flash"):
		var muzzle_flash = get_node(weapid).get_node("muzzle_flash")
		if frames_since_firing == 0:
			muzzle_flash.get_node("mesh").rotation.z = randf() * 2 * PI
			muzzle_flash.visible = true
		else:
			muzzle_flash.visible = false

func press_trigger(t, pressed):
	if pressed: # FIRING ??
		if triggers[t] != 0: # accidental input bleeding!
			return
		triggers[t] = 1
	else:
		if triggers[t] != 2: # accidental input bleeding!
			return
		triggers[t] = 3
func timer_advance(timer, delta, callback, args):
	if timer > 0.0:
		timer -= delta
		if timer <= 0.0 && callback != null: # timer done!
			var cbf = funcref(self, callback)
			cbf.call_funcv(args)
	else:
		timer = 0.0
	return timer
func trigger_state_process(t, delta):
	# update timer, fire if trigger is active
	if triggers[t] > 0:
		trigger_timers[t] += delta

		var tstate = {
			"t": t,
			"state": triggers[t],
			"duration": trigger_timers[t]
		}

		trigger_action(tstate)
	else:
		trigger_timers[t] = 0

	# udpate trigger state
	if triggers[t] == 1:
		triggers[t] = 2 # continuous press
	elif triggers[t] == 3:
		triggers[t] = 0 # trigger release

func _process(delta):
	rof_cooldown = timer_advance(rof_cooldown, delta, null, null)
	reload_timer = timer_advance(reload_timer, delta, "reload", [true])
	trigger_state_process(0, delta)
	trigger_state_process(1, delta)
	trigger_state_process(2, delta)

	# TODO: make this lighter! it re-draws text every frame!!
	UI.update_weap_ammo_counters(true)

	# update misc counters
	if frames_since_firing < 1024:
		frames_since_firing += 1
	if time_since_trigger < 16.0:
		time_since_trigger += delta

	# update bobbling, animations, tilt etc.
	animation_tilt = Vector3()
	animation_offset = Vector3()
	update_anims(delta)
	rotation = camera_tilt + animation_tilt
	translation = animation_offset

	# draw decals & hits
	decals_update()

	Debug.logpaddedinfo("triggers:   ", false, [10], [triggers, "timers:", trigger_timers])
	Debug.logpaddedinfo("timers:     ", true, [5, 10, 10, 10], ["frames:", frames_since_firing, "time:", time_since_trigger, "rof:", rof_cooldown, "reload:", reload_timer, "switching:", anim_weapon_switching])
	Debug.logpaddedinfo("charge:     ", false, [], [charging, charge.missing, "(" + str(charge.consuming) + "/" + str(charge.requesting) + ")"])
