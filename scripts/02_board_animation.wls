#!/usr/bin/env wolframscript
(* 02_board_animation.wls -- REAL-PHYSICS Galton board animation.

   Geometry + parameters match scripts/06_tune.wls which produces a
   bell-curve distribution with 18-row rectangular alternating-offset
   peg lattice (the classical physical Galton configuration).

     * Balls are genuine Rapier DynamicBody spheres, pegs are
       genuine FixedBody cylinders — balls physically bounce off
       pegs, they never pass through.
     * ball_r 0.08, peg_r 0.025 -> peg-to-ball radius ratio ~0.3;
       dx 0.22 > 2*(ball_r + peg_r) = 0.21 so each ball hits exactly
       ONE peg per row (overlapping contact zones would cancel
       stochasticity).
     * A small per-step linear velocity damping approximates air drag
       (Rapier has no built-in drag); without it balls accelerate
       indefinitely and skip rows.
     * The peg layout is jittered slightly (per-simulation, not
       per-ball) so the board isn't perfectly symmetric — this supplies
       the stochasticity that deterministic rigid-body physics lacks.
     * Multiple balls are released from a thin horizontal strip
       centred over the top of the board, staggered vertically so
       they enter the cascade one after another instead of all piling
       on the apex peg.
*)

Needs["ArnoudBuzing`PhysicsModelLink`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "board.wl"}]];

SeedRandom[20260424];

CreatePhysicsModel    = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody           = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody             = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelIterate   = ArnoudBuzing`PhysicsModelLink`PhysicsModelIterate;
PhysicsModelPlot      = ArnoudBuzing`PhysicsModelLink`PhysicsModelPlot;
DestroyPhysicsModel   = ArnoudBuzing`PhysicsModelLink`DestroyPhysicsModel;
RapierGetBodyPositions = ArnoudBuzing`PhysicsModelLink`RapierGetBodyPositions;
RapierSetBodyVelocity = ArnoudBuzing`PhysicsModelLink`RapierSetBodyVelocity;

(* -- Parameters -- *)
nBalls    = 400;             (* many balls -> clear bell curve pile-up *)
xReleaseSpread = GaltonBoard`$PegDx/6;
dzStack   = 0.50;            (* spacing in the ball stack; with damping the balls
                                reach a terminal velocity ~16 m/s so successive
                                balls arrive at the top peg ~0.03 s apart *)
dt        = 1/240.;
nFrames   = 14400;           (* 60 s of physics -- all 400 balls fully settled *)
videoStep = 36;              (* 400 frames @ 30 fps = 13 s playback *)
damping   = 0.99;            (* same drag as the histogram script *)
dampEvery = 4;
damping   = 0.99;            (* velocity kept per-damp-step *)
dampEvery = 4;               (* physics steps per damping tick *)
pegJitter = 0.004;           (* small: keeps peg-edge gap > ball diameter everywhere *)

(* -- Balls: small x-spread, staggered z, random tiny vx -- *)
balls = Table[
  GaltonBoard`MakeBall[
    {RandomReal[{-xReleaseSpread, xReleaseSpread}],
     GaltonBoard`$BoardTopZ + 0.6 + k*dzStack},
    {RandomReal[{-0.05, 0.05}], 0.},
    Hue[Mod[k*0.09, 1]]],
  {k, 0, nBalls - 1}];

(* -- Static bodies: real pegs, bin separators, floor, boundary walls -- *)
pegs  = GaltonBoard`PegList[pegJitter];
bins  = GaltonBoard`BinSeparators[];
floor = FixedBody[{GrayLevel[0.85],
          Cuboid[{-GaltonBoard`$BoardHalfWidth, -GaltonBoard`$SlabHalfY,
                  GaltonBoard`$BoardBottomZ},
                 { GaltonBoard`$BoardHalfWidth,  GaltonBoard`$SlabHalfY,
                  GaltonBoard`$BoardBottomZ + 0.12}]},
          "Restitution" -> 0.1, "Friction" -> 0.9];
stackTop = GaltonBoard`$BoardTopZ + 0.6 + (nBalls - 1)*dzStack + 0.5;
walls    = GaltonBoard`BoundaryWalls[stackTop];

model = CreatePhysicsModel[
  Join[balls, pegs, bins, {floor}, walls],
  "Gravity" -> {0., 0., -9.81},
  "Graphics3DOptions" -> {
    PlotRange    -> {{-GaltonBoard`$BoardHalfWidth, GaltonBoard`$BoardHalfWidth},
                     {-0.6, 0.6},
                     {GaltonBoard`$BoardBottomZ - 0.15, GaltonBoard`$BoardTopZ + 1.6}},
    Boxed        -> False,
    Axes         -> False,
    Lighting     -> "Neutral",
    ViewPoint    -> {0, -20, 0},
    ViewVertical -> {0, 0, 1},
    Background   -> RGBColor[0.97, 0.97, 1.0]}];

worldId     = model[[1]]["WorldID"];
ballHandles = Table[model[[1]]["Bodies"][[k]]["Handle"], {k, 1, nBalls}];

Print["model: ", nBalls, " balls + ", Length[pegs], " pegs (",
      GaltonBoard`$PegRows, " rows x ", GaltonBoard`$PegCols,
      " cols) + ", Length[bins], " bin separators + floor + 6 walls."];
Print["  ball dia / peg dia = ",
      2 GaltonBoard`$BallRadius / (2 GaltonBoard`$PegRadius),
      " ; contact dist / (dx/2) = ",
      (GaltonBoard`$PegRadius + GaltonBoard`$BallRadius) / (GaltonBoard`$PegDx/2)];

(* -- Main loop: step physics; every `dampEvery` steps refresh each ball's
   velocity (tiny damping factor ~= 1) so Rapier's body-sleep mechanism
   doesn't freeze balls on top of pegs. Real air drag would do something
   similar physically. -- *)
Print["evolving ", nFrames, " frames @ dt=", 1.0*dt, " s..."];
t0       = AbsoluteTime[];
current  = model;
prevPoss = Table[current[[1]]["Bodies"][[k]]["Position"], {k, 1, nBalls}];
frames   = Reap[
  Do[
    current = PhysicsModelIterate[current, 1, dt];
    If[Mod[step, dampEvery] == 0,
      Do[Module[{curPos, vel},
          curPos = current[[1]]["Bodies"][[b]]["Position"];
          vel    = (curPos - prevPoss[[b]]) / (dampEvery * dt);
          RapierSetBodyVelocity[worldId, ballHandles[[b]], vel * damping];
          prevPoss[[b]] = curPos],
        {b, 1, nBalls}]];
    Sow[current],
    {step, 1, nFrames}]][[2, 1]];
Print["sim done in ", Round[AbsoluteTime[] - t0, 0.1], " s."];

videoFrames = frames[[;; ;; videoStep]];
Print["rendering ", Length[videoFrames], " video frames..."];
renderedImages = Table[
  Rasterize[PhysicsModelPlot[f], ImageSize -> {720, 1080}, Background -> White],
  {f, videoFrames}];

videoPath = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "02_board_animation.mp4"}];
Export[videoPath, renderedImages, "MP4", "FrameRate" -> 30];
Print["wrote ", videoPath];

stillPath = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "02_board_final.png"}];
Export[stillPath, PhysicsModelPlot[frames[[-1]]], ImageSize -> {900, 1350}];
Print["wrote ", stillPath];

(* -- Empirical bin counts from this physics run -- *)
dynBodies = Select[frames[[-1]][[1]]["Bodies"], #["BodyType"] === "Dynamic" &];
finalXs   = #["Position"][[1]] & /@ dynBodies;
finalZs   = #["Position"][[3]] & /@ dynBodies;
Print["final z min/max: ", Min[finalZs], " / ", Max[finalZs]];
Print["BinTopZ = ", GaltonBoard`$BinTopZ];
settled   = Pick[finalXs, # < GaltonBoard`$BinTopZ & /@ finalZs];
Print["settled balls: ", Length[settled], " / ", Length[dynBodies]];
If[Length[settled] > 0,
  binsCount = Table[
    Count[GaltonBoard`BinIndex /@ settled, b], {b, 1, GaltonBoard`$NBins}];
  Print["bin counts: ", binsCount]];

DestroyPhysicsModel[model];
Print["done."];
