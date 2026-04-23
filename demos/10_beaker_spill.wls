#!/usr/bin/env wolframscript
(* 10_beaker_spill.wls -- a beaker full of "water" progressively
   tipped over.  The paclet doesn't expose kinematic rotation, so we
   achieve a continuously-rotating beaker by STITCHING many short
   simulations: at each stitch we destroy the model, rebuild it with
   the beaker rotated a few degrees further, and re-inject the balls
   at their last-known positions + estimated velocities.  The
   illusion is a beaker smoothly tipping from upright through ~120
   deg while water pours out. *)

Needs["ArnoudBuzing`PhysicsModelLink`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "_common.wl"}]];

CreatePhysicsModel    = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody           = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody             = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelIterate   = ArnoudBuzing`PhysicsModelLink`PhysicsModelIterate;
PhysicsModelPlot      = ArnoudBuzing`PhysicsModelLink`PhysicsModelPlot;
PhysicsBoundaryBox    = ArnoudBuzing`PhysicsModelLink`PhysicsBoundaryBox;
DestroyPhysicsModel   = ArnoudBuzing`PhysicsModelLink`DestroyPhysicsModel;
RapierSetBodyVelocity = ArnoudBuzing`PhysicsModelLink`RapierSetBodyVelocity;

SeedRandom[10];

(* -- Beaker dimensions -- *)
bHalfX = 0.18;
bHalfY = 0.14;
bHeight = 0.55;
bWallThk = 0.015;
(* Pivot raised to 0.70 m: at 125 deg tilt the lowest rotated
   beaker corner is still well above the floor, so the beaker
   doesn't sink into the table as it tips. *)
pivotPoint = {0.7, 0., 0.70};

(* -- Build the beaker walls given a tilt angle (radians).  Returns a
   list of FixedBody walls in world frame. -- *)
beakerWalls[tilt_] := Module[
  {rot, mkWall, glass, base, sideXm, sideXp, sideYm, sideYp},
  rot = RotationMatrix[tilt, {0, 1, 0}];
  glass = Directive[Opacity[0.25], RGBColor[0.55, 0.75, 0.9]];
  mkWall[localCentre_, localHalfExt_, col_] := Module[{cw, pmin, pmax},
    cw   = rot . localCentre + pivotPoint;
    pmin = cw - localHalfExt;
    pmax = cw + localHalfExt;
    FixedBody[{col, Cuboid[pmin, pmax]},
      "Orientation" -> rot,
      "Restitution" -> 0.05, "Friction" -> 0.4]];
  base   = mkWall[{0., 0., -bWallThk/2},
                  {bHalfX + bWallThk, bHalfY + bWallThk, bWallThk/2},
                  GrayLevel[0.55]];
  sideXm = mkWall[{-bHalfX - bWallThk/2, 0., bHeight/2},
                  {bWallThk/2, bHalfY, bHeight/2}, glass];
  sideXp = mkWall[{ bHalfX + bWallThk/2, 0., bHeight/2},
                  {bWallThk/2, bHalfY, bHeight/2}, glass];
  sideYm = mkWall[{0., -bHalfY - bWallThk/2, bHeight/2},
                  {bHalfX, bWallThk/2, bHeight/2}, glass];
  sideYp = mkWall[{0.,  bHalfY + bWallThk/2, bHeight/2},
                  {bHalfX, bWallThk/2, bHeight/2}, glass];
  {base, sideXm, sideXp, sideYm, sideYp}];

(* -- Water balls: generate initial positions in the beaker's local
   frame, then rotate to world frame. -- *)
ballR = 0.012;
step  = 2.3 ballR;
rot0  = RotationMatrix[0., {0, 1, 0}];   (* upright initially *)

localBallPos = Flatten[
  Table[{x, y, z},
    {x, -bHalfX + 1.5 ballR, bHalfX - 1.5 ballR, step},
    {y, -bHalfY + 1.5 ballR, bHalfY - 1.5 ballR, step},
    {z, 1.5 ballR, bHeight * 0.60, step}], 2];
nBalls = Length[localBallPos];
Print["water balls: ", nBalls];

initialBallPos = (rot0 . # + pivotPoint) & /@ localBallPos;

(* -- Floor the water pours onto -- *)
floor = FixedBody[{GrayLevel[0.92],
  Cuboid[{-0.2, -0.35, -0.06}, {2.2, 0.35, -0.02}]},
  "Restitution" -> 0.05, "Friction" -> 0.5];

bbox = PhysicsBoundaryBox[{
  {-0.3, -0.4, -0.08}, {2.3, 0.4, 1.7}},
  "Thickness" -> 0.3];

(* -- Stitched-simulation controller -- *)
nSegments   = 50;
stepsPerSeg = 30;
tiltFinal   = 125 Degree;
dt          = 1/240.;

currentPos = initialBallPos;
currentVel = ConstantArray[0., {nBalls, 3}];
allFrames  = {};

Print["running ", nSegments, " stitched segments..."];
t0 = AbsoluteTime[];

Do[
  Module[{tilt, walls, ballBodies, model, worldId, ballHandles, prevPos, frames},
    tilt = tiltFinal * (seg - 1) / (nSegments - 1);
    walls = beakerWalls[tilt];

    ballBodies = Table[
      DynamicBody[{Hue[0.55 + 0.12 RandomReal[]],
        Sphere[currentPos[[k]], ballR]},
        "Density"     -> 1.0,
        "Restitution" -> 0.05,
        "Friction"    -> 0.25,
        "Velocity"    -> currentVel[[k]]],
      {k, 1, nBalls}];

    model   = CreatePhysicsModel[
      Join[walls, {floor}, ballBodies, bbox],
      "Gravity" -> {0., 0., -9.81},
      "Graphics3DOptions" -> {
        PlotRange    -> {{-0.1, 2.2}, {-0.3, 0.3}, {-0.05, 1.6}},
        Boxed        -> False, Axes -> False,
        Lighting     -> "Neutral",
        ViewPoint    -> {0.8, -4.0, 0.6},
        ViewVertical -> {0, 0, 1},
        Background   -> RGBColor[0.97, 0.97, 1.0]}];

    worldId     = model[[1]]["WorldID"];
    ballHandles = Table[model[[1]]["Bodies"][[k]]["Handle"],
                         {k, Length[walls] + 2, Length[walls] + 1 + nBalls}];
    (* balls are added AFTER walls + floor (walls = nW bodies, floor = 1),
       so they start at index nW+2 in the Bodies list *)

    frames = Reap[
      Module[{cur = model},
        Do[
          cur = PhysicsModelIterate[cur, 1, dt];
          Sow[cur],
          {stepsPerSeg}];
        cur]][[2, 1]];

    (* Last and second-to-last frame positions -> velocity estimate *)
    prevPos = #["Position"] & /@
      Select[frames[[-2]][[1]]["Bodies"], #["BodyType"] === "Dynamic" &];
    currentPos = #["Position"] & /@
      Select[frames[[-1]][[1]]["Bodies"], #["BodyType"] === "Dynamic" &];
    currentVel = (currentPos - prevPos) / dt;

    AppendTo[allFrames, frames];
    DestroyPhysicsModel[model];

    If[Mod[seg, 10] == 0,
      Print["  segment ", seg, " / ", nSegments,
            "  tilt=", NumberForm[tilt 180/Pi, {4, 1}], " deg",
            "  elapsed ", Round[AbsoluteTime[] - t0, 0.1], " s"]]
  ],
  {seg, 1, nSegments}];

allFrames = Flatten[allFrames, 1];
Print["total frames: ", Length[allFrames], "  real time: ",
      Round[AbsoluteTime[] - t0, 0.1], " s"];

outDir    = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "demos"}];
mp4Path   = FileNameJoin[{outDir, "10_beaker_spill.mp4"}];
gifPath   = FileNameJoin[{outDir, "10_beaker_spill.gif"}];
stillPath = FileNameJoin[{outDir, "10_beaker_spill_final.png"}];

GaltonBoardDemos`RenderVideo[allFrames, mp4Path,
  "VideoStep" -> 3, "ImageSize" -> {1100, 520}, "FrameRate" -> 30];
Print["wrote ", mp4Path];
GaltonBoardDemos`MakeGif[mp4Path, gifPath, 720, 15];
Print["wrote ", gifPath];
Export[stillPath, PhysicsModelPlot[allFrames[[-1]]], ImageSize -> {1100, 520}];
Print["wrote ", stillPath];
