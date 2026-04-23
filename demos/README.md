# PhysicsModelLink Demos

Nine stand-alone rigid-body demonstrations built on
[`ArnoudBuzing/PhysicsModelLink`](https://www.wolframcloud.com/obj/arnoudbuzing/DeployedResources/Paclet/ArnoudBuzing/PhysicsModelLink/).
Every primitive (sphere, cuboid, cylinder, cone) is a real Rapier
rigid body. Gravity, contacts, restitution, friction and (some) small
velocity-damping tricks do all the rest.

| # | Demo | Output | Notes |
|---|---|---|---|
| 1 | [`01_hourglass.wls`](01_hourglass.wls) | [mp4](../output/demos/01_hourglass.mp4) • [gif](../output/demos/01_hourglass.gif) | ~560 grains cascade through an aperture into a conical pile in the lower funnel |
| 2 | [`02_sandpile.wls`](02_sandpile.wls)    | [compare](../output/demos/02_sandpile_compare.png) • [slick.mp4](../output/demos/02_sandpile_slick.mp4) • [medium](../output/demos/02_sandpile_medium.mp4) • [rough](../output/demos/02_sandpile_rough.mp4) | Three friction panels (μ = 0.1 / 0.4 / 0.8): the spread radius of the landed grains decreases with friction (0.88 → 0.73 → 0.74 m) — friction effect visible, full conical pile not reached (see "Known limits" below) |
| 3 | [`03_domino_cascade.wls`](03_domino_cascade.wls) | [mp4](../output/demos/03_domino_cascade.mp4) • [gif](../output/demos/03_domino_cascade.gif) | 38 dominoes along an S-curve; dense ball fired horizontally into domino 0 triggers the chain reaction through the first half-arc |
| 4 | [`04_dam_break.wls`](04_dam_break.wls)  | [mp4](../output/demos/04_dam_break.mp4) • [gif](../output/demos/04_dam_break.gif) | Granular dam break — a heavy gate flung up at t = 0 releases grains which flow in a proper granular front down a 1.8 m channel |
| 5 | [`05_sphere_packing.wls`](05_sphere_packing.wls) | [mp4](../output/demos/05_sphere_packing.mp4) • [gif](../output/demos/05_sphere_packing.gif) | 1 800 spheres dropped into a transparent cube; beautiful rainbow pile |
| 6 | [`06_brazil_nut.wls`](06_brazil_nut.wls) | [mp4](../output/demos/06_brazil_nut.mp4) • [gif](../output/demos/06_brazil_nut.gif) | Single big red sphere among 370 small ones, periodic upward kicks every 0.25 s; big sphere rises (visible halfway up the jar at end of 25-s sim) |
| 7 | [`07_superballs.wls`](07_superballs.wls) | [mp4](../output/demos/07_superballs.mp4) • [gif](../output/demos/07_superballs.gif) | 180 high-restitution (0.95) spheres in a sealed zero-gravity cube, initial velocities up to 6 m/s — elastic chaos |
| 8 | [`08_tower_collapse.wls`](08_tower_collapse.wls) | [mp4](../output/demos/08_tower_collapse.mp4) • [gif](../output/demos/08_tower_collapse.gif) | 18-layer Jenga tower, dense (ρ = 20) cannonball at 12 m/s knocks it down |
| 9 | [`09_breaking_wave.wls`](09_breaking_wave.wls) | [mp4](../output/demos/09_breaking_wave.mp4) • [gif](../output/demos/09_breaking_wave.gif) | ~290 cubes on a 28° ramp; released to cascade down into a catch basin |

All demos share helpers (video export, non-overlapping point sampling,
GIF conversion via `ffmpeg`) in [`_common.wl`](_common.wl).

## Running

Each demo is a stand-alone `wolframscript`:

```bash
wolframscript -file demos/01_hourglass.wls
```

Output lands in `output/demos/` (MP4 + GIF + final-frame PNG). The
GIFs are sized for inline-embed into Wolfram Community posts (loop
forever, ≤ 540 px wide).

## Common tricks

* **Rotated walls.** For slanted walls (hourglass, ramp) we set
  `"Orientation" -> RotationMatrix[θ, axis]` on a FixedBody cuboid.
* **Dynamic "gate" instead of a kinematic wall.** The paclet only
  exposes Dynamic and Fixed body types; we simulate a wall that
  disappears at t = 0 (dam break) with a very heavy DynamicBody
  given a large initial upward velocity, so it flies out of the way.
* **Shaking the contents, not the container.** Since there is no
  kinematic floor, the Brazil-nut demo periodically resets every
  dynamic body's velocity via `RapierSetBodyVelocity` — a lossy but
  cheap way to inject energy.
* **Velocity damping via per-step position deltas.** Same trick as
  the Galton board: the paclet has no built-in air drag, so every
  few steps we read each body's position, estimate velocity by
  finite difference, and write it back scaled by 0.9–0.99.
* **Thick bounding walls.** `PhysicsBoundaryBox[..., "Thickness" -> 0.2]`
  prevents balls from tunnelling through the wall in one time-step
  at high velocities.

## Known limits

The paclet's `CreatePhysicsModel` is one-shot — you can't add new
bodies mid-simulation. That rules out the "continuous grain injection
from a funnel" you need for a clean angle-of-repose pile, so the
sandpile demo's pile is shallower than a true Bernal-packed cone.
All other demos are self-contained and work on the first evaluate.

Co-authored with Claude Opus 4.7 (1M context).
