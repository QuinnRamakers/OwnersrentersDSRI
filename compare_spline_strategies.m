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
%   Carlo noise. Strategies are RANKED by V_tilde (best first), but the
%   reported CEV is always measured against NO_PENSION (kappa=0, from
%   run_combined.m's combined_{housing}_kappa0.mat) as the reference, not
%   against whichever entry happens to rank best -- no pension is the
%   natural policy counterfactual ("is a DC pension worth having"), and
%   no-pension ranking #1 (beating every glide path) is a normal, expected
%   possible outcome, not an error to flag. CEV of strategy A vs reference B:
%       g_A = (V_tilde_A / V_tilde_B)^(1/(1-gamma)) - 1
%   read as: g_A > 0 means A delivers g_A*100% MORE lifetime consumption
%   than no pension (A better); g_A < 0 means A is worse by |g_A|*100%.
%   Falls back to CEV-vs-best if no combined_{housing}_kappa0.mat is found.
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
    R = struct('name',cell(n,1), 'fracs',[], 'Vt0',[], 'gamma',[], 'tau',[], ...
               'ages',[], 'is_benchmark',[], 'file',[], 'fp',[], 'kappa',[]);
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
        R(k).name         = si.name;
        R(k).fracs         = si.knot_fracs;
        R(k).Vt0           = Vt0;
        R(k).gamma         = pk.gamma;
        R(k).tau           = pk.tau_S;
        R(k).ages          = (pk.age0 : pk.age0 + pk.T - 2).';
        R(k).is_benchmark  = false;
        R(k).file          = files(k).name;
        R(k).fp            = param_fingerprint(pk);
        R(k).kappa         = pk.kappa;
        R(k).grid_str      = sprintf('%dx%dx%d, gh_n=%d', ...
                                     pk.N_lambda, pk.N_sA, pk.N_sH, pk.gh_n);
    end
    n_found_tot   = n_found_tot + n;
    added_benchmark = false;

    % No-pension (kappa=0) benchmark, from run_combined.m's
    % combined_{housing}_kappa0.mat -- folded into the SAME ranking so its
    % rank position and CEV vs the best strategy read off directly. tau_S
    % is NOT meaningful for this scenario (A stays 0 for life, so the
    % glide path has no effect on anything) -- NaN-padded and excluded
    % from the glide-path figure below, but the file is otherwise read the
    % same way (welfare0 fast-path, sol.V fallback for legacy files).
    nopension_file = fullfile(RES_DIR, sprintf('combined_%s_kappa0.mat', housing));
    if isfile(nopension_file) && n > 0
        m  = matfile(nopension_file);
        vars = who(m);
        pk = m.p;
        if ismember('welfare0', vars)
            w0  = m.welfare0;
            Vt0 = w0.Vt0;
        else
            sol = m.sol;
            V0f = fill_nan_nearest_3d(sol.V(:,:,:,1));
            Fv  = griddedInterpolant({pk.lambda_grid, pk.sA_grid, pk.sH_grid}, ...
                                     V0f, 'linear', 'nearest');
            Vt0 = Fv(1/(1+pk.h_mult), 0, pk.h_mult/(1+pk.h_mult));
        end
        nk = numel(R(1).fracs);
        B.name         = 'NO_PENSION (kappa=0)';
        B.fracs        = nan(1, nk);
        B.Vt0          = Vt0;
        B.gamma        = pk.gamma;
        B.tau          = pk.tau_S;
        B.ages         = (pk.age0 : pk.age0 + pk.T - 2).';
        B.is_benchmark = true;
        B.file         = sprintf('combined_%s_kappa0.mat', housing);
        B.fp           = param_fingerprint(pk);
        B.kappa        = pk.kappa;
        B.grid_str     = sprintf('%dx%dx%d, gh_n=%d', ...
                                 pk.N_lambda, pk.N_sA, pk.N_sH, pk.gh_n);
        R = [R; B];
        n = n + 1;
        added_benchmark = true;
        n_found_tot = n_found_tot + 1;
    elseif n > 0
        fprintf('  NOTE: %s not found -- no-pension benchmark not included (run run_combined first).\n', ...
            nopension_file);
    end

    % CONSISTENCY GATE: every file in a ranking must share the same grid
    % AND the same calibration -- V_tilde values from different grids or
    % different parameter vintages are not comparable, and mixing them
    % produces garbage CEVs that LOOK plausible (this actually happened:
    % stale pre-calibration-overhaul spl_* files got ranked against a
    % fresh kappa0 benchmark, yielding a nonsense +792% "pension value").
    % kappa is checked separately (benchmark is kappa=0 BY DESIGN; all
    % strategy files must share one kappa but differ from the benchmark).
    fps  = {R.fp};
    ufps = unique(fps);
    if numel(ufps) > 1
        fprintf('\n  *** GRID/CALIBRATION MISMATCH across the files in this ranking: ***\n');
        for u = 1:numel(ufps)
            members = find(strcmp(fps, ufps{u}));
            fprintf('  Group %d (%d files): %s\n', u, numel(members), ufps{u});
            show = members(1:min(4, numel(members)));
            for mm = show, fprintf('      %s\n', R(mm).file); end
            if numel(members) > numel(show)
                fprintf('      ... and %d more\n', numel(members) - numel(show));
            end
        end
        error('compare_spline_strategies:mismatch', ...
            ['Files in %s were produced on different grids and/or calibrations ', ...
             '(see groups above) -- their V_tilde values are not comparable. ', ...
             'Delete the stale files (or move them out of the results dir) and re-run.'], RES_DIR);
    end
    strat_kappas = unique([R(~[R.is_benchmark]).kappa]);
    assert(isscalar(strat_kappas), 'compare_spline_strategies:kappaMix', ...
        'Strategy files mix multiple kappa values (%s) -- not one comparable sweep.', ...
        strjoin(compose('%.3g', strat_kappas), ', '));

    % Rank: V_tilde is increasing in welfare (negative under gamma>1, but
    % larger = better), so descending sort puts the best strategy first.
    [~, ord] = sort([R.Vt0], 'descend');
    R = R(ord);

    % Welfare gain is always measured against NO_PENSION as the reference
    % (not against whichever entry happens to rank best) -- see docstring.
    if added_benchmark
        bi      = find([R.is_benchmark]);
        Vt0_ref = R(bi).Vt0;
        col_name = 'cev_vs_nopension_pct';
        col_hdr  = 'CEV vs no pension';
    else
        Vt0_ref  = R(1).Vt0;
        col_name = 'cev_vs_best_pct';
        col_hdr  = 'CEV vs best';
    end
    g = arrayfun(@(r) cev(Vt0_ref, r.Vt0, r.gamma), R);   % >0: r beats the reference

    fprintf('\n%s\n-- %s: %d entries, best first (%s) --\n', ...
        repmat('=',1,78), housing, n, ...
        ternary(added_benchmark, 'CEV reference: NO_PENSION', 'no-pension reference missing; CEV vs best'));
    fprintf('   All entries verified to share one grid + calibration: state %s, kappa=%.3g\n%s\n', ...
        R(1).grid_str, strat_kappas, repmat('=',1,78));
    row_fmt = '  %4s  %-22s %-18s %14s %12s\n';
    fprintf(row_fmt, 'rank', 'strategy', 'knot fracs', 'V_tilde0', col_hdr);
    n_show = min(n, 15);
    print_row = @(k, suffix) fprintf(row_fmt, sprintf('%d', k), R(k).name, ...
        ['[' strjoin(compose('%.2f', R(k).fracs), ' ') ']'], ...
        sprintf('%.5g', R(k).Vt0), [sprintf('%+.3f%%', g(k)*100) suffix]);
    for k = 1:n_show
        print_row(k, ternary(R(k).is_benchmark, '  (reference)', ''));
    end
    if n > n_show
        fprintf('  %4s  (%d more -- full ranking in CSV)\n', '...', n - n_show);
        print_row(n, [ternary(R(n).is_benchmark, '  (reference)', '') '  (worst)']);
    end

    % CSV: full ranking, machine-readable (one fraction column per knot)
    fr = vertcat(R.fracs);
    frac_cols = arrayfun(@(j) fr(:,j), 1:size(fr,2), 'UniformOutput', false);
    frac_names = compose('f_knot%d', 1:size(fr,2));
    T = table((1:n).', {R.name}.', frac_cols{:}, [R.Vt0].', 100*g(:), ...
              'VariableNames', [{'rank','strategy'}, frac_names, ...
                                {'V_tilde0', col_name}]);
    csv_file = fullfile(RES_DIR, sprintf('%s_comparison_%s.csv', prefix, housing));
    writetable(T, csv_file);
    fprintf('  CSV written: %s\n', csv_file);

    % Figure panel: top 3 (solid) and bottom 3 (dashed) glide paths. The
    % NO_PENSION benchmark is excluded here -- its tau_S is not meaningful
    % (A stays 0 for life, so the glide path has no effect on anything).
    not_bench = ~[R.is_benchmark];
    Rp = R(not_bench); gp = g(not_bench); np = numel(Rp);
    subplot(1, 2, hi); hold on;
    for k = 1:min(3, np)
        plot(Rp(k).ages, Rp(k).tau, 'LineWidth', 1.8, ...
            'DisplayName', sprintf('#%d %s (%.2f%%)', k, strrep(Rp(k).name,'_','\_'), gp(k)*100));
    end
    for k = max(1, np-2):np
        if k <= 3, continue; end
        plot(Rp(k).ages, Rp(k).tau, '--', 'LineWidth', 1.1, ...
            'DisplayName', sprintf('#%d %s (%.2f%%)', k, strrep(Rp(k).name,'_','\_'), gp(k)*100));
    end
    xlabel('age'); ylabel('\tau_S');
    title(sprintf('%s: best (solid) vs worst (dashed)', housing));
    legend('Location','southwest', 'FontSize', 7);
    ylim([-0.05 1.05]); grid on;
end

if n_found_tot > 0
    fig_file = fullfile(RES_DIR, ternary(opts.smoke, ...
        'smoke_fig_spline_comparison.png', 'fig_spline_comparison.png'));
    % exportgraphics, not the legacy print(...,'-dpng',...) -- print's
    % rasterization path can hang/timeout on headless machines with no
    % display (e.g. the cluster pod); exportgraphics is what every other
    % figure-saving call in this repo already uses without issue.
    exportgraphics(fig, fig_file, 'Resolution', 140);
    fprintf('\nFigure saved: %s\n', fig_file);
else
    fprintf('\nNo strategy files found -- nothing to compare.\n');
end
end

%% =======================================================================
function s = param_fingerprint(p)
%PARAM_FINGERPRINT  One-line string identifying the grid + calibration a
%   file was solved under. Two files are welfare-comparable iff their
%   fingerprints match. kappa is deliberately EXCLUDED (the no-pension
%   benchmark differs in kappa by design); it is checked separately.
flds = {'N_lambda','N_sA','N_sH','gh_n','age0','T','retirement_age', ...
        'gamma','beta','chi','alpha','theta','h_mult','r','mu_S_level', ...
        'sigma_S_level','mu_H_level','sigma_H_level','r_m','replacement', ...
        'sigma_l_log','tau_inc','tau_cg_stock'};
parts = cell(1, numel(flds));
for i = 1:numel(flds)
    if isfield(p, flds{i}), v = p.(flds{i}); else, v = NaN; end
    parts{i} = sprintf('%s=%.6g', flds{i}, v);
end
s = strjoin(parts, ' ');
end

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
