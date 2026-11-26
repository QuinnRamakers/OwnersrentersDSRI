# Part 0 of docs/prompts/neural_policy.md: the time of one training step of the
# toy 76-year problem (toy.jl), on the CPU and the GPU, by batch size.
# Run from the repository root:
#   julia --project=neural neural/scripts/part0_timing.jl
using NeuralPolicy, Flux, CUDA, Statistics, Printf, LinearAlgebra, Random

function train_step!(model, opt, s)
    l, g = Flux.withgradient(m -> -toy_lifetime_utility(m, s), model)
    Flux.update!(opt, model, g[1])
    return l
end

# Median milliseconds of one step (gradient through 76 years plus the Adam
# update), after two steps that compile and warm up.
function step_ms(model, s; reps=5, on_gpu=false)
    opt = Flux.setup(Adam(1f-3), model)
    train_step!(model, opt, s)
    train_step!(model, opt, s)
    on_gpu && CUDA.synchronize()
    ts = Float64[]
    for _ in 1:reps
        t0 = time_ns()
        train_step!(model, opt, s)
        on_gpu && CUDA.synchronize()
        push!(ts, (time_ns() - t0) / 1e6)
    end
    return median(ts)
end

gpu_ok = CUDA.functional()
println("Julia ", VERSION, ", ", Threads.nthreads(), " Julia thread(s), ",
        BLAS.get_num_threads(), " BLAS threads, ", Sys.CPU_THREADS, " logical cores")
gpu_ok && println("GPU: ", CUDA.name(CUDA.device()), ", CUDA runtime ", CUDA.runtime_version())
println("Network: 2 inputs, two hidden layers of 64 (tanh), 2 sigmoid outputs; ",
        TOY_YEARS, " years; Float32")
println()
@printf("%10s %14s %14s %10s %22s\n", "households", "CPU ms/step", "GPU ms/step",
        "CPU/GPU", "GPU min per 10k steps")
for N in (1_024, 4_096, 16_384)
    s = toy_shocks(Float32, N; seed=1)
    m = toy_policy(Float32; hidden=64, rng=Xoshiro(2))
    cpu = step_ms(m, s)
    if gpu_ok
        gpu_t = step_ms(to_gpu(toy_policy(Float32; hidden=64, rng=Xoshiro(2))), to_gpu(s); on_gpu=true)
        @printf("%10d %14.1f %14.1f %10.1f %22.1f\n", N, cpu, gpu_t, cpu / gpu_t, gpu_t * 1e4 / 6e4)
    else
        @printf("%10d %14.1f %14s %10s %22s\n", N, cpu, "-", "-", "-")
    end
end
