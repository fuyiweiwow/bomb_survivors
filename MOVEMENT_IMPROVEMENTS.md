# Direct Grid Movement Update

The player movement input has been revised for a smoother but non-inertial feel.

## Current behavior

- Movement has no acceleration, deceleration, friction curve, or sliding state.
- Releasing all movement keys prevents another grid step from starting.
- The current grid step still finishes at the cell center so collision, bombs, and tile interactions stay aligned.
- When multiple directions are held, the most recently pressed direction has priority.
- Releasing the newest direction falls back to the previously held direction.
- A quick turn is buffered for 0.38 seconds, long enough to survive the slowest normal grid step.
- If the preferred direction is blocked, other still-held directions are tried in priority order.
- Remaining physics-frame travel is reused across cell boundaries, avoiding a one-frame pause without introducing inertia.
- The character keeps a continuous world position while moving; its logical cell is derived from that position instead of being reserved at movement start.
- `grid_pos` changes only after the character center crosses the boundary halfway between two tile centers.
- Interrupted movement snaps to the nearest actual cell, keeping bombs, terrain effects, and visuals on the same tile.

## Files changed

- `scripts/character/player_input_controller.gd`
- `scripts/character/grid_movement_controller.gd`
- `scripts/core/constants.gd`
- `scripts/character/player_manager.gd`
- `scripts/game/game_manager_3d.gd`
- `tests/modular_gameplay_smoke.gd`
