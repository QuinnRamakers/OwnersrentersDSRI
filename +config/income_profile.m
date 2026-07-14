function [logY, mu_growth, sigma_l_log] = income_profile(p)
%INCOME_PROFILE  Deterministic log-income path and growth/shock vectors.
%
%   logY        T x 1   log income at each life period
%   mu_growth   (T-1)x1 deterministic log-income growth t -> t+1
%   sigma_l_log (T-1)x1 std dev of log-income shock at each transition
%                       (zero for t >= retirement)
%
%   Post-retirement income is the FIRST-PILLAR (AOW) only:
%       y_R = p.replacement * Y_{T_R - 1}
%   The DC second pillar is added separately in the Bellman / simulation,
%   so p.replacement should be calibrated as the AOW-only replacement
%   rate (Dutch context: ~0.30-0.40 of modal gross income), NOT the total
%   target replacement rate.
%
%   Working-age SHAPE, selected by p.income_source:
%
%   'poly'  -- third-order-in-age cubic, p.income_coef = [a1 a2 a3 a4]:
%              logY = a1 + a2*age + a3*age^2/100 + a4*age^3/1e4.
%              Currently a CGM (2005, RFS) high-school-group placeholder
%              (see params.m / TODO.md) -- US data, fitted, not Dutch.
%
%   'table' -- DIRECT lookup of the semi-parametric age-effect estimates
%              in Been, Knoef & Vethaak (2026, JBES 44(1):215-226),
%              Online Appendix Tables D.1 (men) / D.2 (women),
%              "Full-time, Selection" column. No cubic-fitting step, no
%              smoothing: ages 24-64 get their exact published
%              coefficient. Selected by p.sex (1=men, 2=women,
%              3=pooled -- currently a plain mean of the two published
%              series, NOT participation-weighted; see TODO.md).
%              Ages below 24 are outside the paper's estimation sample
%              (24-64) and would be linearly extrapolated using the slope
%              of the first three observed points (ages 24-27) -- a
%              placeholder assumption, not an estimate. With the current
%              default p.age0=25 this extrapolation path is never
%              exercised (work_ages starts one year past the table's own
%              reference age); it stays in the code as a guard for any
%              p.age0 < 24 configuration.
%              Ages above 64 (relevant once p.retirement_age > 65, e.g.
%              the current default of 67) are likewise outside the
%              sample and are held FLAT at the age-64 growth value --
%              i.e. zero further deterministic income growth from 64
%              onward, per user decision (not a linear extrapolation of
%              the pre-64 decline, which is unreliable this close to the
%              edge of the sample).

T     = p.T;
t_ret = p.t_ret;
ages  = (p.age0 : p.age0 + T - 1).';

work_idx  = 1 : (t_ret - 1);
work_ages = ages(work_idx);

switch p.income_source
    case 'poly'
        a = p.income_coef;
        logY_work = a(1) ...
                  + a(2) .* work_ages ...
                  + a(3) .* (work_ages.^2) / 100 ...
                  + a(4) .* (work_ages.^3) / 1e4;

    case 'table'
        [tbl_ages, g_men, g_women] = config.income_table_bkv();
        switch p.sex
            case 1
                growth = g_men;
            case 2
                growth = g_women;
            case 3
                growth = (g_men + g_women) / 2;  % plain mean -- see TODO.md
            otherwise
                error('income_profile:sex', 'p.sex must be 1, 2, or 3 for p.income_source=''table''.');
        end

        % Extrapolate below the paper's youngest observed age (24) using
        % the slope of the first three data points (ages 24-27).
        early_slope = (growth(4) - growth(1)) / (tbl_ages(4) - tbl_ages(1));
        lo_ages     = (min(work_ages) : (tbl_ages(1) - 1)).';
        lo_growth   = growth(1) + early_slope * (lo_ages - tbl_ages(1));

        % Extrapolate above the paper's oldest observed age (64): FLAT
        % continuation at the age-64 growth value (zero further growth),
        % not a linear extension of the pre-64 slope -- see docstring.
        hi_ages   = ((tbl_ages(end) + 1) : max(work_ages)).';
        hi_growth = growth(end) * ones(size(hi_ages));

        all_ages   = [lo_ages; tbl_ages; hi_ages];
        all_growth = [lo_growth; growth; hi_growth];

        if max(work_ages) > max(all_ages)
            error('income_profile:tableGap', ...
                'work_ages extend past age 64; table + extrapolation do not cover them.');
        end
        [tf, loc] = ismember(work_ages, all_ages);
        assert(all(tf), 'income_profile:tableGap', ...
            'work_ages not fully covered by table + extrapolation.');
        growth_at_work_ages = all_growth(loc);

        % Anchor: absolute euro level at age 25, from Been et al.
        % Section 3.2.3 descriptives (full-time average wage by sex).
        % Shifts the whole (relative) growth series to pass through it.
        switch p.sex
            case 1
                anchor_age = 25; anchor_level = 33000;
            case 2
                anchor_age = 25; anchor_level = 30000;
            case 3
                anchor_age = 25; anchor_level = (33000 + 30000) / 2;  % see TODO.md
        end
        anchor_idx = find(all_ages == anchor_age, 1);
        logY_work  = log(anchor_level) + (growth_at_work_ages - all_growth(anchor_idx));

    otherwise
        error('income_profile:source', 'p.income_source must be ''poly'' or ''table''.');
end

logY = nan(T, 1);
logY(work_idx) = logY_work;

logY(t_ret) = logY(t_ret - 1) + log(p.replacement);
for t = (t_ret + 1) : T
    logY(t) = logY(t - 1);
end

mu_growth                = diff(logY);
sigma_l_log              = p.sigma_l_log * ones(T - 1, 1);
% The retirement transition step (t_ret-1 -> t_ret) is DETERMINISTIC: AOW is
% replacement * Y_{t_ret-1} with no shock. Simulator implements it that way;
% solver must agree, so we zero out sigma here as well as in retirement itself.
sigma_l_log(t_ret - 1 : end) = 0;

end
