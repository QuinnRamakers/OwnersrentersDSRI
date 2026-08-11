% RUN_MIDBAND_CANDIDATES  Solve the three candidate collective allocations
% fitted to the midpoint of the private responses under spl_100_100_100.
%
%   linear  straight line, 77% at 25 to 6% at 67 (2 knots -> PCHIP is linear)
%   knot3   the current menu form, knots at 25/67/99
%   mid     dense knots tracking the midpoint itself
%
%   Grids are run_spline_strategies defaults ([25 15 15], gh_n 5, 5000
%   households), matching the existing spl_* files so welfare stays
%   comparable across the sweep.

cd(fileparts(mfilename('fullpath')));
setenv('CGM_N_WORKERS', '10');           % laptop: Threads profile caps at 2

%% Midpoint of the private responses under the 100%-equity arm
REF = 'spl_100_100_100';
for ten = {'renter','owner'}
    D   = load(sprintf('%s_%s.mat', REF, ten{1}));
    sim = simulate.paths(D.p, D.profile, D.sol, D.ann_price, 6000, [], 1.0);
    act = (sim.X ./ sim.Y) > 0.05;
    pi_ = sim.pi;  pi_(~act) = NaN;
    PI.(ten{1}) = mean(pi_, 1, 'omitnan');
    ages = double(sim.ages);  p = D.p;
end
work = ages < p.retirement_age;
age  = ages(work);
mid  = 0.5 * (PI.renter(work) + PI.owner(work));

mid_ages  = [25:4:65, p.retirement_age];
mid_fracs = round(interp1(age, mid, min(mid_ages, age(end))), 2);

strats = struct( ...
    'name',       {'spl_lin_77_06', 'spl_knot3_77_06', 'spl_mid_100eq'}, ...
    'knot_ages',  {[25 p.retirement_age], [p.age0 p.retirement_age p.age0+p.T-2], mid_ages}, ...
    'knot_fracs', {[0.77 0.06],           [0.77 0.06 0.06],                       mid_fracs});

for k = 1:numel(strats)
    fprintf('%-16s ages [%s]\n%16s fracs [%s]\n', strats(k).name, ...
        num2str(strats(k).knot_ages), '', num2str(strats(k).knot_fracs, ' %.2f'));
end

t0 = tic;
run_spline_strategies(strats);
fprintf('\nAll six jobs done in %.1f min\n', toc(t0)/60);
