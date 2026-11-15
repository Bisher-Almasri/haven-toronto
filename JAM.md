Jam: <fill in name + URL>     Deadline: <fill in>     Format: science-fair style. Participants play each other's games and vote for the best teams.
Rules: team <?> | assets: all art by the team, all audio generated in code (no files) | platforms: laptop demo + Web (itch.io HTML5) | submit: <where>

Judging format drives every design call:
- A voter walks up, gets maybe 1-3 minutes. The game must be understood in seconds and be funny/hooking right away.
- Voters compare scores, so a local top-5 leaderboard (names + times) gives people a reason to try again and brag.
- The table resets itself so the next visitor always sees a fresh title screen.

Concept: You bounce a lost hedgehog home. Drop into the cave, race over a hill while boulders rain down, cross a seesaw bridge under a swinging chestnut, then chain mushroom bounces up a tower to the master mushroom. Fastest time wins the table.
Two levels (pick on the title with 1 / 2 or the buttons; N or a button on the finish screen switches; each has its own top-5):
- Level 1 "Mushroom Hill" (short, ~5,900 px wide): hill + boulders, seesaw bridge, mushroom tower.
- Level 2 "The Long Way Home" (LONG, ~14,350 px wide, 2.4x Level 1): rolling hills, three thorn pits (bounce pillar, two seesaw bridges), a boulder canyon, a 5-island bounce chasm, pendulum alley with two seesaw bridges, then the mushroom tower and master mushroom.
The 3D game has three more levels (pick with 1-5; N on the finish screen goes to the next one; each has its own top-5 and medal times in toy_medals.gd; the 2D game still has just levels 1 and 2):
- Level 3 "Boulder Run" (MEDIUM, ~10,650 px): three boulder-shower hills, brambles, two seesaw bridges with swinging chestnuts. Mossy green theme.
- Level 4 "Swing Time" (MEDIUM, ~10,650 px): four seesaw bridges under pendulums, a 5-island bounce chasm, a bramble before the tower. Icy blue theme.
- Level 5 "The Gauntlet" (LONG, ~13,750 px): a bit of everything: two bounce-pillar pits, a shower hill, a chasm, two seesaw bridges, brambles and beetles. Ember red theme.
- Level layouts are in game3d/game3d.gd (_terrain_level_N / _gadgets_level_N with shared helpers _chasm_*, _pillar_pit*, _seesaw_pit, _shower_gadgets); bounce_zones lists the stretches that need mushroom chains so the route test can play any level.
Everything is shown 1.4x bigger (camera zoom) so it reads from a table.
Main scene: prototypes/ragdoll_bounce/toy.tscn (rigid-body hedgehog, Happy Wheels style). The earlier platformer climb (scenes/main.tscn) is kept but not used.

3D version (main scene is now game3d/game3d.tscn; the 2D game still runs from prototypes/ragdoll_bounce/toy.tscn):
- Same two levels, same tuning (100 px = 1 m), as a 2.5D game: the world is real 3D (perspective camera, sun with shadows that make light shafts through the forest-floor holes, terrain extruded from the old outlines, Jolt physics) but the hedgehog and all gadgets use the original 2D art on flat Sprite3D quads.
- The hedgehog is a RigidBody3D locked to the z = 0 plane (no depth movement). Hedgehog = the PNGs + a spatial port of the outline shader (shaders/sprite_outline_3d.gdshader).
- game3d/art2d.gd renders the real 2D Mushroom / Beetle classes and small ported painters (boulder, thorns, seesaw, pendulum) into hidden SubViewports and puts the textures on Sprite3D.
- Code lives in game3d/ (game3d.gd = main, hog3d.gd, gadgets3d.gd, art2d.gd, terrain3d.gd, backdrop3d.gd, cam3d.gd). The HUD, scores (own table: user://toy3d_*), medals and audio are shared with the 2D game.
- Cave: painted knotted root columns (Art2D.column, tinted per level theme) in front of a textured rock wall (Art2D.rock); the big trunk by the hole has a bark texture (Terrain3D.bark_texture).
- Background: painted autumn trees (4 variants drawn by Art2D._draw_tree, same sketchy style as the sprites) on a leafy forest floor with horizon haze. Lighting: warm sun with soft shadows + cool fill light, glow and a little colour grading, a lantern on the hedgehog and a warm lamp on the active checkpoint. Props stay unlit so the painted art keeps its colours (Art2D.LIT_PROPS flips that; Art2D.PAINTED_MUSHROOM switches back to the code-drawn mushroom).
- Mushrooms test the hog's position directly instead of Area3D overlaps, because Jolt reports overlaps ~2 frames late (too slow at fall speed).
- Tests: godot --headless --path . --script res://game3d/tests/test_3d.gd (18 checks); res://game3d/tests/route3d.gd -- <level> <delay> (bot plays a level); res://game3d/tests/shots3d.gd needs a window and saves screenshots.

3D hazards and bounce (done, game3d/):
- Boulders only hurt on a real slam (closing speed >= 4.5 m/s, not on touch): plush is knocked out, a spike ball rebounds off them (Hog3D.shove_back). Showers drop one boulder every 0.3 s and set up again if you die before them.
- Brambles (Gadgets3D.Bramble, 5 m tall) knock out plush and let a spike ball roll through: 1 in level 1, 3 in level 2. Spike mode is required to pass them.
- Bounce chain: a spike ball gets +12% on mushroom bounces and +5% per bounce in a row (max 5) (Hog3D.bounce_bonus); the HUD shows BOUNCE xN, leaves burst at the feet.
- Tests: res://game3d/tests/test_hazards3d.gd.

Walk-up demo features (done):
- Title screen (prototypes/ragdoll_bounce/toy_title.gd, shared by the 2D and 3D games): overworld_bg.webp full screen with a slow drift, falling autumn leaves, leafy ground, the title in augiepixel.ttf with a wavy "Bounce!", and the title hedgehog curling into a spike ball and bouncing off the painted mushroom. Level buttons, top-5 table, medal line and "press any key" are unchanged in behaviour.
- Title screen with the top-5 table, "press any key", 1 second to first input. Every level starts in the cave on the floor below the hole (Game3D.START_X), where the hedgehog lands after Terry's trap.
- Clean HUD (timer, KOs, best time) and a controls hint for the first 14 s. No story or popup text in play.
- Hit-stop, camera shake, dust and leaf confetti at the finish; all feedback is visual and audio, not text.
- Sounds for everything plus a music loop, all synthesized in code (scripts/audio.gd). M mutes.
- R retries instantly. Esc opens a pause menu (Resume / Retry / Back to title, all clickable). The clock stops and the finish screen appears 1 s after the master-mushroom launch. Finish screen: type a name for a top-5 time, PLAY AGAIN / BACK TO TITLE buttons (a typed name is saved first).
- Idle reset: back to the title after 60 s idle mid-run or 40 s idle on the finish screen.
- Scores persist locally (user://toy_scores.cfg). On the web build that is browser storage per browser.

Polish pass 2 (done, code only; real art still to come):
- Parallax rock columns, fog, drifting spores, vignette, light beams through the holes, glowing checkpoints and master mushroom.
- Level 2 changes colour theme along the course (warm, purple chasm, teal, warm again).
- Dynamic camera zoom out at speed, spike-ball trail, KO stars, fade-in on level load.
- Gold / silver / bronze medals per level (thresholds in toy_medals.gd, tune after playtests), course progress bar, ghost of your best run per level.
- 1920x1080 window, 4x 2D anti-aliasing, F = fullscreen.

Stretch (cut order, post-jam):
1. Gamepad button prompts
2. Second route / secrets
3. Ghost of the best run

Tests (run before every upload):
- godot --headless --path . --script res://prototypes/ragdoll_bounce/test_toy.gd        (33 physics/gameplay checks)
- godot --headless --path . --script res://prototypes/ragdoll_bounce/test_toy_flow.gd   (title, retry, combo, name entry, leaderboard)
- godot --headless --path . --script res://prototypes/ragdoll_bounce/test_toy_route.gd -- 0   (a bot plays a whole level; args: <level 1|2> <delay frames>, e.g. -- 2 40)
- Legacy platformer: tests/test_game.gd, tests/test_flow.gd, tests/test_route.gd

Credits: Code, art and design: <team>. Engine: Godot 4. Sound: procedural (scripts/audio.gd). Font: "Augie Pixel" by Augie Ruben (augiepixel.ttf, check its licence allows use in the jam entry).

Level 1 opening cutscene (game3d/intro3d.gd, Intro3D):
- Plays when level 1 is started from the title (not on R / PLAY AGAIN retries, not on other levels, not via start_run()). SPACE / click = next line, ESC or R = skip. About 35 s.
- Story: the hedgehog strolls home through Red Leaf Forest, Terry the fox (terry_green_emerald.png, the evil fox) steps out from behind the big tree, stomps, and the leaf-covered trap over the hole collapses. The hedgehog falls into the cave, Terry laughs from the rim, the hedgehog curls into a ball and bounces, then the level card shows and the run starts in the cave.
- It uses a puppet; the real hedgehog stays hidden at its cave start, so the clock starts at 0 on handover. Camera cutscene mode: Cam3D.cine_to().
- Tests: godot --headless --path . --script res://game3d/tests/test_intro.gd; screenshots: game3d/tests/shots_intro.gd (needs a window).
