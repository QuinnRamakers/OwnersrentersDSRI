# The model's year in Julia: the year of simulate.paths_lna written again, for
# all households at once (1 x N arrays), so that a network can choose and
# Zygote can differentiate the whole life. Every number comes from
# neural.export_model; nothing is derived here. The replay test in
# test/runtests.jl ties this file to paths_lna.
#
# Not covered yet: default as a choice (production, step 24) and the bequest
# motive (chi > 0, step 23). Both raise an error rather than run wrongly.

"""
    Model

One calibration for one tenure, as exported by `neural.export_model`.
Vectors by age have `T` elements, or `T - 1` for transitions.
"""
Base.@kwdef struct Model
    T::Int
    t_ret::Int
    age0::Int
    is_owner::Bool
    gamma::Float64
    beta::Float64
    chi::Float64
    beq_bankrupt::Float64
    tau_inc::Float64
    tau_cg_bond::Float64
    tau_wealth::Float64
    tau_cg_stock::Float64
    cg_loss_offset::Bool
    r::Float64
    Rf::Float64
    mu_S::Float64
    sigma_S::Float64
    mu_H::Float64
    sigma_H::Float64
    mu_REIT::Float64
    sigma_REIT::Float64
    reit_on::Bool
    tau_e::Vector{Float64}
    reit_e::Vector{Float64}
    dc_choice::Bool
    Y0::Float64
    b0::Float64
    replacement::Float64
    kappa::Vector{Float64}
    mu_growth::Vector{Float64}
    sigma_l_log::Vector{Float64}
    p_surv::Vector{Float64}
    ann_price::Vector{Float64}
    h_mult::Float64
    alpha::Float64
    theta::Float64
    sell_cost::Float64
    annuity::Bool
    maint_on_purchase::Bool
    m_rate::Vector{Float64}
    floor_absorbing::Bool
    default_choice::Bool
    phi_floor::Float64
    phi_path::Vector{Float64}
    D_abs::Vector{Float64}
    D_beq::Vector{Float64}
    chol::Matrix{Float64}
end

_scalar(x) = x isa AbstractArray ? Float64(only(x)) : Float64(x)
_column(x) = x isa AbstractArray ? vec(Float64.(collect(x))) : [Float64(x)]

"Build a `Model` from the dictionary MAT.jl reads from `neural.export_model`."
function Model(d::AbstractDict)
    s(k) = _scalar(d[k])
    v(k) = _column(d[k])
    b(k) = _scalar(d[k]) != 0
    Model(T=Int(s("T")), t_ret=Int(s("t_ret")), age0=Int(s("age0")), is_owner=b("is_owner"),
          gamma=s("gamma"), beta=s("beta"), chi=s("chi"), beq_bankrupt=s("beq_bankrupt"),
          tau_inc=s("tau_inc"), tau_cg_bond=s("tau_cg_bond"), tau_wealth=s("tau_wealth"),
          tau_cg_stock=s("tau_cg_stock"), cg_loss_offset=b("cg_loss_offset"),
          r=s("r"), Rf=s("Rf"), mu_S=s("mu_S"), sigma_S=s("sigma_S"),
          mu_H=s("mu_H"), sigma_H=s("sigma_H"), mu_REIT=s("mu_REIT"), sigma_REIT=s("sigma_REIT"),
          reit_on=b("reit_on"), tau_e=v("tau_e"), reit_e=v("reit_e"), dc_choice=b("dc_choice"),
          Y0=s("Y0"), b0=s("b0"), replacement=s("replacement"), kappa=v("kappa"),
          mu_growth=v("mu_growth"), sigma_l_log=v("sigma_l_log"), p_surv=v("p_surv"),
          ann_price=v("ann_price"), h_mult=s("h_mult"), alpha=s("alpha"), theta=s("theta"),
          sell_cost=s("sell_cost"), annuity=b("annuity"), maint_on_purchase=b("maint_on_purchase"),
          m_rate=v("m_rate"), floor_absorbing=b("floor_absorbing"),
          default_choice=b("default_choice"), phi_floor=s("phi_floor"), phi_path=v("phi_path"),
          D_abs=v("D_abs"), D_beq=v("D_beq"), chol=Matrix{Float64}(d["chol"]))
end

"Does the model have a house or rent index (H > 0)?"
has_housing(m::Model) = m.h_mult > 0

"Does the model have a DC pot (a contribution at some age)?"
has_dc(m::Model) = any(>(0), m.kappa)

"Refuse the parts of the model the Julia year does not cover yet."
function check_supported(m::Model)
    m.default_choice && error("default as a choice (step 24) is not in the Julia year yet")
    return m
end

"""
Years of draws a life needs: T - 1 transitions, and one more with a bequest
motive, for the year of returns the last bequest earns (as in the solver).
"""
n_draw_years(m::Model) = m.chi > 0 ? m.T : m.T - 1

"""
    draws_from_matlab(d, m; seed=777)

The draws `neural.draw_shocks` exported (N x (T-1) each) as vectors of
1 x N rows, one a year. With a bequest motive the last year's draws, which
MATLAB's panel does not need, are added from Julia's generator (`seed`), the
same for every policy evaluated on these draws.
"""
function draws_from_matlab(d::AbstractDict, m; seed::Integer=777)
    T = m.T
    rows(E) = [reshape(Float64.(E[:, t]), 1, :) for t in 1:T-1]
    e = (; eps_Y=rows(d["eps_Y"]), eps_S=rows(d["eps_S"]),
         eps_H=rows(d["eps_H"]), eps_R=rows(d["eps_R"]))
    if m.chi > 0
        N = size(d["eps_Y"], 1)
        last = draw_year(m, N, Xoshiro(seed), Float64)
        e = (; eps_Y=[e.eps_Y; [last[1]]], eps_S=[e.eps_S; [last[2]]],
             eps_H=[e.eps_H; [last[3]]], eps_R=[e.eps_R; [last[4]]])
    end
    return e
end
draws_from_matlab(d::AbstractDict, T::Integer) = draws_from_matlab(d, (; T, chi=0.0))

function draw_year(m, N, rng, F)
    L = F.(m.chol)
    k = size(L, 1)
    E = L * randn(rng, F, k, N)
    return (E[1:1, :], E[2:2, :], E[3:3, :], k == 4 ? E[4:4, :] : zeros(F, 1, N))
end

"""
    draw(m, N, rng; F=Float32)

Fresh correlated draws for N households, by the exported Cholesky factor, in
the order income, stock, house, REIT, on the CPU, for `n_draw_years(m)`
years. Not the same numbers as MATLAB's for any seed; for training only.
"""
function draw(m::Model, N::Integer, rng::AbstractRNG; F::Type{<:AbstractFloat}=Float32)
    L = F.(m.chol)
    k = size(L, 1)
    eY = Vector{Matrix{F}}(undef, n_draw_years(m))
    eS = similar(eY); eH = similar(eY); eR = similar(eY)
    for t in 1:n_draw_years(m)
        E = L * randn(rng, F, k, N)
        eY[t] = E[1:1, :]
        eS[t] = E[2:2, :]
        eH[t] = E[3:3, :]
        eR[t] = k == 4 ? E[4:4, :] : zeros(F, 1, N)
    end
    return (; eps_Y=eY, eps_S=eS, eps_H=eH, eps_R=eR)
end

"""
    entry(m, template; unit=m.Y0)

The entry state of `simulate.paths_lna` for every household: income `unit`
(the euro income at 25, or 1 to work in units of it), b0 years of income in
liquid wealth, the house or rent index h_mult times income, no DC pot, q = 1.
`template` is a 1 x N array of the element type and device wanted.
"""
function entry(m::Model, template::AbstractArray; unit=m.Y0)
    F = eltype(template)
    z = zero(template)
    Y = z .+ F(unit)
    return (; Y, X=F(m.b0) .* Y, A=z, H=F(m.h_mult) .* Y, q=z .+ one(F),
            gone=z .> one(F), Cbar=z)
end

"""
    year(m, t, s, ch, e)

Year `t` of `simulate.paths_lna` for state `s` and choices `ch`. The choice
of consumption comes either as `ch.c`, a share of liquid resources (as the
grid policy stores it), or as `ch.s`, a share of the resources above the
floor (what the network gives: consumption = floor + s (resources - floor),
the search domain of the solver). `ch.pi` is the liquid equity share; with
`dc_choice`, `ch.tS` and `ch.tR` the fund's stock and REIT shares. Returns
the next state (nothing in the last year) and the year's consumption,
resources, bankruptcy entries, the solvent households and, in the last year,
the bequest.
"""
function year(m::Model, t::Integer, s, ch, e)
    F = eltype(s.Y)
    retired = t >= m.t_ret
    net_inc = F(1 - m.tau_inc)
    kappa_t = F(m.kappa[t])

    # Housing cost as a share of H: the annuity on the purchase price q H,
    # maintenance on the purchase price or the current value.
    # Without a house (H = 0) or a pot (no contribution at any age, so A = 0)
    # the terms they would add are zero and are left out, which changes no
    # number and saves work.
    hous = has_housing(m)
    dc = has_dc(m)
    if hous && m.is_owner
        mr = F(m.m_rate[t])
        m_q = m.annuity ? mr .* s.q : mr
        th_q = m.maint_on_purchase ? F(m.theta) .* s.q : F(m.theta)
        hcr = th_q .+ m_q
    else
        hcr = F(m.alpha)
    end

    ann_pay = nothing
    if retired
        if dc
            ann_pay = s.A ./ F(m.ann_price[t])
            LW = hous ? s.X .+ net_inc .* s.Y .+ ann_pay .* net_inc .- hcr .* s.H :
                        s.X .+ net_inc .* s.Y .+ ann_pay .* net_inc
        else
            LW = hous ? s.X .+ net_inc .* s.Y .- hcr .* s.H : s.X .+ net_inc .* s.Y
        end
    else
        contrib_factor = (1 - kappa_t) * net_inc
        LW = hous ? s.X .+ contrib_factor .* s.Y .- hcr .* s.H : s.X .+ contrib_factor .* s.Y
    end

    # The floor. With the absorbing floor a household bankrupt earlier has no
    # resources of its own, and one short of the floor now goes bankrupt.
    F_t = F(m.phi_path[t]) .* s.Y
    if m.floor_absorbing
        LW = ifelse.(s.gone, zero(F), LW)
        enter = .!s.gone .& (LW .< F_t)
        gone = s.gone .| enter
        Cbar = ifelse.(enter, F_t, s.Cbar)
    else
        enter = s.gone
        gone = s.gone
        Cbar = s.Cbar
    end
    look = .!gone

    if haskey(ch, :s)
        C = F_t .+ ch.s .* max.(LW .- F_t, zero(F))
    else
        C = ch.c .* max.(LW, zero(F))
    end
    C = ifelse.(LW .< F_t, F_t, C)
    pi_ = ch.pi
    if m.floor_absorbing
        C = ifelse.(look, max.(C, F_t), Cbar)
        pi_ = ifelse.(look, pi_, zero(F))
    end

    # With a bequest motive the solver values, for a death after this year,
    # the liquid wealth and the house (net of the sale cost) after a year of
    # returns, bounded below by 1e-12 of this year's wealth W (FLOOR_EPS in
    # solver.bellman_step_lna). The last year is no exception: the bequest
    # earns one more year of returns, from the extra year of draws.
    bequest = m.chi > 0
    h_beq_s = (m.is_owner && hous) ? F(1 - m.sell_cost) : zero(F)
    W = bequest ? s.X .+ s.A .+ s.H .+ s.Y : nothing

    if t == m.T && !bequest
        h_beq = m.is_owner ? F(1 - m.sell_cost) : zero(F)
        beq = max.(LW .- C, zero(F)) .+ h_beq .* s.H
        beq = ifelse.(look, beq, zero(F))
        return (; state=nothing, C, LW, enter, look, beq, pi=pi_, beq_next=nothing, W)
    end

    X_post = max.(LW .- C, zero(F))
    R_S = exp.(F(m.mu_S) .+ F(m.sigma_S) .* e.eps_S[t])
    R_H = exp.(F(m.mu_H) .+ F(m.sigma_H) .* e.eps_H[t])
    gain = m.cg_loss_offset ? R_S .- one(F) : max.(R_S .- one(F), zero(F))
    R_S_at = (R_S .- F(m.tau_cg_stock) .* gain) .* F(1 - m.tau_wealth)
    Rf_at = F((1 + m.r * (1 - m.tau_cg_bond)) * (1 - m.tau_wealth))
    R_X = (one(F) .- pi_) .* Rf_at .+ pi_ .* R_S_at

    if t == m.T
        # The panel's bequest is that of simulate.paths_lna, before returns.
        h_beq = m.is_owner ? F(1 - m.sell_cost) : zero(F)
        beq = ifelse.(look, max.(LW .- C, zero(F)) .+ h_beq .* s.H, zero(F))
        beq_next = R_X .* X_post .+ h_beq_s .* (R_H .* s.H)
        return (; state=nothing, C, LW, enter, look, beq, pi=pi_, beq_next, W)
    end

    if dc
        if m.dc_choice
            tS = clamp.(ch.tS, zero(F), one(F))
            tR = clamp.(ch.tR, zero(F), one(F))
            tot = tS .+ tR
            over = tot .> one(F)
            tS = ifelse.(over, tS ./ tot, tS)
            tR = ifelse.(over, tR ./ tot, tR)
            tS = ifelse.(look, tS, F(m.tau_e[t]))
            tR = ifelse.(look, tR, F(m.reit_e[t]))
        else
            tS = F(m.tau_e[t])
            tR = F(m.reit_e[t])
        end
        R_REIT = m.reit_on ? exp.(F(m.mu_REIT) .+ F(m.sigma_REIT) .* e.eps_R[t]) : one(F)
        R_A = ((one(F) .- tS .- tR) .* F(m.Rf) .+ tS .* R_S .+ tR .* R_REIT) ./ F(max(m.p_surv[t], 1e-8))
        A_pre = retired ? s.A .- ann_pay : s.A .+ kappa_t .* s.Y
        A1 = R_A .* A_pre
    else
        A1 = s.A
    end
    X1 = R_X .* X_post
    H1 = hous ? R_H .* s.H : s.H
    q1 = s.q ./ R_H
    beq_next = bequest ? X1 .+ h_beq_s .* H1 : nothing
    if m.floor_absorbing
        X1 = ifelse.(look, X1, zero(F))
        A1 = ifelse.(look, A1, zero(F))
        H1 = ifelse.(look, H1, zero(F))
    end
    if t < m.t_ret - 1
        Y1 = s.Y .* exp.(F(m.mu_growth[t]) .+ F(m.sigma_l_log[t]) .* e.eps_Y[t])
    elseif t == m.t_ret - 1
        Y1 = F(m.replacement) .* s.Y
    else
        Y1 = s.Y
    end
    state = (; Y=Y1, X=X1, A=A1, H=H1, q=q1, gone, Cbar)
    return (; state, C, LW, enter, look, beq=nothing, pi=pi_, beq_next, W)
end

crra(c, omg) = c^omg / omg

"""
    year_utility(m, t, o, unit, guard)

Each household's utility this year, discounted to year t only by nothing
(the caller multiplies by the discount): u(C) for a solvent household; for one
going bankrupt this year u(F) D_beq(t), the value of the floor for the rest
of its life as the solver counts it; zero for one bankrupt before. Utility is
of consumption in units of `unit`. With a bequest motive a solvent household
also gets beta (1 - p_t) chi u(bequest after a year of returns), the value of
dying after this year in the solver (p_T = 0, so the last year counts it
fully). `guard` bounds consumption and the bequest below (a share of `unit`)
so that Float32 cannot overflow; it is 0 in evaluation.
"""
function year_utility(m::Model, t::Integer, o, unit, guard)
    F = eltype(o.C)
    omg = F(1 - m.gamma)
    c = max.(o.C ./ F(unit), F(guard))
    u = crra.(c, omg)
    if m.floor_absorbing
        u = ifelse.(o.enter, u .* F(m.D_beq[t]), ifelse.(o.look, u, zero(F)))
    end
    if m.chi > 0
        b = max.(o.beq_next, F(1e-12) .* o.W) ./ F(unit)
        ub = F(m.beta * (1 - m.p_surv[t]) * m.chi) .* crra.(max.(b, F(guard)), omg)
        u = u .+ ifelse.(o.look, ub, zero(F))
    end
    return u
end

"""
    lifetime(m, s0, choose, e; unit=1, guard=0)

Each household's realised lifetime utility from state `s0`, with `choose(t,
s)` giving the choices: the sum over years of beta^(t-1) S_t times
`year_utility`, with S_t the probability of being alive at t. A 1 x N array.
Differentiable by Zygote: nothing is written into an array.
"""
function lifetime(m::Model, s0, choose, e; unit=1, guard=0)
    s = s0
    F = eltype(s.Y)
    U = zero(s.Y)
    disc = one(F)
    for t in 1:m.T
        o = year(m, t, s, choose(t, s), e)
        U = U .+ disc .* year_utility(m, t, o, unit, guard)
        disc = disc * F(m.beta * m.p_surv[t])
        s = o.state
    end
    return U
end

"""
    panel(m, s0, choose, e; unit=m.Y0)

As `lifetime`, keeping the paths: N x T matrices of Y, X, A, H, q, C, LW,
the liquid equity share applied (pi), the bankrupt households (`absorbed`, from the year of entry on), the bequest
and the lifetime utility U (in units of `unit`). For evaluation, not training.
"""
function panel(m::Model, s0, choose, e; unit=m.Y0)
    N = length(s0.Y)
    T = m.T
    P = Dict{String,Any}(k => zeros(N, T) for k in ("Y", "X", "A", "H", "q", "C", "LW", "pi", "absorbed"))
    s = s0
    U = zeros(1, N)
    disc = 1.0
    beq = zeros(1, N)
    for t in 1:T
        for (k, v) in (("Y", s.Y), ("X", s.X), ("A", s.A), ("H", s.H), ("q", s.q))
            P[k][:, t] = vec(Array(v))
        end
        o = year(m, t, s, choose(t, s), e)
        P["C"][:, t] = vec(Array(o.C))
        P["LW"][:, t] = vec(Array(o.LW))
        P["pi"][:, t] = vec(Array(o.pi .+ zero(o.C)))
        P["absorbed"][:, t] = vec(Array(.!o.look))
        U = U .+ disc .* Array(year_utility(m, t, o, unit, 0))
        disc *= m.beta * m.p_surv[t]
        if t == T
            beq = Array(o.beq)
        end
        s = o.state
    end
    P["bequest"] = vec(beq)
    P["U"] = vec(U)
    return P
end

"""
    certainty_equivalent(m, U)

The constant consumption, in units of the utility's unit (entry income),
worth the mean of `U` over the households, with its Monte Carlo standard
error by the delta method: c = ((1-gamma) mean(U) / D_abs(1))^(1/(1-gamma)),
as `ce_entry` in model.checks.
"""
function certainty_equivalent(m::Model, U::AbstractArray)
    g = m.gamma
    EU = mean(U)
    se_EU = std(vec(U)) / sqrt(length(U))
    ce = ((1 - g) * EU / m.D_abs[1])^(1 / (1 - g))
    se = ce * se_EU / abs((1 - g) * EU)
    return (; ce, se, EU)
end

"The share of total utility that comes from the worst `q` share of paths."
function worst_share(U::AbstractArray; q=0.01)
    u = sort(vec(U))
    k = max(1, round(Int, q * length(u)))
    return sum(u[1:k]) / sum(u)
end
