# Grayscale value-textures for generated sheets: pattern carries the material,
# the game's tint carries the hue. Each is f(x, y) -> 0..255 for a FILL pixel,
# tile-local coordinates (y from the tile top), strictly 8-periodic so any
# tile placement composes seamlessly.

require_relative "../lib/dragon_autotile"

MATERIALS = {}

# Dressed stone: 4x4 blocks, darker seams, a catch-light on each block corner.
MATERIALS[:smooth] = lambda do |x, y|
  return 185 if x % 4 == 3 || y % 4 == 3

  base = 222 + (DragonAutotile.position_hash(x / 4, y / 4, 11) % 3) * 9
  shine = DragonAutotile.position_hash(x / 4, y / 4, 19) % 4 == 0
  return 248 if shine && x % 4 == 0 && y % 4 == 0

  base
end

# Running-bond brick: mortar rows every 4, joints alternating per course.
MATERIALS[:brick] = lambda do |x, y|
  return 172 if y % 4 == 3

  course = (y % 8) / 4
  joint = course == 0 ? 7 : 3
  return 172 if x == joint

  value = 226 + (DragonAutotile.position_hash((x + course * 4) / 8, y / 4, 23) % 3) * 8
  y % 4 == 0 ? value + 14 : value
end

# Sheet ice: bright base, diagonal glints, sparse hairline cracks.
MATERIALS[:ice] = lambda do |x, y|
  d = (x + y) % 8
  return 255 if d == 1
  return 246 if d == 2
  return 206 if DragonAutotile.position_hash(x, y, 37) % 11 == 0

  (x - y) % 8 == 5 ? 228 : 238
end

# Rough rock: quantised value noise with sparse dark cracks.
MATERIALS[:rock] = lambda do |x, y|
  crack_here = DragonAutotile.position_hash(x, y, 53) % 17 == 0
  crack_left = DragonAutotile.position_hash((x - 1) % 8, y, 53) % 17 == 0
  crack_up   = DragonAutotile.position_hash(x, (y - 1) % 8, 53) % 17 == 0
  return 158 if crack_here || crack_left || crack_up

  [190, 214, 240][DragonAutotile.position_hash(x, y, 41) % 3]
end

# Ornate inlay: a diamond ring per tile with a bright centre stud.
MATERIALS[:ornate] = lambda do |x, y|
  ring = (x * 2 - 7).abs + (y * 2 - 7).abs
  return 250 if ring <= 2
  return 188 if ring == 6 || ring == 7
  return 206 if (x % 7 == 0) && (y % 7 == 0)

  228
end
