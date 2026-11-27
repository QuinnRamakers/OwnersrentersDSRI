# Step 24: where the lifetime utility of the grid policy and of a network comes
# from, on one test set's draws: consumption while continuing, the default
# value, and the bequest term, by age; the worst households; defaults.
# Run from the repository root:
#   julia --project=neural diagnostics/step24_default/decompose.jl <results tag> <run> <testset.mat>
using NeuralPolicy, MAT, Flux, Statistics, Printf

const DATA = joinpath(@__DIR__, "..", "..", "neural", "data")
tag, key, file = ARGS[1], ARGS[2], ARGS[3]
r = matread(joinpath(DATA, "results_$tag.mat"))[key]
spec = Spec(retire=r["retire"], tenure=r["joint"], default=get(r, "default", false))
_, re = Flux.destructure(f64(policy_net(spec; hidden=Int(r["hidden"]), depth=Int(r["depth"]))))
net = re(Float64.(vec(r["theta"])))
d = matread(joinpath(DATA, file))
m = Model(d["model"])
e = draws_from_matlab(d["draws"], m)
N = size(d["panel"]["C"], 1)
g = m.gamma
crra(c) = c^(1 - g) / (1 - g)

function parts(choose)
    s = entry(m, zeros(1, N); unit=m.Y0)
    disc = 1.0
    uc = zeros(N); ud = zeros(N); ub = zeros(N)
    by_age = zeros(m.T, 3)
    minbeq = fill(Inf, N); belowF = falses(N)
    for t in 1:m.T
        o = year(m, t, s, choose(t, s), e)
        wc = vec(o.wc); wd = vec(o.wd)
        c = vec(o.C) ./ m.Y0
        a = disc .* ifelse.(wc .> 0, wc .* crra.(c), 0.0)
        b = disc .* wd .* crra.(vec(o.F_t) ./ m.Y0) .* m.D_beq[t]
        bq = max.(vec(o.beq_next), 1e-12 .* vec(o.W)) ./ m.Y0
        q = disc .* ifelse.(wc .> 0, wc .* m.beta * (1 - m.p_surv[t]) * m.chi .* crra.(bq), 0.0)
        uc .+= a; ud .+= b; ub .+= q
        by_age[t, :] = [mean(a), mean(b), mean(q)]
        minbeq = ifelse.(wc .> 0, min.(minbeq, bq), minbeq)
        belowF .|= (wc .> 0) .& (vec(o.C) .< vec(o.F_t))
        disc *= m.beta * m.p_surv[t]
        s = o.state
    end
    U = uc .+ ud .+ ub
    ce = certainty_equivalent(m, U).ce
    gone = vec(s === nothing ? zeros(N) : 1 .- s.w)
    return (; U, uc, ud, ub, ce, by_age, minbeq, belowF)
end

grid = parts(replay_choices(d["panel"], m.T))
nn = parts(choices(net, m, spec; hard=true))
P = panel(m, entry(m, zeros(1, N); unit=m.Y0), choices(net, m, spec; hard=true), e; unit=m.Y0)
ab_n = vec(any(P["absorbed"] .> 0.5; dims=2)); ab_g = vec(any(d["panel"]["absorbed"] .> 0.5; dims=2))
ages = m.age0:(m.age0 + m.T - 1)
for (name, x, ab) in (("grid policy", grid, ab_g), ("network", nn, ab_n))
    @printf("\n%s: ce %.5f; mean utility %.4g = consumption %.4g + default %.4g + bequest %.4g\n", name, x.ce,
            mean(x.U), mean(x.uc), mean(x.ud), mean(x.ub))
    @printf("  defaulted %.4f; continued below the floor amount at some age %.4f; smallest bequest base %.3g of entry income\n",
            mean(ab), mean(x.belowF), minimum(x.minbeq))
    worst = sortperm(x.U)[1:5]
    for i in worst
        @printf("  household %d: U %.4g (consumption %.4g, default %.4g, bequest %.4g), smallest bequest %.3g\n", i, x.U[i], x.uc[i], x.ud[i], x.ub[i], x.minbeq[i])
    end
    k = sortperm(x.by_age[:, 3])[1:3]
    @printf("  ages with the largest bequest term: %s\n", join(["$(ages[j]) ($(round(x.by_age[j, 3]; sigdigits=3)))" for j in k], ", "))
    srt = sort(x.U); @printf("  share of total utility in the worst 10 households: %.4f; ce without them %.5f\n", sum(srt[1:10]) / sum(srt),
                         ((1 - g) * mean(srt[11:end]) / m.D_abs[1])^(1 / (1 - g)))
end
