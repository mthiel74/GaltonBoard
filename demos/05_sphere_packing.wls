#!/usr/bin/env wolframscript
(* 05_sphere_packing.wls -- random close packing of ~2000 small spheres
   in a transparent cuboidal jar.  After settling, report the packing
   fraction; expectation for random close packing is ~0.64 (Bernal). *)

Needs["ArnoudBuzing`PhysicsModelLink`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "_common.wl"}]];

CreatePhysicsModel = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody        = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody          = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelEvolve = ArnoudBuzing`PhysicsModelLink`PhysicsModelEvolve;
PhysicsModelPlot   = ArnoudBuzing`PhysicsModelLink`PhysicsModelPlot;
PhysicsBoundaryBox = ArnoudBuzing`PhysicsModelLink`PhysicsBoundaryBox;

SeedRandom[5];

(* -- Jar dimensions -- *)
jarHalfX   = 0.18;     (* interior half-width *)
jarHalfY   = 0.18;
jarHeight  = 1.00;     (* tall jar to hold the stack during settle *)
wallThk    = 0.02;

ballR      = 0.018;
nBalls     = 1800;

(* -- Ball stack: random positions in a column above the jar floor -- *)
zBottom   = 0.05;
dzStack   = 0.045;      (* >> 2*ballR so balls don't overlap at t=0 *)
ballPos = Table[
  {RandomReal[{-jarHalfX + 2 ballR, jarHalfX - 2 ballR}],
   RandomReal[{-jarHalfY + 2 ballR, jarHalfY - 2 ballR}],
   zBottom + k*dzStack},
  {k, 0, nBalls - 1}];

balls = Table[
  DynamicBody[{Hue[Mod[0.7 + 0.0011 k, 1]],
    Sphere[ballPos[[k + 1]], ballR]},
    "Density"     -> 1.0,
    "Restitution" -> 0.05,
    "Friction"    -> 0.4,
    "Velocity"    -> {0., 0., 0.}],
  {k, 0, nBalls - 1}];

(* -- Jar walls (four side walls + floor); open top -- *)
mkWall[pmin_, pmax_] := FixedBody[{Opacity[0.18], GrayLevel[0.5],
  Cuboid[pmin, pmax]},
  "Restitution" -> 0.05, "Friction" -> 0.6];
floor = FixedBody[{GrayLevel[0.9],
  Cuboid[{-jarHalfX - wallThk, -jarHalfY - wallThk, -0.02},
         { jarHalfX + wallThk,  jarHalfY + wallThk, 0.0}]},
  "Restitution" -> 0.05, "Friction" -> 0.8];

left  = mkWall[{-jarHalfX - wallThk, -jarHalfY - wallThk, 0.},
               {-jarHalfX,            jarHalfY + wallThk, jarHeight}];
right = mkWall[{ jarHalfX,           -jarHalfY - wallThk, 0.},
               { jarHalfX + wallThk,  jarHalfY + wallThk, jarHeight}];
front = mkWall[{-jarHalfX - wallThk, -jarHalfY - wallThk, 0.},
               { jarHalfX + wallThk, -jarHalfY,           jarHeight}];
back  = mkWall[{-jarHalfX - wallThk,  jarHalfY,           0.},
               { jarHalfX + wallThk,  jarHalfY + wallThk, jarHeight}];

bbox = PhysicsBoundaryBox[{
  {-jarHalfX - 0.1, -jarHalfY - 0.1, -0.05},
  { jarHalfX + 0.1,  jarHalfY + 0.1, zBottom + nBalls*dzStack + 0.5}},
  "Thickness" -> 0.2];

model = CreatePhysicsModel[
  Join[{floor, left, right, front, back}, balls, bbox],
  "Gravity" -> {0., 0., -9.81},
  "Graphics3DOptions" -> {
    PlotRange    -> {{-jarHalfX - wallThk - 0.03, jarHalfX + wallThk + 0.03},
                     {-jarHalfY - wallThk - 0.03, jarHalfY + wallThk + 0.03},
                     {-0.05, 0.8}},
    Boxed        -> False, Axes -> False,
    Lighting     -> "Neutral",
    ViewPoint    -> {2.8, -3.2, 1.4},
    ViewVertical -> {0, 0, 1},
    Background   -> RGBColor[0.97, 0.97, 1.0]}];

Print["evolving..."];
dt      = 1/240.;
nFrames = 4200;
t0      = AbsoluteTime[];
frames  = PhysicsModelEvolve[model, nFrames, dt];
Print["sim done in ", Round[AbsoluteTime[] - t0, 0.1], " s."];

(* -- Packing fraction: pile height from highest ball z -- *)
dynBodies = Select[frames[[-1]][[1]]["Bodies"], #["BodyType"] === "Dynamic" &];
topZ = Max[#["Position"][[3]] + ballR & /@ dynBodies];
totalBallVol = nBalls * (4/3) Pi ballR^3;
jarVol       = (2 jarHalfX)*(2 jarHalfY)*topZ;
phi          = totalBallVol / jarVol;
Print["pile height = ", NumberForm[topZ, {5, 4}], " m"];
Print["packing fraction phi = ", NumberForm[phi, {4, 3}],
      "  (Bernal RCP ~= 0.64)"];

outDir    = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "demos"}];
mp4Path   = FileNameJoin[{outDir, "05_sphere_packing.mp4"}];
gifPath   = FileNameJoin[{outDir, "05_sphere_packing.gif"}];
stillPath = FileNameJoin[{outDir, "05_sphere_packing_final.png"}];

GaltonBoardDemos`RenderVideo[frames, mp4Path,
  "VideoStep" -> 11, "ImageSize" -> {620, 900}, "FrameRate" -> 30];
Print["wrote ", mp4Path];
GaltonBoardDemos`MakeGif[mp4Path, gifPath, 420, 15];
Print["wrote ", gifPath];
Export[stillPath, PhysicsModelPlot[frames[[-1]]], ImageSize -> {620, 900}];
Print["wrote ", stillPath];
