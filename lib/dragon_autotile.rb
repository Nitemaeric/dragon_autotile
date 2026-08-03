require_relative "dragon_autotile/version"
require_relative "dragon_autotile/layout"
require_relative "dragon_autotile/tileset"
require_relative "dragon_autotile/grid"
require_relative "dragon_autotile/baker"

module DragonAutotile
  # Deterministic per-cell hash for variant selection: stable across frames and
  # edits (rand() flickers and re-rolls the map). Integer mixing only — no
  # Random state, mruby-safe.
  def self.position_hash(col, row, seed = 0)
    n = (col * 374_761_393 + row * 668_265_263 + seed * 2_147_483_647) & 0x7fffffff
    n = ((n ^ (n >> 13)) * 1_274_126_177) & 0x7fffffff
    n ^ (n >> 16)
  end
end
