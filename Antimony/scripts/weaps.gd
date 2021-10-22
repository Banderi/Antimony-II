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
func scope(tstate):
	if game.settings.controls.aim_toggle:
		if tstate == 1:
			scope_enabled = !scope_enabled
	else:
		if tstate == 1:
			scope_enabled = true
		elif tstate == 3:
			scope_enabled = false
	UI.update_weap_hud()
func scope_zoom(z):
	pass # TODO

func spawn_bullet(bullet):
	# TODO
	if bullet == null:
		return

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
	# no matter the action or weapon - do not fire while reloading
	if reload_timer > 0:
		return

	var weapid = game.gamestate.curr_weapon
	var weap_data = game.weapons[weapid]

	###


	# logic for different kinds of firing actions
	match action:
		fa.semi:
			if rof_cooldown <= 0 && tstate == 1:
				firing = true
		fa.auto:
			if rof_cooldown <= 0:
				firing = true

	# fire...??
	if firing:
		var missing = 0
		missing = game.consume_weapon_ammo(weapid, q) # attempts consuming first, returns results
		if !missing:
			game.controller.weapon_shake(weap_data.shake_strength)
			spawn_bullet(bullet) # FIRE!!!!!!
			rof_cooldown = rof
		else:
			if reload_timer <= 0 && game.settings.controls.auto_reload:
				reload(false)
			firing = false
func fire(t):
	# THIS FUNCTION IS IMPLEMENTED IN THE GAME'S OWN
	# CHILD SCRIPT INHERITING THIS CLASS.
	pass

func reload(finished):
	if !finished && reload_timer > 0:
		return

	var weapid = game.gamestate.curr_weapon
	var weap_data = game.weapons[weapid]

	var ammoid = weap_data.ammo
	var curr_mag = game.gamestate.magazines[weapid]
	var curr_tot = game.gamestate.inventory[ammoid]
	var max_mag = weap_data.mag_max

	###

	if !weap_data.use_mag || curr_mag >= max_mag || curr_tot <= 0:
		return
	if !finished:
		var cooldown = float(weap_data.reload_cooldown)
		reload_timer = cooldown
	else:
		var requesting = max_mag - curr_mag
		var missing = 0
#		var missing = game.consume_amount(ammoid, requesting) # naughty!!! consuming amounts BEFORE figuring out how much to take!
		var given = requesting - missing
		game.reload_amount(weapid, given)
		UI.update_weap_ammo_counters()

func delta_interpolate(old, new, s, delta):
	return old + (new - old) * s * 60 * delta
var anim_firing_z_offset = 0
func update_anims(delta):
	var weapid = game.gamestate.curr_weapon
	var weap_data = game.weapons[weapid]

	###

	animation_tilt = Vector3()
	animation_offset = Vector3()

	# firing anim
	if firing:
		anim_firing_z_offset = 0.1
	anim_firing_z_offset = delta_interpolate(anim_firing_z_offset, 0, 0.1, delta)
	animation_offset.z = anim_firing_z_offset

	# reload anim
	var reload_anim_linear = reload_timer / weap_data.reload_cooldown
	var reload_anim_coeff = sin(reload_anim_linear * PI)
	var reload_anim_coeff_2 = sin(reload_anim_linear * PI * 2)
	var reload_anim_coeff_3 = sin(reload_anim_linear * PI * 3)
	animation_offset.y += -0.003 * reload_anim_coeff_3 - 0.01 * reload_anim_coeff_2 - 0.005 * reload_anim_coeff
	animation_tilt.x += -0.25 * reload_anim_coeff
	animation_tilt.z += -0.03 * reload_anim_coeff_3 + 0.02 * reload_anim_coeff_2

	# vertical speed
	animation_offset.y += 1 * (game.player.velocity.y / game.max_fall_speed)

	# update muzzle flash
	var muzzle_flash = get_node(weapid).get_node("muzzle_flash")
	if firing:
		if muzzle_flash.has_node("mesh"):
			var mesh = muzzle_flash.get_node("mesh")
			mesh.rotation.z = randf()
		muzzle_flash.visible = true
	else:
		muzzle_flash.visible = false

func press_trigger(t, pressed):
	if pressed: # FIRING ??
		if triggers[t] != 0: # accidental input bleeding!
			return
		triggers[t] = 1
		fire(t)
	else:
		if triggers[t] != 2: # accidental input bleeding!
			return
		triggers[t] = 3
		fire(t)
		trigger_timers[t] = 0.0 # trigger released -- cease fire and reset the trigger timer
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
	if triggers[t] == 3: # finished pressing
		triggers[t] = 0
	elif triggers[t] >= 1: # continuos press
		triggers[t] = 2
		trigger_timers[t] += delta
		fire(t)

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

	debug.logpaddedinfo("triggers:   ", false, [10], [triggers, "timers:", trigger_timers])
	debug.logpaddedinfo("firing:     ", false, [7, 10], [firing, rof_cooldown, reload_timer])

	# reset FIRING states
	firing = false

func _ready():
	pass # Replace with function body.
