# GaltonBoard

A physically simulated Galton Board built in the Wolfram Language
using [Arnoud Buzing's PhysicsModelLink paclet](https://www.wolframcloud.com/obj/arnoudbuzing/DeployedResources/Paclet/ArnoudBuzing/PhysicsModelLink/).

Balls fall under gravity through a triangular grid of fixed pegs, ricochet randomly,
and accumulate in bins at the bottom. Their distribution approaches a Normal /
Gaussian profile — the classical central-limit-theorem demonstration, but here driven
by real rigid-body collision dynamics rather than a symbolic coin-flip model.

Run scripts live in [`scripts/`](scripts/) and are executed with `wolframscript`.

## Status

Work in progress — see commits for progress.
