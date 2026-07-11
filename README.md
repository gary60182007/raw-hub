# Raw Hub

Official public bootstrap for Raw Hub.

This repository contains only the small bootstrap loader. The private runtime, vocabulary, keys, and server secrets are not stored here.

## Loader

```lua
loadstring(game:HttpGet("https://gary60182007.github.io/raw-hub/loader.lua"))()
```

The bootstrap forwards requests to the protected Raw Hub delivery service. Match records remain local and are never uploaded automatically.
