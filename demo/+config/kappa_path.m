function kap = kappa_path(p)
% legacy code for old constant contribution rates to convert into vectors

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
