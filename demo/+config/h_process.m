function [mu, sigma] = h_process(p)
%Code to set  the owner and renter housing processes with seperate
%parameters

is_owner = isfield(p, 'is_owner') && p.is_owner;

if ~is_owner && isfield(p, 'mu_R') && isfield(p, 'sigma_R')
    mu    = p.mu_R;
    sigma = p.sigma_R;
else
    mu    = p.mu_H;
    sigma = p.sigma_H;
end

end
