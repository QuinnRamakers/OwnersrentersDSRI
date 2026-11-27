# The policy network: its inputs, its outputs and its training on simulated
# lifetime utility (docs/prompts/neural_policy.md, "The idea").

"""
    Spec(; retire=false, tenure=false)

Which inputs the network gets besides age and the normalised state (u1, u2,
u3, q): `retire` adds years to retirement and a retired indicator, `tenure`
an owner indicator (for one network trained on both tenures).
"""
Base.@kwdef struct Spec
    retire::Bool = false
    tenure::Bool = false
end

n_inputs(spec::Spec) = 5 + 2 * spec.retire + spec.tenure

"""
    features(m, t, s, spec)

The network's input at year `t`: a `n_inputs(spec)` x N matrix. Age is
scaled to [0, 1]; u1 = Y/W, u2 = (A + H)/(W - Y), u3 = A/(A + H) as on the
solver's cube; q only where it enters the budget (owners with the annuity
mortgage or maintenance on the purchase price), 1 elsewhere.
"""
function features(m::Model, t::Integer, s, spec::Spec)
    F = eltype(s.Y)
    if has_housing(m) || has_dc(m)
        W = s.X .+ s.A .+ s.H .+ s.Y
        u1 = s.Y ./ W
        sA = s.A ./ W
        sAH = sA .+ s.H ./ W
        u2 = sAH ./ max.(one(F) .- u1, F(1e-12))
        u3 = clamp.(sA ./ max.(sAH, F(1e-12)), zero(F), one(F))
    else
        u1 = s.Y ./ (s.X .+ s.Y)     # A = H = 0, so u2 = u3 = 0
        u2 = zero(u1)
        u3 = u2
    end
    q_on = m.is_owner && (m.annuity || m.maint_on_purchase)
    q = q_on ? s.q : zero(u1) .+ one(F)
    age = zero(u1) .+ F((t - 1) / (m.T - 1))
    rows = (age, u1, u2, u3, q)
    if spec.retire
        ytr = zero(u1) .+ F(max(m.t_ret - t, 0) / (m.t_ret - 1))
        ret = zero(u1) .+ F(t >= m.t_ret)
        rows = (rows..., ytr, ret)
    end
    if spec.tenure
        rows = (rows..., zero(u1) .+ F(m.is_owner))
    end
    return vcat(rows...)
end

"""
    policy_net(spec; hidden=64, depth=2, rng=Random.default_rng())

A network from `features` to two raw outputs, mapped to (0, 1) by `choices`:
the share of resources above the floor consumed and the liquid equity share.
`depth` hidden layers of `hidden` units, tanh; the outputs start at a
consumption share of `c_init` and an equity share of one half.
"""
function policy_net(spec::Spec; hidden::Integer=64, depth::Integer=2,
                    rng::AbstractRNG=Random.default_rng(), c_init::Real=0.5)
    init = Flux.glorot_uniform(rng)
    layers = Any[Dense(n_inputs(spec) => hidden, tanh; init)]
    for _ in 2:depth
        push!(layers, Dense(hidden => hidden, tanh; init))
    end
    out = Dense(hidden => 2; init)
    # The output biases set the starting consumption share. At step 1 a start
    # at 0.85 began further from the grid policy than one at 0.5 (objective
    # -182,000 against -2,400, the grid at -1) and had caught up by step 250.
    out.bias .= [log(c_init / (1 - c_init)), 0.0]
    push!(layers, out)
    return f32(Chain(layers...))
end

"""
    choices(net, m, spec)

A `choose(t, s)` function for `lifetime` and `panel`: the network's outputs
through a sigmoid. In the last year without a bequest motive everything is
consumed, as in the solver.
"""
function choices(net, m::Model, spec::Spec)
    return function (t, s)
        out = net(features(m, t, s, spec))
        sh = sigmoid.(out[1:1, :])
        if t == m.T && m.chi <= 0
            sh = one.(sh)
        end
        return (; s=sh, pi=sigmoid.(out[2:2, :]))
    end
end

"""
    replay_choices(panel, T)

A `choose(t, s)` function that returns the choices a MATLAB panel applied
(the share of resources consumed and the equity share; 0 where the panel
has NaN, the bankrupt households, whose choices are not used).
"""
function replay_choices(P::AbstractDict, T::Integer)
    nan0(x) = isnan(x) ? 0.0 : x
    c = Float64.(P["c_frac"]); p = Float64.(P["pi"])
    tA = Float64.(P["tau_A"]); rA = Float64.(P["reit_A"])
    row(M, t) = reshape(nan0.(M[:, t]), 1, :)
    return function (t, s)
        tt = min(t, size(tA, 2))
        return (; c=row(c, t), pi=row(p, t), tS=row(tA, tt), tR=row(rA, tt))
    end
end

"""
    train(models, spec; weights, steps, N, lr, seed, device, hidden, depth, guard, log_every)

Train one network on the mean lifetime utility of the households of each
model in `models` (one model, or both tenures for a joint network), each
model's mean multiplied by its weight (for a joint network, 1 over the
absolute value of a reference value, so both tenures count alike). Fresh
draws every step, Float32, on `device` (:gpu or :cpu). The learning rate is
`lr` for the first two thirds of the steps and `lr / 10` after. Returns the
network on the CPU and the training curve (the weighted objective at every
`log_every` steps). Prints the objective and the time every `progress` steps.
"""
function train(models::Vector{Model}, spec::Spec; weights=ones(length(models)),
               steps::Integer=3000, N::Integer=4096, lr=1e-3, seed::Integer=1,
               device::Symbol=:gpu, hidden::Integer=64, depth::Integer=2,
               guard=1e-3, log_every::Integer=50, progress::Integer=250)
    foreach(check_supported, models)
    t0 = time()
    rng = Xoshiro(seed)
    net = policy_net(spec; hidden, depth, rng)
    on_gpu = device === :gpu
    move(x) = on_gpu ? to_gpu(x) : x
    net = move(net)
    opt = Flux.setup(Adam(Float32(lr)), net)
    template = move(zeros(Float32, 1, N))
    curve = Tuple{Int,Float64}[]
    for k in 1:steps
        k == round(Int, 2 * steps / 3) && Optimisers.adjust!(opt, Float32(lr / 10))
        es = [move(draw(m, N, rng)) for m in models]
        val, g = Flux.withgradient(net) do nn
            tot = 0f0
            for (j, m) in enumerate(models)
                s0 = entry(m, template; unit=1)
                U = lifetime(m, s0, choices(nn, m, spec), es[j]; unit=1, guard)
                tot += Float32(weights[j]) * mean(U)
            end
            -tot
        end
        if !isfinite(val)
            error("training step $k: the objective is not finite ($val)")
        end
        Flux.update!(opt, net, g[1])
        if k % log_every == 0 || k == 1
            push!(curve, (k, -Float64(val)))
        end
        if progress > 0 && (k % progress == 0 || k == 1)
            println("step $k of $steps: objective $(round(-Float64(val); sigdigits=6)), ",
                    "$(round(Int, time() - t0)) s")
            flush(stdout)
        end
    end
    return cpu(net), curve
end

"""
    evaluate(net, m, spec, e)

The network's panel on draws `e` (from MATLAB, Float64, on the CPU), with
utility in units of entry income: N x T paths, U, and the certainty
equivalent with its standard error.
"""
function evaluate(net, m::Model, spec::Spec, e)
    net64 = f64(cpu(net))
    N = size(e.eps_Y[1], 2)
    s0 = entry(m, zeros(1, N); unit=m.Y0)
    P = panel(m, s0, choices(net64, m, spec), e; unit=m.Y0)
    return P, certainty_equivalent(m, P["U"])
end
