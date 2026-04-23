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

(* Classical pin-and-ball Galton geometry. Pegs are small pin-like
   colliders (much smaller than the ball) so each one is a discrete
   deflector rather than a slab of a solid barrier. The horizontal peg
   spacing dx is chosen so that adjacent pegs' contact zones OVERLAP
   (dx < 2*(ball_r + peg_r)) -- the ball can never slip past a row
   without touching a peg.  Hexagonal vertical spacing dz = dx*sqrt(3)/2
   for a close-packed triangular lattice. *)
$PegRows    = 18;
$PegRadius  = 0.035;             (* slightly bigger: ensures contact even with small jitter *)
$BallRadius = 0.075;             (* ball dia 0.15 *)
(* Same-row peg-edge gap = dx - 2*peg_r = 0.24 - 0.07 = 0.17
    = ball_dia + 0.02 m margin -- wide enough that small peg jitter
   can't close it below the ball diameter. *)
$PegDx      = 0.24;
$PegDz      = 0.21;              (* slightly less than dx so adjacent-row gap also fits *)
$SlabHalfY  = 0.13;

(* -- Derived -- *)
$BoardHalfWidth::usage = "half the horizontal extent of the bounding box.";
$BoardTopZ::usage      = "z of the top peg (row 0).";
$BoardBottomZ::usage   = "z of the bin floor.";
$BinTopZ::usage        = "z at which bin separators start.";

$BoardTopZ       = 0.0;
$BoardBottomZ    = -($PegRows - 1)*$PegDz - 5.0;    (* bin depth ~5 m: deep slots for many balls *)
$BinTopZ         = -($PegRows - 1)*$PegDz - 0.4;
(* Walls flush with the outermost bin edges ($NBins/2 * dx).  The peg
   array is narrower than the bin array so the outermost peg is well
   inside the wall (peg-to-wall gap = 1-1.5 * dx > ball diameter). *)
$BoardHalfWidth  = $NBins/2.0 * $PegDx;

$PegCols::usage = "$PegCols = number of peg columns in even rows (odd rows carry $PegCols - 1 pegs offset by $PegDx/2 so both rows are symmetric about x=0 and the lattice is classical alternating-offset hexagonal).";
$PegCols = 31;   (* odd: 31 pegs in even rows, 30 in odd rows, wide enough
                    to cover >5-sigma of the Binomial(18, 1/2) distribution
                    so extreme bins are statistically empty. *)

$NBins::usage = "$NBins = number of bins at the bottom. Odd so that bins are symmetric about x=0. Larger than $PegRows+1 and wider than the peg array's x-extent so that no ball is forced into an extreme bin just by falling off the edge of the peg grid.";
$NBins = 33;

PegList::usage = "PegList[] returns the (pristine) rectangular peg grid.  PegList[jitter] returns the same grid with each peg's x-coordinate perturbed uniformly in [-jitter, jitter]; call with a fresh RandomReal seed per simulation to generate trial-to-trial variation.";
PegList[] := PegList[0.0];
PegList[jitter_?NumericQ] := Module[{row, j, xj, x, pegs = {}, nPegs, firstX},
  Do[
    If[OddQ[row],
      (* odd row: one FEWER peg, offset so the row is symmetric about 0 *)
      nPegs  = $PegCols - 1;
      firstX = -(($PegCols - 2)/2.0) * $PegDx,
      (* even row *)
      nPegs  = $PegCols;
      firstX = -(($PegCols - 1)/2.0) * $PegDx
    ];
    Do[
      x  = firstX + j * $PegDx;
      xj = x + If[jitter > 0, RandomReal[{-jitter, jitter}], 0.];
      AppendTo[pegs,
        FixedBody[{GrayLevel[0.35],
          Cylinder[{{xj, -$SlabHalfY, -row*$PegDz},
                    {xj,  $SlabHalfY, -row*$PegDz}}, $PegRadius]},
          "Restitution" -> 0.5, "Friction" -> 0.0]],
      {j, 0, nPegs - 1}],
    {row, 0, $PegRows - 1}];
  pegs];

BinSeparators::usage = "BinSeparators[] returns FixedBody thin vertical walls that partition the floor into $NBins collection bins of width $PegDx.";
BinSeparators[] := Module[{xs, walls = {}, dxHalf = 0.02},
  (* $NBins-1 interior separators at x = (k - $NBins/2)*dx, k=1..$NBins-1, symmetric about 0 *)
  xs = Table[(k - $NBins/2.0) * $PegDx, {k, 1, $NBins - 1}];
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
    "Restitution" -> 0.5,
    "Friction"    -> 0.0,
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

BinIndex::usage = "BinIndex[x] returns 1..$NBins telling which bin an x-coordinate falls into (clamped to the ends). Bin k is centered at x = (k - ($NBins+1)/2)*$PegDx.";
BinIndex[x_?NumericQ] := Module[{k},
  k = Floor[(x + $NBins/2.0 * $PegDx)/$PegDx] + 1;
  Clip[k, {1, $NBins}]];

BinCenters::usage = "BinCenters[] returns the list of $NBins bin-center x-coordinates.";
BinCenters[] := Table[(k - ($NBins + 1)/2.0) * $PegDx, {k, 1, $NBins}];

BinEdges::usage = "BinEdges[] returns the $NBins+1 bin-edge x-coordinates for BinCounts.";
BinEdges[] := Table[(j - $NBins/2.0) * $PegDx, {j, 0, $NBins}];

EndPackage[];
