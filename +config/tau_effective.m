function tau_e = tau_effective(p)
%TAU_EFFECTIVE  The DC equity share the fund actually runs, all T-1 transitions.
%
%   tau_e = config.tau_effective(p)     % (T-1) x 1
%
%   Splices two regimes at retirement:
%
%     ACCUMULATION (t < t_ret)   p.tau_S(t), the glide. Under p.choose_tau_S
%       the solver optimises tau per state and this is only the seed and
%       fallback, but it is still what the glide arm uses.
%
%     DECUMULATION (t >= t_ret)  p.tau_decum if set, else p.tau_S(t).
%
%   Why the split. Free tau choice is accumulation-only, and that restriction
%   is what keeps the annuity price correct without a new state variable.
%   a(t) is read only for t >= t_ret and recurses backward from T, so a(t_ret)
%   depends solely on tau from t_ret onward; make that deterministic and
%   pension.annuity_price prices exactly the fund the household runs. The
%   alternatives are worse: letting retirees re-choose tau turns the draw rate
%   1/a(tau) into a decumulation-speed lever, and pinning it at conversion
%   means carrying the conversion tau as a fourth state variable.
%
%   p.tau_decum accepts:
%     absent / []            keep p.tau_S over retirement too. tau_S is 0
%                            across retirement, so this is an all-bond fund,
%                            and it reproduces pre-existing results exactly.
%     scalar                 constant equity share held through retirement.
%     vector, T-1 or T long  a full path; entries t_ret..T-1 are used.
%     vector, T-t_ret long   the retirement path on its own.
%
%   Anything set here is priced: pension.annuity_price reads this function,
%   so the annuity and the portfolio can never disagree.

assert(isfield(p, 'tau_S') && ~isempty(p.tau_S), 'tau_effective:no_tau_S', ...
    'p.tau_S is required.');
T     = p.T;
t_ret = p.t_ret;
tau_e = p.tau_S(:);
assert(numel(tau_e) >= T - 1, 'tau_effective:tau_S_length', ...
    'p.tau_S must have at least T-1 = %d entries (got %d).', T - 1, numel(tau_e));
tau_e = tau_e(1 : T - 1);

if ~isfield(p, 'tau_decum') || isempty(p.tau_decum)
    return                      % historical path, bit-identical
end

d    = p.tau_decum(:);
idx  = t_ret : T - 1;           % retirement transitions
n_rt = numel(idx);

if isscalar(d)
    tau_e(idx) = d;
elseif numel(d) == n_rt
    tau_e(idx) = d;
elseif numel(d) >= T - 1
    tau_e(idx) = d(idx);
else
    error('tau_effective:tau_decum_length', ...
        ['p.tau_decum must be a scalar, a %d-vector (the retirement ' ...
         'transitions t_ret..T-1), or a full path of at least T-1 = %d ' ...
         'entries (got %d).'], n_rt, T - 1, numel(d));
end

assert(all(tau_e >= 0 & tau_e <= 1), 'tau_effective:range', ...
    'effective tau must lie in [0, 1].');
end
