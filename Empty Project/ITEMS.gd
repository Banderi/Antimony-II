extends Node

func init():
	# item data
	# item types: 0 = weapon; 1 = ammo/pickups; 2 = consumable; 3 = equipment; 4 = key items
	#			  10 = level elements; 11 = units/pawns
	Game.db.items = {

		### PROPS
		"target": {
			"type": 999,
			"health": 100
		},

		### BUILDINGS
		"house": {
			"name": "Cottage",
			"type": 10,
			"health": 100,
		},

		### UNITS
		"villager": {
			"name": "Villager",
			"type": 11,
			"health": 100,
		},
		"soldier": {
			"name": "Foot solider",
			"type": 11,
			"health": 100,
		},
	}
