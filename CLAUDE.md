# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is "Valley" - a 2D top-down survival/crafting game built with Godot 4.6 using GDScript and GL Compatibility renderer. Features infinite procedural world generation, crafting, smelting, storage boxes, multi-level mines, day/night cycle, and multiplayer support.

## Code Style

- **4-space indentation** for all GDScript files (enforced via `.editorconfig`)
- Godot editor is configured to use spaces (not tabs) with convert-on-save enabled

## Running the Project

Open in Godot Editor or run headless validation:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --headless --quit
```

Use the Godot MCP to run and test the project interactively. Call `run_project` to launch, `get_debug_output` to check for errors/warnings, and `stop_project` when done.

## Testing

Uses GdUnit4 testing framework. Run tests with:
```bash
./test.sh                    # Run all tests
./test.sh -tc PlayerTest     # Run specific test suite
```

Note: `test.sh` has a hardcoded Godot path that may be wrong. Use the Godot binary directly if it fails:
```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . --headless -s addons/gdUnit4/bin/GdUnitCmdTool.gd -a test/ --ignoreHeadlessMode
```

Test files are in `test/` and extend `GdUnitTestSuite`.

For interactive testing use godot-mcp.

## Architecture

### Autoloads (Singletons)
- `GameMode` - Tracks current mode (NORMAL or SANDBOX); `GameMode.is_sandbox()` for checks
- `NetworkManager` - Multiplayer connection handling
- `SaveManager` - Game persistence to `user://save.json` (normal) or `user://sandbox_save.json` (sandbox)

### Game Flow
- Main menu (`scenes/main_menu.tscn`) is the entry point with Play and Sandbox buttons
- Play starts normal mode; Sandbox starts creative mode (free crafting, separate save file)
- Pause menu (ESC) has a "Main Menu" button to return to mode selection
- Sandbox mode has a tools menu (`scripts/sandbox_menu.gd`) with time controls, teleport, noclip

### World as System Orchestrator

`world.gd` extends TileMapLayer and acts as a facade, delegating to extracted `RefCounted` subsystems. Each subsystem is initialized with `init(world)` to receive the world reference:

- `TileDamageSystem` - tile/roof health, durability, tool validation, health bar UI
- `FurnaceSystem` - background smelting state, ticks every frame independent of UI
- `MineSystem` - mine generation/entry/exit, torch lights, mine lighting
- `HitEffects` - particle + flash effects when tiles are damaged
- `DayNightCycle` - 300-second day cycle, global CanvasModulate lighting
- `CampfireManager` - campfire light entities and flicker animation

World exposes subsystem properties via proxy getters/setters for save/load:
```gdscript
var furnace_states: Dictionary:
    get: return _furnace.states
    set(v): _furnace.states = v
```

### Core Systems

**Item System** (`scripts/item.gd`, `scripts/item_registry.gd`, `scripts/texture_cache.gd`):
- `ItemRegistry`: Central definition of all items with id, texture_key, max_stack, display_name
- `Item`: Resource class that looks up properties from registry via `item_id`
- `TextureCache`: Static lazy-loaded texture lookup by key
- Create items with `Item.create(item_id, quantity)`
- Add new items by: 1) add to `ItemRegistry.ITEMS`, 2) add texture to `TextureCache._ensure_loaded()`

**World Generation** (`scripts/world.gd`):
- Infinite procedural generation with deterministic position-based hash (WORLD_SEED)
- TileType enum: GRASS, ROCK, TREE, BOX, WOOD_WALL, STONE_WALL, FURNACE, IRON_ORE, IRON_WALL, WOOD_FLOOR, STONE_FLOOR, GOLD_WALL, MINE_ENTRANCE, MINE_EXIT, CAVE_WALL, GOLD_ORE, CAVE_FLOOR, TORCH, COAL_ORE
- Host-authoritative in multiplayer: validates hits/placements, tracks tile health and modifications
- Manages box contents (`_box_contents`) and furnace states (via `FurnaceSystem`)
- Manages roof layer (separate TileMapLayer "RoofLayer" at z_index=20) with `_roof_modifications`

**Mine System** (`scripts/mine_system.gd`, `scripts/mine_generator.gd`):
- Mines exist at Y < -100,000 (far below overworld), each level offset by 100,000 Y units
- `MineGenerator` uses deterministic static methods: seed = hash(entrance_pos) + level * 7919
- Generates 5-7 rooms connected by corridors; 10% chance for breakable "stone cave" variant
- Room resources: 3% gold ore, 8% iron, 16% coal, 26% rocks
- `mine_return_stack` (LIFO) enables nested mine depth tracking
- Torch rendering uses PointLight2D + unshaded additive Sprite2D to bypass GL Compat 16-light limit
- Single-player only (multiplayer blocked)

**Day/Night Cycle** (`scripts/day_night_cycle.gd`):
- 300-second cycle: Dawn (0–0.15) → Day (0.15–0.55) → Dusk (0.55–0.70) → Night (0.70–1.0)
- Global CanvasModulate for surface; separate dark modulate (0.05, 0.05, 0.08) in mines
- Fire flicker uses overlapping sine waves at different frequencies for natural variation
- `game_time` persisted in save file

**Tile Damage** (`scripts/tile_damage_system.gd`):
- Durability: base 10, walls 20–120 by material, ores 15–20
- Tool strength: plastic (10) → wood (5) → stone (3) → iron/gold (1)
- Custom health bar (green→yellow→red) rendered as Node2D above damaged tiles

**Player** (`scripts/player.gd`):
- WASD/Arrow movement, Shift to walk slower
- Left-click uses selected tool (picks break rocks/ore, axes break trees, any tool for walls)
- Pickup system with audio deduplication
- Night light energy set by day/night cycle darkness value

**Inventory** (`scripts/hotbar.gd`):
- 9-slot hotbar with 1-9 selection, Q to drop
- Full drag-and-drop between slots
- Stacking up to max_stack (99 for most items)

**Crafting** (`scripts/crafting_window.gd`):
- C key toggles window
- Recipes defined in `_setup_recipes()` as `{ingredients: {item_id: qty}, output_quantity: int}`

**Smelting** (`scripts/furnace_system.gd`, `scripts/furnace_inventory.gd`):
- `FurnaceSystem`: Background smelting state, ticks independently every frame (host-only)
- `furnace_inventory.gd`: UI for dragging ore/fuel into furnace
- Recipes: iron_ore→iron, gold_ore→gold (30-second smelt time)
- Fuel: coal (5.0s burn), wood (0.05s burn)

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
- Tile hit flow: player → `request_hit_tile` RPC → host validates → `_damage.apply_tile_damage()` → broadcast health + hit effects

### Save System
- Save file: `user://save.json` (version 1 format)
- Saves: player position, hotbar, tile modifications, roof modifications, dropped items, box contents, furnace states, mine states, game_time
- Mine state includes: player_in_mine, mine_level, mine_return_stack, known mines
- Autosaves on tile changes (debounced) and furnace completions; only in single-player/host mode

### Display Settings
- Base viewport: 640x360 with "canvas_items" stretch mode, aspect "expand"
- Physics runs on separate thread
