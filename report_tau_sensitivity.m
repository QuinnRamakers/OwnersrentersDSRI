function S = report_tau_sensitivity(results_dir, opts)
%REPORT_TAU_SENSITIVITY  Welfare gradient from tau_bump_sensitivity runs.
%
%   report_tau_sensitivity
%   report_tau_sensitivity('D:\downloads\all')
%   S = report_tau_sensitivity('', anchor="b_alt")
%
%   For each bumped age, reports the consumption-equivalent welfare change from
%   holding more and less equity at that age alone, and the slope per unit of
%   equity share:
%
%       g     = (V_bump / V_baseline)^(1/(1-gamma)) - 1
%       slope = 100 * g / (realised change in tau)   [CEV points per unit tau]
%
%   The divisor is the realised change rather than the nominal delta: near
%   tau = 0 or 1 the bump is clamped, so the nominal step would overstate what
%   was done. Runs clamped to no change are dropped.
%
%   Verdict column:
%     optimum    both directions lower welfare
%     add risk   more equity raises welfare
%     cut risk   less equity raises welfare
%     both up    neither direction lowers welfare, so the response is not
%                locally concave. The bump is within solver noise and the age
%                carries no signal until re-run with a larger delta.
%
%   Welfare defaults to the b0 anchor. b0 and b_alt are the only buffers
%   config.insert_anchor_nodes places on the grid as exact nodes; anywhere else
%   V_tilde is interpolated, and that ripple is comparable in size to the
%   welfare differences measured here (see welfare_by_wealth).
%
%   Writes tau_sensitivity_{housing}.csv and fig_tau_sensitivity.png.

arguments
    results_dir {mustBeTextScalar} = ''
    opts.tag (1,1) string = ""      % "" = auto (errors if the folder mixes tags)
    opts.anchor (1,1) string ...
        {mustBeMember(opts.anchor, ["corner","b0","b_alt"])} = "b0"
end

RES_DIR = char(results_dir);
if isempty(RES_DIR), RES_DIR = utility.output_dir(); end
assert(isfolder(RES_DIR), 'report_tau_sensitivity:nodir', 'Not a folder: %s', RES_DIR);

S = table();
fig = figure('Visible','off', 'Position',[80 80 1150 460]);
np  = 0;
HOUSING = {'renter','owner'};

for hi = 1:numel(HOUSING)
    h = HOUSING{hi};
    L = dir(fullfile(RES_DIR, sprintf('bump_*_%s.mat', h)));
    if isempty(L)
        fprintf('\n-- %s: no bump_*_%s.mat files in %s --\n', h, h, RES_DIR); continue
    end

    E = struct('age',{},'sgn',{},'d',{},'V',{},'fp',{},'gamma',{},'tag',{}, ...
               'is_base',{},'file',{},'tau_base',{});
    for k = 1:numel(L)
        m  = matfile(fullfile(L(k).folder, L(k).name));
        bi = m.bump_info;  w = m.welfare0;  pk = m.p;
        switch char(opts.anchor)
            case 'corner', V = w.Vt0;
            case 'b0',     V = w.Vt0_b0;
            case 'b_alt',  V = w.Vt0_b_alt;
        end
        E(end+1) = struct('age', bi.age, 'sgn', bi.sign, 'd', bi.delta_total, ...
            'V', V, 'fp', utility.param_fingerprint(pk), 'gamma', pk.gamma, ...
            'tag', string(bi.tag), 'is_base', logical(bi.is_baseline), ...
            'file', L(k).name, 'tau_base', bi.tau_base); %#ok<AGROW>
    end

    tags = unique([E.tag]);
    if opts.tag ~= ""
        E = E([E.tag] == opts.tag);
        assert(~isempty(E), 'report_tau_sensitivity:tag', ...
            'No %s files with tag "%s".', h, opts.tag);
    else
        assert(isscalar(tags), 'report_tau_sensitivity:mixedtags', ...
            ['This folder holds bump runs from %d different baselines (%s). ' ...
             'Gradients are relative to their own baseline, so pass tag="..." ' ...
             'to pick one.'], numel(tags), strjoin(cellstr(tags), ', '));
    end

    ufp = unique({E.fp});
    assert(isscalar(ufp), 'report_tau_sensitivity:mismatch', ...
        ['Bump files for %s come from %d different grids/calibrations -- their ' ...
         'V_tilde values are not comparable. Delete the stale ones and re-run.'], ...
        h, numel(ufp));

    ib = find([E.is_base], 1);
    assert(~isempty(ib), 'report_tau_sensitivity:nobase', ...
        ['No baseline run (bump_%s_base_%s.mat) for %s -- the gradient is ' ...
         'measured against it, so it must be solved too.'], char(tags(1)), h, h);
    Vb    = E(ib).V;
    gamma = E(ib).gamma;
    cev   = @(V) (V / Vb)^(1/(1-gamma)) - 1;

    B = E(~[E.is_base]);
    ages = unique([B.age]);
    rows = cell(numel(ages), 1);

    fprintf('\n%s\n-- %s: welfare response to a one-age change in tau (baseline %s) --\n', ...
        repmat('=',1,86), h, char(tags(1)));
    fprintf('   welfare read at %s;  CEV in %% of lifetime consumption\n', anchor_text(opts.anchor, E(ib)));
    fprintf('   slope is CEV points per unit of tau; CEV columns are the raw change\n');
    fprintf('   %5s %9s %10s %10s %12s %12s   %s\n', ...
        'age', 'tau_base', 'CEV +', 'CEV -', 'slope +', 'slope -', 'verdict');
    for k = 1:numel(ages)
        a  = ages(k);
        bp = B([B.age] == a & [B.sgn] > 0);
        bm = B([B.age] == a & [B.sgn] < 0);
        [gp, sp] = one_side(bp, cev);
        [gm, sm] = one_side(bm, cev);
        tb = E(ib).tau_base(a - anchor_age0(E(ib)) + 1);
        v  = verdict(gp, gm);
        fprintf('   %5d %9.3f %9.3f%% %9.3f%% %12.2f %12.2f   %s\n', ...
            a, tb, 100*gp, 100*gm, sp, sm, v);
        rows{k} = table(string(h), a, tb, 100*gp, 100*gm, sp, sm, string(v), ...
            'VariableNames', {'housing','age','tau_base','cev_plus_pct', ...
                              'cev_minus_pct','slope_plus','slope_minus','verdict'});
    end
    Th = vertcat(rows{:});
    S  = [S; Th]; %#ok<AGROW>
    writetable(Th, fullfile(RES_DIR, sprintf('tau_sensitivity_%s.csv', h)));

    % Which ages matter most: biggest absolute welfare response either way.
    resp = max(abs([Th.cev_plus_pct, Th.cev_minus_pct]), [], 2);
    [~, o] = sort(resp, 'descend');
    fprintf('   ages ranked by how much welfare moves at all: %s\n', ...
        strjoin(compose('%d (%.2f%%)', Th.age(o(1:min(4,end))), resp(o(1:min(4,end)))), ', '));

    np = np + 1;
    subplot(1, 2, hi); hold on; grid on;
    plot(Th.age, Th.slope_plus,  '-o', 'LineWidth', 1.6, 'DisplayName', 'slope, more equity');
    plot(Th.age, Th.slope_minus, '-s', 'LineWidth', 1.6, 'DisplayName', 'slope, less equity');
    yline(0, 'k-', 'HandleVisibility','off');
    xlabel('age of the bumped year'); ylabel('CEV per unit of \tau');
    title(sprintf('%s: welfare gradient in one-age equity risk', h));
    legend('Location','best','FontSize',8);
end

if np > 0
    out = fullfile(RES_DIR, 'fig_tau_sensitivity.png');
    exportgraphics(fig, out, 'Resolution', 140);
    fprintf('\nFigure saved: %s\n', out);
else
    fprintf('\nNo bump files found -- run tau_bump_sensitivity first.\n');
end
close(fig);
end

%% =======================================================================
function [g, slope] = one_side(b, cev)
%ONE_SIDE  CEV and per-unit slope for one direction, NaN if absent/clamped.
g = NaN; slope = NaN;
if isempty(b), return; end
g = cev(b(1).V);
if abs(b(1).d) > 1e-12, slope = 100 * g / b(1).d; end
end

function v = verdict(gp, gm)
if isnan(gp) || isnan(gm), v = '(need both signs)'; return; end
up = [gp > 0, gm > 0];
if      all(up),      v = 'both up (no signal)';
elseif  ~any(up),     v = 'optimum';
elseif  up(1),        v = 'add risk';
else,                 v = 'cut risk';
end
end

function a0 = anchor_age0(e)
%ANCHOR_AGE0  age0 implied by the stored baseline path length is not reliable;
% the bump files all come from one config.params, so read it back off that.
p = config.params();
a0 = p.age0;
if numel(e.tau_base) ~= p.T - 1
    warning('report_tau_sensitivity:age0', ...
        ['Stored tau_base has %d entries but the current config.params gives ' ...
         'T-1 = %d -- ages may be misaligned if config.params changed since ' ...
         'the solve.'], numel(e.tau_base), p.T - 1);
end
end

function s = anchor_text(a, e)
switch char(a)
    case 'corner', s = 'the b = 0 corner (interpolated, not an exact node)';
    case 'b0',     s = 'the calibrated buffer b0 (an exact grid node)';
    case 'b_alt',  s = 'the sensitivity buffer b_alt (an exact grid node)';
end
if isfield(e, 'gamma'), s = sprintf('%s, gamma = %g', s, e.gamma); end
end
