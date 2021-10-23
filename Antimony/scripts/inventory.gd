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

func in_inv(item): # return -1 if not in invequip - return parent's item array index if so
	var r = -1
	var items = UI.hh_invequip[item.slot[0]].items # check in slot
	for i in items.size(): # still, use first slot for now
		var hi = items[i]
		if Game.get_item_data(hi.prop.itemid).layer == item.layer:
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

var curr_weapon = ""
var last_weapon = ""

func reload_amount(weapid, amount):
	match invsystem:
		ivs.simple:
			var available_space = Game.get_weap_data(weapid).mag_max - db.magazines[weapid]
			var accepted = min(available_space, amount)
			var refused = amount - available_space
			db.magazines[weapid] += accepted
			return refused
func give_amount(itemid, amount):
	match invsystem:
		ivs.simple:
			var available_space = Game.get_item_data(itemid).quantity_max - db.items[itemid]
			var accepted = min(available_space, amount)
			var refused = amount - available_space
			db.items[itemid] += accepted
			return refused
func consume_weapon_ammo(weapid, amount):
	match invsystem:
		ivs.simple:
			var weap_data = Game.get_weap_data(weapid)
			var missing = 0
			if weap_data.use_mag:
				var available = min(db.magazines[weapid], amount)
				missing = amount - available
				if missing == 0: # do not fire if not enough ammo "rounds" are available
					db.magazines[weapid] -= available
			else:
				missing = consume_amount(weap_data.ammo, amount, false)
			return missing
func consume_amount(itemid, amount, consume_if_missing = true):
	match invsystem:
		ivs.simple:
			var available = min(db.items[itemid], amount)
			var missing = amount - available
			if missing == 0 || consume_if_missing:
				db.items[itemid] -= available
			return missing
