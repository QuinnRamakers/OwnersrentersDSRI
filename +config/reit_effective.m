function reit_e = reit_effective(p)
%REIT_EFFECTIVE  The DC REIT share the fund runs, all T-1 transitions.
%
%   reit_e = config.reit_effective(p)     % (T-1) x 1
%
%   Twin of config.tau_effective for the retirement-account REIT leg. The DC
%   fund holds three assets: a stock share tau_S (config.tau_effective), a REIT
%   share reit_e (this function), and the residual 1 - tau_S - reit_e in bonds.
%
%   p.tau_REIT accepts, exactly as p.tau_S / p.tau_decum do, so a constant share
%   today can grow into a full glide later without touching the solver,
%   simulator or annuity pricer that read this:
%     scalar                 constant REIT share at every age.
%     vector, T-1 or T long   a full path; the first T-1 entries are used.
%
%   p.reit_decum (optional) overrides the retirement transitions t_ret..T-1,
%   mirroring p.tau_decum. Anything set here is priced: pension.annuity_price
%   reads this function, so the annuity and the portfolio can never disagree.
%
%   Absent / empty p.tau_REIT means no REIT (all-zero share), which reproduces
%   the pre-REIT model; config.reit_active gates the fourth shock on the same
%   condition.

T     = p.T;
t_ret = p.t_ret;

if ~isfield(p, 'tau_REIT') || isempty(p.tau_REIT)
    reit_e = zeros(T - 1, 1);
    return
end

r = p.tau_REIT(:);
if isscalar(r)
    reit_e = repmat(r, T - 1, 1);
elseif numel(r) >= T - 1
    reit_e = r(1 : T - 1);
else
    error('reit_effective:tau_REIT_length', ...
        ['p.tau_REIT must be a scalar or a vector of at least T-1 = %d ' ...
         'entries (got %d).'], T - 1, numel(r));
end

if isfield(p, 'reit_decum') && ~isempty(p.reit_decum)
    d    = p.reit_decum(:);
    idx  = t_ret : T - 1;           % retirement transitions
    n_rt = numel(idx);
    if isscalar(d)
        reit_e(idx) = d;
    elseif numel(d) == n_rt
        reit_e(idx) = d;
    elseif numel(d) >= T - 1
        reit_e(idx) = d(idx);
    else
        error('reit_effective:reit_decum_length', ...
            ['p.reit_decum must be a scalar, a %d-vector (the retirement ' ...
             'transitions t_ret..T-1), or a full path of at least T-1 = %d ' ...
             'entries (got %d).'], n_rt, T - 1, numel(d));
    end
end

assert(all(reit_e >= 0 & reit_e <= 1), 'reit_effective:range', ...
    'effective REIT share must lie in [0, 1].');
end
