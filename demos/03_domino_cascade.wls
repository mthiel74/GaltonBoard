#!/usr/bin/env wolframscript
(* 03_domino_cascade.wls -- chain reaction of ~200 thin dominoes laid
   out along an Archimedean spiral, triggered by a ball dropped onto
   the first one.  Every cuboid is a DynamicBody -- the chain reaction
   is entirely rigid-body physics (no scripted falls). *)

Needs["ArnoudBuzing`PhysicsModelLink`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "_common.wl"}]];

CreatePhysicsModel = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody        = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody          = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelEvolve = ArnoudBuzing`PhysicsModelLink`PhysicsModelEvolve;
PhysicsModelPlot   = ArnoudBuzing`PhysicsModelLink`PhysicsModelPlot;
PhysicsBoundaryBox = ArnoudBuzing`PhysicsModelLink`PhysicsBoundaryBox;

SeedRandom[3];

(* -- Domino dimensions (m) -- *)
dThk  = 0.012;   (* half-thickness along "chain" direction *)
dWid  = 0.050;   (* half-width perpendicular to chain *)
dTal  = 0.12;    (* half-height *)

(* -- Spiral layout -- *)
r0       = 0.30;
rN       = 1.00;
nRevs    = 2.0;
spacing  = 0.10;            (* arc-length between domino centres *)

thetaMax = 2 Pi nRevs;
bSpiral  = (rN - r0)/thetaMax;

(* Walk along the spiral in arc-length increments *)
pts = Module[{theta = 0., r = r0, acc = {}},
  While[theta < thetaMax,
    AppendTo[acc, {r, theta}];
    theta += spacing / Sqrt[r^2 + bSpiral^2];
    r = r0 + bSpiral * theta];
  acc];
Print["Dominos placed: ", Length[pts]];

(* Build a domino at (r, theta) oriented tangent to the spiral *)
makeDomino[{r_, theta_}, color_] := Module[
  {cx, cy, cz, tx, ty, rotMat},
  cx = r Cos[theta]; cy = r Sin[theta]; cz = dTal;
  (* tangent of r(theta) cos/sin theta *)
  tx = bSpiral Cos[theta] - r Sin[theta];
  ty = bSpiral Sin[theta] + r Cos[theta];
  With[{n = Sqrt[tx^2 + ty^2]},
    tx /= n; ty /= n];
  (* orientation matrix: local X = tangent, local Y = outward normal,
     local Z = vertical.  Columns of rotMat. *)
  rotMat = Transpose[{{tx, ty, 0}, {-ty, tx, 0}, {0, 0, 1}}];
  DynamicBody[{color,
    Cuboid[{cx - dThk, cy - dWid, cz - dTal},
           {cx + dThk, cy + dWid, cz + dTal}]},
    "Density"     -> 1.0,
    "Restitution" -> 0.1,
    "Friction"    -> 0.7,
    "Orientation" -> rotMat]];

dominoes = MapIndexed[
  makeDomino[#1, Hue[Mod[0.015 First[#2], 1]]] &, pts];

(* -- Projectile: a ball dropped onto the first domino -- *)
firstR      = pts[[1, 1]];
firstTheta  = pts[[1, 2]];
projX       = firstR Cos[firstTheta];
projY       = firstR Sin[firstTheta];
projectile  = DynamicBody[
  {RGBColor[0.85, 0.1, 0.1],
   Sphere[{projX, projY, 6 dTal}, 0.06]},
  "Density"     -> 3.0,
  "Restitution" -> 0.1,
  "Friction"    -> 0.7,
  "Velocity"    -> {0., 0., -3.0}];

(* -- Floor and boundary -- *)
floorHalf = rN + 0.25;
floor = FixedBody[{GrayLevel[0.92],
  Cuboid[{-floorHalf, -floorHalf, -0.08},
         { floorHalf,  floorHalf,  0.0}]},
  "Restitution" -> 0.05, "Friction" -> 0.8];
bbox = PhysicsBoundaryBox[{
  {-floorHalf - 0.05, -floorHalf - 0.05, -0.10},
  { floorHalf + 0.05,  floorHalf + 0.05, 1.50}}];

model = CreatePhysicsModel[
  Join[{floor, projectile}, dominoes, bbox],
  "Gravity" -> {0., 0., -9.81},
  "Graphics3DOptions" -> {
    PlotRange    -> {{-floorHalf, floorHalf},
                     {-floorHalf, floorHalf},
                     {-0.02, 0.6}},
    Boxed        -> False, Axes -> False,
    Lighting     -> "Neutral",
    ViewPoint    -> {1.2, -1.8, 0.9},
    ViewVertical -> {0, 0, 1},
    Background   -> RGBColor[0.97, 0.97, 1.0]}];

Print["evolving..."];
dt      = 1/240.;
nFrames = 4200;      (* 17.5 s *)
t0      = AbsoluteTime[];
frames  = PhysicsModelEvolve[model, nFrames, dt];
Print["sim done in ", Round[AbsoluteTime[] - t0, 0.1], " s."];

outDir    = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "demos"}];
mp4Path   = FileNameJoin[{outDir, "03_domino_cascade.mp4"}];
gifPath   = FileNameJoin[{outDir, "03_domino_cascade.gif"}];
stillPath = FileNameJoin[{outDir, "03_domino_cascade_final.png"}];

GaltonBoardDemos`RenderVideo[frames, mp4Path,
  "VideoStep" -> 10, "ImageSize" -> {900, 700}, "FrameRate" -> 30];
Print["wrote ", mp4Path];
GaltonBoardDemos`MakeGif[mp4Path, gifPath, 540, 15];
Print["wrote ", gifPath];
Export[stillPath, PhysicsModelPlot[frames[[-1]]], ImageSize -> {900, 700}];
Print["wrote ", stillPath];
