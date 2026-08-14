function T = tau_policy_profile(results_dir, opts)
%TAU_POLICY_PROFILE  Distribution of the freely chosen DC equity share by age.
%
%   tau_policy_profile
%   T = tau_policy_profile('D:\downloads\all')
%   tau_policy_profile('', overlay=["spl_000_000_000","spl_100_000_000"])
%
%   Reads sim.tau_A from combined_{housing}_freetau.mat and reports percentiles
%   of the chosen equity share at each age, with imposed glide paths overlaid.
%   Nothing is re-solved.
%
%   An imposed spline is a function of age alone, while the free arm's tau is a
%   function of the state, so at a given age it is a distribution. The p10-p90
%   spread is the part of the free policy no glide path can reproduce, which is
%   why it is reported next to the median rather than only a mean. The mean
%   alone is also a survivors' statistic, weighted toward households whose DC
%   pot did well, whereas the value function under gamma = 5 is driven by the
%   branches where the free household cuts tau hard.
%
%   Households count while alive (C > 0); the dead carry C = 0 for the rest of
%   the panel and would drag the profile toward zero. Rows at or after
%   p.retirement_age are flat because config.tau_effective pins the share to
%   p.tau_decum once retired, so they report the decumulation setting rather
%   than a choice.
%
%   Returns the table, writes tau_policy_profile_{housing}.csv and
%   fig_tau_policy_profile.png.

arguments
    results_dir {mustBeTextScalar} = ''
    opts.housing (1,1) string ...
        {mustBeMember(opts.housing, ["renter","owner","both"])} = "both"
    opts.overlay (1,:) string = ["spl_000_000_000", "spl_100_000_000"]
    opts.ages    (1,:) double = []      % default: every age in the solution
end

RES_DIR = char(results_dir);
if isempty(RES_DIR), RES_DIR = utility.output_dir(); end
assert(isfolder(RES_DIR), 'tau_policy_profile:nodir', 'Not a folder: %s', RES_DIR);

if opts.housing == "both", HOUSING = {'renter','owner'};
else,                      HOUSING = {char(opts.housing)};
end

fig = figure('Visible','off', 'Position',[80 80 1150 460]);
T   = table();
np  = 0;

for hi = 1:numel(HOUSING)
    h = HOUSING{hi};
    f = fullfile(RES_DIR, sprintf('combined_%s_freetau.mat', h));
    if ~isfile(f)
        fprintf('\n-- %s: %s not found -- skipping.\n', h, f); continue
    end

    m   = matfile(f);
    pk  = m.p;
    sim = m.sim;
    assert(isfield(sim, 'tau_A'), 'tau_policy_profile:notau', ...
        ['%s has no sim.tau_A -- it predates the free-tau feature, so there ' ...
         'is no chosen share to profile.'], f);

    ages_all = pk.age0 : pk.age0 + size(sim.tau_A, 2) - 1;
    ages = opts.ages;
    if isempty(ages), ages = ages_all; end
    ages = ages(ismember(ages, ages_all));

    % Dead households carry C = 0 for the rest of the panel; averaging their
    % tau in would drag the profile toward zero where mortality bites hardest.
    alive = sim.C > 0;

    q = nan(numel(ages), 5);
    for k = 1:numel(ages)
        t  = ages(k) - pk.age0 + 1;
        x  = sim.tau_A(alive(:,t), t);
        x  = x(~isnan(x));
        if isempty(x), continue; end
        q(k,1:3) = prctile(x, [10 50 90]);
        q(k,4)   = q(k,3) - q(k,1);
        q(k,5)   = mean(x);
    end

    t_ret_age = pk.retirement_age;
    fprintf('\n%s\n-- %s: free-choice tau by age (%d households, alive only) --\n', ...
        repmat('=',1,78), h, size(sim.tau_A,1));
    fprintf('   retirement age %d: rows at/after it are pinned by p.tau_decum, not chosen\n', t_ret_age);
    fprintf('   %5s %8s %8s %8s %10s %8s\n', 'age', 'p10', 'p50', 'p90', 'p90-p10', 'mean');
    show = ages(mod(ages - ages(1), 5) == 0 | ages == t_ret_age - 1 | ages == t_ret_age);
    for k = find(ismember(ages, show))
        star = '';
        if ages(k) >= t_ret_age, star = '  (retired: not a choice)'; end
        fprintf('   %5d %8.3f %8.3f %8.3f %10.3f %8.3f%s\n', ...
            ages(k), q(k,1), q(k,2), q(k,3), q(k,4), q(k,5), star);
    end

    work = ages < t_ret_age;
    fprintf('   working life: mean p90-p10 spread = %.3f\n', mean(q(work,4), 'omitnan'));
    fprintf('   that spread is the state-contingency an age-only glide path cannot express\n');

    Th = table(repmat(string(h), numel(ages), 1), ages(:), q(:,1), q(:,2), q(:,3), q(:,4), q(:,5), ...
        'VariableNames', {'housing','age','tau_p10','tau_p50','tau_p90','tau_spread','tau_mean'});
    T = [T; Th]; %#ok<AGROW>
    writetable(Th, fullfile(RES_DIR, sprintf('tau_policy_profile_%s.csv', h)));

    % ------------------------------------------------------------- figure
    np = np + 1;
    subplot(1, numel(HOUSING), np); hold on; grid on;
    band = [q(:,1); flipud(q(:,3))];
    fill([ages(:); flipud(ages(:))], band, [0.2 0.4 0.8], ...
        'FaceAlpha', 0.15, 'EdgeColor','none', 'DisplayName','free tau p10-p90');
    plot(ages, q(:,2), 'LineWidth', 2, 'DisplayName', 'free tau median');
    for s = opts.overlay
        fo = fullfile(RES_DIR, sprintf('%s_%s.mat', s, h));
        if ~isfile(fo), continue; end
        mo = matfile(fo);
        po = mo.p;
        ao = po.age0 : po.age0 + numel(po.tau_S) - 1;
        plot(ao, po.tau_S, '--', 'LineWidth', 1.3, ...
            'DisplayName', strrep(char(s), '_', '\_'));
    end
    xline(t_ret_age, 'k:', 'HandleVisibility','off');
    text(t_ret_age, 1.02, ' retirement', 'FontSize', 8);
    xlabel('age'); ylabel('DC equity share \tau');
    ylim([-0.05 1.10]);
    title(sprintf('%s: free choice is a DISTRIBUTION, not a path', h));
    legend('Location','southwest', 'FontSize', 7);
end

if np > 0
    out = fullfile(RES_DIR, 'fig_tau_policy_profile.png');
    exportgraphics(fig, out, 'Resolution', 140);
    fprintf('\nFigure saved: %s\n', out);
end
close(fig);
end
