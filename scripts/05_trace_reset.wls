#!/usr/bin/env wolframscript
(* 05_trace_reset.wls -- trace a single ball through the board WITH per-row
   velocity-reset logic, printing (x, z) at each row crossing. *)

Needs["ArnoudBuzing`PhysicsModelLink`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "board.wl"}]];

CreatePhysicsModel    = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
FixedBody             = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelIterate   = ArnoudBuzing`PhysicsModelLink`PhysicsModelIterate;
DestroyPhysicsModel   = ArnoudBuzing`PhysicsModelLink`DestroyPhysicsModel;
RapierSetBodyVelocity = ArnoudBuzing`PhysicsModelLink`RapierSetBodyVelocity;

SeedRandom[42];

pegs = GaltonBoard`PegList[0.06];
bins = GaltonBoard`BinSeparators[];
floor = FixedBody[{GrayLevel[0.85],
           Cuboid[{-GaltonBoard`$BoardHalfWidth, -GaltonBoard`$SlabHalfY,
                   GaltonBoard`$BoardBottomZ},
                  { GaltonBoard`$BoardHalfWidth,  GaltonBoard`$SlabHalfY,
                   GaltonBoard`$BoardBottomZ + 0.15}]},
           "Restitution" -> 0.05, "Friction" -> 1.0];
walls = GaltonBoard`BoundaryWalls[GaltonBoard`$BoardTopZ + 2.5];

ball = GaltonBoard`MakeBall[
  {0.005, GaltonBoard`$BoardTopZ + GaltonBoard`$PegRadius + GaltonBoard`$BallRadius + 0.10},
  {0., 0.},
  RGBColor[0.85, 0.2, 0.2]];

model   = CreatePhysicsModel[Join[{ball}, pegs, bins, {floor}, walls], "Gravity" -> {0., 0., -9.81}];
worldId = model[[1]]["WorldID"];
bodyId  = model[[1]]["Bodies"][[1]]["Handle"];
Print["worldId = ", worldId, "  bodyId = ", bodyId];

dt = 1/240.;
current = model;
rowIdx  = 0;
Do[
  current = PhysicsModelIterate[current, 8, dt];
  pos = current[[1]]["Bodies"][[1]]["Position"];
  While[rowIdx < GaltonBoard`$PegRows &&
        pos[[3]] < -rowIdx * GaltonBoard`$PegDz + GaltonBoard`$PegRadius + GaltonBoard`$BallRadius,
    Print["  row ", rowIdx, " threshold reached at step ", step,
          "  x=", NumberForm[pos[[1]], {6, 4}],
          "  z=", NumberForm[pos[[3]], {6, 4}],
          " -> reset vx"];
    RapierSetBodyVelocity[worldId, bodyId, {0., 0., -0.8}];
    rowIdx++;
  ];
  If[pos[[3]] < GaltonBoard`$BinTopZ, Break[]];
  If[Mod[step, 20] == 0,
    Print["step ", step, " t=", NumberForm[step*8*dt, {5, 3}], "s  x=", NumberForm[pos[[1]], {6, 4}],
          "  z=", NumberForm[pos[[3]], {6, 4}]]];
  ,
  {step, 1, 400}];

Print["\nfinal position x=", pos[[1]], " z=", pos[[3]]];
Print["bin index: ", GaltonBoard`BinIndex[pos[[1]]]];
DestroyPhysicsModel[model];
