# Realistic Heap Physics

An experimental Farming Simulator 25 script mod that adjusts the game's
leveler behavior while pushing wood chips, chaff, and silage. It targets
leveler blades and buckets that include the game's leveler component, such as
the stock Volvo L180H and L120H buckets. The goal is to let implements work
deeper into heaps and spread material toward their edges.

## How it works

For leveler nodes that already have smoothing enabled, the mod checks the
material in front of the implement, temporarily allows smoothing in the
leveler's pickup direction, and increases the configured smoothing radius by
30% during that update. For an active, moving pickup that can use the detected
material, it also disables the leveler's surface-depth checks and widens its
normal drop line to at least 0.25 m beyond each side of the implement. This
encourages deeper pickup and wider spreading; it does not explicitly push
material into separate piles at the edges. The wider drop is skipped if its
sampled surrounding area is not accessible farmland, unless the leveler is
configured to ignore farmland restrictions. The game's leveler code still
handles pickup, placement, fill units, and silo notifications. Other materials
and levelers with smoothing disabled retain their normal behavior.

This is not a fluid simulation or a change to the material's viscosity, heap
resolution, maximum slope, or collision properties. It may not stop vehicles
riding up over heaps, and spreading past an edge is not guaranteed. It does not add smoothing
to shovel-only buckets or other implements without the leveler specialization.
Whether a bulldozer blade is supported depends on its configuration. Smoothing
can affect adjacent material within the game's smoothing radius, so avoid
working against mixed heaps until the behavior has been tested. Existing heaps
are only affected when worked with a suitable leveler.

## Compatibility and testing

The descriptor targets FS25 mod descriptor version 115, as reported by game
version 1.25.0.0. Multiplayer is disabled because synchronization has not
been tested. Other mods that replace leveler behavior may conflict.

The deeper pickup and wider drop are new and have not been verified in game.
Before using this mod on a valued save, back it up and compare identical heaps
with and without the mod. Test wood chips, chaff, and silage with a leveler
that supports each material, checking pushing and backing up, material at both
edges, fill quantities, bunker silo compaction, mixed heaps, farmland
boundaries, and other fill types, including with a stock wheel-loader bucket.
The farmland check samples positions around the wider drop; it cannot guarantee
that every point inside an irregular boundary is accessible. Inspect `log.txt`
for errors. The behavior remains subject to the game's height-map resolution
and the implement's settings.

To install, place the mod contents at the root of a mod folder or zip named
`FS25_RealisticHeapPhysics` in the game's `mods` folder and enable it for a
savegame.

The isolated script checks can be run from the mod folder with
`lua tests/RealisticHeapPhysicsTest.lua`; they do not replace in-game testing.
