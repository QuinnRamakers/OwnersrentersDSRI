function tf = tenures_differ(p)
%TENURES_DIFFER  True if renters and owners need separate solves.
%
%   With housing they always do. Without it they differ only through the
%   tenure-specific income fields (config.income_process).

tf = p.h_mult > 0;
if ~tf && isfield(p, 'income_coef_rent')
    tf = ~isequal(p.income_coef, p.income_coef_rent) || ...
         ~isequal(p.sigma_l_log, p.sigma_l_log_rent);
end
end
