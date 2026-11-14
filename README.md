# ECHO: Sound Reveals Reality

A first-person 3D puzzle adventure made in Godot 4.7. Parts of a floating ruined world exist but can't be seen. Your gauntlet sends out sound pulses that reveal hidden bridges, make them briefly solid, and wake ancient machinery.

## Play

Run `ECHO.exe` (Windows 10/11, x64). It needs no install.

| Input | Action |
|---|---|
| WASD | Move |
| Mouse | Look |
| Space | Jump |
| Shift | Sprint |
| **Q / Right-click** | **Echo Pulse** |
| Esc | Pause (resume, restart from checkpoint, settings) |

A full run takes about 3–5 minutes.

## What to look for (30-second demo)

1. **The pulse.** A cyan wavefront expands from the player. You can see it sweep across every stone surface as a glowing ring.
2. **Hidden bridge.** An empty gap fills with a holographic bridge that pops into place and is solid to walk on.
3. **Fair timing.** Revealed paths last 6.5 seconds and flicker before they fade. Pulsing again while you stand on one renews it.
4. **The relay.** The cracked pillar is too far for your pulse to reach. Cross the hidden steps, pulse beside it, and it fires a beam of sound that unlocks the gate.
5. **Timed ascent.** You need a second pulse partway up the climb to reveal the upper steps.
6. **Signal Gate.** Reaching it restores the gate with a sky beam, a victory cinematic and your run time.

## Technically interesting

- **Everything is made in code.** There are no imported 3D models, textures or audio files. Islands, ruins, grass, waterfalls and clouds come from primitives and custom shaders. The sound effects, ambient wind and the seamless-looping music pad are synthesized at startup.
- **Global echo uniform.** The pulse writes its origin and radius to Godot global shader uniforms, so every stone material draws the travelling sound ring without the gameplay code tracking it.
- **Reusable echo interface.** Any node in the `echo_reactive` group that implements `on_echo(origin, wave)` reacts to pulses. Platforms, the relay, the holographic ruins and the gate all share that one rule.
- **Runs on integrated GPUs.** Graphics quality is detected automatically. Integrated GPUs get FSR upscaling, cheaper shadows and FXAA. It holds about 60 FPS on an AMD Radeon 610M. Settings has a toggle for high quality.
- **Automated QA.** These modes are built into the game:
  - `--qa=logic` plays through the puzzle: it walks across revealed bridges, checks the relay range, the timeouts, respawn and the win condition. All 18 checks pass.
  - `--qa=shots:<dir>` saves gameplay screenshots.
  - `--qa=perf` measures FPS and CPU time at each section.

## Run from source

```
godot --path .                      # play
godot --headless --path . -- --qa=logic
godot --path . -- --qa=perf
```

## Credits

Design, code, shaders and audio were made for this hackathon with Godot 4.7.2. It uses no third-party assets.
