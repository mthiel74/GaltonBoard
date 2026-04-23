#!/usr/bin/env wolframscript
(* ::Package:: *)

(* 00_prototype.wls -- single ball falling on a single peg.
   Sanity-check that PhysicsModelLink is installed correctly, gravity points
   down, and spheres bounce off cylinder pegs. *)

Needs["ArnoudBuzing`PhysicsModelLink`"];

(* Use the paclet's own symbols explicitly; the Needs call pulls them into the
   current context but when running as a script via wolframscript they can be
   shadowed by Global` symbols with the same name. Fully qualify to be safe. *)
CreatePhysicsModel  = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody         = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody           = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsBoundaryBox  = ArnoudBuzing`PhysicsModelLink`PhysicsBoundaryBox;
PhysicsModelEvolve  = ArnoudBuzing`PhysicsModelLink`PhysicsModelEvolve;
PhysicsModelPlot    = ArnoudBuzing`PhysicsModelLink`PhysicsModelPlot;
PhysicsModelVideo   = ArnoudBuzing`PhysicsModelLink`PhysicsModelVideo;
DestroyPhysicsModel = ArnoudBuzing`PhysicsModelLink`DestroyPhysicsModel;

(* Scene: one ball dropped slightly off-center above a peg, with a floor. *)
ball  = DynamicBody[{RGBColor[0.9, 0.3, 0.3], Sphere[{0.05, 0., 2.0}, 0.12]},
           "Density" -> 1.0, "Restitution" -> 0.6, "Friction" -> 0.2];

peg   = FixedBody[{GrayLevel[0.5],
           Cylinder[{{0., -0.2, 0.}, {0., 0.2, 0.}}, 0.08]},
           "Restitution" -> 0.6, "Friction" -> 0.2];

(* 1m-thick floor to prevent tunneling at moderate dt *)
floor = FixedBody[{GrayLevel[0.8], Cuboid[{-2., -0.3, -2.0}, {2., 0.3, -1.0}]}];

model = CreatePhysicsModel[{ball, peg, floor},
          "Gravity" -> {0, 0, -9.81},
          "Graphics3DOptions" -> {PlotRange -> {{-2, 2}, {-0.5, 0.5}, {-2.0, 2.5}},
                                  Boxed -> True, Axes -> True,
                                  ViewPoint -> {0, -5, 0}}];

(* Evolve for 200 frames at dt = 1/60 s (~3.3 s). *)
frames = PhysicsModelEvolve[model, 200, 1./60.];

lastBodies = frames[[-1]][[1]]["Bodies"];
lastBall   = SelectFirst[lastBodies, #["BodyType"] === "Dynamic" &];
Print["evolved ", Length[frames], " frames; final ball position: ", lastBall["Position"]];

video = PhysicsModelVideo[frames];
Export[FileNameJoin[{Directory[], "output", "00_prototype.mp4"}], video];
Export[FileNameJoin[{Directory[], "output", "00_prototype_final.png"}],
   PhysicsModelPlot[frames[[-1]]], ImageSize -> 600];

DestroyPhysicsModel[model];
Print["done."];
