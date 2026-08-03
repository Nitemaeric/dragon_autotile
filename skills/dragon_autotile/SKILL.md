---
name: dragon_autotile
description: Dual-grid auto-tiling for DragonRuby GTK games — terrain grids that resolve corner/edge sprites automatically. Use when a project vendors dragon_autotile (mygame/vendor/dragon_autotile, DragonAutotile::Grid/Tileset) or the task involves auto-tiling, wall/floor tilesets, or tile corner resolution in DragonRuby.
---

# dragon_autotile

Dual-grid auto-tiling: terrain lives on the structure grid, sprites resolve on
the dual grid (one tile per corner of four cells, drawn offset half a tile).
README and inline docs carry the API; these are the rules that prevent bugs.

## Golden rules

1. **Gameplay reads the structure grid, never the dual grid.** Collision,
   pathing, editing, picking: `grid.get/set/solid?` in whole cells. The dual
   grid and its half-tile offset are render-only; `each_resolved` /
   `draw_cell` already bake the offset in.
2. **Never select variants with rand().** `variants:` uses a position hash —
   stable per cell across frames and edits. If you need different variety,
   change `seed:`, don't add randomness.
3. **The library never touches time.** Animated tilesets (`paths:`) expose
   `path_at(cursor)`; the caller supplies the cursor — a Conjuration scene
   clock (pause-correct) or `Kernel.tick_count`. Don't add timers inside.
4. **Layout rows count from the image top; DragonRuby's source_y counts from
   the bottom.** `Tileset#source_rect` flips internally — never "fix" a
   wrong-looking sheet by re-flipping source_y; fix the layout table or the
   sheet.
5. **Edits are local.** `set` dirties exactly four dual cells; use
   `drain_dirty` to re-render only those (chunked caching, editors). Never
   re-resolve a whole large map because one cell changed.
6. **No art yet? Bake.** `Baker.bake(outputs, path:, tile_size:)` renders a
   correct grayscale placeholder sheet at boot; tint per region at draw time.
   Artists replace it by painting over `templates/template_16.png`, where each
   cell's guides show its solid quadrants.

7. **Pixel-art games: `scale_quality=0`.** Filtered sampling halos the cutout
   silhouettes and bleeds sheet neighbours at fractional zoom. The generated
   gutters (`gutter: 1`) cover the filtered case, but nearest is the correct
   lowrez look.
8. **The outline value is palette-relative.** It tints to a fraction of the
   wall colour: bright definition when floors are darker than walls, shadow
   when lighter. Regenerate with the generator's last argument (160 bright,
   80–100 shadow, 255 none) instead of editing pixels.

## Boundaries

- `edge: :solid` caps the map border (mazes); `:empty` leaves it open.
- Cells hold any value (region ids); `solid:` decides what counts as filled.
  Regions = same structure resolution, different tileset/tint at draw time.
- Multi-terrain transitions (grass-water vs grass-sand) are out of scope in
  v1 — don't emulate them by stacking grids unless the game truly needs it.

## mruby

Same runtime rules as any DragonRuby library: no Range#step, no
Enumerable#sum, no defined?; DragonRuby's Integer#/ is float division (this
library uses bitwise/`>>` internally for that reason — keep it that way).
