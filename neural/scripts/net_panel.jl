# A trained network's panel on a test set's draws, saved for MATLAB, so that
# simulate.paths_lna with the network as its policy (neural.net_policy) can be
# checked against the Julia year household by household.
# Run from the repository root:
#   julia --project=neural neural/scripts/net_panel.jl <results tag> <run> <testset.mat>
# Writes neural/data/netpanel_<tag>_<run>_<test set>.mat: C, X, A, H, LW, absorbed (N x T)
# and U (N), in euros and utility in units of entry income, and U_grid, the
# test set's grid policy replayed in the Julia year.
using NeuralPolicy, MAT, Flux

const DATA = joinpath(@__DIR__, "..", "data")
tag, key, file = ARGS[1], ARGS[2], ARGS[3]
r = matread(joinpath(DATA, "results_$tag.mat"))[key]
spec = Spec(retire=r["retire"], tenure=r["joint"], default=get(r, "default", false))
_, re = Flux.destructure(f64(policy_net(spec; hidden=Int(r["hidden"]), depth=Int(r["depth"]))))
net = re(Float64.(vec(r["theta"])))
d = matread(joinpath(DATA, file))
m = Model(d["model"])
e = draws_from_matlab(d["draws"], m)
N = size(d["panel"]["C"], 1)
P = panel(m, entry(m, zeros(1, N); unit=m.Y0), choices(net, m, spec; hard=true), e; unit=m.Y0)
out = Dict{String,Any}(k => P[k] for k in ("C", "X", "A", "H", "LW", "absorbed", "U"))
# The grid policy of the test set, replayed in the Julia year: its lifetime utility
G = panel(m, entry(m, zeros(1, N); unit=m.Y0), replay_choices(d["panel"], m.T), e; unit=m.Y0)
out["U_grid"] = G["U"]
out["test_set"] = file
f = joinpath(DATA, "netpanel_$(tag)_$(key)_$(replace(replace(file, "testset_" => ""), ".mat" => "")).mat")
matwrite(f, out)
println("Wrote ", f)
