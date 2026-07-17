# Raw Hub

Official public bootstrap for Raw Hub.

This repository contains only the small bootstrap loader. The private runtime, vocabulary, keys, and server secrets are not stored here.

## Loader

```lua
loadstring(game:HttpGet("https://gary60182007.github.io/raw-hub/loader.lua"))()
```

The bootstrap forwards requests to the protected Raw Hub delivery service. Match records remain local and are never uploaded automatically.

## Active game routes

- Jailbird — GameId `5091490171`, PlaceId `14939963714`
- Operation One — GameId `8307114974`, PlaceId `72920620366355`
- Operation: Siege — GameId `4849157113`, PlaceId `13997264379`
- Ottomans Entrenched WW1 — GameId `1281592938`, PlaceId `3678761576`
- The Final Stand 2 — GameId `44636121`, PlaceId `2899434514`
- The Storage — GameId `4756005135`, PlaceId `13704594433`
- TANMK Battles — GameId `2491559356`, PlaceId `6925857548`
- Valley Prison — GameId `5456952508`, PlaceId `84335391000070`

## Studio training lab

The repository also includes a Studio-only NPC targeting and ballistic-visualization tool under [`studio/`](./studio/README.md). It runs only during Studio play tests and only tracks models tagged `TrainingTarget`.
