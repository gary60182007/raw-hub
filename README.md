# Raw Hub

Official public bootstrap for Raw Hub.

This repository contains the public bootstrap loader and a standalone executor edition. Private game routes, vocabulary, keys, and server secrets are not stored here.

## Loader

```lua
loadstring(game:HttpGet("https://gary60182007.github.io/raw-hub/loader.lua"))()
```

The bootstrap forwards requests to the protected Raw Hub delivery service. Match records remain local and are never uploaded automatically.

## Executor edition

[`executor/RawHub.lua`](./executor/RawHub.lua) is the in-game executor version of the targeting HUD. It targets live player characters, supports team and line-of-sight checks, draws ESP/tracers/prediction, and provides hold-to-aim camera guidance.

```lua
loadstring(game:HttpGet("https://gary60182007.github.io/raw-hub/loader.lua"))()
```

Controls: **F1** toggles ESP, **F2** toggles aim guidance, **RMB** holds aim, and **Right Shift** toggles the panel.

## Active game routes

- Mid Eastern Conflict Sim — GameId `3550555214`, PlaceId `9531918774`
- Jailbird — GameId `5091490171`, PlaceId `14939963714`
- Operation One — GameId `8307114974`, PlaceId `72920620366355`
- Operation: Siege — GameId `4849157113`, PlaceId `13997264379`
- Ottomans Entrenched WW1 — GameId `1281592938`, PlaceId `3678761576`
- The Final Stand 2 — GameId `44636121`, PlaceId `2899434514`
- The Storage — GameId `4756005135`, PlaceId `13704594433`
- TANMK Battles — GameId `2491559356`, PlaceId `6925857548`
- Valley Prison — GameId `5456952508`, PlaceId `84335391000070`
