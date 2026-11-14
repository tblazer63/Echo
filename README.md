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
| **R** | **Record an Echo Clone** (5 s) |
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
5. **The Duplicate Key (Echo Clones).** Two pressure switches have to be held at the same time. Stand on switch **A** and press **R** to record your echo. When the hologram appears and holds A, step onto switch **B**. Signs and prompts walk you through it.
6. **Transforming bridge.** Scan the ancient resonance machine and a shattered bridge swings up into place.
7. **The Sentinel (mini-boss).** A floating guardian seals the Spire. Two pylons power its shield, and you break them with Echo Scan or Sonic Bolts. With the shield down, scan to expose its core for double damage. At half health it re-forms the shield and switches to 3-shot spreads.
8. **World restoration.** Restore the Spire: the Dissonance crystals shatter, the muted world floods with color, waterfalls return, flowers bloom, a new music layer begins, and the drones you defeated wake up as friendly robots that circle the Spire.

## Technically interesting

- **Everything is made in code.** There are no imported models, textures or audio files. Islands, ruins, drones, grass, waterfalls and clouds come from primitives and custom shaders. All sound effects and the two music layers are synthesized at startup.
- **One echo rule.** Any node in the `echo_reactive` group with an `on_echo(origin, wave)` method reacts to sound. Hidden platforms, the relay, drones, the machine and the holographic ruins all share that single rule.
- **The world itself shows sound.** The pulse writes its origin and radius to global shader uniforms, so every stone surface draws the travelling ring.
- **Echo Clones** record your transform every physics tick and replay it deterministically on an `AnimatableBody3D` that switches can detect.
- **Echo Surfing** follows a Catmull-Rom `Curve3D` with a generated ribbon mesh and a flowing-wave shader.
- **Runs on integrated GPUs.** Graphics quality is detected automatically: FSR upscaling, cheaper shadows and MultiMesh batching. It holds about 60 FPS on an AMD Radeon 610M.
- **Automated QA.** `--qa=logic` plays through the whole mission in 38 checks. It reveals and walks the bridges, fights the drones with real bolts, rides the wave, solves the clone puzzle, transforms the bridge, beats both phases of the Sentinel and restores the world. `--qa=shots:<dir>` and `--qa=perf` cover screenshots and frame timing.

## Run from source

```
godot --path .
godot --headless --path . -- --qa=logic     # Level 1 playthrough (42 checks)
godot --headless --path . -- --qa=logic2    # Level 2 playthrough (17 checks)
godot --path . -- --qa=perf
```

## Roadmap (after the hackathon)

Stone Guardian, Echo Anchor, Resonance Burst, the Second and Third Spires, and the Resonance Titan.

## Credits

Design, code, shaders and audio were made for this hackathon with Godot 4.7.2. It uses no third-party assets.
