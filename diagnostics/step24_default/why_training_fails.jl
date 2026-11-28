# Why the network fails at step 24 (default as a choice) for renters.
# Step 23 and step 24 differ only in `default_choice`, so both are built from
# replay_23_renter.mat with the switch off and on.
#  1. Where the training objective comes from, at the starting network: each
#     household-year's term split into consumption at or above the floor amount
#     F_t, consumption below it (possible only at step 24), the default value,
#     and the bequest term with a base below or above F_t.
#  2. Both steps, and step 23 without the bequest motive, trained alike (steps, households, rate), then evaluated with
#     hard decisions on the same 20,000 Julia draws.
# Run from the repository root:
#   julia --project=neural diagnostics/step24_default/why_training_fails.jl [steps] [arms] [file]
# arms: a comma list of chi0, s23, s24 and s24ratio (step 24 with the first
# output a ratio of all liquid resources, no lower bound on consumption);
# all four by default. file is the replay or test set the models are built
# from (replay_23_renter.mat by default; its default_choice is set off and on).
using NeuralPolicy, MAT, Flux, Statistics, Printf, Random

const DATA = joinpath(@__DIR__, "..", "..", "neural", "data")
steps = length(ARGS) >= 1 ? parse(Int, ARGS[1]) : 300
arms = length(ARGS) >= 2 ? split(ARGS[2], ",") : ["chi0", "s23", "s24", "s24ratio"]
d = matread(joinpath(DATA, length(ARGS) >= 3 ? ARGS[3] : "replay_23_renter.mat"))
kw = Dict{Symbol,Any}(k => getfield(Model(d["model"]), k) for k in fieldnames(Model))
kw[:default_choice] = false
m23 = Model(; kw...)
kw[:default_choice] = true
m24 = Model(; kw...)
crra(c, g) = c^(1 - g) / (1 - g)

function decompose(m, choose, e, N; guard)
    g = m.gamma
    s = entry(m, zeros(1, N); unit=1)
    disc = 1.0
    parts = Dict(k => zeros(N) for k in ("c >= F", "c < F", "default", "bequest b >= F", "bequest b < F"))
    for t in 1:m.T
        o = year(m, t, s, choose(t, s), e)
        C = vec(o.C); Ft = vec(o.F_t)
        wc = m.default_choice ? vec(o.wc) : Float64.(vec(o.look))
        wd = m.default_choice ? vec(o.wd) : Float64.(vec(o.enter))
        uc = ifelse.(wc .> 0, wc .* crra.(max.(C, guard), g), 0.0) .* disc
        below = C .< Ft
        parts["c < F"] .+= ifelse.(below, uc, 0.0)
        parts["c >= F"] .+= ifelse.(below, 0.0, uc)
        parts["default"] .+= disc .* wd .* crra.(max.(Ft, guard), g) .* m.D_beq[t]
        if m.chi > 0
            b = max.(vec(o.beq_next) .+ m.beq_shift .* vec(o.F_t), 1e-12 .* vec(o.W))
            ub = ifelse.(wc .> 0, wc .* m.beta * (1 - m.p_surv[t]) * m.chi .* crra.(max.(b, guard), g), 0.0) .* disc
            small = b .< Ft
            parts["bequest b < F"] .+= ifelse.(small, ub, 0.0)
            parts["bequest b >= F"] .+= ifelse.(small, 0.0, ub)
        end
        disc *= m.beta * m.p_surv[t]
        s = o.state
    end
    U = sum(values(parts))
    tot = sum(U)
    srt = sort(U)
    k50 = findfirst(cumsum(srt) ./ tot .>= 0.5)
    return (; parts, U, tot, k50)
end

function report(name, m, spec, net, N, seed; guard)
    e = draw(m, N, Xoshiro(seed); F=Float64)
    x = decompose(m, choices(f64(net), m, spec), e, N; guard)
    @printf("\n%s: mean objective %.4g; the worst %d of %d households carry half of it\n", name, x.tot / N, x.k50, N)
    for k in ("c >= F", "c < F", "default", "bequest b >= F", "bequest b < F")
        @printf("  %-15s share %.6f\n", k, sum(x.parts[k]) / x.tot)
    end
    return x
end

g = m23.gamma
guard = 10.0^(-30 / (g - 1))
N = 8192
println("Part 1: the starting network (seed 1), $N households, guard $(round(guard; sigdigits=3))")
s23 = Spec(retire=true); s24 = Spec(retire=true, default=true); s24r = Spec(retire=true, default=true, ratio=true)
report("step 23 (forced default at the floor)", m23, s23, policy_net(s23; rng=Xoshiro(1)), N, 11; guard)
report("step 24 (default as a choice)", m24, s24, policy_net(s24; rng=Xoshiro(1)), N, 11; guard)
report("step 24, consumption a ratio of resources", m24, s24r, policy_net(s24r; rng=Xoshiro(1)), N, 11; guard)

println("\nPart 2: training, $steps steps, 4,096 households a step, lr 3e-3")
eval_e(m) = draw(m, 20000, Xoshiro(202); F=Float64)
kw[:default_choice] = false; kw[:chi] = 0.0
m0 = Model(; kw...)
all_arms = Dict("chi0" => ("step 23 with chi = 0", m0, s23), "s23" => ("step 23", m23, s23), "s24" => ("step 24", m24, s24),
                "s24ratio" => ("step 24, consumption a ratio of resources", m24, s24r))
for (name, m, spec) in (all_arms[a] for a in arms)
    t0 = time()
    net, curve = train([m], spec; steps, N=4096, lr=3e-3, seed=1, device=:cpu, progress=100)
    secs = time() - t0
    e = eval_e(m)
    P, c = evaluate(net, m, spec, e)
    U = vec(P["U"])
    srt = sort(U); k50 = findfirst(cumsum(srt) ./ sum(srt) .>= 0.5)
    X = P["X"] ./ m.Y0
    ab = vec(any(P["absorbed"] .> 0.5; dims=2))
    @printf("%s: ce %.5f (s.e. %.5f), worst %d of 20,000 carry half of E[U], defaulted %.4f, mean liquid wealth at 66 %.2f entry incomes, %.0f s\n",
            name, c.ce, c.se, k50, mean(ab), mean(X[:, 66 - m.age0 + 1]), secs)
    report("  $name trained, objective on fresh draws", m, spec, net, N, 12; guard)
end
