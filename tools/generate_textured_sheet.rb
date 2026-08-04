# Generates a textured grayscale DUAL_GRID_16 sheet: the standard tile geometry
# (quadrant fills, rounded convex corners, optional outline, gutters) with fill
# pixels shaded by a material from materials.rb.
#
#   ruby tools/generate_textured_sheet.rb <material> <tile_size> <out.png> [gutter] [outline]
#   ruby tools/generate_textured_sheet.rb brick 8 walls_brick.png 1 160

require_relative "png_writer"
require_relative "materials"
require_relative "../lib/dragon_autotile/layout"

material_name = (ARGV[0] || "smooth").to_sym
material = MATERIALS.fetch(material_name) { raise "unknown material #{material_name} (#{MATERIALS.keys.join(", ")})" }
tile_size = (ARGV[1] || "8").to_i
out = ARGV[2] || File.expand_path("../templates/sheet_#{material_name}_#{tile_size}.png", __dir__)
gutter = (ARGV[3] || "1").to_i
outline_value = (ARGV[4] || "160").to_i

CLEAR = [0, 0, 0, 0]
OUTLINE = [outline_value, outline_value, outline_value, 255]

def build_tile(mask, tile_size, material, outline)
  half = tile_size / 2
  filled = Array.new(tile_size * tile_size, false)

  [[8, 0, 0], [4, half, 0], [2, 0, half], [1, half, half]].each do |bit, qx, qy|
    next if mask & bit == 0

    half.times { |dy| half.times { |dx| filled[(qy + dy) * tile_size + (qx + dx)] = true } }
  end

  probe = lambda do |x, y|
    return true if x < 0 || x >= tile_size || y < 0 || y >= tile_size

    filled[y * tile_size + x]
  end

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
      if edge && outline[0] < 255
        pixels[y * tile_size + x] = outline
      else
        value = material.call(x, y)
        pixels[y * tile_size + x] = [value, value, value, 255]
      end
    end
  end
  pixels
end

pitch = tile_size + gutter * 2
sheet = pitch * 4
pixels = Array.new(sheet * sheet, CLEAR)

DragonAutotile::Layout::DUAL_GRID_16.each_with_index do |cell, mask|
  tile = build_tile(mask, tile_size, material, OUTLINE)
  clamp = ->(v) { v < 0 ? 0 : (v >= tile_size ? tile_size - 1 : v) }
  (-gutter...(tile_size + gutter)).each do |y|
    (-gutter...(tile_size + gutter)).each do |x|
      px = tile[clamp.call(y) * tile_size + clamp.call(x)]
      pixels[(cell[:row] * pitch + gutter + y) * sheet + (cell[:col] * pitch + gutter + x)] = px
    end
  end
end

PngWriter.write(out, sheet, sheet, pixels)
puts "#{out} (#{material_name}, #{sheet}x#{sheet}, tile #{tile_size}, gutter #{gutter}, outline #{outline_value})"
