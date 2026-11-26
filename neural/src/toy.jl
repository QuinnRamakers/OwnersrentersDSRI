# A stand-in for the model's year, for part 0 of docs/prompts/neural_policy.md:
# timings, gradient checks and a first training run. One household with
# permanent income shocks, a risk-free and a risky asset, CRRA utility and a
# 76-year life. It has the shape of the real problem (a network applied every
# year, utility summed along each path) but its numbers mean nothing.

const TOY_YEARS = 76

"""
    toy_policy(F=Float32; hidden=64, rng=Random.default_rng())

A network from (age, wealth over income) to (consumption share of cash on
hand, risky share), both in (0, 1).
"""
function toy_policy(::Type{F}=Float32; hidden::Integer=64,
                    rng::AbstractRNG=Random.default_rng()) where {F<:AbstractFloat}
    init = Flux.glorot_uniform(rng)
    m = Chain(Dense(2 => hidden, tanh; init),
              Dense(hidden => hidden, tanh; init),
              Dense(hidden => 2, sigmoid; init))
    return F === Float64 ? f64(m) : f32(m)
end

"""
    toy_shocks(F, N; years=TOY_YEARS, seed=1)

Standard-normal draws for income growth and the risky return, one per
household and year: two vectors of `years` matrices of size 1 x N.
"""
function toy_shocks(::Type{F}, N::Integer; years::Integer=TOY_YEARS,
                    seed::Integer=1) where {F<:AbstractFloat}
    rng = Xoshiro(seed)
    eps_y = [randn(rng, F, 1, N) for _ in 1:years]
    eps_r = [randn(rng, F, 1, N) for _ in 1:years]
    return (; eps_y, eps_r)
end

"Move every numeric array in `x` (a network or a set of draws) to the GPU, in Float32."
to_gpu(x) = Flux.fmap(y -> y isa AbstractArray{<:Number} ? CUDA.cu(y) : y, x)

"""
    toy_lifetime_utility(model, shocks; gamma=5, beta=0.96, ...)

Mean over households of discounted lifetime utility when the network chooses
every year. Wealth is in units of current income, so the income level enters
only through the factor P^(1-gamma) on each year's utility. No array is
written into, so Zygote can differentiate it.
"""
function toy_lifetime_utility(model, shocks; gamma=5, beta=0.96, rf=0.0115,
                              mu=0.0456, sigma=0.216, g=0.01, sigma_y=0.1, w0=0.08)
    e1 = first(shocks.eps_y)
    F = eltype(e1)
    years = length(shocks.eps_y)
    omg = F(1 - gamma)
    Rf = F(1 + rf)
    mu_log = F(log(1 + rf + mu) - sigma^2 / 2)
    x = zero(e1) .+ F(w0)            # liquid wealth over income, start of year
    logP = zero(e1)                  # log income
    total = zero(e1)
    disc = one(F)
    for t in 1:years
        age = F((t - 1) / (years - 1))
        out = model(vcat(zero(x) .+ age, x))
        cshare = F(0.01) .+ F(0.99) .* out[1:1, :]
        share = out[2:2, :]
        m = x .+ one(F)              # cash on hand: wealth plus this year's income
        c = cshare .* m
        total = total .+ disc .* exp.(omg .* logP) .* c .^ omg ./ omg
        R = Rf .+ share .* (exp.(mu_log .+ F(sigma) .* shocks.eps_r[t]) .- Rf)
        G = exp.(F(g) .+ F(sigma_y) .* shocks.eps_y[t])
        x = (m .- c) .* R ./ G
        logP = logP .+ log.(G)
        disc = disc * F(beta)
    end
    return mean(total)
end

"""
    toy_ce(EU; gamma=5, beta=0.96, years=TOY_YEARS)

The constant consumption worth `EU` over the toy's life, in units of entry
income.
"""
function toy_ce(EU; gamma=5, beta=0.96, years::Integer=TOY_YEARS)
    D = sum(beta^(t - 1) for t in 1:years)
    return ((1 - gamma) * EU / D)^(1 / (1 - gamma))
end
