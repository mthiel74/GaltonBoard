#!/usr/bin/env wolframscript
(* 01_hourglass.wls -- granular flow through a narrow aperture.

   A 2D-slab hourglass (viewed from the side): two funnels formed by
   four rotated Cuboid walls joined at a small aperture in the middle.
   Many small DynamicBody spheres (the "sand") start in the top half,
   pour through the aperture, and pile up below. The paclet does all
   the physics: gravity, sphere-wall collisions, sphere-sphere
   collisions, friction, energy loss on bounce. The emergent jamming,
   arching and avalanching are entirely Rapier's doing. *)

Needs["ArnoudBuzing`PhysicsModelLink`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "_common.wl"}]];

CreatePhysicsModel = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody        = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody          = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelEvolve = ArnoudBuzing`PhysicsModelLink`PhysicsModelEvolve;
PhysicsModelPlot   = ArnoudBuzing`PhysicsModelLink`PhysicsModelPlot;
PhysicsBoundaryBox = ArnoudBuzing`PhysicsModelLink`PhysicsBoundaryBox;

SeedRandom[1];

(* -- Geometry: a proper sand-timer with a STRAIGHT NECK.
   Balls flow through a short vertical channel in the middle. *)
outerR    = 0.80;    (* outer radius at top and bottom *)
neckR     = 0.05;    (* neck half-width *)
neckHalf  = 0.15;    (* HALF-height of the straight neck section *)
funnelH   = 0.55;    (* HALF-height of each funnel above/below the neck *)
wallThk   = 0.04;
slabY     = 0.05;

halfH     = neckHalf + funnelH;     (* overall half-height *)

ballR     = 0.022;
nBalls    = 600;

wallLen   = Sqrt[(outerR - aperture)^2 + halfH^2];
wallAngle = ArcTan[(outerR - aperture)/halfH];

(* -- Slanted wall between two XZ points: one rotated Cuboid.  The
   cuboid's local +Z axis is rotated to align with the slant
   direction so balls roll along a single flat surface (no stair
   steps). *)
slantWall[{xA_, zA_}, {xB_, zB_}] := Module[
  {cx, cz, L, theta},
  cx = (xA + xB)/2;
  cz = (zA + zB)/2;
  L  = Sqrt[(xB - xA)^2 + (zB - zA)^2];
  (* rotation about Y so local +Z maps to (xB-xA, 0, zB-zA)/L *)
  theta = -ArcTan2[zB - zA, xB - xA] + Pi/2;
  {FixedBody[{RGBColor[0.25, 0.18, 0.12],
    Cuboid[{cx - wallThk, -slabY, cz - L/2},
           {cx + wallThk,  slabY, cz + L/2}]},
    "Orientation" -> RotationMatrix[theta, {0, 1, 0}],
    "Restitution" -> 0.15, "Friction" -> 0.7]}];

(* Four slanted walls (each a short stack of axis-aligned
   mini-cuboids along the slant direction) + two vertical neck walls. *)
topRight    = slantWall[{neckR,  neckHalf}, {+outerR,  halfH}];
topLeft     = slantWall[{-neckR, neckHalf}, {-outerR,  halfH}];
bottomRight = slantWall[{neckR, -neckHalf}, {+outerR, -halfH}];
bottomLeft  = slantWall[{-neckR,-neckHalf}, {-outerR, -halfH}];
slantWalls  = Join[topRight, topLeft, bottomRight, bottomLeft];
(* Straight vertical neck walls: pass-through channel. *)
neckRight = FixedBody[{RGBColor[0.25, 0.18, 0.12],
  Cuboid[{neckR - wallThk, -slabY, -neckHalf},
         {neckR + wallThk,  slabY,  neckHalf}]},
  "Restitution" -> 0.1, "Friction" -> 0.8];
neckLeft  = FixedBody[{RGBColor[0.25, 0.18, 0.12],
  Cuboid[{-neckR - wallThk, -slabY, -neckHalf},
         {-neckR + wallThk,  slabY,  neckHalf}]},
  "Restitution" -> 0.1, "Friction" -> 0.8];

(* -- Top and bottom "caps" closing off the funnels -- *)
capThk  = 0.04;
topCap  = FixedBody[{GrayLevel[0.35],
  Cuboid[{-outerR - capThk, -slabY, halfH}, {outerR + capThk, slabY, halfH + capThk}]},
  "Restitution" -> 0.1, "Friction" -> 0.6];
botCap  = FixedBody[{GrayLevel[0.35],
  Cuboid[{-outerR - capThk, -slabY, -halfH - capThk}, {outerR + capThk, slabY, -halfH}]},
  "Restitution" -> 0.1, "Friction" -> 0.6];

(* -- Visible "glass" side walls for visual clarity (non-physics) *)
sideL = FixedBody[{Opacity[0.15], GrayLevel[0.4],
  Cuboid[{-outerR - capThk, -slabY - 0.005, -halfH - capThk},
         {-outerR,            slabY + 0.005,  halfH + capThk}]},
  "Restitution" -> 0.1, "Friction" -> 0.4];
sideR = FixedBody[{Opacity[0.15], GrayLevel[0.4],
  Cuboid[{ outerR,           -slabY - 0.005, -halfH - capThk},
         { outerR + capThk,   slabY + 0.005,  halfH + capThk}]},
  "Restitution" -> 0.1, "Friction" -> 0.4];

(* -- Sand: grid-pack the upper funnel (above the neck), reject
   points outside the slanted walls. -- *)
step     = 2.1 * ballR;
sandPos  = Flatten[
  Table[
    With[{wallX = neckR + (outerR - neckR) * (z - neckHalf) / funnelH},
      Table[
        If[neckHalf + 1.2 ballR < z < halfH - 2 ballR &&
           Abs[x] < wallX - 1.2 ballR, {x, 0., z}, Nothing],
        {x, -outerR + ballR, outerR - ballR, step}]],
    {z, neckHalf + 0.02, halfH - 2 ballR, step}],
  1];
sandPos = RandomSample[sandPos, UpTo[nBalls]];
actualN = Length[sandPos];
Print["sand grains placed: ", actualN, " (target ", nBalls, ")"];

sand = DynamicBody[
  {Hue[Mod[#[[2]] + 0.3 #[[3]], 1]], Sphere[{#[[1]], 0., #[[3]]}, ballR]},
  "Density"     -> 1.0,
  "Restitution" -> 0.2,
  "Friction"    -> 0.5,
  "Velocity"    -> {0., 0., 0.}] & /@ sandPos;

(* -- Boundary box (outer walls) -- *)
bbox = PhysicsBoundaryBox[{
  {-outerR - 0.03, -slabY - 0.01, -halfH - 0.25},
  { outerR + 0.03,  slabY + 0.01,  halfH + 0.05}}];

model = CreatePhysicsModel[
  Join[slantWalls, {neckRight, neckLeft, topCap, botCap, sideL, sideR}, sand, bbox],
  "Gravity" -> {0., 0., -9.81},
  "Graphics3DOptions" -> {
    PlotRange    -> {{-outerR - 0.15, outerR + 0.15},
                     {-slabY - 0.05, slabY + 0.05},
                     {-halfH - 0.15, halfH + 0.15}},
    Boxed        -> False, Axes -> False,
    Lighting     -> "Neutral",
    ViewPoint    -> {0, -18, 0},
    ViewVertical -> {0, 0, 1},
    Background   -> RGBColor[0.97, 0.97, 1.0]}];

(* -- Evolve -- *)
dt      = 1/240.;
nFrames = 7200;           (* 30 s of physics -- enough for full drain *)
Print["evolving ", nFrames, " frames at dt=", 1.0*dt, "s..."];
t0      = AbsoluteTime[];
frames  = PhysicsModelEvolve[model, nFrames, dt];
Print["sim done in ", Round[AbsoluteTime[] - t0, 0.1], " s."];

outDir   = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "demos"}];
mp4Path  = FileNameJoin[{outDir, "01_hourglass.mp4"}];
gifPath  = FileNameJoin[{outDir, "01_hourglass.gif"}];
stillPath= FileNameJoin[{outDir, "01_hourglass_final.png"}];

(* Square-ish render so the diagonal slant isn't compressed to look
   vertical. *)
GaltonBoardDemos`RenderVideo[frames, mp4Path,
  "VideoStep" -> 12, "ImageSize" -> {720, 720}, "FrameRate" -> 30];
Print["wrote ", mp4Path];

GaltonBoardDemos`MakeGif[mp4Path, gifPath, 540, 15];
Print["wrote ", gifPath];

Export[stillPath, PhysicsModelPlot[frames[[-1]]], ImageSize -> {720, 720}];
Print["wrote ", stillPath];
