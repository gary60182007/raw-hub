# Passive detection review

Review source: the locally exported `mid eastern conflict sim` client scripts dated 2026-07-18.

Observed client-side checks in the representative `GunFramework` export:

- `AntiCheatConfig` defines an allowed humanoid walk-speed range of `0..32`.
- Out-of-range walk speed triggers a report through a `LooseRemotes` event.
- `BodyAngularVelocity` under the character triggers a distinct report.
- A combined `BodyGyro` and `BodyVelocity` under the character triggers another report.
- A firearm bullet count above `20` causes a local kick in the examined branch.
- A camera-to-head separation above `20` studs causes tool unequip; walk speed above `30` in the active gun path causes a local kick.

The exported material is client-side and incomplete, so server validation may include additional checks not represented in the dump. This review records observed behavior only and does not include suppression or bypass logic.
