module DragonAutotile
  # Bakes a placeholder DUAL_GRID_16 sheet into a render target, so a project
  # has correctly-cornered autotiles before any art exists:
  #
  #   DragonAutotile::Baker.bake(args.outputs, path: :walls, tile_size: 8)
  #   tiles = DragonAutotile::Tileset.new(path: :walls, tile_size: 8)
  #
  # Grayscale by default — tint per region at draw time. Each tile is the four
  # quadrants of its mask filled solid; sharp-cornered, readable, replaceable.
  #
  # Geometry is computed by primitives (pure, tested headless); bake only
  # pushes it into outputs.
  module Baker
    extend self

    def bake(outputs, path:, tile_size:, fill: { r: 255, g: 255, b: 255 })
      target = outputs[path]
      target.w = tile_size * 4
      target.h = tile_size * 4
      primitives(tile_size: tile_size, fill: fill).each { |primitive| target.primitives << primitive }
      path
    end

    # Solids for all 16 tiles in the canonical layout, in render-target
    # coordinates (y-up, bottom-left origin — visual row 0 is the TOP row).
    def primitives(tile_size:, fill: { r: 255, g: 255, b: 255 })
      half = tile_size >> 1
      solids = []

      16.times do |mask|
        cell = Layout::DUAL_GRID_16[mask]
        left = cell[:col] * tile_size
        bottom = (3 - cell[:row]) * tile_size

        # Quadrants of the tile, in mask-bit order. A dual tile's top-left
        # quadrant shows the top-left structure cell's corner, and so on.
        quads = [
          { bit: 8, x: left,        y: bottom + half },
          { bit: 4, x: left + half, y: bottom + half },
          { bit: 2, x: left,        y: bottom },
          { bit: 1, x: left + half, y: bottom }
        ]

        quads.each do |quad|
          next if mask & quad[:bit] == 0

          solids << { x: quad[:x], y: quad[:y], w: half, h: half, path: :pixel, **fill }
        end
      end

      solids
    end
  end
end
