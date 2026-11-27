# Train networks at one rung of the ladder and compare them with the grid
# policy on the rung's test set (docs/prompts/neural_policy.md, parts 2-3).
# Run from the repository root:
#   julia --project=neural neural/scripts/train_rung.jl <tag> <testset.mat> [<testset2.mat>] variants=ret,ret_w128
#
# Each test set is a file of neural.make_testsets (one per tenure). A variant
# is a base, `age` (age and the state) or `ret` (also years to retirement and
# a retired indicator), with optional suffixes: _w<hidden units>, _d<hidden
# layers>, _s<seed>, _n<households a step>, _k<training steps>, _lr<rate, as
# 1e-3 written 1e-3>, and _joint (one network for all the test sets, with a
# tenure indicator; with one test set of a model without housing, the second
# tenure is the same model with the indicator set to owner). Writes
# neural/data/results_<tag>.mat and prints a table.
using NeuralPolicy, MAT, Printf, Statistics, Random, Flux

const DATA = joinpath(@__DIR__, "..", "data")

function parse_variant(v::AbstractString)
    parts = split(v, "_")
    base = parts[1]
    base in ("age", "ret") || error("variant $v: the base must be age or ret")
    o = Dict{String,Any}("name" => v, "retire" => base == "ret", "hidden" => 64, "depth" => 2,
                         "seed" => 1, "N" => 16384, "steps" => 3000, "lr" => 1e-3, "joint" => false)
    for p in parts[2:end]
        if p == "joint"
            o["joint"] = true
        elseif startswith(p, "lr")
            o["lr"] = parse(Float64, p[3:end])
        else
            key = Dict('w' => "hidden", 'd' => "depth", 's' => "seed", 'n' => "N", 'k' => "steps")[p[1]]
            o[key] = parse(Int, p[2:end])
        end
    end
    return o
end

"Means by age over the households: consumption, wealth and income in units of entry income, the equity share of the solvent."
function profiles(P, m)
    Y0 = m.Y0
    solvent = P["absorbed"] .== 0
    pi_mean = [mean(P["pi"][solvent[:, t], t]) for t in 1:m.T]
    u1 = P["Y"] ./ (P["X"] .+ P["A"] .+ P["H"] .+ P["Y"])
    qtl(p) = [quantile(u1[:, t], p) for t in 1:m.T]
    return Dict("u1_p01" => qtl(0.01), "u1_p50" => qtl(0.5), "u1_p99" => qtl(0.99),
                "C" => vec(mean(P["C"]; dims=1)) ./ Y0,
                "X" => vec(mean(P["X"]; dims=1)) ./ Y0,
                "W" => vec(mean(P["X"] .+ P["A"] .+ P["H"]; dims=1)) ./ Y0,
                "Y" => vec(mean(P["Y"]; dims=1)) ./ Y0,
                "pi" => pi_mean,
                "absorbed" => vec(mean(P["absorbed"]; dims=1)),
                "ages" => collect(m.age0:m.age0+m.T-1))
end

"The certainty equivalents of two policies on the same households, and the standard error of their difference."
function paired(m, U1, U2)
    a = certainty_equivalent(m, U1)
    b = certainty_equivalent(m, U2)
    g = m.gamma
    h = a.ce / ((1 - g) * a.EU) .* vec(U1) .- b.ce / ((1 - g) * b.EU) .* vec(U2)
    return (; a, b, diff=a.ce - b.ce, se_diff=std(h) / sqrt(length(h)))
end

"""
The lifetime utility, in units of entry income, of a constant consumption
`ce` (the grid value function's certainty equivalent at entry): the scale
each tenure's mean utility is divided by in training, so that the objective
is -1 at the value function's value and both tenures of a joint network
count alike. Not the grid policy's simulated utility: from step 7 to 17 a
few household-years at the yearly top-up make that astronomically large.
"""
eu_ref(m::Model, ce) = ce^(1 - m.gamma) / (1 - m.gamma) * m.D_abs[1]

function with_owner(m::Model, owner::Bool)
    kw = Dict{Symbol,Any}(f => getfield(m, f) for f in fieldnames(Model))
    kw[:is_owner] = owner
    return Model(; kw...)
end

tag = String(ARGS[1])
files = filter(a -> endswith(a, ".mat"), ARGS[2:end])
opts = Dict(split(a, "=")[1] => split(a, "=")[2] for a in ARGS[2:end] if occursin("=", a))
variants = String.(split(get(opts, "variants", "ret"), ","))
device = Symbol(get(opts, "device", "gpu"))

sets = map(files) do f
    d = matread(joinpath(DATA, f))
    m = Model(d["model"])
    e = draws_from_matlab(d["draws"], m)
    N = size(d["panel"]["C"], 1)
    G = panel(m, entry(m, zeros(1, N); unit=m.Y0), replay_choices(d["panel"], m.T), e; unit=m.Y0)
    (; file=f, m, e, G, ce_vf=d["value"]["ce_entry"])
end

results = Dict{String,Any}()
"The share of household-years whose resources fall short of the floor (the top-up, or bankruptcy)."
floored(P, m) = mean(P["LW"] .< m.phi_path' .* P["Y"])

@printf("\n%-22s %-34s %10s %9s %10s %10s %9s %9s %9s %8s\n", "variant", "test set", "ce net", "s.e.",
        "ce grid", "net-grid", "s.e.", "fl. net", "fl. grid", "train s")
for v in variants
    o = parse_variant(v)
    spec = Spec(retire=o["retire"], tenure=o["joint"], default=any(s.m.default_choice for s in sets))
    if o["joint"]
        ms = [s.m for s in sets]
        es = [s.e for s in sets]
        Gs = [s.G for s in sets]
        names = [s.file for s in sets]
        ces = [s.ce_vf for s in sets]
        if length(sets) == 1
            push!(ms, with_owner(sets[1].m, !sets[1].m.is_owner))
            push!(es, sets[1].e)
            push!(Gs, sets[1].G)
            push!(ces, sets[1].ce_vf)
            names = [names[1] * " (as renter)", names[1] * " (as owner)"]
        end
        w = [1 / abs(eu_ref(m, ce)) for (m, ce) in zip(ms, ces)]
        groups = [(ms, es, Gs, names, w)]
    else
        groups = [([s.m], [s.e], [s.G], [s.file], [1 / abs(eu_ref(s.m, s.ce_vf))]) for s in sets]
    end
    for (ms, es, Gs, names, w) in groups
        t0 = time()
        net, curve = train(ms, spec; weights=w, steps=o["steps"], N=o["N"], lr=o["lr"],
                           seed=o["seed"], device, hidden=o["hidden"], depth=o["depth"])
        secs = time() - t0
        theta, _ = Flux.destructure(net)
        for j in eachindex(ms)
            P, _ = evaluate(net, ms[j], spec, es[j])
            c = paired(ms[j], P["U"], Gs[j]["U"])
            fl_net, fl_grid = floored(P, ms[j]), floored(Gs[j], ms[j])
            @printf("%-22s %-34s %10.4g %9.2g %10.4g %10.4g %9.2g %9.5f %9.5f %8.0f\n", v, names[j], c.a.ce,
                    c.a.se, c.b.ce, c.diff, c.se_diff, fl_net, fl_grid, secs)
            key = "run$(length(results) + 1)"
            results[key] = Dict("variant" => v, "test_set" => names[j], "ce_net" => c.a.ce,
                                "se_net" => c.a.se, "ce_grid" => c.b.ce, "se_grid" => c.b.se,
                                "diff" => c.diff, "se_diff" => c.se_diff, "train_sec" => secs,
                                "curve_step" => first.(curve), "curve_value" => last.(curve),
                                "theta" => Float64.(theta), "retire" => o["retire"], "joint" => o["joint"], "default" => spec.default,
                                "hidden" => o["hidden"], "depth" => o["depth"], "seed" => o["seed"],
                                "N" => o["N"], "steps" => o["steps"], "lr" => o["lr"],
                                "net" => profiles(P, ms[j]), "grid" => profiles(Gs[j], ms[j]),
                                "is_owner" => ms[j].is_owner,
                                "floored_net" => fl_net, "floored_grid" => fl_grid,
                                "log10_EU_ratio" => log10(mean(P["U"]) / mean(Gs[j]["U"])),
                                "worst1_net" => worst_share(P["U"]), "worst1_grid" => worst_share(Gs[j]["U"]))
        end
        # With a tenure indicator on a model without housing, the two tenures are
        # the same model: the network should choose the same for both.
        if o["joint"] && length(sets) == 1
            P1, _ = evaluate(net, ms[1], spec, es[1])
            P2, _ = evaluate(net, ms[2], spec, es[2])
            dC = maximum(abs.(P1["C"] ./ P2["C"] .- 1))
            dpi = maximum(abs.(P1["pi"] .- P2["pi"]))
            @printf("%-22s same model, indicator 0 against 1: largest relative gap in C %.4f, in pi %.4f\n", v, dC, dpi)
            results["gap$(length(results) + 1)"] = Dict("variant" => v, "dC" => dC, "dpi" => dpi)
        end
    end
end
for s in sets
    @printf("%-34s grid policy: value function ce %.4f, simulated %.4f\n", s.file, s.ce_vf,
            certainty_equivalent(s.m, s.G["U"]).ce)
end
out = joinpath(DATA, "results_$(tag).mat")
matwrite(out, results)
println("Wrote ", out)
