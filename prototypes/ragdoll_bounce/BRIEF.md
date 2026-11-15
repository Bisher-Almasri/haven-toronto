QUESTION:   Is steering a squishy, bouncy, physics-driven hedgehog through a gadget-filled obstacle
			course (Happy Wheels style, bounce-themed) fun in itself, within 30 seconds, and do
			failures feel funny instead of frustrating?

CORE VERB:  Roll and bounce. Plush mode: run and jump. Hold Shift/X: curl into a bouncy spike ball
			(fast, keeps momentum, kills beetles, immune to thorns, cannot jump). In the air while
			curled, press Space to PUMP (slam down) so the next bounce goes higher.

THROWAWAY:  yes. Lives in prototypes/ragdoll_bounce/ and only reuses art, the outline shader,
			the cave backdrop script and the mushroom/beetle drawing from the main game
			(read-only, nothing in the main game is changed).

TIMEBOX:    90 min of build, then a user playtest.

COURSE:     start -> downhill roll -> beetle valley with boulders -> uphill -> seesaw bridge over a
			thorn pit -> pendulum over mushroom stepping stones -> master mushroom launches you into
			the forest. Mushrooms are also checkpoints: you respawn by being popped out of one.

KEEP IF:    - a fresh player rolls/bounces on purpose within ~30 s, and
			- they retry after a failure without being asked, and laugh or say "again", and
			- the spike-ball pump / rebound is the thing they talk about.
KILL IF:    - it only feels good after explanation, or controls feel like fighting the physics, or
			- failures feel cheap and not funny, or
			- fun depends on levels/art we have not built yet.

STATUS:     Built and verified headless (23 physics checks pass). Waiting for the user playtest.
			Run: open prototypes/ragdoll_bounce/toy.tscn in Godot and press F6, or
			godot --path . res://prototypes/ragdoll_bounce/toy.tscn

PLAYTEST 1: "Moving feels a bit weird but that's good, we can extend it. Being able to move and roll
            feels weird. The pendulum rope should collide. We need to add some story."

CHANGES:    - Story: forest start -> hole -> long fall -> cave course -> master mushroom -> exit hole ->
			  forest home. Narrator captions, story trigger zones, title card, epilogue.
			- Pendulum: rope thickened (26 px collision, matches visible rope), continuous collision.
			  Verified it blocks a hog at up to 3000 px/s; could not reproduce a pass-through.
			- Curling now matches rolling spin to ground speed (no skid on curl).
			- Master launch: vertical rise through the exit hole, then drift to the forest.
			- Camera limited to the world; story lines interrupt each other.
			- Movement is now all-physics (chosen by the user): plush accelerates (2600 px/s^2, top 440),
			  slides to a stop when you let go (1500 px/s^2), turns harder against its own momentum, and
			  keeps full momentum through jumps and falls (no air friction). Landings bounce a little
			  (0.3). Spike ball unchanged. The catch mushroom moved to where a natural walk-off lands.

RESULT:     retune (playtest 2 pending). Open question: what exactly feels weird about move + roll?
