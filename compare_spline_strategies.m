function compare_spline_strategies(results_dir, opts)
%COMPARE_SPLINE_STRATEGIES  Rank every spline strategy run found on disk,
% per housing type, by exact consumption-equivalent welfare.
%
%   compare_spline_strategies                      % scan utility.output_dir()
%   compare_spline_strategies('D:\downloads\all')  % scan a combined folder
%   compare_spline_strategies('', smoke=true)      % rank smoke_ files instead
%
%   Auto-discovers spl_*_{renter|owner}.mat files -- no hardcoded strategy
%   list, so it works on whatever subset the cluster instances have
%   produced. Combining instances = download every instance's output dir
%   into ONE folder and point this function at it.
%
%   Welfare metric (see welfare_dc_strategies.m): homotheticity gives
%   V(W,state) = W^(1-gamma) * V_tilde(state); every strategy starts from
%   the same initial state, so ranking V_tilde there is exact -- no Monte
%   Carlo noise. CEV of strategy A vs the best strategy B:
%       g_A = (V_tilde_B / V_tilde_A)^(1/(1-gamma)) - 1
%   read as: A needs g_A*100% MORE lifetime consumption to match the best.
%
%   Runs saved by run_spline_strategies carry a small top-level `welfare0`
%   struct, read via matfile WITHOUT loading the big sol/sim arrays, so this
%   scans ~100 files in seconds. Falls back to computing V_tilde0 from
%   sol.V for files that predate welfare0.
%
%   Outputs (written into results_dir):
%     printed ranked table per housing type
%     spl_comparison_{renter|owner}.csv   (full ranking, machine-readable)
%     fig_spline_comparison.png           (best/worst glide paths + CEV)
%   (smoke_ prefixed when smoke=true, so smoke checks never overwrite them)

arguments
    results_dir {mustBeTextScalar} = ''
    opts.smoke (1,1) logical = false
end

RES_DIR = char(results_dir);
if isempty(RES_DIR), RES_DIR = utility.output_dir(); end
assert(isfolder(RES_DIR), 'compare_spline_strategies:nodir', 'Not a folder: %s', RES_DIR);
prefix  = ternary(opts.smoke, 'smoke_spl', 'spl');
HOUSING = {'renter', 'owner'};

fig = figure('Visible','off', 'Position',[80 80 1150 440]);
n_found_tot = 0;

for hi = 1:numel(HOUSING)
    housing = HOUSING{hi};
    files = dir(fullfile(RES_DIR, sprintf('%s_*_%s.mat', prefix, housing)));
    if isempty(files)
        fprintf('\n-- %s: no %s_*_%s.mat files in %s --\n', housing, prefix, housing, RES_DIR);
        continue
    end

    n = numel(files);
    R = struct('name',cell(n,1), 'fracs',[], 'Vt0',[], 'gamma',[], 'tau',[], 'ages',[]);
    for k = 1:n
        fname = fullfile(files(k).folder, files(k).name);
        m = matfile(fname);
        vars = who(m);
        si   = m.strat_info;
        pk   = m.p;
        if ismember('welfare0', vars)
            w0 = m.welfare0;
            Vt0 = w0.Vt0;
        else                     % legacy file: compute from sol.V (slow path)
            sol = m.sol;
            V0f = fill_nan_nearest_3d(sol.V(:,:,:,1));
            Fv  = griddedInterpolant({pk.lambda_grid, pk.sA_grid, pk.sH_grid}, ...
                                     V0f, 'linear', 'nearest');
            Vt0 = Fv(1/(1+pk.h_mult), 0, pk.h_mult/(1+pk.h_mult));
        end
        R(k).name  = si.name;
        R(k).fracs = si.knot_fracs;
        R(k).Vt0   = Vt0;
        R(k).gamma = pk.gamma;
        R(k).tau   = pk.tau_S;
        R(k).ages  = (pk.age0 : pk.age0 + pk.T - 2).';
    end
    n_found_tot = n_found_tot + n;

    % Rank: V_tilde is increasing in welfare (negative under gamma>1, but
    % larger = better), so descending sort puts the best strategy first.
    [~, ord] = sort([R.Vt0], 'descend');
    R = R(ord);
    g = arrayfun(@(r) cev(r.Vt0, R(1).Vt0, r.gamma), R);   % CEV vs best

    fprintf('\n%s\n-- %s: %d strategies found (best first) --\n%s\n', ...
        repmat('=',1,66), housing, n, repmat('=',1,66));
    fprintf('  rank  %-22s %-22s %12s %12s\n', 'strategy', 'knot fracs', 'V_tilde0', 'CEV vs best');
    n_show = min(n, 15);
    for k = 1:n_show
        fprintf('  %4d  %-22s [%s] %12.6g %10.3f%%\n', k, R(k).name, ...
            strjoin(compose('%.2f', R(k).fracs), ' '), R(k).Vt0, g(k)*100);
    end
    if n > n_show
        fprintf('  ...   (%d more -- full ranking in CSV)\n', n - n_show);
        fprintf('  %4d  %-22s [%s] %12.6g %10.3f%%  (worst)\n', n, R(n).name, ...
            strjoin(compose('%.2f', R(n).fracs), ' '), R(n).Vt0, g(n)*100);
    end

    % CSV: full ranking, machine-readable (one fraction column per knot)
    fr = vertcat(R.fracs);
    frac_cols = arrayfun(@(j) fr(:,j), 1:size(fr,2), 'UniformOutput', false);
    frac_names = compose('f_knot%d', 1:size(fr,2));
    T = table((1:n).', {R.name}.', frac_cols{:}, [R.Vt0].', 100*g(:), ...
              'VariableNames', [{'rank','strategy'}, frac_names, ...
                                {'V_tilde0','cev_vs_best_pct'}]);
    csv_file = fullfile(RES_DIR, sprintf('%s_comparison_%s.csv', prefix, housing));
    writetable(T, csv_file);
    fprintf('  CSV written: %s\n', csv_file);

    % Figure panel: top 3 (solid) and bottom 3 (dashed) glide paths
    subplot(1, 2, hi); hold on;
    for k = 1:min(3, n)
        plot(R(k).ages, R(k).tau, 'LineWidth', 1.8, ...
            'DisplayName', sprintf('#%d %s (%.2f%%)', k, strrep(R(k).name,'_','\_'), g(k)*100));
    end
    for k = max(1, n-2):n
        if k <= 3, continue; end
        plot(R(k).ages, R(k).tau, '--', 'LineWidth', 1.1, ...
            'DisplayName', sprintf('#%d %s (%.2f%%)', k, strrep(R(k).name,'_','\_'), g(k)*100));
    end
    xlabel('age'); ylabel('\tau_S');
    title(sprintf('%s: best (solid) vs worst (dashed)', housing));
    legend('Location','southwest', 'FontSize', 7);
    ylim([-0.05 1.05]); grid on;
end

if n_found_tot > 0
    fig_file = fullfile(RES_DIR, ternary(opts.smoke, ...
        'smoke_fig_spline_comparison.png', 'fig_spline_comparison.png'));
    print(fig, fig_file, '-dpng', '-r140');
    fprintf('\nFigure saved: %s\n', fig_file);
else
    fprintf('\nNo strategy files found -- nothing to compare.\n');
end
end

%% =======================================================================
function g = cev(V_A, V_B, gamma)
%CEV  Consumption-equivalent variation of A relative to benchmark B.
%   g > 0: A needs g*100% more lifetime consumption to match B (A worse).
    g = (V_B / V_A) ^ (1 / (1 - gamma)) - 1;
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end

function Z = fill_nan_nearest_3d(M)
% Same boundary-NaN helper as welfare_dc_strategies.m (legacy fallback only).
Z = M;
if ~any(isnan(Z(:))), return; end
[NL, NA, NH] = size(Z);
mask_ok = ~isnan(Z);
[Ig, Jg, Kg] = ndgrid(1:NL, 1:NA, 1:NH);
I_ok = Ig(mask_ok); J_ok = Jg(mask_ok); K_ok = Kg(mask_ok); V_ok = Z(mask_ok);
I_bad = Ig(~mask_ok); J_bad = Jg(~mask_ok); K_bad = Kg(~mask_ok);
for k = 1:numel(I_bad)
    di = I_bad(k) - I_ok; dj = J_bad(k) - J_ok; dk = K_bad(k) - K_ok;
    d2 = di.*di + dj.*dj + dk.*dk;
    [~, q] = min(d2);
    Z(I_bad(k), J_bad(k), K_bad(k)) = V_ok(q);
end
end
