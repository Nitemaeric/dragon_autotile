$failures = 0
$count = 0

def check(condition, message)
  $count += 1
  return if condition

  $failures += 1
  puts "FAIL: #{message}"
end

def check_eq(actual, expected, message)
  check(actual == expected, "#{message} (expected #{expected.inspect}, got #{actual.inspect})")
end

# --- Layout -------------------------------------------------------------------

layout = DragonAutotile::Layout::DUAL_GRID_16
check_eq(layout.length, 16, "canonical layout has 16 entries")
check_eq(layout.map { |c| [c[:col], c[:row]] }.uniq.length, 16, "every mask maps to a distinct cell")
check_eq(layout[0], { col: 0, row: 0 }, "mask 0 is top-left")
check_eq(layout[15], { col: 3, row: 3 }, "mask 15 is bottom-right")
check_eq(layout[6], { col: 2, row: 1 }, "index = mask, row-major")

custom = Array.new(16) { |i| { col: 15 - i, row: 0 } }
check_eq(DragonAutotile::Layout.resolve(custom), custom, "a 16-entry table passes through as a custom layout")
begin
  DragonAutotile::Layout.resolve([{ col: 0, row: 0 }])
  check(false, "a short layout raises")
rescue ArgumentError
  check(true, "a short layout raises")
end

# --- Tileset ------------------------------------------------------------------

tiles = DragonAutotile::Tileset.new(path: "sprites/walls.png", tile_size: 8)
rect = tiles.source_rect(0)
check_eq(rect[:source_x], 0, "mask 0 sits in sheet column 0")
check_eq(rect[:source_y], 24, "visual top row flips to the highest source_y band")
rect = tiles.source_rect(15)
check_eq(rect[:source_x], 24, "mask 15 sits in sheet column 3")
check_eq(rect[:source_y], 0, "visual bottom row flips to source_y 0")
check_eq(rect[:source_w], 8, "source_w is the tile size")

varied = DragonAutotile::Tileset.new(path: "sprites/walls.png", tile_size: 8, variants: 3)
a = varied.source_rect(5, col: 10, row: 20)
b = varied.source_rect(5, col: 10, row: 20)
check_eq(a, b, "variant choice is stable for the same cell")
different = (0...32).map { |c| varied.source_rect(5, col: c, row: 0)[:source_y] }.uniq
check(different.length > 1, "variants actually vary across positions")
all_bands = (0...200).map { |c| varied.source_rect(5, col: c, row: 3)[:source_y] }.uniq.sort
check_eq(all_bands.length, 3, "all three variant bands are reachable")

frames = DragonAutotile::Tileset.new(paths: ["a.png", "b.png", "c.png"], tile_size: 8, fps: 6)
check_eq(frames.frame_count, 3, "frame_count counts the sheets")
check_eq(frames.path_at(0), "a.png", "cursor 0 is the first frame")
check_eq(frames.path_at(4), "b.png", "the cursor wraps")
check_eq(frames.source_rect(3)[:path], "a.png", "source_rect uses the first frame's path; callers swap via path_at")

padded = DragonAutotile::Tileset.new(path: "sprites/walls.png", tile_size: 8, gutter: 1)
rect = padded.source_rect(0)
check_eq(rect[:source_x], 1, "gutter insets the first column")
check_eq(rect[:source_y], 31, "gutter-aware flip: rows pitch by tile + 2*gutter")
check_eq(padded.source_rect(15)[:source_x], 31, "column 3 lands past three padded slots")
check_eq(rect[:source_w], 8, "source size stays the bare tile")

# --- position_hash ------------------------------------------------------------

check_eq(DragonAutotile.position_hash(3, 7, 42), DragonAutotile.position_hash(3, 7, 42), "hash is deterministic")
check(DragonAutotile.position_hash(3, 7, 42) != DragonAutotile.position_hash(4, 7, 42), "hash varies by column")
check(DragonAutotile.position_hash(3, 7, 42) != DragonAutotile.position_hash(3, 7, 43), "hash varies by seed")
check(DragonAutotile.position_hash(0, 0, 0) >= 0, "hash is non-negative")

# --- Grid: masks --------------------------------------------------------------

grid = DragonAutotile::Grid.new(w: 4, h: 4)
grid.set(1, 1, :wall)

check_eq(grid.dual_mask(1, 1), 1, "cell is the BR corner of the dual cell up-left of it")
check_eq(grid.dual_mask(2, 1), 2, "and the BL corner one dual cell to the right")
check_eq(grid.dual_mask(1, 2), 4, "and the TR corner one dual cell down")
check_eq(grid.dual_mask(2, 2), 8, "and the TL corner diagonally down-right")
check_eq(grid.dual_mask(0, 0), 0, "far dual cells are empty")

grid.set(2, 1, :wall)
check_eq(grid.dual_mask(2, 1), 3, "two adjacent cells combine corner bits")

# --- Grid: edges --------------------------------------------------------------

open_grid = DragonAutotile::Grid.new(w: 2, h: 2, edge: :empty)
open_grid.fill(0, 0, 2, 2, :wall)
check_eq(open_grid.dual_mask(0, 0), 1, "an open edge leaves boundary corners unfilled")

closed = DragonAutotile::Grid.new(w: 2, h: 2, edge: :solid)
closed.fill(0, 0, 2, 2, :wall)
check_eq(closed.dual_mask(0, 0), 15, "a solid edge caps the boundary")
check_eq(closed.dual_mask(1, 1), 15, "interior is unaffected by edge mode")

# --- Grid: solid predicate ----------------------------------------------------

regions = DragonAutotile::Grid.new(w: 2, h: 1, solid: ->(v) { v == :wall })
regions.set(0, 0, :wall)
regions.set(1, 0, :floor)
check_eq(regions.dual_mask(1, 1), 8, "the predicate decides solidity, not truthiness (:floor is not solid)")

# --- Grid: dirty tracking -----------------------------------------------------

grid = DragonAutotile::Grid.new(w: 4, h: 4)
grid.set(1, 1, :wall)
dirty = grid.drain_dirty.sort
check_eq(dirty, [[1, 1], [1, 2], [2, 1], [2, 2]], "a set dirties exactly its four dual cells")
check_eq(grid.dirty?, false, "drain clears the set")
grid.set(1, 1, :wall)
check_eq(grid.dirty?, false, "an identical write dirties nothing")

# --- Grid: per-pass solid + dirty feeds (terrain layering) --------------------

terrain = DragonAutotile::Grid.new(w: 3, h: 1)
terrain.set(0, 0, :ice)
terrain.set(1, 0, :grass)

ice_or_grass = ->(v) { v == :ice || v == :grass }
grass_only = ->(v) { v == :grass }
check_eq(terrain.dual_mask(1, 1, solid: ice_or_grass), 12, "the lower layer counts higher terrain as solid (extends beneath)")
check_eq(terrain.dual_mask(1, 1, solid: grass_only), 4, "the upper layer counts only itself (its skirt draws over)")
check_eq(terrain.dual_mask(1, 1), 12, "no override falls back to truthiness")

tiles8 = DragonAutotile::Tileset.new(path: "sprites/t.png", tile_size: 8)
grass_draws = 0
terrain.each_resolved(tiles8, solid: grass_only) { |_d, _c, _r| grass_draws += 1 }
check_eq(grass_draws, 4, "a per-pass predicate resolves only that terrain's dual cells")

feed_grid = DragonAutotile::Grid.new(w: 4, h: 4)
feed_a = feed_grid.dirty_feed
feed_b = feed_grid.dirty_feed
feed_grid.set(1, 1, :wall)
check_eq(feed_a.drain_dirty.sort, [[1, 1], [1, 2], [2, 1], [2, 2]], "every feed sees the edit")
check_eq(feed_b.dirty?, true, "draining one feed leaves the others")
check_eq(feed_b.drain_dirty.length, 4, "each feed drains independently")
check_eq(feed_grid.drain_dirty.length, 4, "the legacy single-consumer drain still works")

# --- Grid: draw geometry ------------------------------------------------------

tiles = DragonAutotile::Tileset.new(path: "sprites/walls.png", tile_size: 8)
grid = DragonAutotile::Grid.new(w: 4, h: 4)
grid.set(0, 0, :wall)

drawn = []
grid.each_resolved(tiles) { |d| drawn << d }
check_eq(drawn.length, 4, "one solid cell resolves its four dual corners, empties skipped")

positions = []
grid.each_resolved(tiles) { |_draw, dcol, drow| positions << [dcol, drow] }
check_eq(positions.sort, [[0, 0], [0, 1], [1, 0], [1, 1]], "each_resolved yields the dual position alongside the draw")

top_left = grid.draw_cell(0, 0, tiles)
check_eq(top_left[:x], -4, "dual cell 0,0 draws half a tile left of the map")
check_eq(top_left[:y], 28, "and half a tile above the top structure row (y-up)")
check_eq(top_left[:w], 8, "draw rect is one tile")

# --- Baker --------------------------------------------------------------------

solids = DragonAutotile::Baker.primitives(tile_size: 8)
check_eq(solids.length, 32, "16 masks fill 32 quadrants in total (sum of popcounts)")
mask15 = solids.select { |s| s[:x] >= 24 && s[:y] < 8 }
check_eq(mask15.length, 4, "mask 15 fills all four quadrants")
mask0 = solids.select { |s| s[:x] < 8 && s[:y] >= 24 }
check_eq(mask0.length, 0, "mask 0 fills nothing")
check(solids.all? { |s| s[:w] == 4 && s[:h] == 4 }, "quadrants are half a tile")

# ------------------------------------------------------------------------------

if $failures.zero?
  puts "#{$count} passed, 0 failed"
else
  puts "#{$count - $failures} passed, #{$failures} failed"
  raise "#{$failures} test(s) failed"
end
