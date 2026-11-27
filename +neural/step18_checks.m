function step18_checks(tenure, numerics, opts)
%STEP18_CHECKS  The MATLAB-side checks of the step-18 networks for one tenure and grid.
%
%   neural.step18_checks('renter', 'standard')
%   neural.step18_checks('owner', 'fine', refinement=false)
%
%   Needs neural/data/solve_18_<tenure>_<numerics>.mat
%   (neural.make_testsets(..., keep_solve=true)) and the exported networks
%   (neural/scripts/export_net.jl). Writes, in neural/data:
%     check_18_<tenure>_<numerics>.mat   neural.check_networks: the four
%         networks in MATLAB's simulator and the solver's value of each
%     cmp_18_<tenure>_<numerics>_s202.mat, ..._joint_s202.mat  neural.compare_panels
%         on the 20,000 test households (separate and joint network)
%     cmp_18_<tenure>_<numerics>_s303.mat   the same on 100,000 new households
%     evalref_18_<tenure>.mat   neural.eval_refinement (refinement=true)

arguments
    tenure char
    numerics char
    opts.refinement (1,1) logical = true
end

d = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'neural', 'data');
r = load(fullfile(d, sprintf('solve_18_%s_%s.mat', tenure, numerics))).r;
sep = sprintf('net_step18_%s_k3000_run1.mat', tenure);
nets = {sep, 'net_step18_joint_k3000_run1.mat', sprintf('net_step18_%s_run1.mat', tenure), 'net_step18_joint_run1.mat'};
for s = [2 3]
    f = sprintf('net_step18_%s_s%d_run1.mat', tenure, s);
    if isfile(fullfile(d, f)), nets{end+1} = f; end %#ok<AGROW>
end
tag = sprintf('18_%s_%s', tenure, numerics);

T = neural.check_networks(r, nets);
disp(T);
save(fullfile(d, ['check_' tag '.mat']), 'T');

o = neural.compare_panels(r, sep, N=20000, seed=202);
disp(o.groups);
save(fullfile(d, ['cmp_' tag '_s202.mat']), '-struct', 'o');
j = neural.compare_panels(r, 'net_step18_joint_k3000_run1.mat', N=20000, seed=202);
j = rmfield(j, {'U_grid', 'U_net'});
save(fullfile(d, ['cmp_' tag '_joint_s202.mat']), '-struct', 'j');
o2 = neural.compare_panels(r, sep, N=100000, seed=303);
g = r.p.gamma;
h = o2.ce_net / ((1 - g) * mean(o2.U_net)) * o2.U_net - o2.ce_grid / ((1 - g) * mean(o2.U_grid)) * o2.U_grid;
fprintf('100,000 households, seed 303: ce grid %.4f, network %.4f, difference %+.4f (s.e. %.4f)\n', ...
    o2.ce_grid, o2.ce_net, o2.ce_net - o2.ce_grid, std(h) / sqrt(numel(h)));
disp(o2.groups);
o2.se_diff = std(h) / sqrt(numel(h));
o2 = rmfield(o2, {'U_grid', 'U_net'});
save(fullfile(d, ['cmp_' tag '_s303.mat']), '-struct', 'o2');

if opts.refinement
    R = neural.eval_refinement(r, sep, {[12 12 8 6], 3; [16 16 10 8], 5; [16 16 10 8], 7; [32 16 40 4], 5; ...
        [32 32 40 4], 5; [64 32 40 4], 5; [64 32 80 4], 5; [128 32 80 4], 5});
    disp(R);
    save(fullfile(d, sprintf('evalref_18_%s.mat', tenure)), 'R');
end
end
