# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is "Valley" - a 2D top-down game built with Godot 4.5 using GDScript and GL Compatibility renderer.

## Running the Project

Open in Godot Editor or run headless validation:
```bash
"/Users/matt/Library/Application Support/Steam/steamapps/common/Godot Engine/Godot.app/Contents/MacOS/Godot" --path . --headless --quit
```

## Architecture

### Scene Structure
- `scenes/world.tscn` - Main scene containing TileMapLayer, Player, and UI CanvasLayer
- `scenes/player.tscn` - CharacterBody2D player character
- `scenes/hotbar.tscn` - HBoxContainer-based inventory hotbar (9 slots)
- `scenes/dropped_item.tscn` - Area2D for items dropped in world

### Core Systems

**World Generation** (`scripts/world.gd`):
- Extends TileMapLayer with infinite procedural generation
- Uses deterministic position-based hash for tile placement (WORLD_SEED constant)
- Generates tiles on-demand based on camera viewport with tile_buffer
- TileType enum: GRASS (0), ROCK (1) - rocks spawn 1/40 chance
- Rocks are breakable with Pick tool, replaced with grass and drop rock items

**Player** (`scripts/player.gd`):
- WASD/Arrow movement, Shift to walk slower
- Left-click uses selected tool (Pick breaks rocks within 2-tile range)
- Pickup system: auto-collects DroppedItems within pickup_range
- Connects to hotbar via signal for item_dropped events
- Derives collision/pickup sizes from sprite dimensions

**Inventory** (`scripts/hotbar.gd`):
- 9-slot hotbar with keyboard selection (1-9, +/- to cycle)
- Q key drops single item from selected slot (decrements stack)
- Full drag-and-drop: drag between slots to swap, drag outside to drop entire stack
- Signals: `slot_selected(index)`, `item_dropped(item, slot_index)`
- Stacking: stackable items combine up to max_stack (99)

**Items** (`scripts/item.gd`, `scripts/dropped_item.gd`):
- Item: Resource class with name, texture, quantity, max_stack, stackable properties
- Item.create() static factory method for creating items
- DroppedItem: Area2D wrapper with pickup delay and animated pickup (shrink + move to player)

### Key Patterns
- Group-based node discovery: hotbar uses "hotbar" group, dropped items use "dropped_items" group
- All UI and collision sizes derived from sprite texture dimensions (resolution independence)
- Signals for loose coupling: hotbar emits item_dropped, player listens and spawns DroppedItem

### Display Settings
- Base viewport: 640x360 with "canvas_items" stretch mode, aspect "expand"
- Physics runs on separate thread
