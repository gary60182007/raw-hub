# Mid Eastern Conflict Sim — client detection review

Reviewed from the exported client scripts dated 2026-07-18.

## Detected checks

1. `ReplicatedStorage.Modules.Shared.AntiCheatConfig` defines an allowed WalkSpeed range of `0–32`.
2. `GunFramework` reports an invalid WalkSpeed through descendants of `ReplicatedStorage.LooseRemotes` using `Vector3.new(0, 0, 0)`.
3. Character `BodyAngularVelocity` instances are reported with `Vector3.new(0, 10, 0)`.
4. A combined `BodyGyro` and `BodyVelocity` is reported with `Vector3.new(10, 0, 0)`.
5. An equipped gun is automatically unequipped when the camera is more than 20 studs from the character's head.
6. The gun client directly kicks when WalkSpeed exceeds 30 in its equipped render path.
7. The built-in report interface includes Aimbot and ESP report reasons and sends them through `LooseRemotes.SendReport`.

## Search result

The exported client code contains no explicit checks for `getgenv`, `gethui`, executor identity, `Drawing`, CoreGui descendants, custom ScreenGui names, camera `CFrame` assignment, FOV overlays, highlights or player ESP objects.

Server-only validation code was not included in the passive client export, so remote-side shot validation is outside this review.

## Raw Hub implementation boundary

Raw Hub v2.1 does not change WalkSpeed, Humanoid physics, BodyMovers, ammo, recoil, fire rate, hit results or weapon remotes. It reads replicated weapon configuration for ballistic values, renders local visual objects and character Chams, and applies aim guidance through the local camera or mouse movement path.
