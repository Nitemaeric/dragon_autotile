# dragon_autotile

Dual-grid auto-tiling for DragonRuby GTK. Paint terrain onto a grid; the
library picks the right corner/edge sprite for every cell.

Terrain lives on the **structure grid** — collision, gameplay, and editing all
happen there in whole cells. Rendering happens on the **dual grid**: one tile
per corner of four structure cells, drawn offset by half a tile. Sixteen tiles
cover every corner and edge case, and gameplay never sees the offset.

## Install

```sh
drenv add github:Nitemaeric/dragon_autotile
```

## Use

```ruby
def boot(args)
  # Working placeholder sheet before any art exists (grayscale — tint at draw):
  DragonAutotile::Baker.bake(args.outputs, path: :walls, tile_size: 8)

  $tiles = DragonAutotile::Tileset.new(path: :walls, tile_size: 8)
  $map = DragonAutotile::Grid.new(w: 64, h: 64, edge: :solid)
  $map.fill(10, 10, 6, 4, :wall)
end

def tick(args)
  $map.set(col, row, :wall)                # edits re-resolve locally, O(1)
  $map.each_resolved($tiles) do |draw|
    args.outputs.sprites << draw.merge(r: 180, g: 120, b: 80)   # region tint
  end
end
```

`Grid` cells hold any value (region ids, terrain symbols); pass `solid:` to
decide what counts as filled. `edge: :solid` caps the map boundary, `:empty`
leaves it open.

## Authoring a tileset

The canonical sheet is 4x4 tiles: cell index = corner mask
(`top_left*8 + top_right*4 + bottom_left*2 + bottom_right*1`), left to right,
top to bottom. Don't memorise that — paint over
[templates/template_16.png](templates/template_16.png) (or `template_8.png`):
each cell shows its solid quadrants as guides. Layout rows count from the top
of the image; the library handles DragonRuby's bottom-origin `source_y` flip.

Sheets arranged by other tools fit via a custom `layout:` table (16
`{ col:, row: }` entries).

## Variants and animation

```ruby
# Sheet is 4 cols x 12 rows: three full layouts stacked. Each cell picks a
# variant by position hash — stable across frames and edits, never rand().
DragonAutotile::Tileset.new(path: "sprites/grass.png", tile_size: 16, variants: 3)

# Animation: one sheet per frame, identical layout. You own the cursor —
# a scene clock, tick_count, whatever:
water = DragonAutotile::Tileset.new(paths: ["water_0.png", "water_1.png"], tile_size: 16, fps: 4)
frame = water.path_at(clock.idiv(60).idiv(water.fps))
```

## Scope

v1 is single-terrain dual-grid: walls against floor, per-region skins via
tilesets or tints. Multi-terrain boundaries (grass-water vs grass-sand),
blob-47 layouts, and isometric are deliberately out until a real game needs
them.
