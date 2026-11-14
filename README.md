# ECHO: The Last Resonance

**Sound Reveals Reality.** A first-person 3D action-adventure made in Godot 4.7.

The floating civilization of Auralis has gone silent, and a force called the Dissonance has corrupted its machines. Your Resonance Gauntlet sends out sound that reveals hidden paths, stuns corrupted drones, launches you along waves of energy, records echoes of yourself, and wakes ancient machinery. Restore the **First Resonance Spire** and bring the world back to life.

## Play

Run `ECHO.exe` (Windows 10/11, x64). It needs no install. One run through the mission takes about 5–7 minutes.

| Input | Action |
|---|---|
| WASD / Mouse | Move / look |
| Space | Jump |
| Shift | Sprint |
| F (or Ctrl) | Echo Dash (brief invulnerability) |
| **Q / Right-click** | **Echo Scan** (reveals hidden structures, stuns drones, exposes their cores) |
| **Left-click** (hold) | **Sonic Bolt** |
| **R** | **Record an Echo Clone** (5 s replay of your moves) |
| **C / Middle-click** | **Send Echo**: your echo partner walks to the spot you aim at and holds it |
| **V** | **Echo Follow**: your echo follows you and rejoins you if it gets left behind |
| E | Interact (ride the Echo Wave) |
| Esc | Pause (resume, restart from checkpoint, settings) |

Scan, bolt and dash share one **Echo Energy** bar that refills quickly, so you can never get stuck without energy.

## Two levels

Choose either one from the main menu, or press **Continue** after finishing Level 1.

- **Level 1: The First Resonance.** The full tutorial-to-boss mission described below. It also has an optional hidden side path and a phantom ambush over the hub.
- **Level 2: Dissonant Heights.** A golden-hour climb. You scan your way up timed, ascending hidden steps, rescanning mid-climb, then clear an arena of Echo Drones and **Phantom Drones**. Next comes a longer surf course with Dissonance obstacles, a harder clone puzzle (the switches sit on opposite sides of a pillar), and a resonance-machine bridge. It ends with a **3-pylon Sentinel** guarding the Second Spire.

**Extras in both levels:**
- **Energy Shards** hidden off the main path, often on scan-revealed side routes.
- **Surf time trial.** Dodge the magenta Dissonance orbs, each of which adds 2 s. Your best time is kept for the session.
- **Phantom Drones** are invisible and immune until your Echo Scan reveals them.
- **Victory screen** with time, shards, rings, drones silenced, falls, and a **rank from S to C**.
- **Game feel:** hit-stop on kills, kill bursts, floating damage numbers (gold when you hit an exposed core), muzzle flash and screen shake.

## Level 1 mission: "First Resonance"

1. **The First Echo.** An empty gap is crossed only by a hidden bridge that your scan reveals.
2. **Resonant Crossing.** A cracked relay pillar is out of your scan's reach. Reveal the hidden steps, scan beside it, and its beam of sound unlocks the gate.
3. **Courtyard Interference (combat).** Three corrupted Echo Drones attack, firing slow, readable shots after a visible charge-up. Sonic Bolts damage them. **Echo Scan stuns them and exposes their cores for double damage**, so sound is your best weapon.
4. **Echo Surfing.** Clearing the courtyard wakes a Surf Generator. Ride a glowing wave over the sea of clouds, steer with A/D, and collect rings.
5. **The Duplicate Key (Echo Clones).** Two pressure switches have to be held at the same time. Aim at switch **A** and press **C**: your holographic echo walks over and holds it, and then you step onto switch **B**. Alternatively, stand on A and press **R** to record an echo that replays your moves. **V** calls the echo back to follow you. The echo walks in straight lines and stops at gaps and walls, so in Level 2 you have to guide it around the pillar.
5b. **Echo Lift (co-op elevator, optional).** A lift beside the island rises only while its LIFT switch is held. Send your echo to the switch with C, then ride up to a hidden ledge with a shard. Level 2 has its own lift.
6. **Transforming bridge.** Scan the ancient resonance machine and a shattered bridge swings up into place.
7. **The Sentinel (mini-boss).** A floating guardian seals the Spire. Two pylons power its shield, and you break them with Echo Scan or Sonic Bolts. With the shield down, scan to expose its core for double damage. At half health it re-forms the shield and switches to 3-shot spreads.
8. **World restoration.** Restore the Spire: the Dissonance crystals shatter, the muted world floods with color, waterfalls return, flowers bloom, a new music layer begins, and the drones you defeated wake up as friendly robots that circle the Spire.

## Technically interesting

- **Everything is made in code.** There are no imported models, textures or audio files. Islands, ruins, drones, grass, waterfalls and clouds come from primitives and custom shaders. All sound effects and the two music layers are synthesized at startup.
- **One echo rule.** Any node in the `echo_reactive` group with an `on_echo(origin, wave)` method reacts to sound. Hidden platforms, the relay, drones, the machine and the holographic ruins all share that single rule.
- **The world itself shows sound.** The pulse writes its origin and radius to global shader uniforms, so every stone surface draws the travelling ring.
- **Echo Clones** have two modes. Recorded clones replay your transform frame by frame. Commanded clones (Move Here / Follow / Return) step along the ground using raycasts that detect walls and gaps, give feedback when a target is unreachable, and rejoin you automatically. Both run on an `AnimatableBody3D` that switches can detect.
- **Echo Surfing** follows a Catmull-Rom `Curve3D` with a generated ribbon mesh and a flowing-wave shader.
- **Runs on integrated GPUs.** Graphics quality is detected automatically: FSR upscaling, cheaper shadows and MultiMesh batching. It holds about 60 FPS on an AMD Radeon 610M.
- **Automated QA.** `--qa=logic` plays through the whole of Level 1 in 48 checks, and `--qa=logic2` plays Level 2 in 17. It reveals and walks the bridges, fights the drones with real bolts, rides the wave, solves the clone puzzle, transforms the bridge, beats both phases of the Sentinel and restores the world. `--qa=shots:<dir>` and `--qa=perf` cover screenshots and frame timing.

## Run from source

```
godot --path .
godot --headless --path . -- --qa=logic     # Level 1 playthrough (48 checks)
godot --headless --path . -- --qa=logic2    # Level 2 playthrough (17 checks)
godot --path . -- --qa=perf
```

## Roadmap (after the hackathon)

The hackathon build is a vertical slice of a larger design that leads to the **Heart of Auralis**.

- **Levels:** Forgotten Shores (intro), Resonance Gardens (sound-responsive plants and vine bridges), Shattered Crossing (surf chase with branching routes), Twin Chambers (split-path co-op with the clone, a two-person elevator and character switching), Clockwork Foundry (rotating machinery and Stone Guardians), Storm Citadel (resonance storms and the **Dissonance Weaver**), and Heart of Auralis (the 3-phase **Resonance Titan** and the full restoration).
- **Abilities:** Shockwave, Echo Anchor (a placeable sound source) and Resonance Burst.
- **Enemies:** Stone Guardian and Resonance Beast.
- **Puzzles:** crystal resonance routing, frequency matching and wave interference.
- **Clone:** Interact/Hold commands and direct character switching.
- **Progression:** shard upgrades and music layers that grow as each Spire is restored.

## Credits

Design, code, shaders and audio were made for this hackathon with Godot 4.7.2. It uses no third-party assets.
