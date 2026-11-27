# The grid policy's certainty equivalent on each test set in neural/data,
# simulated (Julia lifetime utility on MATLAB's panel) and from the value
# function, so that the grid's own error (standard against fine numerics, on
# the same draws) sits next to the networks' results.
# Run from the repository root:
#   julia --project=neural neural/scripts/grid_ce.jl
using NeuralPolicy, MAT, Printf, Statistics

const DATA = joinpath(@__DIR__, "..", "data")
files = sort(filter(f -> startswith(f, "testset_") && endswith(f, ".mat"), readdir(DATA)))
@printf("%-40s %7s %12s %12s %9s %10s %10s\n", "test set", "N", "ce value fn", "ce simul.",
        "s.e.", "worst 1%", "floored")
for f in files
    d = matread(joinpath(DATA, f))
    m = Model(d["model"])
    P = d["panel"]
    e = draws_from_matlab(d["draws"], m)
    N = size(P["C"], 1)
    J = panel(m, entry(m, zeros(1, N); unit=m.Y0), replay_choices(P, m.T), e; unit=m.Y0)
    c = certainty_equivalent(m, J["U"])
    @printf("%-40s %7d %12.4f %12.4f %9.4f %10.3f %10.5f\n", f, N, d["value"]["ce_entry"], c.ce, c.se,
            worst_share(J["U"]), mean(P["floored"]))
end
