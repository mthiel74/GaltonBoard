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
dThk  = 0.014;
dWid  = 0.050;
dTal  = 0.14;

(* -- Curved "S"-path layout: two half-circles joined.  Keeps the cascade
   long AND dramatic but with slowly-turning tangent (unlike a spiral)
   so a falling domino lands squarely on the next one. -- *)
arcR    = 0.60;
nArc    = 60;
spacing = 0.095;        (* spacing along the arc *)

pathPts = Join[
  (* first half-circle: centre (-arcR, 0), from angle 0 to Pi, CCW *)
  Table[{-arcR + arcR Cos[t], arcR Sin[t]},
    {t, 0., Pi - 1.5 spacing/arcR, spacing/arcR}],
  (* second half-circle: centre (+arcR, 0), from angle Pi to 0, CW *)
  Table[{+arcR + arcR Cos[t], arcR Sin[t]},
    {t, -Pi, -1.5 spacing/arcR, spacing/arcR}]];
pts = pathPts;
Print["Dominos placed: ", Length[pts]];

(* Tangent at a point on the path (finite difference to the next point). *)
tangentAt[i_] := With[{a = pts[[i]], b = pts[[Min[i + 1, Length[pts]]]]},
  With[{v = b - a, n = Norm[b - a]},
    If[n == 0, {1., 0.}, v/n]]];

(* Build a domino at path-index i oriented tangent to the path *)
makeDomino[i_, color_] := Module[
  {cx, cy, cz, t, tx, ty, rotMat},
  {cx, cy} = pts[[i]];
  cz = dTal;
  t = tangentAt[i];
  {tx, ty} = t;
  rotMat = Transpose[{{tx, ty, 0}, {-ty, tx, 0}, {0, 0, 1}}];
  DynamicBody[{color,
    Cuboid[{cx - dThk, cy - dWid, cz - dTal},
           {cx + dThk, cy + dWid, cz + dTal}]},
    "Density"     -> 1.0,
    "Restitution" -> 0.05,
    "Friction"    -> 0.7,
    "Orientation" -> rotMat]];

dominoes = Table[makeDomino[i,
    Hue[Mod[0.02 i, 1]]], {i, 1, Length[pts]}];

(* (First domino is fine standing upright; the projectile below will
   knock it over with a horizontal hit.) *)

(* -- Projectile: horizontal hit on the first domino. -- *)
{firstCx, firstCy} = pts[[1]];
{tx0, ty0}         = tangentAt[1];
projSpawn  = {firstCx - 0.30 tx0, firstCy - 0.30 ty0, 1.7 dTal};
projectile = DynamicBody[
  {RGBColor[0.85, 0.1, 0.1], Sphere[projSpawn, 0.045]},
  "Density"     -> 8.0,
  "Restitution" -> 0.05,
  "Friction"    -> 0.5,
  "Velocity"    -> {5.0 tx0, 5.0 ty0, 0.}];

(* -- Floor and boundary -- *)
floorHalf = 2.0;
floor = FixedBody[{GrayLevel[0.92],
  Cuboid[{-floorHalf, -floorHalf, -0.08},
         { floorHalf,  floorHalf,  0.0}]},
  "Restitution" -> 0.05, "Friction" -> 0.8];
bbox = PhysicsBoundaryBox[{
  {-floorHalf - 0.05, -floorHalf - 0.05, -0.10},
  { floorHalf + 0.05,  floorHalf + 0.05, 1.50}},
  "Thickness" -> 0.2];

model = CreatePhysicsModel[
  Join[{floor, projectile}, dominoes, bbox],
  "Gravity" -> {0., 0., -9.81},
  "Graphics3DOptions" -> {
    PlotRange    -> {{-1.6, 1.6},
                     {-1.0, 1.0},
                     {-0.02, 0.6}},
    Boxed        -> False, Axes -> False,
    Lighting     -> "Neutral",
    ViewPoint    -> {0.2, -2.2, 1.5},
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
