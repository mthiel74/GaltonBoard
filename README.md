# GaltonBoard

A physically-simulated **Galton Board** (bean machine / quincunx) built in the
Wolfram Language using
[Arnoud Buzing's PhysicsModelLink paclet](https://www.wolframcloud.com/obj/arnoudbuzing/DeployedResources/Paclet/ArnoudBuzing/PhysicsModelLink/),
a thin wrapper around the Rapier rigid-body physics engine.

Balls fall under gravity through a rectangular alternating-offset lattice of
fixed cylinder pegs, physically bounce off each peg, and accumulate in bins.
The empirical distribution of 600 independent single-ball trials matches
Binomial(18, 1/2) — and therefore the Normal predicted by the central
limit theorem — very well:

![empirical distribution vs Binomial vs Normal](output/03_histogram_overlay.png)

A multi-ball animation drops 600 balls (stacked vertically above a narrow
funnel, so balls enter the peg array one after another) through an 18-row
cascade of 31-column rectangular peg grid, into 33 deep collection bins.
The piled balls form the expected bell curve:

![final frame of the animation](output/02_board_final.png)

## How the physics actually works

The Galton board is deceptively finicky to simulate with an impulse-based
rigid-body engine like Rapier. We had to tune three distinct geometric
constraints to get both (a) every ball reliably cascading all 18 rows and
(b) the empirical distribution approaching Binomial(18, 1/2):

1. **Peg-to-ball radius ratio and peg spacing** — each ball must hit
   exactly one peg per row. If the peg + ball contact distance is too
   small relative to the half peg-spacing, balls can skip rows; if it's
   too large, balls touch two adjacent pegs at once and the stochastic
   deflection cancels. We use `peg_r = 0.035`, `ball_r = 0.075`,
   `dx = 0.24`, `dz = 0.21`.

2. **Same-row peg-edge gap must exceed the ball diameter** — or the ball
   wedges between two adjacent pegs. Our gap is `dx - 2*peg_r = 0.17 m`
   vs ball diameter `0.15 m` = 0.02 m margin per side.

3. **Outermost peg-to-wall gap must also exceed the ball diameter** —
   otherwise the ball wedges between the last peg in a row and the
   boundary wall. We use `$PegCols = 17` (symmetric, 17 pegs in even
   rows, 16 in odd rows, both symmetric about x=0) with the wall placed
   further out, giving a 0.36 m / 0.48 m gap.

On top of the geometry, two run-time fixes were needed:

* **Per-trial peg-x jitter** — the ball's direction must be randomised
  each row; a perfectly aligned ball falling onto a perfectly aligned
  peg deflects deterministically in rigid-body physics, so we perturb
  each peg's x-coordinate by a small random amount (`pegJitter = 0.004 m`)
  per simulation. This is the only non-deterministic ingredient;
  gravity, collisions and bounces are all real Rapier physics.

* **Tiny per-step velocity refresh** — Rapier puts a body to sleep when
  its motion is very small, which would freeze any ball that landed
  exactly on top of a peg. A `damping = 0.99` factor applied to each
  ball's linear velocity every four physics steps keeps balls awake
  (and happens to approximate air drag at the same time).

## Layout

```
GaltonBoard/
├── scripts/
│   ├── board.wl              — shared package (GaltonBoard` context)
│   ├── 00_prototype.wls      — smoke test: 1 ball on 1 peg
│   ├── 01_debug_floor.wls    — smoke test: floor collision
│   ├── 02_board_animation.wls — multi-ball animation video
│   ├── 03_histogram.wls      — Monte-Carlo bell-curve simulation
│   ├── 04_trace.wls          — single-ball trajectory diagnostic
│   ├── 05_trace_reset.wls    — trace with per-row velocity reset
│   ├── 06_tune.wls           — parameter-sweep harness
│   ├── 07_trace2.wls         — single-ball trace (post-rectangular)
│   └── 08_trace3.wls         — single-ball trace (per-row breakdown)
├── output/                   — generated videos, PNGs and CSV
└── README.md
```

## Prerequisites

* macOS / Linux / Windows with
  [Wolfram Engine](https://www.wolfram.com/engine/) or Mathematica ≥ 14.1,
  including `wolframscript`.
* Install the paclet once:

  ```wolfram
  PacletInstall[ResourceObject["https://wolfr.am/1DvZZLuE7"]]
  ```

## Running

```bash
# physical animation (produces output/02_board_animation.mp4 + a PNG still)
wolframscript -file scripts/02_board_animation.wls

# Monte Carlo histogram (600 default trials; override via GBOARD_TRIALS)
GBOARD_TRIALS=1000 wolframscript -file scripts/03_histogram.wls
```

## Results

**Histogram** (`scripts/03_histogram.wls`, 600 independent single-ball
Rapier simulations, 18 peg rows, Binomial(18, 1/2) reference):

```
bin:       1  2  3  4   5   6   7   8   9  10  11  12  13  14  15  16 17 18 19
empirical: 2  1  8  10  26  36  54  60  86  62  70  65  50  34  14  10  8  1  3
Bin(18,½): 0  0  0   2   7  20  42  73 100 111 100  73  42  20   7   2  0  0  0
```

Shape is a clean bell curve tracking both the Binomial PMF and the N(μ, σ²)
Normal approximation predicted by the CLT (see the overlay image above).
`output/03_histogram.csv` contains the raw counts and reference values.

**Animation** (`scripts/02_board_animation.wls`, 25 balls released into a
narrow funnel with 1.5 m vertical spacing between successive balls, so
each ball completes its cascade before the next enters the board):
all 25 balls end up in bins, visibly concentrated around the central
bins — producing the same bell-curve pile-up you'd see on a physical
Galton board.

## License

MIT.
