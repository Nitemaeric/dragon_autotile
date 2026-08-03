module DragonAutotile
  # A spritesheet plus the knowledge of where each dual-grid case lives in it.
  #
  #   tiles = DragonAutotile::Tileset.new(path: "sprites/walls.png", tile_size: 8)
  #   tiles.source_rect(mask)                    -> { path:, source_x:, source_y:, source_w:, source_h: }
  #   tiles.source_rect(mask, col: c, row: r)    -> variant picked by position hash, stable per cell
  #
  # Variants: rows below the canonical 4x4 block repeat the full layout, one
  # block per variant. variants: 3 means the sheet is 4 cols x 12 rows and every
  # mask has three interchangeable faces, chosen by hashing the dual-cell
  # position — never rand(), which flickers per frame and re-rolls the map on
  # every edit.
  #
  # Animation: paths: takes several frame sheets with identical layout;
  # path_at(cursor) picks the frame. The caller owns the cursor (a scene clock
  # in Conjuration, Kernel.tick_count in plain DR) — the tileset stays a pure
  # lookup and never touches time.
  class Tileset
    attr_reader :paths, :tile_size, :layout, :variants, :fps, :gutter

    def initialize(path: nil, paths: nil, tile_size:, layout: nil, variants: 1, fps: nil, gutter: 0)
      @paths = paths || [path]
      raise ArgumentError, "path: or paths: required" if @paths.compact.empty?

      @tile_size = tile_size
      @layout = Layout.resolve(layout)
      @variants = variants
      @fps = fps
      @gutter = gutter
    end

    def path
      @paths[0]
    end

    def frame_count
      @paths.length
    end

    def path_at(cursor)
      @paths[cursor % @paths.length]
    end

    def source_rect(mask, col: 0, row: 0, seed: 0)
      cell = @layout[mask & 15]
      variant = @variants > 1 ? DragonAutotile.position_hash(col, row, seed) % @variants : 0

      # Layout rows count from the TOP of the image, the way the template is
      # painted; DragonRuby's source_y counts from the bottom. Flip here so
      # neither artists nor callers ever think about it.
      visual_row = cell[:row] + variant * 4
      flipped_row = @variants * 4 - 1 - visual_row

      pitch = @tile_size + @gutter * 2
      {
        path: path,
        source_x: cell[:col] * pitch + @gutter,
        source_y: flipped_row * pitch + @gutter,
        source_w: @tile_size,
        source_h: @tile_size
      }
    end
  end
end
