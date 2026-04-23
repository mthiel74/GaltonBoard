#!/usr/bin/env wolframscript
(* 02_board_animation.wls -- simulate many balls falling through a Galton
   board and export a video showing the bell curve forming in the bins. *)

Needs["ArnoudBuzing`PhysicsModelLink`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "board.wl"}]];

SeedRandom[20260423];

CreatePhysicsModel  = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody         = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody           = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelEvolve  = ArnoudBuzing`PhysicsModelLink`PhysicsModelEvolve;
PhysicsModelPlot    = ArnoudBuzing`PhysicsModelLink`PhysicsModelPlot;
PhysicsModelVideo   = ArnoudBuzing`PhysicsModelLink`PhysicsModelVideo;
DestroyPhysicsModel = ArnoudBuzing`PhysicsModelLink`DestroyPhysicsModel;

(* -- Ball drop pattern: balls stacked above the top peg, separated by
   dzStack large enough that each ball finishes its descent before the next
   one arrives at the top peg. -- *)
nBalls   = 15;
dzStack  = 1.20;
balls = Table[
  GaltonBoard`MakeBall[
    {RandomReal[{-0.003, 0.003}],            (* x offset *)
     GaltonBoard`$BoardTopZ + 1.2 + k*dzStack}, (* z stack *)
    {RandomReal[{-0.02, 0.02}], 0.},            (* small initial vx *)
    Hue[Mod[k*0.11, 1]]],
  {k, 0, nBalls - 1}];

pegs   = GaltonBoard`PegList[];
bins   = GaltonBoard`BinSeparators[];
floor  = ArnoudBuzing`PhysicsModelLink`FixedBody[{GrayLevel[0.85],
           Cuboid[{-GaltonBoard`$BoardHalfWidth, -GaltonBoard`$SlabHalfY,
                   GaltonBoard`$BoardBottomZ},
                  { GaltonBoard`$BoardHalfWidth,  GaltonBoard`$SlabHalfY,
                   GaltonBoard`$BoardBottomZ + 0.15}]},
           "Restitution" -> 0.15, "Friction" -> 0.6];
(* Place the ceiling well above the highest ball so nothing gets trapped. *)
stackTop = GaltonBoard`$BoardTopZ + 1.2 + (nBalls - 1) * dzStack + 1.0;
walls    = GaltonBoard`BoundaryWalls[stackTop];

model = CreatePhysicsModel[
  Join[balls, pegs, bins, {floor}, walls],
  "Gravity" -> {0., 0., -9.81},
  "Graphics3DOptions" -> GaltonBoard`DefaultGraphics3DOpts[]];

Print["model: ", nBalls, " balls, ", Length[pegs], " pegs, ",
      Length[bins], " bin separators, + floor + 6 walls."];

(* Evolve: dt = 1/120 s to keep tunneling at bay *)
dt        = 1/120.;
nFrames   = 1200;  (* 10 s of physics *)
Print["evolving ", nFrames, " frames @ dt=", 1.0*dt, " s (total ", nFrames*dt, "s of sim)..."];
t0       = AbsoluteTime[];
frames   = PhysicsModelEvolve[model, nFrames, dt];
Print["sim done in ", Round[AbsoluteTime[] - t0, 0.1], " s."];

(* Keep every 4th frame for the video => 225 frames at 30 fps = 7.5 s playback *)
videoFrames = frames[[;; ;; 4]];

videoPath = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "02_board_animation.mp4"}];
Print["rendering video (", Length[videoFrames], " frames) to ", videoPath];
video = PhysicsModelVideo[videoFrames];
Export[videoPath, video];

(* Also export a still of the final state *)
stillPath = FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "02_board_final.png"}];
Export[stillPath, PhysicsModelPlot[frames[[-1]]], ImageSize -> {1200, 1200}];
Print["exported final still ", stillPath];

(* Inspect final bin distribution *)
dynBodies = Select[frames[[-1]][[1]]["Bodies"], #["BodyType"] === "Dynamic" &];
xs        = #["Position"][[1]] & /@ dynBodies;
zs        = #["Position"][[3]] & /@ dynBodies;
settled   = Pick[xs, # < GaltonBoard`$BinTopZ & /@ zs];
Print["settled balls: ", Length[settled], " / ", Length[dynBodies]];
If[Length[settled] > 0,
  Print["bin counts: ",
    BinCounts[settled, {GaltonBoard`BinEdges[][[1]], GaltonBoard`BinEdges[][[-1]], GaltonBoard`$PegDx}]]];

DestroyPhysicsModel[model];
Print["done."];
