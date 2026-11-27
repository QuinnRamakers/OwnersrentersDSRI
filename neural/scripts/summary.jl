# A markdown table of trained networks against the grid policy, from the
# results files of train_rung.jl. Run from the repository root:
#   julia --project=neural neural/scripts/summary.jl step1cpu_age step1cpu_ret ...
# (the tags; with none, every results file in neural/data).
using MAT, Printf

const DATA = joinpath(@__DIR__, "..", "data")
tags = isempty(ARGS) ? [replace(f, r"^results_|\.mat$" => "") for f in readdir(DATA)
                        if startswith(f, "results_") && endswith(f, ".mat")] : ARGS

println("| tag | variant | test set | ce net (s.e.) | ce grid (s.e.) | net - grid (s.e.) | at floor, net / grid | worst 1% share, net / grid | last objective | steps | households | lr | train min |")
println("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
for tag in tags
    file = joinpath(DATA, "results_$tag.mat")
    isfile(file) || continue
    r = matread(file)
    for k in sort(collect(keys(r)))
        v = r[k]
        if startswith(k, "gap")
            @printf("| %s | %s | indicator 0 against 1 on the same model | largest gap in C %.4f, in pi %.4f | | | | | | | | | |\n",
                    tag, v["variant"], v["dC"], v["dpi"])
            continue
        end
        startswith(k, "run") || continue
        fl = haskey(v, "floored_net") ? @sprintf("%.5f / %.5f", v["floored_net"], v["floored_grid"]) : "-"
        @printf("| %s | %s | %s | %.4g (%.2g) | %.4g (%.2g) | %.4g (%.2g) | %s | %.3f / %.3f | %.4g | %d | %d | %.0e | %.0f |\n",
                tag, v["variant"], v["test_set"], v["ce_net"], v["se_net"], v["ce_grid"], v["se_grid"],
                v["diff"], v["se_diff"], fl, v["worst1_net"], v["worst1_grid"], v["curve_value"][end],
                v["steps"], v["N"], v["lr"], v["train_sec"] / 60)
    end
end
