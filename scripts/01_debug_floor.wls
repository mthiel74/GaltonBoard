#!/usr/bin/env wolframscript
(* Debug: drop a single ball onto a thick floor, no peg, and track the z-coord
   over time to confirm the floor stops it. *)

Needs["ArnoudBuzing`PhysicsModelLink`"];
CreatePhysicsModel  = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody         = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody           = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelIterate = ArnoudBuzing`PhysicsModelLink`PhysicsModelIterate;
DestroyPhysicsModel = ArnoudBuzing`PhysicsModelLink`DestroyPhysicsModel;

ball  = DynamicBody[Sphere[{0., 0., 2.0}, 0.12],
           "Density" -> 1.0, "Restitution" -> 0.3, "Friction" -> 0.4];
(* 2m-thick floor, 10m wide *)
floor = FixedBody[Cuboid[{-5., -0.5, -2.0}, {5., 0.5, 0.0}]];

model = CreatePhysicsModel[{ball, floor}, "Gravity" -> {0, 0, -9.81}];

Print["initial positions:"];
Print["  ball:  ", #["Position"]& @ model[[1]]["Bodies"][[1]]];
Print["  floor: ", #["Position"]& @ model[[1]]["Bodies"][[2]]];

current = model;
Do[
  current = PhysicsModelIterate[current, 1, 1./60.];
  If[Mod[step, 10] == 0,
    Print["t=", step/60.0, "s  ball z=", current[[1]]["Bodies"][[1]]["Position"][[3]]]
  ],
  {step, 1, 120}
];

DestroyPhysicsModel[model];
