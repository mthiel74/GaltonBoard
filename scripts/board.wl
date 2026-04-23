(* ::Package:: *)

(* board.wl -- shared Galton Board geometry used by the animation
   and histogram scripts. Load with Get["scripts/board.wl"] or by Needs. *)

BeginPackage["GaltonBoard`", {"ArnoudBuzing`PhysicsModelLink`"}];

(* -- Board dimensions (metres) -- *)
$PegRows::usage    = "$PegRows = number of peg rows (top row has 1 peg).";
$PegDx::usage      = "$PegDx = horizontal spacing between adjacent pegs in a row.";
$PegDz::usage      = "$PegDz = vertical spacing between peg rows.";
$PegRadius::usage  = "$PegRadius = peg cylinder radius.";
$BallRadius::usage = "$BallRadius = ball sphere radius.";
$SlabHalfY::usage  = "$SlabHalfY = half-thickness of the slab in the Y direction.";

(* Classical "close-packed" Galton-board geometry: big pegs arranged in a
   hexagonal grid so that the ball rolls over each peg and drops into a
   V-shaped valley between the two pegs in the next row. dz = dx*sqrt(3)/2
   keeps peg centres on an equilateral triangular lattice. *)
$PegRows    = 10;
$PegDx      = 0.30;
$PegDz      = 0.30 * 0.8660254;   (* sqrt(3)/2 *)
$PegRadius  = 0.13;               (* large pegs, edges nearly touch in a row *)
$BallRadius = 0.045;              (* small ball rolls over peg tops *)
$SlabHalfY  = 0.10;

(* -- Derived -- *)
$BoardHalfWidth::usage = "half the horizontal extent of the bounding box.";
$BoardTopZ::usage      = "z of the top peg (row 0).";
$BoardBottomZ::usage   = "z of the bin floor.";
$BinTopZ::usage        = "z at which bin separators start.";

$BoardTopZ       = 0.0;
$BoardBottomZ    = -($PegRows - 1)*$PegDz - 2.5;    (* bin depth ~2.5 below last peg row *)
$BinTopZ         = -($PegRows - 1)*$PegDz - 0.3;
(* Side walls flush with outermost bin edges so there is no lateral overflow zone. *)
$BoardHalfWidth  = ($PegRows + 1)/2 * $PegDx;

PegList::usage = "PegList[] returns a list of FixedBody pegs laid out in a triangular grid.";
PegList::usage = "PegList[] returns the (pristine) triangular peg grid.  PegList[jitter] returns the same grid but with each peg's x-coordinate perturbed uniformly in [-jitter, jitter]; use a fresh RandomReal seed per call to generate trial-to-trial variation.";
PegList[] := PegList[0.0];
PegList[jitter_?NumericQ] := Module[{row, j, xs, pegs = {}, xj},
  Do[
    xs = Table[(j - row/2.0) * $PegDx, {j, 0, row}];
    Do[
      xj = x + If[jitter > 0, RandomReal[{-jitter, jitter}], 0.];
      AppendTo[pegs,
        FixedBody[{GrayLevel[0.35],
          Cylinder[{{xj, -$SlabHalfY, -row*$PegDz},
                    {xj,  $SlabHalfY, -row*$PegDz}}, $PegRadius]},
          (* Moderate restitution + good friction: ball rolls over each peg
             and slides down one side of the valley between the two pegs
             below.  This is how a physical Galton board actually works. *)
          "Restitution" -> 0.25, "Friction" -> 0.8]],
      {x, xs}],
    {row, 0, $PegRows - 1}];
  pegs];

BinSeparators::usage = "BinSeparators[] returns FixedBody thin vertical walls that separate the collection bins. Separators sit directly below the row-N-1 pegs so bins lie in the gaps between bottom pegs, giving $PegRows+1 bins (including 2 outer overflow regions).";
BinSeparators[] := Module[{xs, walls = {}, dxHalf = 0.02},
  (* Separators align with row N-1 pegs at x = (j - (N-1)/2)*dx, j = 0..N-1 *)
  xs = Table[(j - ($PegRows - 1)/2.0) * $PegDx, {j, 0, $PegRows - 1}];
  Do[
    AppendTo[walls,
      FixedBody[{GrayLevel[0.55],
        Cuboid[{x - dxHalf, -$SlabHalfY, $BoardBottomZ + 0.15},
               {x + dxHalf,  $SlabHalfY, $BinTopZ}]},
        "Restitution" -> 0.1, "Friction" -> 0.6]],
    {x, xs}];
  walls];

BoundaryWalls::usage = "BoundaryWalls[topZ] returns the 6 walls of the PhysicsBoundaryBox with the ceiling at topZ, so balls can be spawned arbitrarily far above the board without being trapped.";
BoundaryWalls[topZ_?NumericQ] :=
  PhysicsBoundaryBox[{
      {-$BoardHalfWidth, -$SlabHalfY - 0.01, $BoardBottomZ},
      { $BoardHalfWidth,  $SlabHalfY + 0.01, topZ}},
    "Thickness" -> 0.05,
    "Directives" -> {Opacity[0.08], GrayLevel[0.5]}];
BoundaryWalls[] := BoundaryWalls[$BoardTopZ + 2.5];

MakeBall::usage = "MakeBall[pos, {vx,vz}] returns a DynamicBody sphere at pos=(x,z) (y=0) with lateral velocity components.";
MakeBall[{x_, z_}, {vx_: 0., vz_: 0.}, color_: Automatic] :=
  DynamicBody[{If[color === Automatic, Hue[RandomReal[]], color], Sphere[{x, 0., z}, $BallRadius]},
    "Density"     -> 1.0,
    "Restitution" -> 0.25,
    "Friction"    -> 0.8,
    "Velocity"    -> {vx, 0., vz}];

DefaultGraphics3DOpts::usage = "Plot options used for both the animation and histogram scripts.";
DefaultGraphics3DOpts[] := {
  PlotRange -> {{-$BoardHalfWidth, $BoardHalfWidth},
                {-0.6, 0.6},
                {$BoardBottomZ - 0.2, $BoardTopZ + 2.5}},
  Boxed     -> False,
  Axes      -> False,
  Lighting  -> "Neutral",
  ViewPoint -> {0, -6, 0},
  ViewVertical -> {0, 0, 1},
  ImageSize -> {900, 900},
  Background -> RGBColor[0.97, 0.97, 1.0]};

BinIndex::usage = "BinIndex[x] returns 1..$PegRows+1 telling which bin an x-coordinate falls into (clamped to the ends). Bin k is centered at x = (k - 1 - $PegRows/2)*$PegDx.";
BinIndex[x_?NumericQ] := Module[{k},
  (* bin centers at (k - 1 - PegRows/2)*dx for k=1..PegRows+1;
     bin boundaries at (j - PegRows/2 - 0.5)*dx for j=0..PegRows+1;
     equivalently: shift by (PegRows/2 + 0.5)*dx, divide by dx, floor, +1 *)
  k = Floor[(x + ($PegRows/2.0 + 0.5)*$PegDx)/$PegDx] + 1;
  Clip[k, {1, $PegRows + 1}]];

BinCenters::usage = "BinCenters[] returns the list of ($PegRows + 1) bin-center x-coordinates.";
BinCenters[] := Table[(k - 1 - $PegRows/2.0) * $PegDx, {k, 1, $PegRows + 1}];

BinEdges::usage = "BinEdges[] returns the ($PegRows + 2) bin-edge x-coordinates for BinCounts.";
BinEdges[] := Table[(j - ($PegRows + 1)/2.0) * $PegDx, {j, 0, $PegRows + 1}];

EndPackage[];
