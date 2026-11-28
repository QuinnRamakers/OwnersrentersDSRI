function [R, info] = find_boundary(t, V_next, p, profile, shocks, ann_price, opts)
%FIND_BOUNDARY  The default boundary on each (u1, u3, q) line of period t's grid.
%
%   [R, info] = solver.find_boundary(t, V_next, p, profile, shocks, ann_price)
%
%   With default as a choice, on a line of fixed u1, u3 and q the household
%   continues at low u2 (much liquid wealth) and defaults near the edge of
%   continuing, u2_max (utility.u2_max), where its resources run out. The
%   boundary is where the value of continuing equals the default value,
%       z_cont(u2) = phi_t u1 D_t^(1/(1-gamma)),
%   in certainty-equivalent units per unit of W. z_cont at a state is the
%   Bellman problem of period t solved there (solver.bellman_step_lna in its
%   point mode, against V_next, the search and quadrature of a grid solve),
%   so the boundary depends on next year's value only and is found before t's
%   grid is solved. With p.u2_coord = 'boundary' the grid's second axis is
%   v = u2 / (R u2_max), and its node v = 1 sits on the boundary.
%
%   On each line the root is found in y = log s, s = LW/W - phi_floor u1 the
%   resources above the edge (utility.slack_terms), between u2 = 0 and
%   u2 = u2_max, by the Illinois rule (regula falsi with halving) on
%   f(y) = log z_cont - log z_def, which is close to linear in y near the
%   edge, where z_cont goes to zero with s. Each round is one point solve of
%   the lines not yet settled; a line is settled when its bracket is below
%   opts.tol in y (a relative error in resources) or opts.rounds is reached.
%
%   R is N_u1 x N_u3 x N_q, rho = s_b / z_def on each line: the resources
%   above the edge at the boundary over the default value's certainty
%   equivalent, the quantity utility.u2_scale_fn interpolates between lines
%   (see finish below for lines without a crossing). info.r holds the
%   boundary's u2 as a share of u2_max: 1 on a line that never defaults
%   before the edge (or where the edge lies past u2 = 1), opts.r_all on one
%   that defaults at u2 = 0 already. info counts those lines (n_none,
%   n_all), the rounds, the point solves and seconds.
%   Where q enters neither this year nor later, one q slice is searched and
%   copied, as the grid solve does.

arguments
    t (1,1) double
    V_next
    p struct
    profile struct
    shocks struct
    ann_price
    opts.tol (1,1) double = 1e-6
    opts.rounds (1,1) double = 40
    opts.r_all (1,1) double = 1e-3
end
t0 = tic;
choice = p.floor_absorbing && isfield(p, 'default_choice') && p.default_choice;
assert(choice, 'find_boundary:choice', 'the default boundary needs default as a choice.');
g = p.gamma;
g1 = utility.grid_at(p, t);
q_grid = p.q_grid(:); Nq = numel(q_grid); iq1 = find(q_grid == 1);
q_now = Nq > 1 && any(p.q_live(t:end));
if q_now, qs = q_grid; else, qs = 1; end
[L1, L3, LQ] = ndgrid(g1(:), p.u3_grid(:), qs);
u1 = L1(:); u3 = L3(:); q = LQ(:); n = numel(u1);
[num, den] = utility.slack_terms(p, t, u1, u3, q, ann_price);
u2m = utility.u2_max(p, t, u1, u3, q, ann_price);
zd = max(p.phi_path(t) * u1, 1e-12) * p.D_beq(t) ^ (1 / (1 - g));
r = ones(n, 1);
info = struct('n_lines', n, 'n_none', 0, 'n_all', 0, 'n_flat', 0, 'rounds', 0, 'solves', 0, 'sec', 0);

% Lines where the edge lies past the cube (den <= 0 or u2_max = 1 with
% resources left at u2 = 1): searched between u2 = 0 and u2 = 1 in u2 itself.
s_lo = num - den .* u2m;
flat = ~(den > 0);
info.n_flat = nnz(flat);
r(flat) = 1;
live = find(~flat);
k = zeros(0, 1); all_def = false(0, 1);
if isempty(live), R = finish(r); return; end

    function f = fz(k, u2)
        % log z_cont - log z_def at u2 on lines k
        lam = u1(k); sA = u2 .* (1 - lam) .* u3(k); sH = u2 .* (1 - lam) .* (1 - u3(k));
        pts = struct('lam', lam, 'sA', sA, 'sH', sH, 'q', q(k));
        [~, ~, ~, ~, ~, Vc] = solver.bellman_step_lna(t, V_next, p, profile, shocks, ann_price, [], [], pts);
        zc = zeros(size(Vc)); m = isfinite(Vc);
        zc(m) = ((1 - g) * Vc(m)) .^ (1 / (1 - g));
        f = log(max(zc, realmin)) - log(zd(k));
        info.solves = info.solves + numel(k);
        info.rounds = info.rounds + 1;
    end
    function u2 = u2_of(k, y)
        u2 = min(max((num(k) - exp(y)) ./ den(k), 0), u2m(k));
    end

% the two ends: u2 = 0 (y = log num) and u2 = u2_max (y = log s_lo)
yb = log(num(live)); ya = log(max(s_lo(live), realmin));
fb = fz(live, zeros(numel(live), 1));
fa = fz(live, u2m(live));
all_def = fb <= 0;                 % defaults with all its wealth liquid
none    = fa > 0;                  % continues up to the edge
info.n_all = nnz(all_def); info.n_none = nnz(none);
r(live(all_def)) = opts.r_all;
r(live(none & ~all_def)) = 1;
go = ~all_def & ~none;
k = live(go); ya = ya(go); yb = yb(go); fa = fa(go); fb = fb(go);
side = zeros(numel(k), 1);         % Illinois: which end was kept last
y = (ya + yb) / 2;
for it = 1:opts.rounds
    open = abs(yb - ya) > opts.tol;
    if ~any(open), break; end
    % regula falsi, falling back to bisection where the secant leaves the bracket
    yn = yb - fb .* (yb - ya) ./ (fb - fa);
    bad = ~isfinite(yn) | yn <= min(ya, yb) | yn >= max(ya, yb);
    yn(bad) = (ya(bad) + yb(bad)) / 2;
    ko = find(open);
    fn = fz(k(ko), u2_of(k(ko), yn(ko)));
    for j = 1:numel(ko)
        i = ko(j);
        if fn(j) > 0          % continuing still worth more: the root is nearer the edge (smaller y)
            yb(i) = yn(i); fb(i) = fn(j);
            if side(i) == 1, fa(i) = fa(i) / 2; end
            side(i) = 1;
        else
            ya(i) = yn(i); fa(i) = fn(j);
            if side(i) == -1, fb(i) = fb(i) / 2; end
            side(i) = -1;
        end
    end
    y(open) = yn(open);
end
% the root: the last secant point, inside the final bracket
y = min(max(y, min(ya, yb)), max(ya, yb));
r(k) = u2_of(k, y) ./ u2m(k);
R = finish(r);

    function R = finish(r)
        % rho: the resources above the edge at the boundary over the default
        % value's certainty equivalent, s_b / z_def, which is what
        % utility.u2_scale_fn interpolates between lines (s_b goes with
        % z_def, so rho changes little along u1). A line that crosses keeps
        % its own; one that does not (the edge past the cube, or past
        % u2_max) takes its nearest crossing neighbour's along u1, at most
        % s(u2_max) / z_def, so that its own node stays at u2_max, or 0
        % (the edge) without one.
        u2b = r .* u2m;
        s_b = num - den .* u2b;
        rho = s_b ./ zd;
        cr = false(n, 1); cr(k) = true;              % lines with a root
        rho(live(all_def)) = num(live(all_def)) ./ zd(live(all_def));
        N1 = numel(g1); N3 = numel(p.u3_grid); NQ = numel(qs);
        rho = reshape(rho, N1, N3, NQ); cr = reshape(cr, N1, N3, NQ);
        cap = reshape(max(s_lo, 0) ./ zd, N1, N3, NQ);
        ad = false(n, 1); ad(live(all_def)) = true; ad = reshape(ad, N1, N3, NQ);
        for jq = 1:NQ
            for j3 = 1:N3
                ic = find(cr(:, j3, jq));
                for j1 = find(~cr(:, j3, jq) & ~ad(:, j3, jq)).'
                    if isempty(ic)
                        rho(j1, j3, jq) = 0;
                    else
                        [~, ii] = min(abs(ic - j1));
                        rho(j1, j3, jq) = min(rho(ic(ii), j3, jq), cap(j1, j3, jq));
                    end
                end
            end
        end
        R = rho;
        info.r = reshape(r, N1, N3, NQ);             % the boundary as a share of u2_max
        if ~q_now && Nq > 1, R = repmat(R, 1, 1, Nq); info.r = repmat(info.r, 1, 1, Nq); end
        info.sec = toc(t0);
    end
end
