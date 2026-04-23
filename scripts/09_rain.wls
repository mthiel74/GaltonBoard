#!/usr/bin/env wolframscript
(* 09_rain.wls -- "ball rain" animation: run N independent single-ball
   Rapier simulations SEQUENTIALLY (so each ball cascades alone, without
   ball-ball collisions), record each ball's trajectory, then composite
   all trajectories into a video where a single ball is shown cascading
   at any given frame and the previously-settled balls accumulate in the
   bins.  With enough balls the accumulated pile is the Binomial(18, 1/2)
   bell curve the user asked for.
*)

Needs["ArnoudBuzing`PhysicsModelLink`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "board.wl"}]];

CreatePhysicsModel    = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody           = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody             = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelIterate   = ArnoudBuzing`PhysicsModelLink`PhysicsModelIterate;
PhysicsModelPlot      = ArnoudBuzing`PhysicsModelLink`PhysicsModelPlot;
DestroyPhysicsModel   = ArnoudBuzing`PhysicsModelLink`DestroyPhysicsModel;
RapierSetBodyVelocity = ArnoudBuzing`PhysicsModelLink`RapierSetBodyVelocity;

getParam[name_String, default_] :=
  With[{e = Environment[name]},
    If[StringQ[e] && StringLength[e] > 0, ToExpression[e], default]];

nBalls      = getParam["NBALLS",  200];
samplesPerBall = getParam["FPB", 6];   (* trajectory frames kept per ball *)
dt          = 1/240.;
maxSteps    = 1500;
damping     = 0.99;
dampEvery   = 4;
pegJitter   = 0.004;

Print["simulating ", nBalls, " independent single-ball sims..."];

(* -- Static bodies shared across all sims -- *)
binSep = GaltonBoard`BinSeparators[];
floor  = FixedBody[{GrayLevel[0.85],
           Cuboid[{-GaltonBoard`$BoardHalfWidth, -GaltonBoard`$SlabHalfY,
                   GaltonBoard`$BoardBottomZ},
                  { GaltonBoard`$BoardHalfWidth,  GaltonBoard`$SlabHalfY,
                   GaltonBoard`$BoardBottomZ + 0.12}]},
           "Restitution" -> 0.1, "Friction" -> 0.9];
walls  = GaltonBoard`BoundaryWalls[GaltonBoard`$BoardTopZ + 2.5];

(* -- Run one ball, returning its trajectory as a list of (x, z) samples + final bin -- *)
runOneBall[seed_Integer] := Module[
  {ballX0, pegs, ball, model, worldId, bodyId, current,
   prevPos, curPos, vel, nsteps, traj, nextSample, sampleStep, pos},
  SeedRandom[seed];
  pegs   = GaltonBoard`PegList[pegJitter];
  ballX0 = RandomReal[{-GaltonBoard`$PegDx/6, GaltonBoard`$PegDx/6}];
  ball = GaltonBoard`MakeBall[{ballX0, GaltonBoard`$BoardTopZ + 0.5}, {0., 0.},
            RGBColor[0.9, 0.3, 0.3]];
  model = CreatePhysicsModel[
    Join[{ball}, pegs, binSep, {floor}, walls],
    "Gravity" -> {0., 0., -9.81}];
  worldId = model[[1]]["WorldID"];
  bodyId  = model[[1]]["Bodies"][[1]]["Handle"];
  current = model;
  nsteps  = 0;
  prevPos = current[[1]]["Bodies"][[1]]["Position"];
  traj    = {prevPos};
  sampleStep = Max[50, Floor[maxSteps / (samplesPerBall + 2)]];
  nextSample = sampleStep;
  While[nsteps < maxSteps,
    current = PhysicsModelIterate[current, dampEvery, dt];
    nsteps += dampEvery;
    curPos = current[[1]]["Bodies"][[1]]["Position"];
    vel    = (curPos - prevPos) / (dampEvery * dt);
    RapierSetBodyVelocity[worldId, bodyId, vel * damping];
    prevPos = curPos;
    If[nsteps >= nextSample && Length[traj] < samplesPerBall,
      AppendTo[traj, curPos];
      nextSample += sampleStep];
    If[curPos[[3]] < -GaltonBoard`$PegRows*GaltonBoard`$PegDz - 0.8, Break[]]
  ];
  pos = current[[1]]["Bodies"][[1]]["Position"];
  AppendTo[traj, pos];   (* final settle pos *)
  DestroyPhysicsModel[model];
  <|"Trajectory" -> traj, "FinalPos" -> pos,
    "Bin" -> GaltonBoard`BinIndex[pos[[1]]]|>];

t0 = AbsoluteTime[];
balls = Table[
  If[Mod[k, 25] == 0,
     Print["  ball ", k, " / ", nBalls,
           "  (elapsed ", Round[AbsoluteTime[] - t0, 0.1], " s)"]];
  runOneBall[k],
  {k, 1, nBalls}];
Print["all ", nBalls, " trajectories done in ", Round[AbsoluteTime[] - t0, 0.1], " s."];

(* -- Bin distribution from the final positions -- *)
nBinsTotal = GaltonBoard`$PegRows + 1;
binCounts  = Table[Count[balls, KeyValuePattern["Bin" -> b]], {b, 1, nBinsTotal}];
Print["empirical bin counts (", Total[binCounts], " balls): ", binCounts];

(* -- Build the video.  Each output frame shows:
     - all pegs + walls + bin separators + floor as Graphics3D
     - previously-settled balls at their final positions
     - the CURRENT ball at its current trajectory sample
   We cycle through the balls in sequence, sampling each ball's trajectory
   at `samplesPerBall` equally-spaced moments. -- *)
Print["building video frames..."];

(* Static decoration: draw pegs/bin-separators/floor as plain Graphics3D *)
pegsVisual = GaltonBoard`PegList[0.0];
decorGraphics = Graphics3D[{
  (* pegs *)
  Table[
    With[{cyl = Cases[pegsVisual[[i]], _Cylinder, Infinity][[1]]},
      {GrayLevel[0.35], cyl}],
    {i, 1, Length[pegsVisual]}],
  (* bin separators *)
  Table[
    With[{cub = Cases[binSep[[i]], _Cuboid, Infinity][[1]]},
      {GrayLevel[0.55], cub}],
    {i, 1, Length[binSep]}],
  (* floor *)
  {GrayLevel[0.85],
   Cuboid[{-GaltonBoard`$BoardHalfWidth, -GaltonBoard`$SlabHalfY,
           GaltonBoard`$BoardBottomZ},
          { GaltonBoard`$BoardHalfWidth,  GaltonBoard`$SlabHalfY,
           GaltonBoard`$BoardBottomZ + 0.12}]}}];

(* Assign each settled ball a color by bin (rainbow) *)
ballColor[bin_] := Hue[Mod[0.10 + 0.05*bin, 1]];

frames = Table[
  Module[{ballIdx, sampleIdx, settledGraphics, activeGraphics},
    ballIdx   = Ceiling[frameIdx / samplesPerBall];
    sampleIdx = Mod[frameIdx - 1, samplesPerBall] + 1;
    settledGraphics = Table[
      With[{p = balls[[j]]["FinalPos"]},
        {ballColor[balls[[j]]["Bin"]],
         Sphere[p, GaltonBoard`$BallRadius]}],
      {j, 1, ballIdx - 1}];
    activeGraphics = With[{traj = balls[[ballIdx]]["Trajectory"],
                           col  = ballColor[balls[[ballIdx]]["Bin"]]},
      With[{p = traj[[Min[sampleIdx, Length[traj]]]]},
        {col, Sphere[p, GaltonBoard`$BallRadius]}]];
    Show[decorGraphics,
         Graphics3D[{settledGraphics, activeGraphics}],
         PlotRange -> {{-GaltonBoard`$BoardHalfWidth, GaltonBoard`$BoardHalfWidth},
                       {-0.6, 0.6},
                       {GaltonBoard`$BoardBottomZ - 0.15,
                        GaltonBoard`$BoardTopZ + 1.6}},
         Boxed -> False, Axes -> False, Lighting -> "Neutral",
         ViewPoint -> {0, -20, 0}, ViewVertical -> {0, 0, 1},
         Background -> RGBColor[0.97, 0.97, 1.0]]],
  {frameIdx, 1, nBalls * samplesPerBall}];

(* Append a few "hold" frames at the end to see the final distribution *)
finalFrame = Show[decorGraphics,
    Graphics3D[Table[
      With[{p = balls[[j]]["FinalPos"]},
        {ballColor[balls[[j]]["Bin"]], Sphere[p, GaltonBoard`$BallRadius]}],
      {j, 1, nBalls}]],
    PlotRange -> {{-GaltonBoard`$BoardHalfWidth, GaltonBoard`$BoardHalfWidth},
                  {-0.6, 0.6},
                  {GaltonBoard`$BoardBottomZ - 0.15,
                   GaltonBoard`$BoardTopZ + 1.6}},
    Boxed -> False, Axes -> False, Lighting -> "Neutral",
    ViewPoint -> {0, -20, 0}, ViewVertical -> {0, 0, 1},
    Background -> RGBColor[0.97, 0.97, 1.0]];
frames = Join[frames, ConstantArray[finalFrame, 60]];  (* 2 s of hold at 30 fps *)

Print["rendering ", Length[frames], " video frames..."];
renderedImages = Table[
  Rasterize[f, ImageSize -> {720, 1080}, Background -> White],
  {f, frames}];

videoPath = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "09_rain.mp4"}];
Export[videoPath, renderedImages, "MP4", "FrameRate" -> 30];
Print["wrote ", videoPath];

stillPath = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "09_rain_final.png"}];
Export[stillPath, finalFrame, ImageSize -> {900, 1350}];
Print["wrote ", stillPath];

Print["done."];
