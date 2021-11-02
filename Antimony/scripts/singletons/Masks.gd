extends Node

# This is painful.

# === EXPLANATION: ===
# The difference between LAYERS and MASKS does not matter in the least.
# The only effect of these is that if an object is set to one of the two
# and a second object is set to the other, they will collide - otherwise
# they will ignore each other.

# === EXAMPLE: ===
# The floor (static) is set to MASK=1. Actors(kinematic) are set to LAYER=1.
# The floor and the actors will collide!
# Same thing happens if the floor is set to LAYER=1 and the actors to MASK=1.

# === NOTE: ===
# These const are for the fields' VALUES, not BIT NUMBER!

const LEVEL = 1
const ACTORS = 2
#const OTHER_ACTORS = 4
const PROPS = 8

const BULLETS = 1024
