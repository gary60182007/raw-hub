# Raw Hub Training Lab

A polished Roblox Studio target-debugging overlay for NPC training ranges. It includes:

- tagged-NPC boxes, names, health bars, range, tracers and highlights;
- nearest-target selection inside an adjustable FOV ring;
- target-velocity lead, projectile time-of-flight and gravity holdover;
- an obstruction check and a smooth hold-to-guide camera;
- an in-game control panel for speed, FOV and smoothing.

The runtime has two hard boundaries: `RunService:IsStudio()` must be true, and targets must be NPC `Model` instances tagged `TrainingTarget`. Player characters are excluded.

## Install

### Roblox Studio

1. Create a `LocalScript` under `StarterPlayer > StarterPlayerScripts`.
2. Copy in [`TrainingHub.client.lua`](./TrainingHub.client.lua).
3. In Tag Editor, add the `TrainingTarget` tag to each NPC model.
4. Start a Studio play test.

### Rojo

```bash
cd studio
rojo serve default.project.json
```

## Controls

| Input | Action |
| --- | --- |
| Right mouse button | Hold camera guidance |
| F1 | Toggle target overlay |
| F2 | Toggle camera guidance |
| Right Shift | Show or hide the control panel |

## Ballistic model

For each target, the overlay iterates time-of-flight from projectile speed, adds target linear-velocity lead, and compensates vertical projectile displacement with:

```text
holdover = 0.5 × workspace.Gravity × flightTime²
```

Set **Projectile speed** to the weapon's muzzle velocity in studs per second. The overlay only guides the camera; it does not fire weapons or invoke remotes.
