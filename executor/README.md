# Raw Hub External

Standalone Roblox executor script. This is the live-player edition; it does not use `RunService:IsStudio()`, `StarterPlayerScripts`, `CollectionService` tags, or Studio-only NPC targets.

## Run

```lua
loadstring(game:HttpGet("https://gary60182007.github.io/raw-hub/loader.lua"))()
```

## Controls

| Input | Action |
| --- | --- |
| Right mouse button | Hold aim guidance |
| F1 | Toggle ESP overlay |
| F2 | Toggle aim guidance |
| Right Shift | Show or hide the control panel |

Re-executing the script unloads the previous instance before creating a new one. The panel exposes team check, line-of-sight filtering, projectile speed, FOV radius, and smoothing.
