# Generates a styled grayscale DUAL_GRID_16 sheet: quadrant fills with a 1px
# outline on exposed surfaces and rounded convex corners. Grayscale so games
# tint per region at draw time.
#
#   ruby tools/generate_sheet.rb <tile_size> <out.png>
#
# Outlines appear only at true wall surfaces: a tile-edge pixel's off-bitmap
# neighbour is the adjacent dual tile continuing the same structure cell, so it
# counts as filled — abutting tiles compose seamlessly, no grid lines inside
# solid walls.

require_relative "png_writer"
require_relative "../lib/dragon_autotile/layout"

FILL  = [255, 255, 255, 255]
CLEAR = [0, 0, 0, 0]

# Outline value is relative to fill after tinting: 160 reads as a dark rim when
# walls are lighter than floors, but as a BRIGHT halo when floors are darker
# than walls. 255 disables the outline (rounded silhouette only).
outline_value = (ARGV[3] || "160").to_i
OUTLINE = [outline_value, outline_value, outline_value, 255]

def build_tile(mask, tile_size)
  half = tile_size / 2
  filled = Array.new(tile_size * tile_size, false)

  quads = [
    [8, 0,    0],
    [4, half, 0],
    [2, 0,    half],
    [1, half, half]
  ]
  quads.each do |bit, qx, qy|
    next if mask & bit == 0

    half.times { |dy| half.times { |dx| filled[(qy + dy) * tile_size + (qx + dx)] = true } }
  end

  # Off-bitmap neighbours count as filled: the adjacent dual tile continues the
  # same structure cells across the seam.
  probe = lambda do |x, y|
    return true if x < 0 || x >= tile_size || y < 0 || y >= tile_size

    filled[y * tile_size + x]
  end

  # Round convex corners: a filled pixel with two orthogonally empty neighbours
  # is a 1px corner tip — cut it.
  cut = []
  tile_size.times do |y|
    tile_size.times do |x|
      next unless filled[y * tile_size + x]

      open_h = !probe.call(x - 1, y) || !probe.call(x + 1, y)
      open_v = !probe.call(x, y - 1) || !probe.call(x, y + 1)
      cut << [x, y] if open_h && open_v
    end
  end
  cut.each { |(x, y)| filled[y * tile_size + x] = false }

  pixels = Array.new(tile_size * tile_size, CLEAR)
  tile_size.times do |y|
    tile_size.times do |x|
      next unless filled[y * tile_size + x]

      edge = !probe.call(x - 1, y) || !probe.call(x + 1, y) || !probe.call(x, y - 1) || !probe.call(x, y + 1)
      pixels[y * tile_size + x] = edge ? OUTLINE : FILL
    end
  end
  pixels
end

tile_size = (ARGV[0] || "8").to_i
out = ARGV[1] || File.expand_path("../templates/sheet_#{tile_size}.png", __dir__)
gutter = (ARGV[2] || "1").to_i

# Gutters: each tile slot is padded by `gutter` px of its own clamped edge
# pixels, so filtered sampling at scaled/subpixel draws never bleeds the
# neighbouring tile's pixels in. Pair with Tileset.new(gutter: N).
pitch = tile_size + gutter * 2
sheet = pitch * 4
pixels = Array.new(sheet * sheet, CLEAR)

DragonAutotile::Layout::DUAL_GRID_16.each_with_index do |cell, mask|
  tile = build_tile(mask, tile_size)
  clamp = ->(v) { v < 0 ? 0 : (v >= tile_size ? tile_size - 1 : v) }
  (-gutter...(tile_size + gutter)).each do |y|
    (-gutter...(tile_size + gutter)).each do |x|
      px = tile[clamp.call(y) * tile_size + clamp.call(x)]
      sx = cell[:col] * pitch + gutter + x
      sy = cell[:row] * pitch + gutter + y
      pixels[sy * sheet + sx] = px
    end
  end
end

PngWriter.write(out, sheet, sheet, pixels)
puts "#{out} (#{sheet}x#{sheet}, tile #{tile_size}, gutter #{gutter})"
