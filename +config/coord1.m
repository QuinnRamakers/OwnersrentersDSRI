function c = coord1(p, t, ann_price)
%COORD1  Forward and inverse maps for the cube's FIRST coordinate.
%
%   c = config.coord1(p, t, ann_price)
%
%   The cube's second and third coordinates describe the composition of wealth
%   and are unaffected. The first one carries the income scale, and p.coord1
%   chooses how:
%
%     'yw'   (default)  v1 = lambda = Y/W. Bit-identical to every solve before
%                       this option existed.
%     'yann'            v1 = (Y + net annuity payout)/W = lambda + af_t * s_A.
%                       The numerator is the household's whole income flow
%                       rather than the wage alone, so it does not step down
%                       when the wage stops.
%     'hk'              v1 = HK/(HK + financial wealth), HK = phi_t * Y.
%                       A stock rather than a flow, so the retirement handover
%                       passes through it almost untouched.
%
%   Each is a monotone reparametrisation of lambda given (u2, u3) and the age,
%   with a closed-form inverse, so no state is added and nothing about the model
%   changes. What changes is where a fixed tensor grid puts its nodes.
%
%   c.fwd(lam, u2, u3)  lambda and the two composition coordinates  ->  v1
%   c.inv(v1, u2, u3)   v1   and the two composition coordinates  ->  lambda
%
%   Both take the same three arguments, both are elementwise, and both clamp to
%   [0, 1]. They are exact inverses of each other at fixed (u2, u3). The DC
%   balance that 'yann' needs is recoverable from the coordinates,
%   s_A = u2 (1 - lambda) u3, which is why no extra argument is required and why
%   the solver's call sites do not change.

mode = 'yw';
if isfield(p, 'coord1') && ~isempty(p.coord1)
    mode = validatestring(p.coord1, {'yw', 'yann', 'hk', 'yf'}, 'config.coord1', 'p.coord1');
end

% Net annuity payout per unit of DC balance, zero while working.
af = 0;
if t >= p.t_ret
    tau_inc = 0; if isfield(p, 'tau_inc'), tau_inc = p.tau_inc; end
    af = (1 - tau_inc) / ann_price(min(t, numel(ann_price)));
end

ph = 1;
if strcmp(mode, 'hk')
    if isfield(p, 'hk_phi') && numel(p.hk_phi) >= p.T
        phi = p.hk_phi;                 % cached by the caller
    else
        phi = config.hk_factor(p);
    end
    ph = phi(min(t, numel(phi)));
end

% range_hi is the top of the axis the chart lives on. Three of the four are
% shares and sit in [0, 1]; 'yf' is a ratio and is unbounded above, so the grid
% builder must not clamp it to 1.
c = struct('mode', mode, 'af', af, 'phi', ph, 'range_hi', 1);
cl = @(x) min(max(x, 0), 1);

switch mode
    case 'yf'
        % Labour income over non-labour wealth, x = Y/F with F = X + A + H.
        % Exactly the same coordinate as 'yw' under x = lam/(1-lam); solving in
        % it can only differ through where the nodes fall. XCAP keeps lam -> 1
        % finite; the interpolant extrapolates 'nearest' above the top node
        % anyway, so the cap only has to be past the end of the grid.
        XCAP  = 1e6;
        c.range_hi = inf;
        c.fwd = @(lam, u2, u3) min(max(lam, 0) ./ max(1 - lam, 1/XCAP), XCAP);
        c.inv = @(v1,  u2, u3) cl(max(v1, 0) ./ (1 + max(v1, 0)));
    case 'yw'
        c.fwd = @(lam, u2, u3) lam;
        c.inv = @(v1,  u2, u3) v1;
    case 'yann'
        % s_A = u2 (1-lam) u3, so with g = af*u2*u3,
        %   v1 = lam + g(1-lam) = lam(1-g) + g.
        c.fwd = @(lam, u2, u3) cl(lam + (af * (u2 .* u3)) .* (1 - lam));
        c.inv = @(v1,  u2, u3) cl((v1 - af * (u2 .* u3)) ./ max(1 - af * (u2 .* u3), 1e-12));
    case 'hk'
        % Human capital counted INCLUSIVE of the current payment, HK = (1+ph)*Y,
        % against financial wealth W - Y:
        %   v1 = P*lam / (P*lam + 1 - lam),   P = 1 + ph.
        %
        % The current payment has to be in it. config.hk_factor counts only what
        % is still to come, and that goes to zero at the end of life, which makes
        % the map constant in lambda and destroys the income state exactly where
        % the retired population lives. Including it gives P >= 1 always, so the
        % chart stays invertible, and at P = 1 it degenerates gracefully to 'yw'
        % rather than to a point.
        P     = 1 + ph;
        c.fwd = @(lam, u2, u3) cl(P * lam ./ max(P * lam + 1 - lam, 1e-12));
        c.inv = @(v1,  u2, u3) cl(v1 ./ max(P * (1 - v1) + v1, 1e-12));
end
end
