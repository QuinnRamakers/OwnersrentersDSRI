# Run from the repository root: julia --project=neural -e "using Pkg; Pkg.test()"
using NeuralPolicy, Flux, Zygote, Statistics, Random, CUDA, MAT, Test

const DATA = joinpath(@__DIR__, "..", "data")

relnorm(a, b) = sqrt(sum(abs2, a .- b)) / sqrt(sum(abs2, b))

# The gradient of a Chain of Dense layers, flattened in a fixed order.
function flat_grad(g)
    parts = Vector{Float64}[]
    for l in g.layers
        push!(parts, vec(Float64.(Array(l.weight))), vec(Float64.(Array(l.bias))))
    end
    return reduce(vcat, parts)
end

function train_toy(seed; steps=20, N=256, years=20, hidden=16)
    m = toy_policy(Float32; hidden, rng=Xoshiro(seed))
    opt = Flux.setup(Adam(1e-2), m)
    for k in 1:steps
        s = toy_shocks(Float32, N; years, seed=seed * 10_000 + k)
        _, g = Flux.withgradient(mm -> -toy_lifetime_utility(mm, s), m)
        Flux.update!(opt, m, g[1])
    end
    return m
end

@testset "NeuralPolicy" begin
    @testset "toy: Zygote's gradient against central finite differences (Float64)" begin
        m = toy_policy(Float64; hidden=8, rng=Xoshiro(1))
        s = toy_shocks(Float64, 64; years=10, seed=2)
        theta, re = Flux.destructure(m)
        f(v) = toy_lifetime_utility(re(v), s)
        g = Zygote.gradient(f, theta)[1]
        gfd = similar(theta)
        for i in eachindex(theta)
            h = 1e-6 * max(1.0, abs(theta[i]))
            e = zero(theta)
            e[i] = h
            gfd[i] = (f(theta .+ e) - f(theta .- e)) / (2h)
        end
        err = relnorm(g, gfd)
        @info "gradient check" n_params = length(theta) relative_error = err
        @test err < 1e-6
    end

    @testset "toy: outputs inside (0, 1) far outside the training states" begin
        m = toy_policy(Float32; rng=Xoshiro(3))
        x = 100f0 .* randn(Xoshiro(4), Float32, 2, 10_000)
        y = m(x)
        @test all(0 .<= y .<= 1)
    end

    @testset "toy: training raises lifetime utility on a fixed test set (CPU)" begin
        test = toy_shocks(Float32, 2_000; years=20, seed=99)
        m0 = toy_policy(Float32; hidden=16, rng=Xoshiro(5))
        m1 = train_toy(5; steps=200)
        u0 = toy_lifetime_utility(m0, test)
        u1 = toy_lifetime_utility(m1, test)
        @info "training on the CPU" ce_before = toy_ce(u0; years=20) ce_after = toy_ce(u1; years=20)
        @test u1 > u0
    end

    @testset "toy: the same seed gives the same training run (CPU)" begin
        a, _ = Flux.destructure(train_toy(7))
        b, _ = Flux.destructure(train_toy(7))
        @test a == b
    end

    replays = isdir(DATA) ? filter(f -> startswith(f, "replay_") && endswith(f, ".mat"), readdir(DATA)) : String[]
    if isempty(replays)
        @warn "No replay panels in neural/data: run neural.make_replays in MATLAB. The replay tests are skipped."
    end
    # Default as a choice (step 24): the quick-grid test sets of neural.make_testsets.
    replays_24 = isdir(DATA) ? filter(f -> startswith(f, "testset_24_") && endswith(f, "_quick.mat"), readdir(DATA)) : String[]
    isempty(replays_24) && @warn "No step-24 test sets in neural/data: the replay of default as a choice is skipped."

    @testset "replay: the Julia year reproduces simulate.paths_lna" begin
        for f in [replays; replays_24]
            d = matread(joinpath(DATA, f))
            m = Model(d["model"])
            P = d["panel"]
            e = draws_from_matlab(d["draws"], m)
            N = size(P["C"], 1)
            J = panel(m, entry(m, zeros(1, N); unit=m.Y0), replay_choices(P, m.T), e; unit=m.Y0)
            # The gap relative to the larger of the value and entry income. Where
            # liquid wealth is a few euros, LW - C cancels two numbers of the
            # order of income, and MATLAB's and Julia's last-digit rounding
            # (1e-16 of income) is up to 1e-11 of the remainder.
            worst = 0.0
            for k in ("C", "X", "A", "H", "Y", "LW", "q")
                scale = k == "q" ? 1.0 : m.Y0
                gap = maximum(abs.(J[k] .- P[k]) ./ max.(abs.(P[k]), scale))
                worst = max(worst, gap)
                @test gap < 1e-12
            end
            @test J["absorbed"] == Float64.(P["absorbed"])
            @test all(isfinite, J["U"])
            gap_beq = maximum(abs.(J["bequest"] .- vec(P["bequest"])) ./ max.(abs.(vec(P["bequest"])), m.Y0))
            @test gap_beq < 1e-12
            @info "replay $f" N largest_gap = max(worst, gap_beq) bankrupt_share = mean(J["absorbed"][:, end])
        end
    end

    if !isempty(replays)
        d1 = matread(joinpath(DATA, replays[1]))
        m1 = Model(d1["model"])

        # The gradient through the model year, and through the bequest term
        # where a panel with a bequest motive exists.
        grad_files = [replays[1]; filter(f -> occursin("chi", f), replays)]
        @testset "model: Zygote's gradient through the model year against finite differences (Float64), $gf" for gf in grad_files
            mg = Model(matread(joinpath(DATA, gf))["model"])
            spec = Spec(retire=true)
            net = f64(policy_net(spec; hidden=6, rng=Xoshiro(11)))
            e = draw(mg, 32, Xoshiro(12); F=Float64)
            s0 = entry(mg, zeros(1, 32); unit=1)
            theta, re = Flux.destructure(net)
            f(v) = mean(lifetime(mg, s0, choices(re(v), mg, spec), e; unit=1))
            g = Zygote.gradient(f, theta)[1]
            gfd = similar(theta)
            for i in eachindex(theta)
                h = 1e-6 * max(1.0, abs(theta[i]))
                ev = zero(theta)
                ev[i] = h
                gfd[i] = (f(theta .+ ev) - f(theta .- ev)) / (2h)
            end
            err = relnorm(g, gfd)
            @info "gradient check through the model year" file = gf chi = mg.chi n_params = length(theta) relative_error = err
            @test err < 1e-6
        end

        # Default as a choice: step 24 is step 23 with the switch on.
        f23 = joinpath(DATA, "replay_23_owner.mat")
        if isfile(f23)
            kw = Dict{Symbol,Any}(k => getfield(Model(matread(f23)["model"]), k) for k in fieldnames(Model))
            kw[:default_choice] = true
            m24 = Model(; kw...)

            @testset "model: Zygote's gradient with default as a choice against finite differences (Float64)" begin
                spec = Spec(retire=true, default=true)
                # A default output near one half, so that both branches carry weight.
                net = f64(policy_net(spec; hidden=6, rng=Xoshiro(21), d_init=0.3))
                e = draw(m24, 32, Xoshiro(22); F=Float64)
                s0 = entry(m24, zeros(1, 32); unit=1)
                theta, re = Flux.destructure(net)
                f(v) = mean(lifetime(m24, s0, choices(re(v), m24, spec), e; unit=1))
                g = Zygote.gradient(f, theta)[1]
                gfd = similar(theta)
                for i in eachindex(theta)
                    h = 1e-6 * max(1.0, abs(theta[i]))
                    ev = zero(theta)
                    ev[i] = h
                    gfd[i] = (f(theta .+ ev) - f(theta .- ev)) / (2h)
                end
                err = relnorm(g, gfd)
                @info "gradient check with default as a choice" n_params = length(theta) relative_error = err
                @test err < 1e-6
            end

            @testset "model: the weighted utility is the expectation over random default decisions" begin
                # Each household defaults each year with probability 0.2 (or is
                # forced): the weighted lifetime utility against the mean over
                # K hard draws of the decisions, on the same income and return paths.
                spec = Spec(retire=true)
                base = choices(f64(policy_net(spec; rng=Xoshiro(23))), m24, spec)
                N, K = 20, 4000
                e = draw(m24, N, Xoshiro(24); F=Float64)
                soft = (t, s) -> merge(base(t, s), (; d=fill(0.2, 1, length(s.Y))))
                U_soft = vec(lifetime(m24, entry(m24, zeros(1, N); unit=1), soft, e; unit=1))
                eK = map(v -> [repeat(x, 1, K) for x in v], e)
                rng = Xoshiro(25)
                hard = (t, s) -> merge(base(t, s), (; d=Float64.(rand(rng, 1, length(s.Y)) .< 0.2)))
                U_hard = reshape(vec(lifetime(m24, entry(m24, zeros(1, N * K); unit=1), hard, eK; unit=1)), N, K)
                mc = vec(mean(U_hard; dims=2))
                se = vec(std(U_hard; dims=2)) ./ sqrt(K)
                z = maximum(abs.(mc .- U_soft) ./ se)
                @info "weighted against random decisions" largest_z = z households = N draws = K
                @test z < 4.5
            end

            @testset "model: with floor_F a household that continues consumes at least F, and defaults when LW <= F" begin
                spec = Spec(retire=true, default=true, floor_F=true)
                ch = choices(f64(policy_net(spec; rng=Xoshiro(26), d_init=0.3)), m24, spec)
                e = draw(m24, 2000, Xoshiro(27); F=Float64)
                s = entry(m24, zeros(1, 2000); unit=1)
                n_forced = 0
                for t in 1:m24.T
                    o = year(m24, t, s, ch(t, s), e)
                    cont = vec(o.wc) .> 0
                    @test all(vec(o.C)[cont] .>= vec(o.F_t)[cont] .* (1 - 1e-12))
                    short = vec(o.LW) .<= vec(o.F_t)
                    @test all(vec(o.wc)[short] .== 0)
                    n_forced += sum(short .& (vec(s.w) .> 0))
                    t < m24.T && (s = o.state)
                end
                @info "floor_F" forced_household_years = n_forced
            end
        end

        # The bequest term against the solver: on the fine grid at step 12 the
        # grid policy's simulated value sits as far from its value function with
        # chi = 32 as without (0.63% and 0.65% on 27 November 2026).
        f0, f1 = joinpath(DATA, "testset_12_nohousing_fine.mat"), joinpath(DATA, "testset_12chi32_nohousing_fine.mat")
        if isfile(f0) && isfile(f1)
            @testset "model: the bequest utility measures what the solver values" begin
                gaps = map((f0, f1)) do f
                    d = matread(f)
                    m = Model(d["model"])
                    N = size(d["panel"]["C"], 1)
                    J = panel(m, entry(m, zeros(1, N); unit=m.Y0), replay_choices(d["panel"], m.T),
                              draws_from_matlab(d["draws"], m); unit=m.Y0)
                    certainty_equivalent(m, J["U"]).ce / d["value"]["ce_entry"] - 1
                end
                @info "simulated against value function, step 12 fine grid" without_bequest = gaps[1] with_bequest = gaps[2]
                @test abs(gaps[2] - gaps[1]) < 0.003
            end
        end

        @testset "model: doubling entry income leaves the choices and scales utility by 2^(1-gamma)" begin
            spec = Spec()
            net = f64(policy_net(spec; rng=Xoshiro(13)))
            e = draw(m1, 200, Xoshiro(14); F=Float64)
            P1 = panel(m1, entry(m1, zeros(1, 200); unit=1.0), choices(net, m1, spec), e; unit=1.0)
            P2 = panel(m1, entry(m1, zeros(1, 200); unit=2.0), choices(net, m1, spec), e; unit=1.0)
            @test maximum(abs.(P2["C"] ./ P1["C"] .- 2)) < 1e-12
            @test maximum(abs.(P2["pi"] .- P1["pi"])) < 1e-12
            @test maximum(abs.(P2["U"] ./ P1["U"] .- 2.0^(1 - m1.gamma))) < 1e-12
        end

        @testset "model: network outputs inside (0, 1) and consumption at or above the floor" begin
            spec = Spec(retire=true, tenure=true)
            net = policy_net(spec; rng=Xoshiro(15))
            x = 100f0 .* randn(Xoshiro(16), Float32, n_inputs(spec), 10_000)
            y = sigmoid.(net(x))
            @test all(0 .<= y .<= 1)
            e = draw(m1, 500, Xoshiro(17); F=Float64)
            P = panel(m1, entry(m1, zeros(1, 500); unit=1.0), choices(f64(policy_net(Spec(); rng=Xoshiro(18))), m1, Spec()), e; unit=1.0)
            floor_ = m1.phi_path' .* P["Y"]
            @test all(P["C"] .>= floor_ .* (1 - 1e-12))
        end
    end

    if CUDA.functional()
        @testset "toy: CPU and GPU agree (Float32)" begin
            m = toy_policy(Float32; hidden=64, rng=Xoshiro(8))
            s = toy_shocks(Float32, 1_024; seed=9)
            mg, sg = to_gpu(m), to_gpu(s)
            lc = toy_lifetime_utility(m, s)
            lg = toy_lifetime_utility(mg, sg)
            gc = Flux.gradient(mm -> toy_lifetime_utility(mm, s), m)[1]
            gg = Flux.gradient(mm -> toy_lifetime_utility(mm, sg), mg)[1]
            loss_err = abs(lg - lc) / abs(lc)
            grad_err = relnorm(flat_grad(gg), flat_grad(gc))
            @info "CPU against GPU" loss_err grad_err
            @test loss_err < 1e-5
            @test grad_err < 1e-4
        end
    else
        @warn "CUDA is not functional here: the GPU tests are skipped."
    end
end
