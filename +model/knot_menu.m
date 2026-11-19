function S = knot_menu(opts)
%KNOT_MENU  Spline funds through free risky shares at 25, mid-career and 67.
%
%   S = model.knot_menu()                                   % the default grid, 108 strategies
%   S = model.knot_menu(at25=[0.8 1], mid=[0.6 0.8], at67=0.2, reit=[0.5 0.75])
%
%   Each strategy is a glide_rule 'knots' fund (config.derive: pchip through
%   the knots, flat outside) with knots at 25, mid_age (46, halfway to 67),
%   67 and 100: the risky share `at25` at 25, `mid` at mid_age, `at67` at
%   67, and at 100 either the same as at 67 (tail "hold") or 0 ("zero"); a
%   fixed fraction `reit` of the risky share in the REIT, the rest in stocks.
%   Unlike model.spline_menu, the share need not be flat to 39 and may rise
%   before it falls. With at67 = 0 only "hold" is kept. Every combination is
%   one strategy, the REIT fractions outermost in the order given.
%
%   Names are k<at25>_<mid>_<at67><h|z>_r<reit> in percent, e.g.
%   k100_70_20z_r75: 100% risky at 25, 70% at 46, 20% at 67 falling to 0 at
%   100, three quarters of the risky share in the REIT.
%
%   A search grid (19 November 2026) around the best funds of model.spline_menu
%   on the medium grid (20% risky at 67, half to three quarters REIT); no data
%   source for any point.

arguments
    opts.at25 (1,:) double {mustBeInRange(opts.at25, 0, 1)} = [0.8 1.0]
    opts.mid  (1,:) double {mustBeInRange(opts.mid, 0, 1)}  = [0.5 0.7 0.9]
    opts.at67 (1,:) double {mustBeInRange(opts.at67, 0, 1)} = [0.1 0.2 0.3]
    opts.mid_age (1,1) double {mustBeInRange(opts.mid_age, 26, 66)} = 46
    opts.tail (1,:) string {mustBeMember(opts.tail, ["hold", "zero"])} = ["hold", "zero"]
    opts.reit (1,:) double {mustBeInRange(opts.reit, 0, 1)} = [0.75 0.5 1.0]
end

S = struct('name', {}, 'label', {}, 'set', {});
for f = opts.reit
    for a = opts.at25
        for m = opts.mid
            for e67 = opts.at67
                for tl = opts.tail
                    if e67 == 0 && tl == "zero", continue, end
                    e100 = e67; if tl == "zero", e100 = 0; end
                    r = [a; m; e67; e100];                     % risky share at 25, mid_age, 67, 100
                    K = [[25; opts.mid_age; 67; 100], r * (1 - f), r * f];
                    name = sprintf('k%d_%d_%d%s_r%d', round(100 * a), round(100 * m), round(100 * e67), ...
                        extractBefore(tl, 2), round(100 * f));
                    tail_txt = 'held to 100'; if tl == "zero", tail_txt = 'to 0 at 100'; end
                    if e67 == 0, tail_txt = 'none after'; end
                    label = sprintf('%d%% risky at 25, %d%% at %d, %d%% at 67, %s; %d%% of risky in REIT', ...
                        round(100 * a), round(100 * m), opts.mid_age, round(100 * e67), tail_txt, round(100 * f));
                    S(end+1) = struct('name', name, 'label', label, ...
                        'set', struct('glide_rule', 'knots', 'glide_knots', K)); %#ok<AGROW>
                end
            end
        end
    end
end
end
