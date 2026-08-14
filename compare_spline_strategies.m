function compare_spline_strategies(results_dir, opts)
%COMPARE_SPLINE_STRATEGIES  Rank every DC arm found on disk, per housing
% type, by exact consumption-equivalent welfare.
%
%   compare_spline_strategies                      % scan utility.output_dir()
%   compare_spline_strategies('D:\downloads\all')  % scan a combined folder
%   compare_spline_strategies('', smoke=true)      % rank smoke_ files instead
%   compare_spline_strategies('', anchor="b_alt")  % read welfare at b_alt
%
%   THREE ARMS go into one ranking, per housing type:
%     NO_PENSION   combined_{housing}_nodc.mat    (run_nodc.m, kappa = 0)
%                  -- the CEV reference. Falls back to the retired
%                  combined_{housing}_kappa0.mat name for legacy folders.
%     FREE_DC      combined_{housing}_freetau.mat (run_combined.m,
%                  choose_tau_S = true) -- the DC equity share is a free
%                  per-state choice, i.e. the upper bound any imposed glide
%                  path can aspire to.
%     spl_*        every imposed spline glide path from run_spline_strategies.
%   All three are solved from the same p on the same grid, so their V_tilde
%   values are on one scale and the table answers both questions at once: is
%   a DC pension worth having, and how much of its value does an imposed
%   glide path capture.
%
%   Auto-discovers spl_*_{renter|owner}.mat files -- no hardcoded strategy
%   list, so it works on whatever subset the cluster instances have
%   produced. Combining instances = download every instance's output dir
%   into ONE folder and point this function at it.
%
%   Welfare metric (see utility.welfare_summary): homotheticity gives
%   V(W,state) = W^(1-gamma) * V_tilde(state); every arm starts from the
%   same initial state, so ranking V_tilde there is exact -- no Monte Carlo
%   noise. Arms are RANKED by V_tilde (best first), but the reported CEV is
%   always measured against NO_PENSION as the reference, not against
%   whichever entry happens to rank best -- no pension is the natural policy
%   counterfactual ("is a DC pension worth having"), and no-pension ranking
%   #1 (beating every glide path) is a normal, expected possible outcome,
%   not an error to flag. CEV of arm A vs reference B:
%       g_A = (V_tilde_A / V_tilde_B)^(1/(1-gamma)) - 1
%   read as: g_A > 0 means A delivers g_A*100% MORE lifetime consumption
%   than no pension (A better); g_A < 0 means A is worse by |g_A|*100%.
%   Falls back to CEV-vs-best if no no-pension file is found.
%
%   WHICH ANCHOR (opts.anchor): V_tilde is read at an initial state carrying
%   a liquid buffer of b years of income (utility.welfare_anchor).
%     "auto"   (default) b0 when every file in the ranking carries it,
%              otherwise the b = 0 corner. Post-re-solve files all carry it.
%     "b0"     the calibrated buffer -- the paper number.
%     "b_alt"  the upper sensitivity buffer.
%     "corner" b = 0. What every pre-2026-08 welfare0.Vt0 means, and a
%              near-zero-consumption corner where CRRA(gamma=5) marginal
%              utility dominates the verdict. README's "Where welfare is
%              read" has the reasoning.
%   The anchor is chosen ONCE and applied to every file in the ranking; a
%   file missing the requested anchor is an error, never a silent fallback.
%
%   Runs saved by run_spline_strategies / run_combined / run_nodc carry a
%   small top-level `welfare0` struct, read via matfile WITHOUT loading the
%   big sol/sim arrays, so this scans ~100 files in seconds. Falls back to
%   computing V_tilde from sol.V for files that predate welfare0.
%
%   Outputs (written into results_dir):
%     printed ranked table per housing type
%     spl_comparison_{renter|owner}.csv   (full ranking, machine-readable,
%                                          carries every anchor's V_tilde)
%     fig_spline_comparison.png           (best/worst glide paths + CEV)
%   (smoke_ prefixed when smoke=true, so smoke checks never overwrite them)

arguments
    results_dir {mustBeTextScalar} = ''
    opts.smoke (1,1) logical = false
    opts.anchor (1,1) string ...
        {mustBeMember(opts.anchor, ["auto","b0","b_alt","corner"])} = "auto"
end

RES_DIR = char(results_dir);
if isempty(RES_DIR), RES_DIR = utility.output_dir(); end
assert(isfolder(RES_DIR), 'compare_spline_strategies:nodir', 'Not a folder: %s', RES_DIR);
prefix  = ternary(opts.smoke, 'smoke_spl', 'spl');
HOUSING = {'renter', 'owner'};

% Rank within ONE coordinate system. The suffix is what selects it, and it
% partitions the folder cleanly: '_lna' matches only cube files, and '' cannot
% match a cube file because those end in _lna.mat. So a directory holding both
% sweeps ranks either one on demand and never mixes them. Even if the glob did
% mix them, the fingerprint gate below carries grid_type and would refuse the
% comparison -- this just means the refusal never has to fire.
GRID_SUFFIX = utility.grid_suffix();

fig = figure('Visible','off', 'Position',[80 80 1150 440]);
n_found_tot = 0;

for hi = 1:numel(HOUSING)
    housing = HOUSING{hi};
    files = dir(fullfile(RES_DIR, sprintf('%s_*_%s%s.mat', prefix, housing, GRID_SUFFIX)));
    if isempty(files)
        fprintf('\n-- %s: no %s_*_%s%s.mat files in %s --\n', ...
            housing, prefix, housing, GRID_SUFFIX, RES_DIR);
        continue
    end

    entries = cell(1, numel(files));
    for k = 1:numel(files)
        fname = fullfile(files(k).folder, files(k).name);
        m  = matfile(fname);
        si = m.strat_info;
        entries{k} = read_entry(m, files(k).name, si.name, 'strategy');
        entries{k}.fracs = si.knot_fracs;
    end
    n_strat = numel(entries);
    nk      = numel(entries{1}.fracs);

    % ---------------------------------------------------------------- arms
    % The two benchmark arms are folded into the SAME ranking so their rank
    % positions and CEVs read off directly. Neither has a meaningful tau_S
    % glide path -- NO_PENSION holds A = 0 for life, and FREE_DC chooses tau
    % per state rather than following a plan -- so both are NaN-padded on the
    % knot columns and excluded from the glide-path figure below. Otherwise
    % they are read exactly like a strategy file (welfare0 fast path, sol.V
    % fallback for legacy files).
    ARMS = { ...
        {sprintf('combined_%s_nodc%s.mat',    housing, GRID_SUFFIX), ...
         sprintf('combined_%s_kappa0%s.mat',  housing, GRID_SUFFIX)}, 'NO_PENSION (no DC)',  true ; ...
        {sprintf('combined_%s_freetau%s.mat', housing, GRID_SUFFIX)}, 'FREE_DC (free tau)',  false };

    missing = {};
    for a = 1:size(ARMS, 1)
        [found, af] = first_existing(RES_DIR, ARMS{a,1});
        if ~found
            missing{end+1} = ARMS{a,1}{1};  %#ok<AGROW>
            continue
        end
        e = read_entry(matfile(fullfile(RES_DIR, af)), af, ARMS{a,2}, 'benchmark');
        e.fracs  = nan(1, nk);
        e.is_ref = ARMS{a,3};
        entries{end+1} = e;  %#ok<AGROW>
    end
    for k = 1:numel(missing)
        fprintf('  NOTE: %s not found -- that arm is missing from the ranking.\n', ...
            fullfile(RES_DIR, missing{k}));
    end

    R = [entries{:}].';
    n = numel(R);
    n_found_tot = n_found_tot + n;
    has_ref = any([R.is_ref]);

    % ------------------------------------------------------ consistency gate
    % Every file in a ranking must share the same grid AND the same
    % calibration -- V_tilde values from different grids or different
    % parameter vintages are not comparable, and mixing them produces garbage
    % CEVs that LOOK plausible (this actually happened: stale
    % pre-calibration-overhaul spl_* files got ranked against a fresh kappa0
    % benchmark, yielding a nonsense +792% "pension value"). The ARM fields
    % kappa and choose_tau_S are checked separately, not fingerprinted: the
    % benchmarks differ in exactly those by design, which is the point.
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

    is_strat     = strcmp({R.kind}, 'strategy');
    strat_kappas = unique([R(is_strat).kappa]);
    assert(isscalar(strat_kappas), 'compare_spline_strategies:kappaMix', ...
        'Strategy files mix multiple kappa values (%s) -- not one comparable sweep.', ...
        strjoin(compose('%.3g', strat_kappas), ', '));
    strat_free = unique([R(is_strat).choose_tau]);
    assert(isscalar(strat_free) && ~strat_free, 'compare_spline_strategies:armMix', ...
        ['Strategy files must all be imposed glide paths (choose_tau_S = false); ', ...
         'found %s. A free-tau run belongs in the FREE_DC arm, not the sweep.'], ...
        strjoin(compose('%g', strat_free), ', '));

    % ----------------------------------------------------- anchor selection
    [Vt0, anchor_used] = pick_anchor(R, opts.anchor);
    for k = 1:n, R(k).Vt0 = Vt0(k); end

    % Rank: V_tilde is increasing in welfare (negative under gamma>1, but
    % larger = better), so descending sort puts the best arm first.
    [~, ord] = sort(Vt0, 'descend');
    R = R(ord);

    % Welfare gain is always measured against NO_PENSION as the reference
    % (not against whichever entry happens to rank best) -- see docstring.
    if has_ref
        Vt0_ref  = R([R.is_ref]).Vt0;
        col_name = 'cev_vs_nopension_pct';
        col_hdr  = 'CEV vs no pension';
    else
        Vt0_ref  = R(1).Vt0;
        col_name = 'cev_vs_best_pct';
        col_hdr  = 'CEV vs best';
    end
    g = arrayfun(@(r) cev(Vt0_ref, r.Vt0, r.gamma), R);   % >0: r beats the reference

    fprintf('\n%s\n-- %s: %d entries (%d imposed strategies + %d benchmark arms), best first (%s) --\n', ...
        repmat('=',1,78), housing, n, n_strat, n - n_strat, ...
        ternary(has_ref, 'CEV reference: NO_PENSION', 'no-pension reference missing; CEV vs best'));
    fprintf('   All entries verified to share one grid + calibration: state %s, sweep kappa=%.3g\n', ...
        R(1).grid_str, strat_kappas);
    fprintf('   Welfare read at %s\n%s\n', anchor_label(anchor_used, R(1)), repmat('=',1,78));
    row_fmt = '  %4s  %-24s %-18s %14s %12s\n';
    fprintf(row_fmt, 'rank', 'arm / strategy', 'knot fracs', 'V_tilde0', col_hdr);
    n_show = min(n, 15);
    print_row = @(k, suffix) fprintf(row_fmt, sprintf('%d', k), R(k).name, ...
        ['[' strjoin(compose('%.2f', R(k).fracs), ' ') ']'], ...
        sprintf('%.5g', R(k).Vt0), [sprintf('%+.3f%%', g(k)*100) suffix]);
    for k = 1:n_show
        print_row(k, ternary(R(k).is_ref, '  (reference)', ''));
    end
    if n > n_show
        fprintf('  %4s  (%d more -- full ranking in CSV)\n', '...', n - n_show);
        print_row(n, [ternary(R(n).is_ref, '  (reference)', '') '  (worst)']);
    end

    % How much of the free-choice value an imposed glide path captures --
    % the headline three-arm number, printed only when all three arms are on
    % the table.
    fi = find(strcmp({R.kind}, 'benchmark') & ~[R.is_ref], 1);
    si = find(strcmp({R.kind}, 'strategy'), 1);     % rank order: best first
    if has_ref && ~isempty(fi) && ~isempty(si)
        fprintf('\n  Three-arm summary (CEV vs no pension):\n');
        fprintf('    free DC choice   %+.3f%%\n', 100*g(fi));
        fprintf('    best imposed     %+.3f%%   (%s)\n', 100*g(si), R(si).name);
        if abs(g(fi)) > eps
            fprintf('    capture ratio    %.1f%% of the free-choice gain\n', 100*g(si)/g(fi));
        end
    end

    % CSV: full ranking, machine-readable (one fraction column per knot).
    % Every anchor's V_tilde travels with it, so the paper can be written at
    % b0 without re-running this at a different anchor.
    fr = vertcat(R.fracs);
    frac_cols  = arrayfun(@(j) fr(:,j), 1:size(fr,2), 'UniformOutput', false);
    frac_names = compose('f_knot%d', 1:size(fr,2));
    T = table((1:n).', {R.name}.', {R.file}.', [R.kappa].', [R.choose_tau].', ...
              frac_cols{:}, [R.Vt0].', [R.Vt0_corner].', [R.Vt0_b0].', ...
              [R.Vt0_b_alt].', 100*g(:), ...
              'VariableNames', [{'rank','strategy','file','kappa','choose_tau_S'}, ...
                                frac_names, {'V_tilde0', 'V_tilde0_corner', ...
                                'V_tilde0_b0', 'V_tilde0_b_alt', col_name}]);
    csv_file = fullfile(RES_DIR, ...
        sprintf('%s_comparison_%s%s.csv', prefix, housing, GRID_SUFFIX));
    writetable(T, csv_file);
    fprintf('  CSV written: %s  (V_tilde0 column = anchor %s)\n', csv_file, anchor_used);

    % Figure panel: top 3 (solid) and bottom 3 (dashed) glide paths. The
    % benchmark arms are excluded here -- neither has a meaningful tau_S
    % glide (NO_PENSION holds A = 0 for life; FREE_DC picks tau per state).
    Rp = R(strcmp({R.kind}, 'strategy'));
    gp = g(strcmp({R.kind}, 'strategy'));
    np = numel(Rp);
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
        sprintf('smoke_fig_spline_comparison%s.png', GRID_SUFFIX), ...
        sprintf('fig_spline_comparison%s.png', GRID_SUFFIX)));
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
function e = read_entry(m, file_name, disp_name, kind)
%READ_ENTRY  One ranking row from an open matfile, without loading sol/sim.
%   Reads every anchor welfare0 carries; the ranking picks one later. Legacy
%   files that predate welfare0 fall back to the slow path (loads sol.V once
%   and evaluates the same anchors off it via utility.welfare_anchor).
vars = who(m);
pk   = m.p;

Vt0_b0 = NaN; Vt0_b_alt = NaN;   % Vt0_corner is set on every path below
if ismember('welfare0', vars)
    w0 = m.welfare0;
    Vt0_corner = w0.Vt0;
    if isfield(w0, 'Vt0_b0'),    Vt0_b0    = w0.Vt0_b0;    end
    if isfield(w0, 'Vt0_b_alt'), Vt0_b_alt = w0.Vt0_b_alt; end
else
    sol = m.sol;
    if isfield(pk, 'b0') && isfield(pk, 'b_alt')
        v = utility.welfare_anchor(pk, sol.V(:,:,:,1), [0, pk.b0, pk.b_alt]);
        Vt0_corner = v(1); Vt0_b0 = v(2); Vt0_b_alt = v(3);
    else
        Vt0_corner = utility.welfare_anchor(pk, sol.V(:,:,:,1), 0);
    end
end

[fp, arm] = utility.param_fingerprint(pk);

% Absent choose_tau_S means the feature did not exist when the file was
% solved, which IS the imposed-glide regime -- normalise NaN to false so a
% folder of pre-freetau files still passes the regime check below.
choose_tau = arm.choose_tau_S;
if isnan(choose_tau), choose_tau = 0; end

e = struct( ...
    'name',       disp_name, ...
    'file',       file_name, ...
    'kind',       kind, ...
    'is_ref',     false, ...
    'fracs',      [], ...
    'Vt0',        NaN, ...            % filled once the anchor is chosen
    'Vt0_corner', Vt0_corner, ...
    'Vt0_b0',     Vt0_b0, ...
    'Vt0_b_alt',  Vt0_b_alt, ...
    'gamma',      pk.gamma, ...
    'tau',        pk.tau_S, ...
    'ages',       (pk.age0 : pk.age0 + pk.T - 2).', ...
    'kappa',      arm.kappa, ...
    'choose_tau', choose_tau, ...
    'b0',         field_or_nan(pk, 'b0'), ...
    'b_alt',      field_or_nan(pk, 'b_alt'), ...
    'fp',         fp, ...
    'grid_str',   grid_str_of(pk));
end

function s = grid_str_of(pk)
%GRID_STR_OF  "N1xN2xN3, gh_n=G" for whichever coordinate system pk is on.
%   Reading N_lambda/N_sA/N_sH unconditionally reported the SIMPLEX sizes for a
%   cube run, and silently: config.params sets both sets of grid fields, so a
%   cube p carries stale 40s there while the sizes it actually solved on live
%   in u1_grid/u2_grid/u3_grid. The header at the top of the ranking would have
%   claimed 40x40x40 for every cube sweep.
%
%   Counts come off the axis vectors, not the N_* fields, so they are right
%   after build_state_grids re-inserts the anchors. An absent grid_type means
%   simplex, the same reading solver.solve and simulate.forward take.
if isfield(pk, 'grid_type') && strcmp(char(pk.grid_type), 'lna')
    n = [numel(pk.u1_grid), numel(pk.u2_grid), numel(pk.u3_grid)];
else
    n = [numel(pk.lambda_grid), numel(pk.sA_grid), numel(pk.sH_grid)];
end
s = sprintf('%dx%dx%d, gh_n=%d', n(1), n(2), n(3), pk.gh_n);
end

function [Vt0, used] = pick_anchor(R, want)
%PICK_ANCHOR  One anchor for the whole ranking -- never a per-file fallback.
have = struct('corner', all(~isnan([R.Vt0_corner])), ...
              'b0',     all(~isnan([R.Vt0_b0])), ...
              'b_alt',  all(~isnan([R.Vt0_b_alt])));
used = char(want);
if strcmp(used, 'auto')
    % b0 is the paper anchor; the corner is the pre-2026-08 convention every
    % legacy welfare0 carries, so it is the fallback that keeps old folders
    % rankable.
    used = ternary(have.b0, 'b0', 'corner');
end
assert(have.(used), 'compare_spline_strategies:anchor', ...
    ['Anchor "%s" is not available on every file in this ranking (older files ' ...
     'carry only the b = 0 corner). Re-solve them, or pass anchor="corner".'], used);
switch used
    case 'corner', Vt0 = [R.Vt0_corner].';
    case 'b0',     Vt0 = [R.Vt0_b0].';
    case 'b_alt',  Vt0 = [R.Vt0_b_alt].';
end
end

function s = anchor_label(used, r)
switch used
    case 'corner', s = 'the b = 0 corner (zero initial liquid buffer)';
    case 'b0',     s = sprintf('the calibrated buffer b0 = %.4f years of income', r.b0);
    case 'b_alt',  s = sprintf('the sensitivity buffer b_alt = %.4f years of income', r.b_alt);
end
end

function v = field_or_nan(p, f)
v = NaN;
if isfield(p, f) && isnumeric(p.(f)) && isscalar(p.(f)), v = double(p.(f)); end
end

function [found, name] = first_existing(dir_path, candidates)
%FIRST_EXISTING  First candidate filename that exists, in preference order.
found = false; name = '';
for k = 1:numel(candidates)
    if isfile(fullfile(dir_path, candidates{k}))
        found = true; name = candidates{k}; return
    end
end
end

function g = cev(V_A, V_B, gamma)
%CEV  Consumption-equivalent variation of B relative to reference A.
%   g > 0: B delivers g*100% more lifetime consumption-equivalent value.
    g = (V_B / V_A) ^ (1 / (1 - gamma)) - 1;
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
