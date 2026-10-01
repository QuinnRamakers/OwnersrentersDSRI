function rent_channel(sp, out_dir)
%RENT_CHANNEL  Is the early-life ruin region the rent obligation?
%
%   ruin_line_by_grid shows a ruin region at age 34 that sits at low u1 --
%   income small relative to wealth -- and grows up the axis as the cube is
%   refined, until at 5808 nodes it covers the whole band households of 34
%   actually occupy. At age 69 the same states are healthy.
%
%   For a renter the H state is a rent index, not a house: it has no resale and
%   no bequest value (config.h_process), and its only role is to set the rent
%   alpha * H. But the cube counts it inside wealth, W = Y + X + A + H, so a
%   state with a small u1 and a large illiquid share is a household whose
%   "wealth" is mostly a rent obligation and whose income is negligible beside
%   it. At the age-34 occupied node the rent runs at 2.8% of W a year against
%   income of 0.04% of W, for 33 more working years. That is a candidate for
%   why those states are worth nothing, and it is testable: alpha enters the
%   budget only through h_cost_rate, so scaling it scales the obligation and
%   nothing else.
%
%   Three arms at one cube, scanning the whole u1 line at two ages. If the ruin
%   region retreats down the axis as alpha falls, the obligation is what makes
%   those states worthless.

if nargin < 1 || isempty(sp)
    sp = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad';
end
if nargin < 2 || isempty(out_dir)
    out_dir = 'C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc/diagnostics';
end
res = fullfile(out_dir, 'rent_channel.mat');

DIM  = [16 16 10];
ALPHAS = [0.060 0.030 0.012];           % production, half, and a fifth
TS   = [10 30];                         % ages 34, 54
TGT  = [0.1393 0.6549 0.2757; ...
        0.0780 0.7365 0.6728];

G = struct('alpha', {}, 'N', {}, 'n', {}, 'sec', {}, 'dir', {}, 't', {}, ...
           'u1', {}, 'i2', {}, 'i3', {}, 'coord23', {}, 'rent_share', {});
if isfile(res), L = load(res); G = L.G; end

for i = 1:numel(ALPHAS)
    if any(abs([G.alpha] - ALPHAS(i)) < 1e-12), continue; end
    sd = fullfile(sp, 'scans_rent', sprintf('a%03d', round(1000*ALPHAS(i))));
    if isfolder(sd), rmdir(sd, 's'); end
    mkdir(sd);
    fprintf('[%s] alpha = %.3f ...\n', datestr(now, 'HH:MM:SS'), ALPHAS(i));

    p = config.params(); p.is_owner = false;
    p.alpha = ALPHAS(i);
    p.grid_mode = 'none'; p.polish_ver = 2; p.polish_algo = 'active-set'; p.use_refine = 0;
    p.lambda_lo = 0.0008; p.lambda_hi = 0.44; p.grid_pow = 1.6;
    p.u2_lo = 0.40; p.grid_pow_u2 = 1; p.u3_lo = 0.02; p.u3_hi = 0.98;
    p = utility.build_state_grids(p, DIM, 5);
    N = [p.N_u1 p.N_u2 p.N_u3];

    nodes = []; i2 = zeros(numel(TS), 1); i3 = zeros(numel(TS), 1); c23 = zeros(numel(TS), 2);
    for a = 1:numel(TS)
        [~, i2(a)] = min(abs(p.u2_grid(:) - TGT(a, 2)));
        [~, i3(a)] = min(abs(p.u3_grid(:) - TGT(a, 3)));
        c23(a, :) = [p.u2_grid(i2(a)) p.u3_grid(i3(a))];
        nodes = [nodes; sub2ind(N, (1:N(1)).', repmat(i2(a), N(1), 1), repmat(i3(a), N(1), 1))]; %#ok<AGROW>
    end
    p.scan = struct('t', TS, 'nodes', unique(nodes), 'c_n', 81, 'pi_n', 61, 'dir', sd);

    [~, mg, sl] = config.income_profile(p);
    pf.mu_growth = mg; pf.sigma_l_log = sl; pf.p_surv = config.survival(p);
    sk = grids.shock_grid(p); an = pension.annuity_price(p, pf, sk);
    tic; solver.solve_lifecycle_lna(p, pf, sk, an); sec = toc;

    % rent as a share of take-home income at the age-34 occupied state
    net = 1; if isfield(p, 'tau_inc'), net = 1 - p.tau_inc; end
    kap = p.kappa(min(TS(1), numel(p.kappa)));
    cf  = (1 - p.delta) * (1 - kap) * net;
    u1v = TGT(1,1); u2v = TGT(1,2); u3v = TGT(1,3);
    sH  = u2v * (1 - u1v) * (1 - u3v);

    G(end+1).alpha = ALPHAS(i); G(end).N = N; G(end).n = prod(N);        %#ok<AGROW>
    G(end).sec = sec; G(end).dir = sd; G(end).t = TS; G(end).u1 = p.u1_grid(:);
    G(end).i2 = i2; G(end).i3 = i3; G(end).coord23 = c23;
    G(end).rent_share = ALPHAS(i) * sH / (cf * u1v);
    save(res, 'G', '-v7.3');
    fprintf('   alpha %.3f | rent = %.0f%% of take-home income | %.0f s | %d scans\n', ...
        ALPHAS(i), 100*G(end).rent_share, sec, numel(dir(fullfile(sd, 'scan_*.mat'))));
end
fprintf('done: %d arms\n', numel(G));
end
