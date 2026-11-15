# HedgeHog Bounce!

A funny little game about a lost hedgehog trying to get home. You bounce, roll and fall your way through the forest. The fastest time wins!

Made with Godot 4.7. It is a 2.5D game: the world is 3D, but the hedgehog and the props use hand-drawn 2D art.

## How to play

Get the hedgehog to the big master mushroom at the end of the level. It launches you home. Your time is saved on a top-5 table, so you can try to beat your friends.

| Key | What it does |
|---|---|
| A / D (or arrows) | Move |
| Space | Jump |
| Hold Shift | Curl into a spike ball. It squishes beetles and does not mind thorns. |
| Space in the air, while curled | Slam down for a bigger bounce |
| R | Retry |
| Esc | Pause menu |
| N | Switch level (on the finish screen) |
| F | Fullscreen |
| M | Mute |

A gamepad works too.

## Levels

1. **Mushroom Hill** (short): a hill with falling boulders, a seesaw bridge, and a mushroom tower.
2. **The Long Way Home** (long): thorn pits, a boulder canyon, a chasm of bouncy islands, a swinging chestnut, and then the big tower.

Each level has its own top-5 table.

## Medals

Finish fast enough to win a medal.

| | Gold | Silver | Bronze |
|---|---|---|---|
| Level 1 | 0:10 | 0:13 | 0:15 |
| Level 2 | 0:55 | 1:00 | 1:10 |

While you play, the box next to the timer shows which medal you can still get. You can change the times in `prototypes/ragdoll_bounce/toy_medals.gd`.

## Run it

1. Install [Godot 4.7](https://godotengine.org/).
2. Open this folder as a project, or run `godot --path .` in a terminal.
3. Press play. The main scene is `game3d/game3d.tscn`.

The older flat 2D version still works. Its scene is `prototypes/ragdoll_bounce/toy.tscn`.

Scores are saved on your computer. In the web build they are saved in your browser.

## Tests

Run these from the project folder:

```
godot --headless --path . --script res://game3d/tests/test_3d.gd
godot --headless --path . --script res://prototypes/ragdoll_bounce/test_toy.gd
godot --headless --path . --script res://prototypes/ragdoll_bounce/test_toy_flow.gd
```

To take screenshots of the menus, run `godot --path . --script res://game3d/tests/shots_ui.gd -- <folder>`.

## Where things are

- `game3d/` - the 3D game (hedgehog, levels, camera, gadgets)
- `prototypes/ragdoll_bounce/` - the 2D game, plus the menus and HUD that both versions share
- `scripts/audio.gd` - all sounds and music, made in code (no audio files)
- `shaders/` - the hedgehog outline shaders
- `build/web/` - the web export

## Credits

Code, art and design: the HedgeHog team. Engine: Godot. Font: "Augie Pixel" by Augie Ruben (check its licence before you share the game).
