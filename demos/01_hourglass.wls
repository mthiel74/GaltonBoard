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

(* -- Geometry -- *)
outerR    = 0.80;    (* outer radius at top / bottom *)
aperture  = 0.08;    (* half-width of the aperture in the middle *)
halfH     = 1.50;    (* half-height of the hourglass *)
wallThk   = 0.02;    (* wall cuboid half-thickness *)
slabY     = 0.05;    (* half-thickness of the slab (Y direction) *)

ballR     = 0.030;
nBalls    = 600;

wallLen   = Sqrt[(outerR - aperture)^2 + halfH^2];
wallAngle = ArcTan[(outerR - aperture)/halfH];

(* -- Helper to build a slanted wall between two points in the XZ plane -- *)
slantWall[{xA_, zA_}, {xB_, zB_}] :=
  Module[{cx, cz, L, theta},
    cx = (xA + xB)/2;
    cz = (zA + zB)/2;
    L  = Sqrt[(xB - xA)^2 + (zB - zA)^2];
    (* rotation about Y: +Z local axis -> direction vector from A to B *)
    theta = ArcTan2[zB - zA, xB - xA] - Pi/2;
    (* Correction: local +Z initially, we want new direction = (xB-xA, 0, zB-zA)/L.
       So rotation by angle alpha where {sin alpha, 0, cos alpha} = direction.
       alpha = ArcTan2[cos, sin] = ArcTan2[(zB-zA)/L, (xB-xA)/L].  *)
    theta = -ArcTan2[zB - zA, xB - xA] + Pi/2;
    FixedBody[{GrayLevel[0.35],
      Cuboid[{cx - wallThk, -slabY, cz - L/2},
             {cx + wallThk,  slabY, cz + L/2}]},
      "Orientation" -> RotationMatrix[theta, {0, 1, 0}],
      "Restitution" -> 0.2, "Friction" -> 0.7]];

topRight    = slantWall[{aperture, 0}, {+outerR,  halfH}];
topLeft     = slantWall[{-aperture, 0}, {-outerR,  halfH}];
bottomRight = slantWall[{aperture, 0}, {+outerR, -halfH}];
bottomLeft  = slantWall[{-aperture, 0}, {-outerR, -halfH}];

(* -- Sand: grid-pack the upper funnel, reject points outside the walls -- *)
step     = 2.1 * ballR;
sandPos  = Flatten[
  Table[
    With[{wallX = aperture + (outerR - aperture) * z / halfH},
      Table[
        If[Abs[x] < wallX - 1.1 ballR, {x, 0., z}, Nothing],
        {x, -outerR + ballR, outerR - ballR, step}]],
    {z, aperture + 1.2 ballR, halfH - 2 ballR, step}],
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
  Join[{topRight, topLeft, bottomRight, bottomLeft}, sand, bbox],
  "Gravity" -> {0., 0., -9.81},
  "Graphics3DOptions" -> {
    PlotRange    -> {{-outerR - 0.05, outerR + 0.05},
                     {-slabY - 0.05, slabY + 0.05},
                     {-halfH - 0.25, halfH + 0.05}},
    Boxed        -> False, Axes -> False,
    Lighting     -> "Neutral",
    ViewPoint    -> {0, -18, 0},
    ViewVertical -> {0, 0, 1},
    Background   -> RGBColor[0.97, 0.97, 1.0]}];

(* -- Evolve -- *)
dt      = 1/240.;
nFrames = 4800;           (* 20 s of physics *)
Print["evolving ", nFrames, " frames at dt=", 1.0*dt, "s..."];
t0      = AbsoluteTime[];
frames  = PhysicsModelEvolve[model, nFrames, dt];
Print["sim done in ", Round[AbsoluteTime[] - t0, 0.1], " s."];

outDir   = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "demos"}];
mp4Path  = FileNameJoin[{outDir, "01_hourglass.mp4"}];
gifPath  = FileNameJoin[{outDir, "01_hourglass.gif"}];
stillPath= FileNameJoin[{outDir, "01_hourglass_final.png"}];

GaltonBoardDemos`RenderVideo[frames, mp4Path,
  "VideoStep" -> 12, "ImageSize" -> {540, 900}, "FrameRate" -> 30];
Print["wrote ", mp4Path];

GaltonBoardDemos`MakeGif[mp4Path, gifPath, 420, 15];
Print["wrote ", gifPath];

Export[stillPath, PhysicsModelPlot[frames[[-1]]], ImageSize -> {540, 900}];
Print["wrote ", stillPath];
