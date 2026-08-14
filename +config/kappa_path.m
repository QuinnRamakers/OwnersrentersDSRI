function kap = kappa_path(p)
%KAPPA_PATH  1 x T row vector of effective DC contribution rates by period.
%
%   From 2026-07 the contribution rate is franchise-based and therefore an
%   age profile (config.params builds p.kappa as a T x 1 vector). Legacy
%   p-structs -- and the p.kappa = 0 override in run_nodc -- carry a SCALAR
%   kappa; those are expanded here, with zeros from retirement on, matching
%   the solver/simulator convention that contributions stop at t_ret.
%
%   Returned as a ROW vector so it broadcasts against N x T simulation
%   matrices via implicit expansion.

k = p.kappa(:).';

if isscalar(k)
    kap = repmat(k, 1, p.T);
else
    if numel(k) < p.T
        kap = [k, zeros(1, p.T - numel(k))];
    else
        kap = k(1:p.T);
    end
end

if isfield(p, 't_ret') && p.t_ret <= p.T
    kap(p.t_ret : end) = 0;
end

end
