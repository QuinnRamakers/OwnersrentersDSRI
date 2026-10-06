function [logY, mu_growth, sigma_l_log] = income_profile(p)
%Income profile construction
%
%   'table' -- Look up of the income profile of Been et al

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
        % the slope of the first three data points (ages 24-27). in case T0
        % is an age before 24
        early_slope = (growth(4) - growth(1)) / (tbl_ages(4) - tbl_ages(1));
        lo_ages     = (min(work_ages) : (tbl_ages(1) - 1)).';
        lo_growth   = growth(1) + early_slope * (lo_ages - tbl_ages(1));

        % Ages above 64 set to 64 as they have no data on this, and the
        % trend is decreasing which would give very strong results 
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

        % Convert process into nominal euros series for contribution rate
        % calculation later
        switch p.sex
            case 1
                anchor_age = 25; anchor_level = 33000;
            case 2
                anchor_age = 25; anchor_level = 30000;
            case 3
                anchor_age = 25; anchor_level = (33000 + 30000) / 2;  
        end
        if isfield(p, 'income_price_factor')
            anchor_level = anchor_level * p.income_price_factor;
        end
        anchor_idx = find(all_ages == anchor_age, 1);
        logY_work  = log(anchor_level) + (growth_at_work_ages - all_growth(anchor_idx));

    otherwise
        error('income_profile:source', 'p.income_source must be ''poly'' or ''table''.');
end

logY = nan(T, 1);
logY(work_idx) = logY_work;
%post retirement constant
logY(t_ret) = logY(t_ret - 1) + log(p.replacement);
for t = (t_ret + 1) : T
    logY(t) = logY(t - 1);
end

mu_growth                = diff(logY);
sigma_l_log              = p.sigma_l_log * ones(T - 1, 1);
% growth and variance after retirement should be zero
sigma_l_log(t_ret - 1 : end) = 0;

end
