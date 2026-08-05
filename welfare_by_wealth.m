function welfare_by_wealth(results_dir, opts)
%WELFARE_BY_WEALTH  Welfare gains by STARTING WEALTH, with the grid-resolution
% health check that says which of those numbers are actually solved.
%
%   welfare_by_wealth                       % scan utility.output_dir()
%   welfare_by_wealth('D:\downloads\all')   % scan a combined folder
%   welfare_by_wealth('', fine=false)       % skip the sol reloads (fast)
%   welfare_by_wealth('', housing="owner")  % one tenure only
%
%   Companion to compare_spline_strategies, which ranks every arm at ONE
%   anchor. This sweeps the anchor instead: how does the value of a DC pension
%   change with the household's starting liquid buffer b (years of income)?
%   Total starting wealth is W0/Y0 = b + h_mult + 1, since the household is
%   endowed with a house worth h_mult * Y0 plus current income.
%
%   FIVE SECTIONS
%     [1] Coarse table  -- CEV vs no pension for every arm at the 8 buffers
%                          welfare0.b_grid carries. Read via matfile, no sol
%                          load, so it is seconds even for ~100 files.
%     [2] Exact-node table -- the same thing at b0 and b_alt ONLY. These are
%                          the two buffers config.insert_anchor_nodes puts on
%                          the lambda/sH grids as exact nodes, so they are the
%                          only SOLVED (non-interpolated) entries in [1].
%     [3] Resolution diagnostic -- how many grid cells the whole b sweep
%                          actually spans, and how much sawtooth that puts on
%                          the curve. See the WARNING below.
%     [4] Arm differences -- the same curves differenced. Interpolation error
%                          is common-mode across arms at a given b, so it
%                          cancels here: rankings and crossovers survive even
%                          where levels do not.
%     [5] Value of wealth WITHIN each arm -- the substitutes/complements
%                          decomposition that explains why the renter and
%                          owner gradients run in OPPOSITE directions.
%
%   WARNING -- WHY [3] EXISTS. The anchor maps a buffer to state coordinates
%   as lam0 = 1/(b + h_mult + 1), so the entire sweep b = 0..12 lands inside
%   roughly THREE cells of the lambda grid. Only b0 and b_alt are exact nodes;
%   every other buffer -- including the b = 0 corner and all of
%   welfare0.b_grid -- is linearly interpolated across a strongly convex value
%   function. On the 27x15x17 sweep grid that puts a ~37 CEV-point sawtooth on
%   the renter LEVELS (the owner value function is far less curved and stays
%   clean). Section [4] is the honest way to read the sweep; section [2] is
%   the honest way to quote a level. The fix is to add whatever buffers you
%   want to report to config.insert_anchor_nodes and re-solve.
%
%   NORMALISATION TRAP (section [5]). utility.welfare_anchor returns V_tilde,
%   the NORMALISED value: V(W, state) = W^(1-gamma) * V_tilde(state). Across
%   different b the total wealth W0 changes too, so V_tilde alone is NOT
%   welfare -- comparing it across b reports that extra wealth makes owners
%   worse off, which is impossible. Section [5] restores the W0^(1-gamma)
%   factor. Cross-arm CEV at a FIXED b is unaffected, because both arms share
%   the same W0 and it cancels exactly; the code asserts that it does.
%
%   Outputs (written into results_dir):
%     printed sections [1]-[5] per housing type
%     welfare_by_wealth_{renter|owner}.csv    (full coarse table)
%     fig_welfare_vs_starting_wealth.png      (levels, with the exact nodes
%                                              marked -- the wiggles between
%                                              them are the interpolation)

arguments
    results_dir {mustBeTextScalar} = ''
    opts.housing (1,1) string ...
        {mustBeMember(opts.housing, ["renter","owner","both"])} = "both"
    opts.fine   (1,1) logical = true          % reload sol for dense curves
    opts.b_fine (1,:) double {mustBeNonnegative} = 0:0.02:10
end

RES_DIR = char(results_dir);
if isempty(RES_DIR), RES_DIR = utility.output_dir(); end
assert(isfolder(RES_DIR), 'welfare_by_wealth:nodir', 'Not a folder: %s', RES_DIR);

if opts.housing == "both", HOUSING = {'renter','owner'};
else,                      HOUSING = {char(opts.housing)};
end

fig = figure('Visible','off', 'Position',[80 80 1150 460]);
n_panel = 0;

for hi = 1:numel(HOUSING)
    h = HOUSING{hi};
    fprintf('\n%s\n#  %s\n%s\n', repmat('#',1,100), upper(h), repmat('#',1,100));

    ref_file  = fullfile(RES_DIR, sprintf('combined_%s_nodc.mat',    h));
    free_file = fullfile(RES_DIR, sprintf('combined_%s_freetau.mat', h));
    if ~isfile(ref_file)
        legacy = fullfile(RES_DIR, sprintf('combined_%s_kappa0.mat', h));
        if isfile(legacy), ref_file = legacy; end
    end
    if ~isfile(ref_file)
        fprintf('  no no-pension arm for %s -- skipping (CEV needs the reference).\n', h);
        continue
    end

    ref  = read_arm(ref_file,  'NO_PENSION (no DC)');
    arms = ref;
    if isfile(free_file)
        arms(end+1) = read_arm(free_file, 'FREE_DC (free tau)'); %#ok<AGROW>
    else
        fprintf('  NOTE: %s not found -- free-choice arm missing.\n', free_file);
    end

    L = dir(fullfile(RES_DIR, sprintf('spl_*_%s.mat', h)));
    for k = 1:numel(L)
        arms(end+1) = read_arm(fullfile(L(k).folder, L(k).name), ...
            erase(L(k).name, ['_' h '.mat'])); %#ok<AGROW>
    end

    % Same gate compare_spline_strategies uses: V_tilde from different grids
    % or calibrations is not comparable, and mixing them looks plausible.
    ufp = unique({arms.fp});
    assert(isscalar(ufp), 'welfare_by_wealth:mismatch', ...
        ['Files in %s come from different grids/calibrations (%d groups) -- ' ...
         'their V_tilde values are not comparable. Run compare_spline_strategies ' ...
         'for the per-group breakdown, then move the stale files out.'], ...
        RES_DIR, numel(ufp));

    p0    = arms(1).p;
    gamma = p0.gamma;
    B     = arms(1).b_grid;
    W0    = B + p0.h_mult + 1;                  % total start wealth, units of Y0
    cev   = @(V, Vr) (V ./ Vr).^(1/(1-gamma)) - 1;

    % ------------------------------------------------------------ [1] coarse
    Vref = ref.Vt0_grid;
    G    = cell2mat(arrayfun(@(a) cev(a.Vt0_grid, Vref), arms(:), 'UniformOutput', false));
    is_spl = startsWith({arms.name}, 'spl_');
    [~, ord] = sort(G(:,1), 'descend', 'MissingPlacement','last');
    ord = [find(~is_spl(ord),1,'first'); ord(is_spl(ord))];   % benchmarks first
    ord = unique([find(strcmp({arms.name},'FREE_DC (free tau)')); ord], 'stable');
    ord(ord == find(strcmp({arms.name}, ref.name), 1)) = [];  % reference row is all zeros

    fprintf('\n[1] CEV vs NO PENSION (%%), by starting liquid buffer\n');
    fprintf('    b  = liquid buffer, years of income;  W0/Y0 = b + %.0f\n', p0.h_mult + 1);
    fprintf('    %-22s', 'b (years income):'); fprintf('%9.2f', B);  fprintf('\n');
    fprintf('    %-22s', 'W0/Y0:');            fprintf('%9.2f', W0); fprintf('\n');
    fprintf('    %s\n', repmat('-', 1, 94));
    for k = ord(:).'
        fprintf('    %-22s', arms(k).name); fprintf('%+9.1f', 100*G(k,:)); fprintf('\n');
    end

    gs = G(is_spl, :);
    [gbest, ib] = max(gs, [], 1);
    spl_names = {arms(is_spl).name};
    fprintf('    %s\n', repmat('-', 1, 94));
    fprintf('    %-22s', 'best imposed'); fprintf('%+9.1f', 100*gbest); fprintf('\n');
    fprintf('    %-22s', '  which:');
    for j = 1:numel(B), fprintf('%9s', erase(spl_names{ib(j)}, 'spl_')); end
    fprintf('\n');
    ifree = find(strcmp({arms.name}, 'FREE_DC (free tau)'), 1);
    if ~isempty(ifree)
        fprintf('    %-22s', 'capture ratio %');
        fprintf('%9.1f', 100*gbest./G(ifree,:)); fprintf('\n');
    end

    T = array2table(100*G, ...
        'VariableNames', matlab.lang.makeValidName(compose('b_%g', B)), ...
        'RowNames', {arms.name});
    csv = fullfile(RES_DIR, sprintf('welfare_by_wealth_%s.csv', h));
    writetable(T, csv, 'WriteRowNames', true);
    fprintf('    CSV: %s\n', csv);

    % -------------------------------------------------------- [2] exact nodes
    fprintf('\n[2] THE ONLY SOLVED (non-interpolated) BUFFERS: b0 = %.4f, b_alt = %.4f\n', ...
        p0.b0, p0.b_alt);
    fprintf('    %-22s %14s %14s\n', 'arm', 'CEV at b0', 'CEV at b_alt');
    for k = ord(:).'
        g_b0 = cev(arms(k).Vt0_b0,    ref.Vt0_b0);
        g_ba = cev(arms(k).Vt0_b_alt, ref.Vt0_b_alt);
        fprintf('    %-22s %13.2f%% %13.2f%%\n', arms(k).name, 100*g_b0, 100*g_ba);
    end

    % --------------------------------------------------- [3] resolution check
    lam = 1 ./ (opts.b_fine + p0.h_mult + 1);
    sH  = p0.h_mult ./ (opts.b_fine + p0.h_mult + 1);
    fprintf('\n[3] GRID RESOLUTION OF THE BUFFER SWEEP  (b = %.1f .. %.1f)\n', ...
        opts.b_fine(1), opts.b_fine(end));
    fprintf('    lam0 spans %.4f .. %.4f  = %.2f cells of the %d-node lambda grid\n', ...
        min(lam), max(lam), span_cells(p0.lambda_grid, lam), numel(p0.lambda_grid));
    fprintf('    sH0  spans %.4f .. %.4f  = %.2f cells of the %d-node sH grid\n', ...
        min(sH),  max(sH),  span_cells(p0.sH_grid, sH),  numel(p0.sH_grid));
    fprintf('    -> every buffer except b0/b_alt is INTERPOLATED across those cells.\n');

    if ~opts.fine
        fprintf('    (fine=false: skipping the sawtooth measurement and sections [4]-[5])\n');
        continue
    end

    % Dense curves need sol.V(:,:,:,1); reload only the arms we plot/difference.
    fam = family_like_for_like(arms, RES_DIR, h);
    want = unique([{ref.file}, ternary(isempty(ifree), {}, {arms(ifree).file}), fam.files], 'stable');
    fprintf('    reloading sol for %d file(s) to build dense curves ... ', numel(want));
    Vd = containers.Map;
    for k = 1:numel(want)
        Vd(want{k}) = dense_curve(want{k}, opts.b_fine);
    end
    fprintf('done\n');

    Vr_d = Vd(ref.file);
    if ~isempty(ifree)
        Gf_d = cev(Vd(arms(ifree).file), Vr_d);
        fprintf('    renter/owner LEVEL curve: %d turning points over b in [%.1f, %.1f]\n', ...
            n_turning(Gf_d), opts.b_fine(1), opts.b_fine(end));
        in12 = opts.b_fine >= 1 & opts.b_fine <= 2;
        fprintf('    sawtooth amplitude of the level curve over b in [1,2]: %.1f CEV points\n', ...
            100*(max(Gf_d(in12)) - min(Gf_d(in12))));
        fprintf('    (a smooth curve has 0-1 turning points; more = interpolation, not economics)\n');
    end

    % --------------------------------------------- [4] differences (robust)
    if numel(fam.files) >= 2
        Glo = cev(Vd(fam.files{1}),   Vr_d);
        Ghi = cev(Vd(fam.files{end}), Vr_d);
        D   = 100*(Ghi - Glo);
        fprintf('\n[4] ARM DIFFERENCE (%s minus %s), in CEV points\n', ...
            fam.names{end}, fam.names{1});
        fprintf('    Interpolation error is common-mode at a given b, so it cancels here.\n');
        fprintf('    %-14s', 'b:');    fprintf('%8.1f', opts.b_fine(1:50:end)); fprintf('\n');
        fprintf('    %-14s', 'diff:'); fprintf('%+8.2f', D(1:50:end));          fprintf('\n');
        % Amplitude, not turning-point COUNT, is the right robustness metric
        % here: a nearly flat difference curve crosses zero slope constantly
        % while barely moving, so it can out-count a wildly swinging level
        % curve. Compare the grid-scale ripple left after removing a smooth
        % trend, in the same CEV points both curves are measured in.
        if ~isempty(ifree)
            fprintf('    grid-scale ripple: %.2f CEV pts on this difference, vs %.2f pts\n', ...
                roughness(D, opts.b_fine), roughness(100*Gf_d, opts.b_fine));
            fprintf('    on the level curve -- that ratio is the common-mode cancellation.\n');
        end
        zc = find(diff(sign(D)) ~= 0);
        if isempty(zc)
            fprintf('    never crosses zero -> %s wins at every b in range\n', fam.names{1});
        else
            fprintf('    crosses zero at b ~ %s  (below: %s wins; above: %s wins)\n', ...
                strjoin(compose('%.2f', opts.b_fine(zc)), ', '), fam.names{1}, fam.names{end});
        end
    end

    % ------------------------------- [5] value of wealth WITHIN each arm
    if ~isempty(ifree)
        W0f = opts.b_fine + p0.h_mult + 1;
        % V_tilde is normalised -- restore W^(1-gamma) before comparing ACROSS b.
        Vn_abs = W0f.^(1-gamma) .* Vr_d;
        Vf_abs = W0f.^(1-gamma) .* Vd(arms(ifree).file);

        % Cross-arm CEV must be invariant to that factor (W0 cancels).
        d_inv = max(abs(cev(Vd(arms(ifree).file), Vr_d) - cev(Vf_abs, Vn_abs)));
        assert(d_inv < 1e-10, 'welfare_by_wealth:normalisation', ...
            'W0 factor failed to cancel in cross-arm CEV (max diff %.3g).', d_inv);

        Bq = [1 2 3 5 10];
        Bq = Bq(Bq <= opts.b_fine(end));
        at = @(V, x) V(find(abs(opts.b_fine - x) < 1e-9, 1));
        gn = arrayfun(@(x) (at(Vn_abs,x)/Vn_abs(1))^(1/(1-gamma)) - 1, Bq);
        gf = arrayfun(@(x) (at(Vf_abs,x)/Vf_abs(1))^(1/(1-gamma)) - 1, Bq);

        fprintf('\n[5] VALUE OF EXTRA STARTING WEALTH WITHIN EACH ARM (CEV vs own b=0)\n');
        fprintf('    W0^(1-gamma) factor restored -- V_tilde alone is not comparable across b.\n');
        fprintf('    cross-arm CEV invariant to it: max diff %.2g (asserted)\n', d_inv);
        fprintf('    %-18s', 'to b =');      fprintf('%10.1f', Bq); fprintf('\n');
        fprintf('    %-18s', 'no pension');  fprintf('%+9.1f%%', 100*gn); fprintf('\n');
        fprintf('    %-18s', 'free DC');     fprintf('%+9.1f%%', 100*gf); fprintf('\n');
        fprintf('    %-18s', 'gains more:');
        for k = 1:numel(Bq)
            fprintf('%10s', ternary(gn(k) > gf(k), 'no pens', 'free DC'));
        end
        fprintf('\n');
        if gn(end) > gf(end)
            fprintf('    -> no-pension gains MORE from wealth: pension and buffer are SUBSTITUTES,\n');
            fprintf('       so the pension''s relative value FALLS as starting wealth rises.\n');
        else
            fprintf('    -> the DC arm gains MORE from wealth: pension and buffer are COMPLEMENTS\n');
            fprintf('       (the buffer is what makes forced illiquid saving bearable), so the\n');
            fprintf('       pension''s relative value RISES as starting wealth rises.\n');
        end
    end

    % ------------------------------------------------------------- figure
    n_panel = n_panel + 1;
    subplot(1, numel(HOUSING), n_panel); hold on; grid on;
    if ~isempty(ifree)
        plot(opts.b_fine, 100*Gf_d, 'LineWidth', 2, 'DisplayName', 'FREE\_DC');
    end
    for k = [1, numel(fam.files)]
        if numel(fam.files) < 2, break; end
        plot(opts.b_fine, 100*cev(Vd(fam.files{k}), Vr_d), 'LineWidth', 1.4, ...
            'DisplayName', strrep(fam.names{k}, '_', '\_'));
    end
    yl = ylim;
    for bn = [p0.b0, p0.b_alt]
        plot([bn bn], yl, 'k:', 'LineWidth', 1.2, 'HandleVisibility', 'off');
    end
    text(p0.b0, yl(2), '  b0, b\_alt: exact solved nodes', ...
        'VerticalAlignment', 'top', 'FontSize', 8);
    yline(0, 'k-', 'HandleVisibility', 'off');
    xlabel('starting liquid buffer b (years of income)');
    ylabel('CEV vs no pension (%)');
    title(sprintf('%s -- wiggles between nodes are interpolation', h));
    legend('Location', 'best', 'FontSize', 8);
end

if n_panel > 0
    fig_file = fullfile(RES_DIR, 'fig_welfare_vs_starting_wealth.png');
    exportgraphics(fig, fig_file, 'Resolution', 140);
    fprintf('\nFigure saved: %s\n', fig_file);
end
close(fig);
end

%% =======================================================================
function a = read_arm(file, disp_name)
%READ_ARM  welfare0 + the p fields needed, without loading sol/sim.
m    = matfile(file);
w    = m.welfare0;
pk   = m.p;
[fp] = utility.param_fingerprint(pk);
a = struct('name', disp_name, 'file', file, ...
    'b_grid', w.b_grid, 'Vt0_grid', w.Vt0_grid, ...
    'Vt0_b0', w.Vt0_b0, 'Vt0_b_alt', w.Vt0_b_alt, ...
    'fp', fp, 'p', pk);
end

function V = dense_curve(file, b)
%DENSE_CURVE  V_tilde on an arbitrary buffer grid (needs sol.V, hence slow).
m   = matfile(file);
sol = m.sol;
V   = utility.welfare_anchor(m.p, sol.V(:,:,:,1), b);
end

function fam = family_like_for_like(arms, res_dir, housing)
%FAMILY_LIKE_FOR_LIKE  Splines whose knots 2..end are ZERO equity.
%   With p.tau_decum unset, knots at/after the retirement age set the
%   DECUMULATION share, an axis FREE_DC never optimises (its default tau_S is
%   0 from retirement). Only this family differs from FREE_DC in the
%   accumulation glide ALONE, so only it is a like-for-like comparison.
fam = struct('files', {{}}, 'names', {{}}, 'lead', {[]});
is_spl = find(startsWith({arms.name}, 'spl_'));
lead = [];
for k = is_spl
    [~, base] = fileparts(arms(k).file);
    si = load_strat_info(fullfile(res_dir, [base '.mat']));
    if isempty(si) || numel(si.knot_fracs) < 2, continue; end
    if all(si.knot_fracs(2:end) == 0)
        fam.files{end+1} = arms(k).file;
        fam.names{end+1} = arms(k).name;
        lead(end+1)      = si.knot_fracs(1);  %#ok<AGROW>
    end
end
[lead, o]  = sort(lead);
fam.files  = fam.files(o);
fam.names  = fam.names(o);
fam.lead   = lead;
if numel(fam.files) >= 2
    fprintf('    like-for-like family (knots 2+ = 0, i.e. all-bond decumulation\n');
    fprintf('    like FREE_DC): %s\n', strjoin(fam.names, ', '));
end
if isempty(fam.files) && ~isempty(is_spl)
    fprintf('    NOTE: no spline has zero equity at knots 2+, so NO strategy is\n');
    fprintf('    comparable to FREE_DC on the accumulation glide alone (%s).\n', housing);
end
end

function si = load_strat_info(file)
si = [];
if ~isfile(file), return; end
m = matfile(file);
if ismember('strat_info', who(m)), si = m.strat_info; end
end

function n = span_cells(grid_vec, x)
%SPAN_CELLS  Width of [min(x), max(x)] in median grid cells.
n = (max(x) - min(x)) / median(diff(grid_vec));
end

function n = n_turning(y)
%N_TURNING  Local extrema of a curve that theory says should be smooth.
n = sum(diff(sign(diff(y))) ~= 0);
end

function r = roughness(y, b)
%ROUGHNESS  Grid-scale ripple: max deviation from a locally smoothed trend.
%   The window spans ~0.5 years of buffer, comfortably wider than one
%   lambda/sH cell, so a genuine economic trend survives the smoothing and
%   only the interpolation kinks show up in the residual.
w = max(3, round(0.5 / median(diff(b))));
r = max(abs(y - movmean(y, w)));
end

function out = ternary(cond, a, b)
    if cond, out = a; else, out = b; end
end
