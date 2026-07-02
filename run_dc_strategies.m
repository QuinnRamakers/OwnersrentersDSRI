% RUN_DC_STRATEGIES  Sweep fixed DC pension equity-allocation rules, crossed
% with renter/owner housing, using the current combined pension+housing model.
%
%   Each strategy overrides the solved-for glide path p.tau_S with a fixed,
%   exogenous rule; the household's own (c,pi) choice is still solved
%   optimally given that rule. Crossed with renter/owner -> 10 x 2 = 20 runs.
%
%   Output files:  dc_{strategy}_{renter|owner}.mat
%   Log file:      dc_strategies_log.txt  (appended, not overwritten)
%
%   Resume-safe: any scenario whose .mat file already exists is skipped, so
%   this is safe to leave running (or restart) unattended on the cluster.
%
%   To add/edit a strategy, edit the STRATS table below.

clear; clc;

LOG_FILE = 'dc_strategies_log.txt';
N_SIM    = 5000;

%% -----------------------------------------------------------------------
%% Strategy table  {name, description, type, param}
%% -----------------------------------------------------------------------
%   Types:
%     'zeros'        : 0% equity throughout
%     'fixed_life'   : param = constant equity fraction, all ages
%     'age_rule_flat': param = K; tau = (K-age)/100 (capped [0,1]) while
%                      working, held flat at the retirement-age level after
%     'target_date'  : param = glide_years; 100% equity until glide_years
%                      before retirement, linear glide to 0% at retirement,
%                      0% thereafter
%     'default'      : leave config.params()'s own glide path untouched
STRATS = {
    'riskfree',         'Risk-free DC (0% equity throughout)',                    'zeros',         NaN;
    'equity_25',        'Constant 25% equity for life',                          'fixed_life',    0.25;
    'equity_50',        'Constant 50% equity for life',                          'fixed_life',    0.50;
    'equity_75',        'Constant 75% equity for life',                          'fixed_life',    0.75;
    'equity_life',      'Constant 100% equity for life',                         'fixed_life',    1.00;
    'rule_100age_flat', '(100-age)% rule; flat at retirement level thereafter',  'age_rule_flat', 100;
    'rule_110age_flat', '(110-age)% rule (capped 100%); flat after',             'age_rule_flat', 110;
    'rule_120age_flat', '(120-age)% rule (capped 100%); flat after',             'age_rule_flat', 120;
    'target_date_10y',  '100% equity to 10y pre-retirement, linear glide to 0',  'target_date',   10;
    'baseline_glide',   'Model default glide path (0.8@30 -> 0 at retirement)',  'default',       NaN;
};

HOUSING = {'renter', 'owner'};

%% -----------------------------------------------------------------------
%% Parallel pool (start once, reused across all 20 runs)
%% -----------------------------------------------------------------------
if isempty(gcp('nocreate'))
    try
        parpool('Threads');
    catch
        try
            parpool('local');
        catch
            warning('parpool failed; running serial');
        end
    end
end

%% -----------------------------------------------------------------------
%% Log header
%% -----------------------------------------------------------------------
n_total = size(STRATS,1) * numel(HOUSING);
lprintf(LOG_FILE, '\n%s\n', repmat('=',1,65));
lprintf(LOG_FILE, 'run_dc_strategies  start: %s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS'));
lprintf(LOG_FILE, 'Strategies: %d  x  Housing: %d  =  %d runs total\n', ...
    size(STRATS,1), numel(HOUSING), n_total);
lprintf(LOG_FILE, '%s\n\n', repmat('-',1,65));

%% -----------------------------------------------------------------------
%% Main loop
%% -----------------------------------------------------------------------
t_wall   = tic;
manifest = {};

for si = 1:size(STRATS,1)
    s_name = STRATS{si,1};
    s_desc = STRATS{si,2};
    s_type = STRATS{si,3};
    s_par  = STRATS{si,4};

    for hi = 1:numel(HOUSING)
        housing  = HOUSING{hi};
        out_file = sprintf('dc_%s_%s.mat', s_name, housing);

        if isfile(out_file)
            lprintf(LOG_FILE, 'SKIP   %s  (file exists)\n', out_file);
            continue
        end

        lprintf(LOG_FILE, '\n--- %s | %s\n', s_name, housing);
        lprintf(LOG_FILE, '    %s\n', s_desc);
        t_sc = tic;

        %% Build params and tau_S override
        p = config.params();
        p.is_owner = strcmp(housing, 'owner');

        ages = (p.age0 : p.age0 + p.T - 2).';   % length T-1, one entry per transition
        switch s_type
            case 'zeros'
                p.tau_S = zeros(p.T-1, 1);
            case 'fixed_life'
                p.tau_S = repmat(s_par, p.T-1, 1);
            case 'age_rule_flat'
                K = s_par;
                ret_level = max(0, min(1, (K - p.retirement_age) / 100));
                tau = max(0, min(1, (K - ages) / 100));
                tau(ages >= p.retirement_age) = ret_level;
                p.tau_S = tau;
            case 'target_date'
                gy = s_par;
                glide_start = p.retirement_age - gy;
                tau = ones(p.T-1, 1);
                in_glide = ages >= glide_start & ages < p.retirement_age;
                tau(in_glide) = (p.retirement_age - ages(in_glide)) / gy;
                tau(ages >= p.retirement_age) = 0;
                p.tau_S = tau;
            case 'default'
                % leave config.params()'s own tau_S untouched
            otherwise
                error('run_dc_strategies:badtype', 'Unknown strategy type: %s', s_type);
        end

        idx = @(a) a - p.age0 + 1;  % age -> 1-based index into tau_S
        lprintf(LOG_FILE, '    tau_S: age20=%.2f  age40=%.2f  age64=%.2f  age66=%.2f\n', ...
            p.tau_S(idx(20)), p.tau_S(idx(40)), p.tau_S(idx(64)), p.tau_S(idx(66)));

        %% Shared inputs
        [~, mu_growth, sigma_l_log] = config.income_profile(p);
        profile.mu_growth   = mu_growth;
        profile.sigma_l_log = sigma_l_log;
        profile.p_surv      = config.survival(p);
        shocks    = grids.shock_grid(p);
        ann_price = pension.annuity_price(p, profile, shocks);

        %% Solve
        sol = solver.solve_lifecycle(p, profile, shocks, ann_price);
        lprintf(LOG_FILE, '    Solver: %.1f s\n', sol.elapsed);

        %% Simulate
        t_sim = tic;
        sim = simulate.paths(p, profile, sol, ann_price, N_SIM);
        sim_elapsed = toc(t_sim);
        lprintf(LOG_FILE, '    Simulated %d households in %.1f s\n', N_SIM, sim_elapsed);

        %% Diagnostic summary at key ages
        lprintf(LOG_FILE, '    age  meanPi  meanC   meanA   meanH\n');
        for a = [30, 50, 65, 75]
            t = a - p.age0 + 1;
            if t < 1 || t > p.T, continue; end
            lprintf(LOG_FILE, '    %3d  %5.3f  %6.3f  %6.3f  %6.3f\n', ...
                a, mean(sim.pi(:,t)), mean(sim.C(:,t)), mean(sim.A(:,t)), mean(sim.H(:,t)));
        end

        %% Save -- timing carries per-period, per-run, and sim timing for the
        %% cross-run runtime analysis in analyze_dc_strategies_timing.m
        strat_info      = struct('name',s_name,'desc',s_desc,'type',s_type,'param',s_par,'housing',housing);
        timing          = sol.timing;
        timing.sim_sec  = sim_elapsed;
        timing.strategy = s_name;
        timing.housing  = housing;
        save(out_file, 'p','profile','shocks','ann_price','sol','sim','strat_info','timing', '-v7.3');
        elapsed_sc = toc(t_sc);
        lprintf(LOG_FILE, '    Saved %-38s  (%.1f min)\n', out_file, elapsed_sc/60);

        manifest{end+1} = {out_file, s_name, housing, elapsed_sc/60};  %#ok<AGROW>
    end
end

%% -----------------------------------------------------------------------
%% Footer
%% -----------------------------------------------------------------------
elapsed_total = toc(t_wall);
lprintf(LOG_FILE, '\n%s\n', repmat('=',1,65));
lprintf(LOG_FILE, 'DONE  total wall time: %.1f min  (%d new scenarios)\n', ...
    elapsed_total/60, numel(manifest));
if ~isempty(manifest)
    lprintf(LOG_FILE, 'Completed this session:\n');
    for k = 1:numel(manifest)
        lprintf(LOG_FILE, '  %-42s  %.1f min\n', manifest{k}{1}, manifest{k}{4});
    end
end
lprintf(LOG_FILE, '%s\n\n', repmat('=',1,65));

fprintf('\nLog written to: %s\n', LOG_FILE);

%% =======================================================================
function lprintf(log_file, fmt, varargin)
%LPRINTF  Write formatted text to console and append to log file.
    msg = sprintf(fmt, varargin{:});
    fprintf('%s', msg);
    fid = fopen(log_file, 'a');
    if fid >= 0, fprintf(fid, '%s', msg); fclose(fid); end
end
