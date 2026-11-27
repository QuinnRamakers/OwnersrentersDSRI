# Write a trained network's layers to a .mat file for MATLAB
# (neural.net_policy), with a check: random inputs and the network's outputs.
# Run from the repository root:
#   julia --project=neural neural/scripts/export_net.jl <results tag> <run>
# Writes neural/data/net_<tag>_<run>.mat.
using NeuralPolicy, MAT, Flux, Random

const DATA = joinpath(@__DIR__, "..", "data")
tag, key = ARGS[1], ARGS[2]
r = matread(joinpath(DATA, "results_$tag.mat"))[key]
spec = Spec(retire=r["retire"], tenure=r["joint"])
_, re = Flux.destructure(f64(policy_net(spec; hidden=Int(r["hidden"]), depth=Int(r["depth"]))))
net = re(Float64.(vec(r["theta"])))
out = Dict{String,Any}("retire" => spec.retire, "tenure" => spec.tenure, "n_layers" => length(net.layers),
                       "variant" => r["variant"], "tag" => tag, "run" => key)
for (i, l) in enumerate(net.layers)
    out["W$i"] = Matrix{Float64}(l.weight)
    out["b$i"] = Vector{Float64}(l.bias)
end
X = rand(Xoshiro(5), n_inputs(spec), 50)
out["check_in"] = X
out["check_out"] = net(X)
file = joinpath(DATA, "net_$(tag)_$(key).mat")
matwrite(file, out)
println("Wrote ", file)
