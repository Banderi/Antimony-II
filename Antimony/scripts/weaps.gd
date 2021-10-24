extends Spatial
class_name WeaponSystem

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
		if tstate == 1:
			scope(!scope_enabled)
	else:
		if tstate == 1:
			scope(true)
		elif tstate == 3:
			scope(false)
func scope_zoom(z):
	pass # TODO

var max_hit_history = 10
var hits_history = []
func decals_update():
	# remove old decals
	if hits_history.size() > max_hit_history:
		var old = hits_history[0]
		# TODO: potential bug?
		# the node sometimes becomes invalid before
		# this line is called...
		if weakref(old.node).get_ref() != null:
			old.node.queue_free()
		hits_history.pop_front()
func invoke_hit(hit_result, ammoid):
	var ammo_data = Game.get_ammo_data(ammoid)

	###

	# give damage to object hit
	var victim_coll = instance_from_id(hit_result.collider_id)
	var victim = victim_coll.get_parent()
	var local_hit_position = victim_coll.to_local(hit_result.position)
	var local_normal = victim_coll.to_local(hit_result.position + hit_result.normal) - local_hit_position
	if victim.has_method("take_hit"):
		victim.take_hit({
			"ammo_data": ammo_data,
			"position": local_hit_position,
			"normal": local_normal
		})
		print(victim.data.health)

	# add decals
	var decal = load("res://scenes/decals/" + ammoid + ".tscn").instance()

	var rand_decal_index = randi() % ammo_data.decal_files_max
	decal.get_node("mesh").get("material/0").albedo_texture = load("res://textures/decals/" + ammoid + "/" + str(rand_decal_index) + ".png")
	decal.get_node("mesh").rotation.z = randf() * 2 * PI
	victim_coll.add_child(decal) # add to the tree before facing the normal to avoid having the engine scream at me
	decal.look_at_from_position(hit_result.position, hit_result.position + hit_result.normal, Vector3(1, 1, 1))

	# sparkles
	match ammo_data.sparkles.type:
		1: # classic simple sparks -- metal on metal
			var sparkles = load("res://Antimony/scenes/particles/sparkles_fast.tscn").instance()
			decal.add_child(sparkles)
			sparkles.emitting = true
			Game.set_death_timeout(sparkles, 1)

	# add hit to history
	hit_result["node"] = decal
	hits_history.push_back(hit_result)

func fire_bullet(ammoid):
	print("shot!")
	var ammo_data = Game.get_ammo_data(ammoid)

	###

#	$sfx/audio_gun_shot.play()
	spawn_bullet(ammo_data.bullet) # this is what exits the gun...

	if ammo_data.bullet == null: # no physical bullet -- hit instantaneously
		var hit_result = Game.controller.pick[0]
		if hit_result.size() != 0 && hit_result.has("position"):
			invoke_hit(hit_result, ammoid)
func spawn_bullet(bullet):
	# THIS FUNCTION IS IMPLEMENTED IN THE GAME'S OWN
	# CHILD SCRIPT INHERITING THIS CLASS.
	pass

enum fa {
	none,
	semi,
	auto,
	burst,
	chunk,
	charge
}
var firing = false
func fire_action(action, tstate, bullet, q, rof):
	# no matter the action or weapon - do not fire while reloading or on cooldown
	if busy():
		return

	var weapid = Inventory.curr_weapon
	var weap_data = Game.get_weap_data(weapid)

	###

	# specific conditional logic for different firing actions
	match action:
		fa.semi:
			if tstate == 1:
				firing = true
		fa.auto:
			firing = true

	# fire...??
	if firing:
		var missing = 0
		missing = Inventory.consume_weapon_ammo(weapid, q) # attempts consuming first, returns results
		if !missing:
			Game.controller.weapon_shake(weap_data.shake_strength)
			fire_bullet(bullet) # FIRE!!!!!!
			rof_cooldown = rof
		else:
			firing = false
			if reload_timer <= 0 && Game.settings.controls.auto_reload:
				reload(false)
func live_action(t):
	# THIS FUNCTION IS IMPLEMENTED IN THE GAME'S OWN
	# CHILD SCRIPT INHERITING THIS CLASS.
	pass

func busy():
	if firing || reload_timer > 0 || rof_cooldown > 0:
		return true

func reload(finished):
	if !finished && busy():
		return

	var weapid = Inventory.curr_weapon
	var weap_data = Game.get_weap_data(weapid)

	var ammoid = weap_data.ammo
	var curr_mag = Inventory.db.magazines[weapid]
	var curr_tot = Inventory.db.items[ammoid]
	var max_mag = weap_data.mag_max

	###

	if !weap_data.use_mag || curr_mag >= max_mag || curr_tot <= 0:
		return

	scope(false) # reset scope while reloading

	if !finished:
		var cooldown = float(weap_data.reload_cooldown)
		reload_timer = cooldown
#		$sfx/audio_gun_reload.play()
	else:
		var requesting = max_mag - curr_mag
		var missing = 0
#		var missing = Game.consume_amount(ammoid, requesting) # naughty!!! consuming amounts BEFORE figuring out how much to take!
		var given = requesting - missing
		Inventory.reload_amount(weapid, given)
		UI.update_weap_ammo_counters()

func select_weapon(weapid):
	anim_weapon_switching = 0.5
	for n in get_children():
		n.get_node("muzzle_flash").visible = false # just to be safe
		if n.name == weapid:
			n.visible = true
		else:
			n.visible = false

var anim_firing_z_offset = 0
var anim_weapon_switching = 0
func update_anims(delta):
	var weapid = Inventory.curr_weapon
	var weap_data = Game.get_weap_data(weapid)

	###

	animation_tilt = Vector3()
	animation_offset = Vector3()

	# firing anim
	if firing:
		anim_firing_z_offset = 0.1
	anim_firing_z_offset = Game.delta_interpolate(anim_firing_z_offset, 0, 0.4, delta)
	animation_offset.z = anim_firing_z_offset

	# reload anim
	if weap_data.ammo != null:
		var reload_anim_linear = reload_timer / weap_data.reload_cooldown
		var reload_anim_coeff = sin(reload_anim_linear * PI)
		var reload_anim_coeff_2 = sin(reload_anim_linear * PI * 2)
		var reload_anim_coeff_3 = sin(reload_anim_linear * PI * 3)
		animation_offset.y += -0.003 * reload_anim_coeff_3 - 0.01 * reload_anim_coeff_2 - 0.005 * reload_anim_coeff
		animation_tilt.x += -0.25 * reload_anim_coeff
		animation_tilt.z += -0.03 * reload_anim_coeff_3 + 0.02 * reload_anim_coeff_2

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
	var muzzle_flash = get_node(weapid).get_node("muzzle_flash")
	if firing:
		muzzle_flash.get_node("mesh").rotation.z = randf() * 2 * PI
		muzzle_flash.visible = true
	elif !firing && muzzle_flash.visible:
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
		live_action(t)
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

	# update bobbling, animations, tilt etc.
	update_anims(delta)
	rotation = camera_tilt + animation_tilt
	translation = animation_offset

	# draw decals & hits
	decals_update()

	Debug.logpaddedinfo("triggers:   ", false, [10], [triggers, "timers:", trigger_timers])
	Debug.logpaddedinfo("firing:     ", false, [7, 10, 10], [firing, rof_cooldown, reload_timer, anim_weapon_switching])

	# reset FIRING states
	firing = false
