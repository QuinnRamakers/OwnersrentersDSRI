function tau_e = tau_effective(p)
%Helper code that is used for free dc choice, where decumulation is set

assert(isfield(p, 'tau_S') && ~isempty(p.tau_S), 'tau_effective:no_tau_S', ...
    'p.tau_S is required.');
T     = p.T;
t_ret = p.t_ret;
tau_e = p.tau_S(:);
assert(numel(tau_e) >= T - 1, 'tau_effective:tau_S_length', ...
    'p.tau_S must have at least T-1 = %d entries (got %d).', T - 1, numel(tau_e));
tau_e = tau_e(1 : T - 1);

if ~isfield(p, 'tau_decum') || isempty(p.tau_decum)
    return                      
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
