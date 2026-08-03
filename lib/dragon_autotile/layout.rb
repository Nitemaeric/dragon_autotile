module DragonAutotile
  # A layout maps a dual-grid corner mask to a cell in the spritesheet.
  #
  # The mask is 4 bits, one per structure cell touching the dual cell's centre:
  # top-left * 8 + top-right * 4 + bottom-left * 2 + bottom-right * 1. The
  # canonical DUAL_GRID_16 sheet is 4 columns x 4 rows, cell index == mask,
  # left to right, top to bottom. Any 16-entry table of { col:, row: } works as
  # a custom layout for sheets arranged by other tools.
  module Layout
    # Bitwise, not division: DR patches Integer#/ to float division, harnesses don't.
    DUAL_GRID_16 = Array.new(16) { |mask| { col: mask & 3, row: mask >> 2 } }.each(&:freeze).freeze

    def self.resolve(layout)
      return DUAL_GRID_16 if layout.nil? || layout == :dual_grid_16
      raise ArgumentError, "layout must be 16 { col:, row: } entries (got #{layout.inspect})" unless layout.is_a?(Array) && layout.length == 16

      layout
    end
  end
end
