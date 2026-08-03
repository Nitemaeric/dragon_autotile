#!/usr/bin/env bash
#
# Run the suite under DragonRuby's mruby-patched interpreter (built by
# build-mruby.sh, or point MRUBY_BIN at an existing binary). Falls back to
# plain ruby with --plain for quick local runs — but mruby is the truth:
# the lib targets DragonRuby's runtime, not CRuby.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

files=(
  lib/dragon_autotile/version.rb
  lib/dragon_autotile/layout.rb
  lib/dragon_autotile/tileset.rb
  lib/dragon_autotile/grid.rb
  lib/dragon_autotile/baker.rb
)

if [ "${1:-}" = "--plain" ]; then
  args=()
  for file in "${files[@]}"; do args+=(-r "./$file"); done
  # position_hash lives in the entry file; load it without its require_relatives.
  exec ruby "${args[@]}" -e "$(grep -v require_relative lib/dragon_autotile.rb)" -e "$(cat test/run.rb)"
fi

MRUBY="${MRUBY_BIN:-$ROOT/tmp/mruby/bin/mruby}"
if [ ! -x "$MRUBY" ]; then
  "$ROOT/script/build-mruby.sh"
fi

args=()
for file in "${files[@]}"; do args+=(-r "$file"); done
grep -v require_relative lib/dragon_autotile.rb > tmp/entry_no_requires.rb 2>/dev/null || {
  mkdir -p tmp && grep -v require_relative lib/dragon_autotile.rb > tmp/entry_no_requires.rb
}
args+=(-r tmp/entry_no_requires.rb)

exec "$MRUBY" "${args[@]}" test/run.rb
