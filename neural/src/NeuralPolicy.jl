"""
    NeuralPolicy

Policies of the life-cycle model from a neural network trained on simulated
lifetime utility. The plan is docs/prompts/neural_policy.md and the code is
described in neural/README.md. MATLAB stays the model's definition: every
number comes from its exports.
"""
module NeuralPolicy

using Flux, Zygote, Optimisers, Statistics, Random, MAT
using CUDA

include("toy.jl")
include("model.jl")
include("policy.jl")

export toy_policy, toy_shocks, toy_lifetime_utility, toy_ce, to_gpu, TOY_YEARS
export Model, has_housing, has_dc, check_supported, draws_from_matlab, draw, entry, year, lifetime, panel
export certainty_equivalent, worst_share
export Spec, n_inputs, n_outputs, features, policy_net, choices, replay_choices, train, evaluate

end
