% WELFARE_DC_STRATEGIES  Consumption-equivalent welfare comparison across
% DC investment strategies, for renters and owners.
%
%   Exploits the homothetic structure of the solved model:
%       V(W, state) = W^(1-gamma) * V_tilde(state)
%   sol.V(:,:,:,1) IS V_tilde at age0 (t=1). Every strategy starts from the
%   same normalised initial state (lambda0, sA0=0, sH0), since X0=A0=0 and
%   H0 = h_mult*Y0 are identical across strategies. So welfare comparisons
%   reduce to comparing V_tilde at that one grid point -- no simulation,
%   no Monte Carlo noise, exact given the solved value function.
%
%   Consumption-equivalent variation (CEV) of strategy A vs benchmark B:
%       g_A = ( V_tilde_B / V_tilde_A ) ^ (1/(1-gamma)) - 1
%   g_A > 0  => strategy A needs g_A*100% MORE lifetime consumption to
%               match the benchmark (A is worse).
%   g_A < 0  => strategy A delivers the equivalent of |g_A|*100% MORE
%               lifetime consumption than the benchmark (A is better).
%
%   Usage:
%       welfare_dc_strategies

clear; clc;

%% -----------------------------------------------------------------------
%% Config
%% -----------------------------------------------------------------------
STRATS   = {'riskfree', 'equity_life', 'rule_100age_flat'};
HOUSING  = {'renter', 'owner'};
BENCHMARK = 'rule_100age_flat';   % <-- change reference strategy here

%% -----------------------------------------------------------------------
%% Load V_tilde at the initial state (t=1) for every available scenario
%% -----------------------------------------------------------------------
Vt0    = nan(numel(STRATS), numel(HOUSING));
gamma_ = nan(numel(STRATS), numel(HOUSING));
found  = false(numel(STRATS), numel(HOUSING));

for si = 1:numel(STRATS)
    for hi = 1:numel(HOUSING)
        fname = sprintf('dc_%s_%s.mat', STRATS{si}, HOUSING{hi});
        if ~isfile(fname)
            warning('welfare:missing', 'Missing %s -- skipping.', fname);
            continue
        end
        d = load(fname, 'p', 'sol');

        lam0 = 1 / (1 + d.p.h_mult);
        sA0  = 0;
        sH0  = d.p.h_mult / (1 + d.p.h_mult);

        F = griddedInterpolant({d.p.lambda_grid, d.p.sA_grid, d.p.sH_grid}, ...
                                d.sol.V(:,:,:,1), 'linear', 'nearest');
        Vt0(si, hi)    = F(lam0, sA0, sH0);
        gamma_(si, hi) = d.p.gamma;
        found(si, hi)  = true;
    end
end

%% -----------------------------------------------------------------------
%% CEV vs benchmark, per housing type
%% -----------------------------------------------------------------------
bi = find(strcmp(STRATS, BENCHMARK));
if isempty(bi)
    error('welfare:badbench', 'Benchmark "%s" not in STRATS list.', BENCHMARK);
end

fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('Welfare (consumption-equivalent) vs benchmark = "%s"\n', BENCHMARK);
fprintf('%s\n', repmat('=', 1, 70));

for hi = 1:numel(HOUSING)
    fprintf('\n-- %s --\n', HOUSING{hi});
    if ~found(bi, hi)
        fprintf('  Benchmark scenario missing for %s -- skipping.\n', HOUSING{hi});
        continue
    end
    fprintf('  %-18s %12s %14s\n', 'strategy', 'V_tilde0', 'CEV vs bench');
    for si = 1:numel(STRATS)
        if ~found(si, hi)
            fprintf('  %-18s %12s %14s\n', STRATS{si}, 'MISSING', '--');
            continue
        end
        if si == bi
            fprintf('  %-18s %12.6g %13s\n', STRATS{si}, Vt0(si, hi), '(benchmark)');
            continue
        end
        g = cev(Vt0(si, hi), Vt0(bi, hi), gamma_(si, hi));
        sign_str = ternary(g >= 0, 'worse by', 'better by');
        fprintf('  %-18s %12.6g %8.3f%%  (%s)\n', STRATS{si}, Vt0(si, hi), g*100, sign_str);
    end
end

%% -----------------------------------------------------------------------
%% Full pairwise CEV matrix, per housing type (bonus -- not just vs bench)
%% -----------------------------------------------------------------------
fprintf('\n%s\n', repmat('=', 1, 70));
fprintf('Full pairwise CEV matrix: row = %%-more-consumption row needs to match column\n');
fprintf('%s\n', repmat('=', 1, 70));

for hi = 1:numel(HOUSING)
    fprintf('\n-- %s --\n', HOUSING{hi});
    fprintf('%-18s', '');
    for cj = 1:numel(STRATS)
        fprintf('%16s', STRATS{cj});
    end
    fprintf('\n');
    for ri = 1:numel(STRATS)
        fprintf('%-18s', STRATS{ri});
        for cj = 1:numel(STRATS)
            if ~found(ri, hi) || ~found(cj, hi)
                fprintf('%16s', 'n/a');
                continue
            end
            if ri == cj
                fprintf('%16s', '--');
                continue
            end
            g = cev(Vt0(ri, hi), Vt0(cj, hi), gamma_(ri, hi));
            fprintf('%15.3f%%', g*100);
        end
        fprintf('\n');
    end
end
fprintf('\n');

%% =======================================================================
function g = cev(V_A, V_B, gamma)
%CEV  Consumption-equivalent variation of A relative to benchmark B.
%   g > 0: A needs g*100% more lifetime consumption to match B (A worse).
    g = (V_B / V_A) ^ (1 / (1 - gamma)) - 1;
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
