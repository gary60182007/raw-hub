# Raw Hub v2.2 — Mid Eastern Conflict Sim

Custom executor runtime for GameId `3550555214` / PlaceId `9531918774`.

## Cloud loader

```lua
loadstring(game:HttpGet("https://gary60182007.github.io/raw-hub/loader.lua"))()
```

## Aim system

- smooth hold-RMB camera or mouse guidance;
- sticky closest-to-cursor target selection inside an adjustable FOV;
- Head, UpperTorso, HumanoidRootPart and automatic visible-part selection;
- team, distance and line-of-sight filters;
- maximum turn-rate limiting and adjustable smoothing;
- iterative velocity lead and distance-based drop compensation.

## Automatic ballistics

The script reads the equipped module under `ReplicatedStorage.ACS_Engine.WeaponConfigs`, then applies:

- the weapon's `MuzzleVelocity`;
- `workspace.BulletGravity`;
- the weapon's `GravCoeff`;
- `MuzzleVelocity` multipliers from Sight, Barrel, UnderBarrel, Other and Ammo attachments.

Mounted weapons use `Mounted Gun Common.Modules.WeaponsConfig`, `projectileSpeed` and `workspace.MountedBulletGravity`. Manual velocity and gravity remain available as a fallback.

## Detailed ESP

- clean full boxes with a soft fill and dual-layer glow;
- optional minimalist display name and team dot without background cards;
- optional distance and equipped-weapon text without background cards;
- name, distance and equipped weapon are disabled by default;
- vertical health bar;
- R6/R15 skeleton;
- bottom tracers and true through-wall character Chams;
- adjustable Chams fill opacity with a sharp visibility-colored outline;
- predicted impact marker with drop, lead and flight-time telemetry;
- off-screen directional arrows.

## Controls

| Input | Action |
| --- | --- |
| Right mouse button | Hold aim assist |
| F1 | Toggle detailed ESP |
| F2 | Toggle aim assist |
| Right Shift | Show/hide the Raw Hub panel |
| End | Unload the complete runtime |

Re-executing the loader unloads the previous session first.
