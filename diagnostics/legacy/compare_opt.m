function compare_opt()
%COMPARE_OPT  Controlled comparison of the per-node optimiser on the private
%   (c, pi) policy: {active-set, interior-point} x {refine on, off}. One POLISHED
%   Bellman step at a fixed continuation V_next and node grid, so the ONLY thing
%   that varies is the optimiser + refinement. Reports pi/c stats, timing, and
%   how far each policy sits from the active-set+refine reference.
repo = 'C:\Users\Quinn\Desktop\claudecodetest\OwnersrentersDSRI-rentproc';
addpath(repo); cd(repo);
d = load('combined_owner_lna.mat');
p = d.p; profile = d.profile; shocks = d.shocks; ann = d.ann_price;
p.skip_polish = false;
t = 20;                                  % age 44, working
Vn = d.sol.V(:,:,:,t+1);
pol_next = struct('c', d.sol.c_pol(:,:,:,t+1), 'pi', d.sol.pi_pol(:,:,:,t+1), 'tau', []);

combos = { 'active-set',    true ;
           'active-set',    false;
           'interior-point',true ;
           'interior-point',false };

fprintf('\nOne polished Bellman step at age %d (grid %dx%dx%d, gh_n=%d).\n', ...
    p.age0+t-1, p.N_u1,p.N_u2,p.N_u3, p.gh_n);
fprintf('%-16s %-7s | %6s %6s %6s | %7s %7s | %8s | %s\n', ...
    'algorithm','refine','pi_mn','pi>.01','pi_md','c_mn','c_md','time(s)','maxDiff pi vs AS+ref');
fprintf('%s\n', repmat('-',1,100));
ref_pi = [];
for i = 1:size(combos,1)
    p.polish_algo = combos{i,1};
    p.use_refine  = combos{i,2};
    tic;
    [~, c_pol, pi_pol] = solver.bellman_step_lna(t, Vn, p, profile, shocks, ann, pol_next);
    tt = toc;
    if i==1, ref_pi = pi_pol; end
    md = max(abs(pi_pol(:) - ref_pi(:)));
    fprintf('%-16s %-7s | %6.3f %6.3f %6.3f | %7.3f %7.3f | %8.1f | %.4f\n', ...
        combos{i,1}, mat2str(combos{i,2}), mean(pi_pol(:)), mean(pi_pol(:)>0.01), ...
        median(pi_pol(:)), mean(c_pol(:)), median(c_pol(:)), tt, md);
end
fprintf('\n(maxDiff is the largest per-node |pi - pi_{active-set,refine}| over all %d nodes.)\n', numel(ref_pi));
end
