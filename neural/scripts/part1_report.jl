# Part 1 of docs/prompts/neural_policy.md: for each replay panel in neural/data,
# the grid policy's simulated certainty equivalent (lifetime utility from the
# Julia year on MATLAB's draws) against the value function's (ce_entry), the
# share of utility from the worst 1% of paths, the share bankrupt at 100 and
# the share of household-years at the floor (with the absorbing floor: bankrupt).
# Run from the repository root:
#   julia --project=neural neural/scripts/part1_report.jl
using NeuralPolicy, MAT, Printf, Statistics

const DATA = joinpath(@__DIR__, "..", "data")
files = sort(filter(f -> startswith(f, "replay_") && endswith(f, ".mat"), readdir(DATA));
             by=f -> (parse(Int, match(r"replay_(\d+)", f).captures[1]), f))

@printf("%-26s %6s %6s %11s %11s %9s %8s %10s %10s %10s\n", "panel", "gamma", "N", "ce value fn",
        "ce simul.", "s.e.", "gap %", "worst 1%", "bankrupt", "floored")
for f in files
    d = matread(joinpath(DATA, f))
    m = Model(d["model"])
    P = d["panel"]
    e = draws_from_matlab(d["draws"], m)
    N = size(P["C"], 1)
    J = panel(m, entry(m, zeros(1, N); unit=m.Y0), replay_choices(P, m.T), e; unit=m.Y0)
    ce = certainty_equivalent(m, J["U"])
    ce_vf = d["value"]["ce_entry"]
    note = m.chi > 0 ? "  (bequest motive)" : ""
    @printf("%-26s %6.0f %6d %11.4f %11.4f %9.4f %8.2f %10.3f %10.3f %10.5f%s\n", f, m.gamma, N, ce_vf,
            ce.ce, ce.se, 100 * (ce.ce / ce_vf - 1), worst_share(J["U"]), mean(J["absorbed"][:, end]), mean(P["floored"]), note)
end
