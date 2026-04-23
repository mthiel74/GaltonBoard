#!/usr/bin/env wolframscript
(* 07_superballs.wls -- elastic chaos.  ~180 high-restitution (0.95)
   spheres are given random initial velocities inside a sealed cube.
   They bounce off the walls and each other forever (until the
   tiny energy loss from restitution < 1 eventually damps them). *)

Needs["ArnoudBuzing`PhysicsModelLink`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "_common.wl"}]];

CreatePhysicsModel = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody        = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody          = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelEvolve = ArnoudBuzing`PhysicsModelLink`PhysicsModelEvolve;
PhysicsModelPlot   = ArnoudBuzing`PhysicsModelLink`PhysicsModelPlot;
PhysicsBoundaryBox = ArnoudBuzing`PhysicsModelLink`PhysicsBoundaryBox;

SeedRandom[7];

boxHalf  = 0.50;
ballR    = 0.04;
nBalls   = 180;

(* Grid-pack the cube so balls don't overlap at t=0 *)
step = 2.2 ballR;
positions = Flatten[
  Table[{x, y, z},
    {x, -boxHalf + 1.5 ballR, boxHalf - 1.5 ballR, step},
    {y, -boxHalf + 1.5 ballR, boxHalf - 1.5 ballR, step},
    {z, -boxHalf + 1.5 ballR, boxHalf - 1.5 ballR, step}], 2];
positions = RandomSample[positions, UpTo[nBalls]];
Print["spheres placed: ", Length[positions]];

balls = DynamicBody[
  {Hue[RandomReal[]], Sphere[#, ballR]},
  "Density"     -> 1.0,
  "Restitution" -> 0.95,               (* very elastic *)
  "Friction"    -> 0.02,
  "Velocity"    -> RandomPoint[Ball[{0, 0, 0}, 6.0]]] & /@ positions;

bbox = PhysicsBoundaryBox[{
  {-boxHalf, -boxHalf, -boxHalf}, {boxHalf, boxHalf, boxHalf}},
  "Thickness" -> 0.15,
  "Directives" -> {Opacity[0.1], GrayLevel[0.4]}];

model = CreatePhysicsModel[
  Join[balls, bbox],
  "Gravity" -> {0., 0., 0.},   (* zero gravity chamber *)
  "Graphics3DOptions" -> {
    PlotRange    -> {{-boxHalf, boxHalf}, {-boxHalf, boxHalf}, {-boxHalf, boxHalf}},
    Boxed        -> False, Axes -> False,
    Lighting     -> "Neutral",
    ViewPoint    -> {3.0, -3.0, 1.0},
    ViewVertical -> {0, 0, 1},
    Background   -> RGBColor[0.95, 0.95, 1.0]}];

Print["evolving..."];
dt      = 1/240.;
nFrames = 3000;        (* 12.5 s *)
t0      = AbsoluteTime[];
frames  = PhysicsModelEvolve[model, nFrames, dt];
Print["sim done in ", Round[AbsoluteTime[] - t0, 0.1], " s."];

outDir    = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "demos"}];
mp4Path   = FileNameJoin[{outDir, "07_superballs.mp4"}];
gifPath   = FileNameJoin[{outDir, "07_superballs.gif"}];
stillPath = FileNameJoin[{outDir, "07_superballs_final.png"}];

GaltonBoardDemos`RenderVideo[frames, mp4Path,
  "VideoStep" -> 8, "ImageSize" -> {800, 700}, "FrameRate" -> 30];
Print["wrote ", mp4Path];
GaltonBoardDemos`MakeGif[mp4Path, gifPath, 540, 15];
Print["wrote ", gifPath];
Export[stillPath, PhysicsModelPlot[frames[[-1]]], ImageSize -> {800, 700}];
Print["wrote ", stillPath];
