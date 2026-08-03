# Generates the annotated paint-over templates (templates/template_8.png and
# template_16.png): the canonical DUAL_GRID_16 layout with each cell's solid
# quadrants shown as guides. Artists paint over the guides on a layer above.
#
# Plain-Ruby tool (zlib), run at development time — never shipped to games.
#   ruby tools/generate_templates.rb

require "zlib"
require_relative "../lib/dragon_autotile/layout"

def write_png(path, w, h, pixels)
  raw = +""
  h.times do |y|
    raw << "\x00"
    w.times { |x| raw << pixels[y * w + x].pack("C4") }
  end

  def chunk(type, data)
    [data.bytesize].pack("N") + type + data + [Zlib.crc32(type + data)].pack("N")
  end

  png = "\x89PNG\r\n\x1a\n".b
  png << chunk("IHDR", [w, h, 8, 6, 0, 0, 0].pack("NNC5"))
  png << chunk("IDAT", Zlib::Deflate.deflate(raw))
  png << chunk("IEND", "")
  File.binwrite(path, png)
end

GUIDE  = [120, 130, 150, 255]
EMPTY  = [24, 24, 30, 255]
GRID   = [60, 60, 70, 255]

def generate(tile_size)
  sheet = tile_size * 4
  half = tile_size / 2
  pixels = Array.new(sheet * sheet, EMPTY)

  DragonAutotile::Layout::DUAL_GRID_16.each_with_index do |cell, mask|
    left = cell[:col] * tile_size
    top = cell[:row] * tile_size

    quads = [
      [8, left,        top],
      [4, left + half, top],
      [2, left,        top + half],
      [1, left + half, top + half]
    ]

    quads.each do |bit, qx, qy|
      next if mask & bit == 0

      half.times do |dy|
        half.times do |dx|
          pixels[(qy + dy) * sheet + (qx + dx)] = GUIDE
        end
      end
    end
  end

  # Cell borders so the 16 tiles read as a grid in an editor.
  4.times do |line|
    edge = line * tile_size
    sheet.times do |i|
      pixels[edge * sheet + i] = GRID
      pixels[i * sheet + edge] = GRID
    end
  end

  write_png(File.expand_path("../templates/template_#{tile_size}.png", __dir__), sheet, sheet, pixels)
  puts "templates/template_#{tile_size}.png (#{sheet}x#{sheet})"
end

generate(8)
generate(16)
