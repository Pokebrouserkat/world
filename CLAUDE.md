# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is "Valley" - a 2D top-down survival/crafting game built with Godot 4.5 using GDScript and GL Compatibility renderer. Features infinite procedural world generation, crafting, smelting, storage boxes, and multiplayer support.

## Running the Project

Open in Godot Editor or run headless validation:
```bash
~/"Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot" --path . --headless --quit
```

## Testing

Uses GdUnit4 testing framework. Run tests with:
```bash
./test.sh                    # Run all tests
./test.sh -tc PlayerTest     # Run specific test suite
```

Test files are in `test/` and extend `GdUnitTestSuite`.

## Architecture

### Autoloads (Singletons)
- `NetworkManager` - Multiplayer connection handling
- `SaveManager` - Game persistence to `user://save.json`

### Core Systems

**Item System** (`scripts/item.gd`, `scripts/item_registry.gd`, `scripts/texture_cache.gd`):
- `ItemRegistry`: Central definition of all items with id, texture_key, max_stack, display_name
- `Item`: Resource class that looks up properties from registry via `item_id`
- `TextureCache`: Static lazy-loaded texture lookup by key
- Create items with `Item.create(item_id, quantity)`
- Add new items by: 1) add to `ItemRegistry.ITEMS`, 2) add texture to `TextureCache._ensure_loaded()`

**World Generation** (`scripts/world.gd`):
- Extends TileMapLayer with infinite procedural generation
- Deterministic position-based hash for tile placement (WORLD_SEED)
- TileType enum: GRASS, ROCK, TREE, BOX, WOOD_WALL, STONE_WALL, FURNACE, IRON_ORE, IRON_WALL, WOOD_FLOOR, STONE_FLOOR, GOLD_WALL
- Host-authoritative in multiplayer: validates hits/placements, tracks tile health and modifications
- Manages box contents (`_box_contents`) and furnace states (`_furnace_states`)
- Manages roof layer (separate TileMapLayer "RoofLayer" at z_index=20) with `_roof_modifications`

**Player** (`scripts/player.gd`):
- WASD/Arrow movement, Shift to walk slower
- Left-click uses selected tool (picks break rocks, axes break trees)
- Tool tiers: plastic (10 strength) → wood (5) → stone (3) → iron (1) → gold (1)
- Wall/roof durability: wood (20) → stone (30) → iron (60) → gold (120); floors (10)
- Pickup system with audio deduplication

**Inventory** (`scripts/hotbar.gd`):
- 9-slot hotbar with 1-9 selection, Q to drop
- Full drag-and-drop between slots
- Stacking up to max_stack (99 for most items)

**Crafting** (`scripts/crafting_window.gd`):
- C key toggles window
- Recipes defined in `_setup_recipes()` as `{ingredients: {item_id: qty}, output_quantity: int}`

**Smelting** (`scripts/furnace_inventory.gd`):
- Drag ore into furnace input → smelts over 30 seconds (iron_ore→iron, gold_ore→gold)
- Smelting recipes defined in `SMELT_RECIPES` dictionary
- Furnace state persisted in world's `_furnace_states`

**Storage** (`scripts/box_inventory.gd`):
- 9-slot storage boxes placed in world
- Contents tracked in world's `_box_contents` by tile position

**Roofs** (managed by `scripts/world.gd`, rendered on separate "RoofLayer" TileMapLayer):
- Placeable over any tile, rendered at z_index=20 (above everything)
- 4 tiers: wood, stone, iron, gold (durability matches wall tiers)
- Transparency shader reveals player when standing under enclosed roof (tile + 4 cardinal neighbors)
- Roof source IDs in RoofLayer TileSet: 0=wood, 1=stone, 2=iron, 3=gold

### Key Patterns
- Group-based node discovery: "world", "player", "hotbar", "dropped_items", "crafting_window", "box_inventory"
- All UI sizes derived from sprite texture dimensions
- Signals for loose coupling: hotbar emits `item_dropped`, windows emit `closed`
- RPC naming conventions:
  - `request_*` methods: client→host requests (any_peer, call_local, reliable)
  - `_rpc_*` methods: host→client broadcasts (authority, call_local or call_remote, reliable)
  - Host handles local player specially (call_remote won't reach self, so use direct local function calls)

### Save System
- Save file: `user://save.json` (version 1 format)
- Saves: player position, hotbar, tile modifications, roof modifications, dropped items, box contents, furnace states
- Autosaves on tile changes (debounced); only in single-player/host mode

### Display Settings
- Base viewport: 640x360 with "canvas_items" stretch mode, aspect "expand"
- Physics runs on separate thread
