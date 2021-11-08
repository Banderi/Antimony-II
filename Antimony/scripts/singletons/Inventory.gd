extends Node

# database placeholders
var db = {
	"items": {
		# ...
	},
	"magazines": {
		# ...
	}
}

enum ivs {
	simple,		# bog standard dictionary stored above, ez pz
	rpg			# used in games like Project K - has a fixed inventory menu and a hotbar/toolbelt that receives the props
}
var invsystem = ivs.simple

func in_inv(itemid): # return -1 if not in invequip - return parent's item array index if so
	match invsystem:
		ivs.simple:
			if db.items.has(itemid) && db.items[itemid] > 0:
				return db.items[itemid];
			return 0
		ivs.rpg:
			var r = -1
			var item_data = Game.get_item_data(itemid)
			var items = UI.hh_invequip[item_data.slot[0]].items # check in slot
			for i in items.size(): # still, use first slot for now
				var hi = items[i]
				if Game.get_item_data(hi.prop.itemid).layer == item_data.layer:
					r = i
			return r
func can_equip(item):
	var s = in_inv(item)
	if !item.stackable && s > -1: # cannot be equip! (not stackable)
		return false
	return true
func eyed_slot(item): # return the would-be slot offset index of the new item, or 0 if cannot equip
	var s = in_inv(item) + 1 # no item defaults to -1, so minimum is 0
	if s > 0 && !item.stackable: # cannot be stacked!
		return [3, s - 1] # e.g. item is at slot 4 --> return -5
	return [2, s]
func first_free_invslot():
	for s in range(0,3):
		if !UI.hh_invbar[s].has_items():
			return s
	return -1
func equip(prop): # updates stats, actor equipment slots (3d models) etc.
	prop.RPC_hide() # easier to put this call here? hacky, but it's fine...
	var item_data = Game.get_item_data(prop.itemid)
	if item_data.slot != null:
		Game.player.rpc("RPC_equip", prop.itemid, true)
	match item_data.ammo:
		1: # lockable gear
			pass
		2: # gasmask/oxygen tank
			var diff = 1000 - Game.player.oxygen
			var accept = min(diff, prop.custom_item.quantity)
			Game.player.oxygen += accept # add ammo quantity to store
			prop.custom_item.quantity -= accept
			pass
		3: # goo gun/canister
			pass
		4: # energy gear/cell
			pass
func unequip(prop):
	var item_data = Game.get_item_data(prop.itemid)
	if item_data.slot != null:
		Game.player.rpc("RPC_equip", prop.itemid, false)
func giveitem(prop):
	var item_data = Game.get_item_data(prop.itemid)

	match invsystem:
		ivs.simple:
			pass
		ivs.rpg:
			var s = first_free_invslot()
			if Game.settings.controls.equip_on_pickup: # autoequip
				if can_equip(item_data):
					s = item_data.slot[0] + 3
				elif item_data.ammo > -1: # has ammo value - add to the ammo store!
					s = -3
			if s == -1:
				return false

			var hi = UI.insert_HUDitem(prop, s)

	return true
func dropitem(hi):
	UI.pop_HUDitem(hi)
func despawn(hi):
	hi.get_parent().get_parent().remove_item(hi)
	hi.prop.queue_free()
	hi.queue_free()

var curr_weapon = null
var last_weapon = null

func get_weapon_bank(weapid):
	for b in Game.db.weap_banks.size():
		var i = Game.db.weap_banks[b].index_of(weapid)
		if i != -1:
			return [b, i]
	return null
func equip_weapon(weapid):
	if weapid == null || Game.weaps.busy():
		return
	last_weapon = curr_weapon
	curr_weapon = weapid
	Game.weaps.update_weapon_selection()
	UI.update_weap_hud()
	UI.update_weap_ammo_counters()
func weapon_prev():
	var prev_weapon = null
	for bank in Game.db.weap_banks:
		for weapid in bank:
			if weapid != curr_weapon && in_inv(weapid):
				var ammoid = Game.get_weap_data(weapid).ammoid
				if ammoid == null || in_inv(ammoid) || Game.settings.controls.equip_empty_weapons: # check ammo
					prev_weapon = weapid
			if weapid == curr_weapon && prev_weapon != null: # found a weapon preceding the currently equipped one
				return equip_weapon(prev_weapon)
	if prev_weapon != null:
		equip_weapon(prev_weapon) # finally, if no valid weapon before the current one - equipped whatever last valid weapon is in the banks
func weapon_next():
	var next_weapon = null
	var after_current = false
	for bank in Game.db.weap_banks:
		for weapid in bank:
			if weapid == curr_weapon:
				after_current = true
			elif next_weapon == null || after_current:
				if in_inv(weapid):
					var ammoid = Game.get_weap_data(weapid)
					if ammoid == null || in_inv(ammoid) || Game.settings.controls.equip_empty_weapons: # check ammo
						if after_current:
							return equip_weapon(weapid) # found a weapon succeeding the currently equipped one
						next_weapon = weapid
	if next_weapon != null:
		equip_weapon(next_weapon) # finally, if no valid weapon after the current one - equipped whatever first valid weapon is in the banks

func give_amount(itemid, amount):
	match invsystem:
		ivs.simple:
			var item_data = Game.get_item_data(itemid)
			var quantity_max = 1
			if item_data.has("quantity_max"):
				quantity_max = item_data.quantity_max
			var ininv = in_inv(itemid)
			var available_space = quantity_max - ininv
			var accepted = min(available_space, amount)
			var refused = amount - available_space
			db.items[itemid] = ininv + accepted
			return refused
func reload_ammo(weapid, amount):
	match invsystem:
		ivs.simple:
			if !db.magazines.has(weapid):
				db.magazines[weapid] = 0
			var available_space = Game.get_weap_data(weapid).mag_max - db.magazines[weapid]
			var accepted = min(available_space, amount)
			var refused = amount - available_space
			db.magazines[weapid] += accepted
			return refused
func ammo_in_mag(weapid):
	match invsystem:
		ivs.simple:
			var weap_data = Game.get_weap_data(weapid)
			if weap_data.use_mag:
				return db.magazines[weapid]
			else:
				return in_inv(weap_data.ammoid)
func consume_ammo(weapid, amount):
	match invsystem:
		ivs.simple:
			var weap_data = Game.get_weap_data(weapid)
			var missing = 0
			if weap_data.use_mag:
				var available = min(ammo_in_mag(weapid), amount)
				missing = amount - available
				if missing == 0: # do not fire if not enough ammo "rounds" are available
					db.magazines[weapid] -= available
			else:
				missing = consume_amount(weap_data.ammoid, amount, false)
			return missing
func consume_amount(itemid, amount, consume_if_missing = true):
	match invsystem:
		ivs.simple:
			var available = min(db.items[itemid], amount)
			var missing = amount - available
			if missing == 0 || consume_if_missing:
				db.items[itemid] -= available
			return missing

func give_weapon(weapid, ammo_amount = -1):
	var weap_data = Game.get_weap_data(weapid)
	give_amount(weapid, 1)
	if !weap_data.infinite_ammo:
		# default: use pickup_ammo amount
		if ammo_amount == -1:
			ammo_amount = weap_data.pickup_ammo
		give_amount(weap_data.ammoid, ammo_amount)

		# if it uses magazines, reload automatically
		if weap_data.use_mag:
			var requesting = weap_data.mag_max
			var missing = consume_amount(weap_data.ammoid, requesting)
			var available = requesting - missing
			reload_ammo(weapid, available)
	else:
		if weap_data.use_mag:
			reload_ammo(weapid, weap_data.mag_max)
