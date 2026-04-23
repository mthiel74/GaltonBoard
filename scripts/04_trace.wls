#!/usr/bin/env wolframscript
(* 04_trace.wls -- simulate a single ball through the board and print
   (x, z) every 0.05 s, plus compute an x-vs-row table to see where the
   ball exits each peg row. *)

Needs["ArnoudBuzing`PhysicsModelLink`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "board.wl"}]];

CreatePhysicsModel  = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody         = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody           = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelIterate = ArnoudBuzing`PhysicsModelLink`PhysicsModelIterate;
DestroyPhysicsModel = ArnoudBuzing`PhysicsModelLink`DestroyPhysicsModel;
PhysicsModelPlot    = ArnoudBuzing`PhysicsModelLink`PhysicsModelPlot;

SeedRandom[7];

x0 = RandomReal[{-0.01, 0.01}];
Print["x0 = ", x0];

ball = GaltonBoard`MakeBall[{x0, GaltonBoard`$BoardTopZ + 1.0}, {0., 0.},
          RGBColor[0.85, 0.2, 0.2]];
pegs = GaltonBoard`PegList[];
bins = GaltonBoard`BinSeparators[];
floor = FixedBody[{GrayLevel[0.85],
           Cuboid[{-GaltonBoard`$BoardHalfWidth, -GaltonBoard`$SlabHalfY,
                   GaltonBoard`$BoardBottomZ},
                  { GaltonBoard`$BoardHalfWidth,  GaltonBoard`$SlabHalfY,
                   GaltonBoard`$BoardBottomZ + 0.15}]},
           "Restitution" -> 0.15, "Friction" -> 0.6];
walls = GaltonBoard`BoundaryWalls[GaltonBoard`$BoardTopZ + 2.5];

model = CreatePhysicsModel[Join[{ball}, pegs, bins, {floor}, walls],
          "Gravity" -> {0., 0., -9.81},
          "Graphics3DOptions" -> GaltonBoard`DefaultGraphics3DOpts[]];

dt = 1/240.;
current = model;
trajectory = {};
Do[
  current = PhysicsModelIterate[current, 12, dt];
  pos = current[[1]]["Bodies"][[1]]["Position"];
  AppendTo[trajectory, {step*12*dt, pos[[1]], pos[[3]]}];
  If[Mod[step, 10] == 0 || pos[[3]] < GaltonBoard`$BinTopZ,
    Print["t=", NumberForm[step*12*dt, {5, 3}],
          "s  x=", NumberForm[pos[[1]], {7, 4}],
          "  z=", NumberForm[pos[[3]], {7, 4}]]];
  If[pos[[3]] < GaltonBoard`$BoardBottomZ + 0.3, Break[]],
  {step, 1, 120}];

Print["\nbin index: ", GaltonBoard`BinIndex[pos[[1]]]];

Export[FileNameJoin[{DirectoryName[$InputFileName, 2], "output", "04_trajectory.png"}],
  ListLinePlot[{#[[2]], #[[3]]} & /@ trajectory, AspectRatio -> 1,
     PlotLabel -> "ball trajectory",
     AxesLabel -> {"x", "z"},
     PlotStyle -> Thick,
     ImageSize -> 600]];

DestroyPhysicsModel[model];
