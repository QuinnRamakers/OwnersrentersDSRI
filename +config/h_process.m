function [mu, sigma] = h_process(p)
%H_PROCESS  Log drift and vol of the H state's gross growth factor, by tenure.
%
%   [mu, sigma] = config.h_process(p)
%
%   The H state means different things in the two scenarios, so its growth
%   factor is a different process in each.
%
%   Owner:  H is the house. H_{t+1}/H_t is the house-price return, and H also
%           carries resale value into the bequest. Uses (mu_H, sigma_H).
%   Renter: H is a rent index. It has no resale or bequest value there
%           (h_beq_fac = 0 in solver.bellman_step), and its only role is to set
%           the rent alpha*H_t, so H_{t+1}/H_t is the rent increase. Uses
%           (mu_R, sigma_R).
%
%   Both are log-space parameters of a lognormal growth factor, i.e.
%   H_{t+1} = H_t * exp(mu + sigma*z) with z standard normal, so log H is a
%   random walk with drift under either tenure. config.params derives them
%   from the level-space calibration inputs mu_*_level / sigma_*_level.
%
%   A p-struct with no rent fields falls back to the housing pair. Every solve
%   predating the rent/house split assumed exactly that, so old p-structs
%   re-simulate unchanged.

is_owner = isfield(p, 'is_owner') && p.is_owner;

if ~is_owner && isfield(p, 'mu_R') && isfield(p, 'sigma_R')
    mu    = p.mu_R;
    sigma = p.sigma_R;
else
    mu    = p.mu_H;
    sigma = p.sigma_H;
end

end
