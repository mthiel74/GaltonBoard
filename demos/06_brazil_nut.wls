#!/usr/bin/env wolframscript
(* 06_brazil_nut.wls -- the Brazil-nut effect.

   One big sphere (radius 0.10) starts at the bottom of a box of
   ~400 small spheres (radius 0.02).  We "shake" the container by
   giving every ball a short upward velocity impulse every ~0.15 s.
   The big sphere rises to the top as small spheres fill in
   underneath it.  PhysicsModelLink does not expose a kinematic
   floor, so shaking the content is the cleanest equivalent. *)

Needs["ArnoudBuzing`PhysicsModelLink`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "_common.wl"}]];

CreatePhysicsModel    = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody           = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody             = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelIterate   = ArnoudBuzing`PhysicsModelLink`PhysicsModelIterate;
PhysicsModelPlot      = ArnoudBuzing`PhysicsModelLink`PhysicsModelPlot;
PhysicsBoundaryBox    = ArnoudBuzing`PhysicsModelLink`PhysicsBoundaryBox;
RapierSetBodyVelocity = ArnoudBuzing`PhysicsModelLink`RapierSetBodyVelocity;

SeedRandom[6];

(* -- Container -- *)
jarHalfX = 0.18; jarHalfY = 0.12; jarH = 0.7;
wallThk  = 0.02;

(* -- Small grains packed around a big central ball at the bottom -- *)
bigR  = 0.09;
bigZ  = bigR + 0.02;
big   = DynamicBody[{RGBColor[0.9, 0.2, 0.2], Sphere[{0., 0., bigZ}, bigR]},
  "Density" -> 1.0, "Restitution" -> 0.2, "Friction" -> 0.4];

smallR = 0.020;
smallStep = 2.1 smallR;
smallPos = Flatten[Table[
  If[EuclideanDistance[{x, y, z}, {0., 0., bigZ}] > bigR + smallR + 0.003 &&
     Abs[x] < jarHalfX - smallR && Abs[y] < jarHalfY - smallR,
    {x, y, z}, Nothing],
  {z, smallR + 0.01, jarH - smallR, smallStep},
  {x, -jarHalfX + smallR, jarHalfX - smallR, smallStep},
  {y, -jarHalfY + smallR, jarHalfY - smallR, smallStep}], 2];
smallPos = Take[smallPos, UpTo[500]];
Print["small grains placed: ", Length[smallPos]];

smalls = DynamicBody[
  {Hue[Mod[0.5 + 0.02 #[[1]] + 0.01 #[[3]], 1]], Sphere[#, smallR]},
  "Density" -> 1.0, "Restitution" -> 0.3, "Friction" -> 0.4] & /@ smallPos;

(* -- Jar walls: transparent box -- *)
mkWall[pmin_, pmax_] := FixedBody[{Opacity[0.18], GrayLevel[0.5],
  Cuboid[pmin, pmax]},
  "Restitution" -> 0.1, "Friction" -> 0.5];
floor = FixedBody[{GrayLevel[0.9],
  Cuboid[{-jarHalfX - wallThk, -jarHalfY - wallThk, -0.02},
         { jarHalfX + wallThk,  jarHalfY + wallThk, 0.0}]},
  "Restitution" -> 0.05, "Friction" -> 0.8];
left  = mkWall[{-jarHalfX - wallThk, -jarHalfY - wallThk, 0.},
               {-jarHalfX,            jarHalfY + wallThk, jarH}];
right = mkWall[{ jarHalfX,           -jarHalfY - wallThk, 0.},
               { jarHalfX + wallThk,  jarHalfY + wallThk, jarH}];
front = mkWall[{-jarHalfX - wallThk, -jarHalfY - wallThk, 0.},
               { jarHalfX + wallThk, -jarHalfY,           jarH}];
back  = mkWall[{-jarHalfX - wallThk,  jarHalfY,           0.},
               { jarHalfX + wallThk,  jarHalfY + wallThk, jarH}];

bbox = PhysicsBoundaryBox[{
  {-jarHalfX - 0.1, -jarHalfY - 0.1, -0.05},
  { jarHalfX + 0.1,  jarHalfY + 0.1, jarH + 0.3}},
  "Thickness" -> 0.2];

model = CreatePhysicsModel[
  Join[{floor, left, right, front, back, big}, smalls, bbox],
  "Gravity" -> {0., 0., -9.81},
  "Graphics3DOptions" -> {
    PlotRange    -> {{-jarHalfX - wallThk - 0.02, jarHalfX + wallThk + 0.02},
                     {-jarHalfY - wallThk - 0.02, jarHalfY + wallThk + 0.02},
                     {-0.05, jarH + 0.05}},
    Boxed        -> False, Axes -> False,
    Lighting     -> "Neutral",
    ViewPoint    -> {3.5, -4.5, 1.5},
    ViewVertical -> {0, 0, 1},
    Background   -> RGBColor[0.97, 0.97, 1.0]}];

worldId    = model[[1]]["WorldID"];
ballHandles = With[{bodies = model[[1]]["Bodies"]},
  With[{dyn = Select[bodies, #["BodyType"] === "Dynamic" &]},
    #["Handle"] & /@ dyn]];
nDyn = Length[ballHandles];
Print["dynamic bodies: ", nDyn];

(* -- Main loop: step physics, kick every ~0.15 s -- *)
dt        = 1/240.;
nFrames   = 7200;      (* 30 s *)
kickEvery = 36;        (* 0.15 s *)
kickVz    = 4.0;       (* upward velocity magnitude per kick *)

current = model;
frames  = Reap[
  Do[
    current = PhysicsModelIterate[current, 1, dt];
    If[Mod[step, kickEvery] == 0,
      (* shake: give every dynamic body a random upward velocity *)
      Do[
        RapierSetBodyVelocity[worldId, h,
          {RandomReal[{-0.3, 0.3}], RandomReal[{-0.3, 0.3}],
           kickVz + RandomReal[{-0.5, 0.5}]}],
        {h, ballHandles}]];
    Sow[current],
    {step, 1, nFrames}]][[2, 1]];

Print["sim done."];

outDir    = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "demos"}];
mp4Path   = FileNameJoin[{outDir, "06_brazil_nut.mp4"}];
gifPath   = FileNameJoin[{outDir, "06_brazil_nut.gif"}];
stillPath = FileNameJoin[{outDir, "06_brazil_nut_final.png"}];

GaltonBoardDemos`RenderVideo[frames, mp4Path,
  "VideoStep" -> 18, "ImageSize" -> {540, 900}, "FrameRate" -> 30];
Print["wrote ", mp4Path];
GaltonBoardDemos`MakeGif[mp4Path, gifPath, 420, 15];
Print["wrote ", gifPath];
Export[stillPath, PhysicsModelPlot[frames[[-1]]], ImageSize -> {540, 900}];
Print["wrote ", stillPath];
