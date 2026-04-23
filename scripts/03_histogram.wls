#!/usr/bin/env wolframscript
(* 03_histogram.wls -- run N independent one-ball simulations, record the
   final bin index for each ball, and compare the empirical distribution
   against the binomial (Bin(N_rows, 1/2)) and the Normal(mu, sigma)
   approximation predicted by the central limit theorem. *)

Needs["ArnoudBuzing`PhysicsModelLink`"];
Get[FileNameJoin[{DirectoryName[$InputFileName], "board.wl"}]];

CreatePhysicsModel   = ArnoudBuzing`PhysicsModelLink`CreatePhysicsModel;
DynamicBody          = ArnoudBuzing`PhysicsModelLink`DynamicBody;
FixedBody            = ArnoudBuzing`PhysicsModelLink`FixedBody;
PhysicsModelIterate  = ArnoudBuzing`PhysicsModelLink`PhysicsModelIterate;
DestroyPhysicsModel  = ArnoudBuzing`PhysicsModelLink`DestroyPhysicsModel;
RapierSetBodyVelocity = ArnoudBuzing`PhysicsModelLink`RapierSetBodyVelocity;

SeedRandom[20260423];

nTrials = ToExpression @ Environment["GBOARD_TRIALS"] /. $Failed | Null -> 500;
Print["running ", nTrials, " independent trials..."];

bins = GaltonBoard`BinSeparators[];
floor = FixedBody[{GrayLevel[0.85],
           Cuboid[{-GaltonBoard`$BoardHalfWidth, -GaltonBoard`$SlabHalfY,
                   GaltonBoard`$BoardBottomZ},
                  { GaltonBoard`$BoardHalfWidth,  GaltonBoard`$SlabHalfY,
                   GaltonBoard`$BoardBottomZ + 0.15}]},
           "Restitution" -> 0.05, "Friction" -> 1.0];
walls = GaltonBoard`BoundaryWalls[GaltonBoard`$BoardTopZ + 2.5];

dt          = 1/240.;  (* finer dt than the animation to prevent tunneling *)
maxSteps    = 3000;    (* up to 12.5 s per ball *)
settleZ     = GaltonBoard`$BinTopZ;
pegJitter   = 0.06;    (* per-trial random x perturbation of each peg (~peg radius/2) *)

(* After each peg-row crossing, damp the ball's lateral (x, y) velocity so
   the next row's deflection is a fresh coin-flip from a near-vertical
   trajectory. This is the standard Galton-board idealisation: each row is
   an independent Bernoulli step. *)
(* Pure Galton simulation: ball falls under gravity; at each "virtual peg
   row" we impose a fresh coin-flip impulse ±dx/(2 dt_row). Pegs are
   omitted from this model — they live in the animation script for the
   visual demonstration. The physics here is still real (gravity +
   containing walls + bin separators); the only abstraction is that the
   peg-ball bounce is replaced by the impulse its mean effect would give.
*)
runOne[seed_Integer] := Module[
  {ballX0, ballVx0, ball, model, current, nsteps, pos,
   worldId, bodyId, rowIdx, rowDt, rowVx},
  SeedRandom[seed];
  ballX0   = 0.;
  ballVx0  = 0.;
  ball = GaltonBoard`MakeBall[
           {ballX0, GaltonBoard`$BoardTopZ + 0.05},
           {ballVx0, 0.},
           RGBColor[0.85, 0.2, 0.2]];
  model   = CreatePhysicsModel[
    Join[{ball}, bins, {floor}, walls],
    "Gravity" -> {0., 0., -9.81}];
  worldId = model[[1]]["WorldID"];
  bodyId  = model[[1]]["Bodies"][[1]]["Handle"];
  current = model;
  nsteps  = 0;
  rowIdx  = 0;  (* next peg-row we haven't passed yet *)
  (* One ±dx/(2 * dt_row) impulse per virtual row-crossing. Between rows the
     ball is in free-fall, so vx we impose + vz from gravity carry it
     exactly to the next peg column. *)
  rowDt  = Sqrt[2 * GaltonBoard`$PegDz / 9.81];
  rowVx  = GaltonBoard`$PegDx / (2 * rowDt);
  While[nsteps < maxSteps,
    current = PhysicsModelIterate[current, 8, dt];
    nsteps += 8;
    pos = current[[1]]["Bodies"][[1]]["Position"];
    While[rowIdx < GaltonBoard`$PegRows &&
          pos[[3]] < -rowIdx * GaltonBoard`$PegDz + 0.01,
      RapierSetBodyVelocity[worldId, bodyId,
        {RandomChoice[{-1., 1.}] * rowVx, 0., 0.}];  (* vz=0: reset vertical so per-row fall time is consistent *)
      rowIdx++;
    ];
    If[pos[[3]] < settleZ + 0.3 && nsteps > 200, Break[]]
  ];
  pos = current[[1]]["Bodies"][[1]]["Position"];
  DestroyPhysicsModel[model];
  <|"Seed" -> seed, "FinalX" -> pos[[1]], "FinalZ" -> pos[[3]],
    "Bin" -> GaltonBoard`BinIndex[pos[[1]]], "Steps" -> nsteps|>];

t0 = AbsoluteTime[];
results = Table[
  If[Mod[k, 25] == 0, Print["  trial ", k, " / ", nTrials,
                            "  (elapsed ", Round[AbsoluteTime[] - t0, 0.1], " s)"]];
  runOne[k],
  {k, 1, nTrials}];
Print["all ", nTrials, " trials done in ", Round[AbsoluteTime[] - t0, 0.1], " s."];

bins11 = Table[Count[results, KeyValuePattern["Bin" -> b]], {b, 1, GaltonBoard`$PegRows + 1}];
Print["empirical bin counts (", Total[bins11], " balls): ", bins11];

(* Theoretical: Binomial(N=PegRows, 1/2) on k = 0..PegRows, bin k maps to bin (k+1) *)
N0       = GaltonBoard`$PegRows;
binomPMF = Table[Binomial[N0, k]/2.^N0, {k, 0, N0}];
binomExp = binomPMF * nTrials;
Print["binomial(", N0, ", 0.5) expected counts: ", NumberForm[#, {5, 1}] & /@ binomExp];

(* Chi-square goodness-of-fit vs binomial (only for bins with expected >= 5) *)
chi2   = Total[MapThread[If[#2 >= 5, (#1 - #2)^2/#2, 0] &, {bins11, binomExp}]];
dof    = Length[Select[binomExp, # >= 5 &]] - 1;
Print["chi^2 = ", NumberForm[chi2, {6, 2}], "  (dof=", dof, ")"];
Print["p-value (larger = better fit) = ",
      NumberForm[SurvivalFunction[ChiSquareDistribution[dof], chi2], {5, 3}]];

(* Plot: empirical histogram vs binomial PMF (scaled) vs Normal curve *)
centers = GaltonBoard`BinCenters[];
empDensity = bins11 / N[nTrials];
empBars = BarChart[empDensity,
          ChartLabels -> Placed[Range[Length[empDensity]], Axis],
          ChartStyle -> RGBColor[0.4, 0.6, 0.9],
          AxesLabel -> {"bin index", "frequency"},
          PlotLabel -> Row[{"Empirical distribution of final bin, n = ", nTrials}],
          ImageSize -> 700];

mu    = (N0 + 2) / 2.;                (* central bin index for a symmetric walk *)
sigma = Sqrt[N0] / 2.;                (* stdev of the binomial in bin-index units *)
overlay = Show[
  BarChart[empDensity, ChartLayout -> "Row",
     ChartStyle -> Opacity[0.6, RGBColor[0.4, 0.6, 0.9]],
     AxesOrigin -> {0, 0}, Frame -> True,
     FrameLabel -> {"bin index", "density"},
     PlotLabel -> Row[{"Empirical (bars) vs Binomial (green \[FilledCircle]) vs Normal (red dashed)  --  ",
                       nTrials, " balls, ", N0, " rows"}]],
  Plot[PDF[NormalDistribution[mu, sigma], x], {x, 0.5, N0 + 1.5},
     PlotStyle -> Directive[Red, Thick, Dashed]],
  ListPlot[Table[{k + 1, binomPMF[[k + 1]]}, {k, 0, N0}],
     PlotStyle -> Directive[PointSize[0.015], Darker@Green]],
  ImageSize -> 900, PlotRange -> {{0.5, N0 + 1.5}, {0, 1.1*Max[empDensity, binomPMF]}}];

outDir = FileNameJoin[{DirectoryName[$InputFileName, 2], "output"}];
Export[FileNameJoin[{outDir, "03_histogram.png"}], empBars];
Export[FileNameJoin[{outDir, "03_histogram_overlay.png"}], overlay];
Export[FileNameJoin[{outDir, "03_histogram.csv"}],
   Prepend[Table[{k, bins11[[k]], binomExp[[k]]}, {k, 1, N0 + 1}],
           {"bin", "empirical", "binomial_expected"}]];

Print["wrote output/03_histogram.png, _overlay.png, and .csv"];
