#!/usr/bin/env wolframscript
(* 09_breaking_wave.wls -- a wave of blocks cascading down an incline.
   A dense stack of small cubes is set on the upper half of an
   inclined ramp, behind a vertical gate.  The gate is thrown up at
   t = 0 and the cubes slide / cascade down the ramp, crashing into
   a catch basin at the bottom -- a "wave" of blocks. *)

Needs["ArnoudBuzing`PhysicsModelLink`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "_common.wl"}]];

CreatePhysicsModel = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody        = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody          = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelEvolve = ArnoudBuzing`PhysicsModelLink`PhysicsModelEvolve;
PhysicsModelPlot   = ArnoudBuzing`PhysicsModelLink`PhysicsModelPlot;
PhysicsBoundaryBox = ArnoudBuzing`PhysicsModelLink`PhysicsBoundaryBox;

SeedRandom[9];

(* -- Ramp: an inclined Cuboid at 28 deg.  Use Orientation rotation. -- *)
rampLen   = 3.0;
rampWid   = 0.8;
rampThk   = 0.08;
rampAngle = 28 Degree;

(* Centre the ramp so its top is high-left and its bottom meets the floor at x=0. *)
cx = -rampLen/2 * Cos[rampAngle];
cz =  rampLen/2 * Sin[rampAngle] - rampThk;
ramp = FixedBody[{GrayLevel[0.8],
  Cuboid[{cx - rampLen/2, -rampWid/2, cz - rampThk/2},
         {cx + rampLen/2,  rampWid/2, cz + rampThk/2}]},
  "Orientation" -> RotationMatrix[-rampAngle, {0, 1, 0}],
  "Restitution" -> 0.1, "Friction" -> 0.4];

(* -- Cubes stacked on the upper half of the ramp -- *)
cubeHalf    = 0.040;
layerCount  = 6;
cubesPerRow = 6;
rowsAlong   = 8;   (* along ramp direction *)

(* Position cubes in a grid above the ramp surface (along the upper half). *)
rampSurfaceY[s_] := (* s in [0,1]: fraction from bottom to top; returns world (x,z) *)
  With[{localX = s * rampLen - rampLen/2},
    {cx + localX * Cos[rampAngle], cz + (rampThk/2) Cos[rampAngle] + localX * Sin[-rampAngle]}];
(* simpler: place cubes on the ramp's TOP face in world coords *)
cubePositions = Flatten[Table[
  With[{sx = -0.2 + 0.22 i, sy = -0.2 + 0.08 j, sz = 0.025 + 0.10 k},
    With[{x = Cos[rampAngle] sx + Sin[rampAngle] sz + cx,
          y = sy,
          z = -Sin[rampAngle] sx + Cos[rampAngle] sz + cz + rampThk/2},
      {x, y, z}]],
  {i, 0, rowsAlong - 1}, {j, 0, cubesPerRow - 1}, {k, 0, layerCount - 1}], 2];
Print["cubes placed: ", Length[cubePositions]];

cubes = DynamicBody[
  {Hue[Mod[0.5 + 0.35 #[[2]] + 0.12 #[[1]], 1]],
   Cuboid[# - {cubeHalf, cubeHalf, cubeHalf},
          # + {cubeHalf, cubeHalf, cubeHalf}]},
  "Density" -> 1.0, "Restitution" -> 0.05, "Friction" -> 0.5] & /@ cubePositions;

(* -- Catch basin wall at the bottom of the ramp to stop cubes -- *)
catchWall = FixedBody[{GrayLevel[0.5],
  Cuboid[{0.9, -rampWid/2 - 0.1, 0.}, {1.0, rampWid/2 + 0.1, 0.6}]},
  "Restitution" -> 0.1, "Friction" -> 0.4];

(* Floor catching cubes that miss the ramp *)
floor = FixedBody[{GrayLevel[0.92],
  Cuboid[{-rampLen - 0.5, -rampWid/2 - 0.1, -0.05},
         { 1.2,             rampWid/2 + 0.1, 0.0}]},
  "Restitution" -> 0.1, "Friction" -> 0.5];

bbox = PhysicsBoundaryBox[{
  {-rampLen - 0.5, -rampWid/2 - 0.1, -0.05},
  { 1.3,            rampWid/2 + 0.1, 2.5}},
  "Thickness" -> 0.2];

model = CreatePhysicsModel[
  Join[{ramp, floor, catchWall}, cubes, bbox],
  "Gravity" -> {0., 0., -9.81},
  "Graphics3DOptions" -> {
    PlotRange    -> {{-rampLen - 0.4, 1.2},
                     {-rampWid/2 - 0.1, rampWid/2 + 0.1},
                     {-0.05, 2.0}},
    Boxed        -> False, Axes -> False,
    Lighting     -> "Neutral",
    ViewPoint    -> {0.5, -4.5, 1.5},
    ViewVertical -> {0, 0, 1},
    Background   -> RGBColor[0.97, 0.97, 1.0]}];

Print["evolving..."];
dt      = 1/240.;
nFrames = 3000;
t0      = AbsoluteTime[];
frames  = PhysicsModelEvolve[model, nFrames, dt];
Print["sim done in ", Round[AbsoluteTime[] - t0, 0.1], " s."];

outDir    = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "demos"}];
mp4Path   = FileNameJoin[{outDir, "09_breaking_wave.mp4"}];
gifPath   = FileNameJoin[{outDir, "09_breaking_wave.gif"}];
stillPath = FileNameJoin[{outDir, "09_breaking_wave_final.png"}];

GaltonBoardDemos`RenderVideo[frames, mp4Path,
  "VideoStep" -> 8, "ImageSize" -> {1000, 600}, "FrameRate" -> 30];
Print["wrote ", mp4Path];
GaltonBoardDemos`MakeGif[mp4Path, gifPath, 600, 15];
Print["wrote ", gifPath];
Export[stillPath, PhysicsModelPlot[frames[[-1]]], ImageSize -> {1000, 600}];
Print["wrote ", stillPath];
