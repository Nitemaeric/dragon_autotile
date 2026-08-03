module DragonAutotile
  # The structure grid: what the game actually is (walls, floors, terrain ids).
  # Gameplay, collision, and editing all live here, in whole cells. The dual
  # grid is derived: (w+1) x (h+1) render cells, each sitting on the corner of
  # four structure cells, drawn offset by half a tile. Rendering is the ONLY
  # thing that sees the offset.
  #
  #   grid = DragonAutotile::Grid.new(w: 64, h: 64, edge: :solid)
  #   grid.set(col, row, :wall)
  #   grid.each_resolved(tileset) { |draw| outputs.sprites << draw.merge(tint) }
  #
  # Cells hold any value; a cell counts as solid when `solid.call(value)` is
  # true (default: truthiness). Store region ids directly and give each region
  # its own tileset/tint at draw time.
  #
  # edge: what lies beyond the map — :solid closes the boundary (a maze's outer
  # wall caps itself), :empty leaves it open.
  class Grid
    attr_reader :w, :h, :edge, :seed

    def initialize(w:, h:, edge: :empty, seed: 0, solid: nil)
      @w = w
      @h = h
      @edge = edge
      @seed = seed
      @solid = solid
      @cells = Array.new(w * h)
      @dirty = {}
    end

    def get(col, row)
      return nil unless col >= 0 && col < @w && row >= 0 && row < @h

      @cells[row * @w + col]
    end

    def set(col, row, value)
      return unless col >= 0 && col < @w && row >= 0 && row < @h

      index = row * @w + col
      return if @cells[index] == value

      @cells[index] = value
      # The four dual cells whose corner this structure cell forms.
      @dirty[[col, row]] = true
      @dirty[[col + 1, row]] = true
      @dirty[[col, row + 1]] = true
      @dirty[[col + 1, row + 1]] = true
      value
    end

    def fill(col, row, cols, rows, value)
      r = row
      while r < row + rows
        c = col
        while c < col + cols
          set(c, r, value)
          c += 1
        end
        r += 1
      end
    end

    def solid?(col, row)
      value = get(col, row)
      if value.nil? && (col < 0 || col >= @w || row < 0 || row >= @h)
        return @edge == :solid
      end

      @solid ? !!@solid.call(value) : !!value
    end

    # The 4-bit corner mask for dual cell (dcol, drow): which of the four
    # structure cells meeting at that corner are solid. TL*8 + TR*4 + BL*2 + BR*1.
    # Dual row 0 is the TOP row of dual cells, so its top structure row is row - 1.
    def dual_mask(dcol, drow)
      mask = 0
      mask |= 8 if solid?(dcol - 1, drow - 1)
      mask |= 4 if solid?(dcol,     drow - 1)
      mask |= 2 if solid?(dcol - 1, drow)
      mask |= 1 if solid?(dcol,     drow)
      mask
    end

    def each_dual_cell
      drow = 0
      while drow <= @h
        dcol = 0
        while dcol <= @w
          yield dcol, drow, dual_mask(dcol, drow)
          dcol += 1
        end
        drow += 1
      end
    end

    # Everything needed to draw one dual cell: merge and push. world_y treats
    # row 0 as the top of the map (DragonRuby y-up), tile_size positions in
    # pixels, and the half-tile offset is baked in — callers never see it.
    def draw_cell(dcol, drow, tileset)
      half = tileset.tile_size >> 1
      tileset.source_rect(dual_mask(dcol, drow), col: dcol, row: drow, seed: @seed).merge(
        x: dcol * tileset.tile_size - half,
        y: (@h - drow) * tileset.tile_size - half,
        w: tileset.tile_size,
        h: tileset.tile_size
      )
    end

    def each_resolved(tileset, skip_empty: true)
      each_dual_cell do |dcol, drow, mask|
        next if skip_empty && mask == 0

        yield draw_cell(dcol, drow, tileset), dcol, drow
      end
    end

    # Dual cells invalidated by set() since the last drain — the editor/chunk
    # hook: re-resolve exactly these, leave the rest of a big map untouched.
    def drain_dirty
      dirty = @dirty.keys
      @dirty = {}
      dirty
    end

    def dirty?
      !@dirty.empty?
    end
  end
end
