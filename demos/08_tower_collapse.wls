#!/usr/bin/env wolframscript
(* 08_tower_collapse.wls -- Jenga-style tower hit by a cannonball.

   18 layers of 3 long cuboids each (alternating 90 deg per layer
   like a real Jenga stack).  A dense sphere is fired at the tower's
   base with high horizontal velocity; the tower topples through
   Rapier's rigid-body contacts. *)

Needs["ArnoudBuzing`PhysicsModelLink`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "_common.wl"}]];

CreatePhysicsModel = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody        = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody          = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelEvolve = ArnoudBuzing`PhysicsModelLink`PhysicsModelEvolve;
PhysicsModelPlot   = ArnoudBuzing`PhysicsModelLink`PhysicsModelPlot;
PhysicsBoundaryBox = ArnoudBuzing`PhysicsModelLink`PhysicsBoundaryBox;

SeedRandom[8];

(* -- Block dimensions (m) -- *)
bLen   = 0.18;   (* long dimension *)
bWid   = 0.060;  (* short dimension *)
bHi    = 0.048;  (* half-thickness in z *)
blockColors = ColorData["Warm"] /@ Subdivide[0., 1., 17];
nLayers = 18;

(* -- Build the tower: 3 blocks per layer, alternating 90-deg -- *)
buildLayer[layerIdx_] := Module[{z0, parallel, offset, makeBlock, col},
  z0 = 2 bHi * layerIdx + bHi;       (* centre-z of this layer *)
  parallel = OddQ[layerIdx];          (* true -> blocks along Y *)
  col = blockColors[[Mod[layerIdx, 17] + 1]];
  Table[
    With[{shift = (bWid + 0.001) * (k - 1)},
      If[parallel,
        DynamicBody[{col,
          Cuboid[{-bWid/2 + shift - bWid, -bLen/2, z0 - bHi},
                 { bWid/2 + shift - bWid,  bLen/2, z0 + bHi}]},
          "Density" -> 1.0, "Restitution" -> 0.05, "Friction" -> 0.7],
        DynamicBody[{col,
          Cuboid[{-bLen/2,          -bWid/2 + shift - bWid, z0 - bHi},
                 { bLen/2,           bWid/2 + shift - bWid, z0 + bHi}]},
          "Density" -> 1.0, "Restitution" -> 0.05, "Friction" -> 0.7]]],
    {k, 0, 2}]];

tower = Flatten @ Table[buildLayer[i], {i, 0, nLayers - 1}];
Print["tower blocks: ", Length[tower], " (", nLayers, " layers x 3)"];

(* -- Floor -- *)
floor = FixedBody[{GrayLevel[0.92],
  Cuboid[{-2.0, -2.0, -0.05}, {2.0, 2.0, 0.0}]},
  "Restitution" -> 0.05, "Friction" -> 0.8];

(* -- Cannonball flying in from the -X side at the middle of layer 1 -- *)
ball = DynamicBody[
  {RGBColor[0.2, 0.1, 0.3], Sphere[{-1.2, 0., 0.06}, 0.07]},
  "Density"     -> 20.0,     (* very dense -> big momentum *)
  "Restitution" -> 0.05,
  "Friction"    -> 0.3,
  "Velocity"    -> {12.0, 0., 0.}];

bbox = PhysicsBoundaryBox[{
  {-2.0, -1.5, -0.05}, {2.0, 1.5, 2.0}},
  "Thickness" -> 0.2];

model = CreatePhysicsModel[
  Join[{floor, ball}, tower, bbox],
  "Gravity" -> {0., 0., -9.81},
  "Graphics3DOptions" -> {
    PlotRange    -> {{-1.8, 1.8}, {-0.6, 0.6}, {-0.05, 2.0}},
    Boxed        -> False, Axes -> False,
    Lighting     -> "Neutral",
    ViewPoint    -> {-0.8, -4.2, 1.5},
    ViewVertical -> {0, 0, 1},
    Background   -> RGBColor[0.97, 0.97, 1.0]}];

Print["evolving..."];
dt      = 1/240.;
nFrames = 2400;
t0      = AbsoluteTime[];
frames  = PhysicsModelEvolve[model, nFrames, dt];
Print["sim done in ", Round[AbsoluteTime[] - t0, 0.1], " s."];

outDir    = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "demos"}];
mp4Path   = FileNameJoin[{outDir, "08_tower_collapse.mp4"}];
gifPath   = FileNameJoin[{outDir, "08_tower_collapse.gif"}];
stillPath = FileNameJoin[{outDir, "08_tower_collapse_final.png"}];

GaltonBoardDemos`RenderVideo[frames, mp4Path,
  "VideoStep" -> 6, "ImageSize" -> {900, 700}, "FrameRate" -> 30];
Print["wrote ", mp4Path];
GaltonBoardDemos`MakeGif[mp4Path, gifPath, 540, 15];
Print["wrote ", gifPath];
Export[stillPath, PhysicsModelPlot[frames[[-1]]], ImageSize -> {900, 700}];
Print["wrote ", stillPath];
