# Score trained networks on other test sets: for example networks trained
# against a quick-grid test set, scored against the grid policy of a finer
# grid on the same draws (the test sets of one step share their draws).
# Run from the repository root:
#   julia --project=neural neural/scripts/evaluate.jl <results tag> <run> <testset.mat> [...]
# <run> is the key of the network in the results file (run1, run2, ...); a
# joint network is scored on each test set with its own tenure indicator.
using NeuralPolicy, MAT, Flux, Printf, Statistics

const DATA = joinpath(@__DIR__, "..", "data")
tag, key = ARGS[1], ARGS[2]
r = matread(joinpath(DATA, "results_$tag.mat"))[key]
spec = Spec(retire=r["retire"], tenure=r["joint"])
_, re = Flux.destructure(policy_net(spec; hidden=Int(r["hidden"]), depth=Int(r["depth"])))
net = re(Float32.(vec(r["theta"])))
println("network $tag/$key: $(r["variant"]), trained against $(r["test_set"])")
@printf("%-34s %10s %9s %10s %10s %9s %9s %9s %12s\n", "test set", "ce net", "s.e.", "ce grid", "net-grid", "s.e.",
        "fl. net", "fl. grid", "ce value fn")
for f in ARGS[3:end]
    d = matread(joinpath(DATA, f))
    m = Model(d["model"])
    e = draws_from_matlab(d["draws"], m)
    N = size(d["panel"]["C"], 1)
    G = panel(m, entry(m, zeros(1, N); unit=m.Y0), replay_choices(d["panel"], m.T), e; unit=m.Y0)
    P, _ = evaluate(net, m, spec, e)
    a, b = certainty_equivalent(m, P["U"]), certainty_equivalent(m, G["U"])
    g = m.gamma
    h = a.ce / ((1 - g) * a.EU) .* vec(P["U"]) .- b.ce / ((1 - g) * b.EU) .* vec(G["U"])
    fl(Q) = mean(Q["LW"] .< m.phi_path' .* Q["Y"])
    @printf("%-34s %10.4g %9.2g %10.4g %10.4g %9.2g %9.5f %9.5f %12.4f\n", f, a.ce, a.se, b.ce, a.ce - b.ce,
            std(h) / sqrt(length(h)), fl(P), fl(G), d["value"]["ce_entry"])
end
