function S = spline_menu(opts)
%SPLINE_MENU  A menu of spline glide paths with different stock and REIT mixes.
%
%   S = model.spline_menu()                                   % the default menu, 84 strategies
%   S = model.spline_menu(young=[0.8 1], at67=[0.2 0.4], reit=[0 0.5])
%
%   Each strategy is a glide_rule 'knots' fund (config.derive: pchip through
%   the knots, flat outside) with knots at 25, 39, 67 and 100:
%     the risky share `young` from 25 to 39 (as production holds 80% to 39),
%     `at67` at 67, and at 100 either the same (tail "hold") or 0 ("zero"),
%   and a fixed fraction `reit` of the risky share in the REIT, the rest in
%   stocks. With at67 = 0 the two tails are the same fund and only "hold" is
%   kept. Every combination of the four lists is one strategy, ordered with
%   the REIT fractions outermost in the order given, so that a run cut short
%   by its deadline misses whole REIT blocks, not scattered points.
%
%   Names are s<young>_<at67><h|z>_r<reit> in percent, e.g. s80_20h_r50: 80%
%   risky to 39, 20% at 67, held to 100, half of the risky share in the REIT.
%   For model.strategies; the reference (production) is not in the menu.
%
%   A search grid (17 November 2026), no data source for any point.

arguments
    opts.young (1,:) double {mustBeInRange(opts.young, 0, 1)} = [0.6 0.8 1.0]
    opts.at67  (1,:) double {mustBeInRange(opts.at67, 0, 1)}  = [0 0.2 0.4 0.6]
    opts.tail  (1,:) string {mustBeMember(opts.tail, ["hold", "zero"])} = ["hold", "zero"]
    opts.reit  (1,:) double {mustBeInRange(opts.reit, 0, 1)}  = [0.5 0 0.25 0.75]
end

S = struct('name', {}, 'label', {}, 'set', {});
for f = opts.reit
    for y = opts.young
        for m = opts.at67
            for tl = opts.tail
                if m == 0 && tl == "zero", continue, end
                e = m; if tl == "zero", e = 0; end
                r = [y; y; m; e];                     % risky share at 25, 39, 67, 100
                K = [[25; 39; 67; 100], r * (1 - f), r * f];
                name = sprintf('s%d_%d%s_r%d', round(100 * y), round(100 * m), extractBefore(tl, 2), round(100 * f));
                tail_txt = 'held to 100'; if tl == "zero", tail_txt = 'to 0 at 100'; end
                if m == 0, tail_txt = 'none after'; end
                label = sprintf('%d%% risky to 39, %d%% at 67, %s; %d%% of risky in REIT', ...
                    round(100 * y), round(100 * m), tail_txt, round(100 * f));
                S(end+1) = struct('name', name, 'label', label, ...
                    'set', struct('glide_rule', 'knots', 'glide_knots', K)); %#ok<AGROW>
            end
        end
    end
end
end
