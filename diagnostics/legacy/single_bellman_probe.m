function single_bellman_probe()
%SINGLE_BELLMAN_PROBE  One POLISHED Bellman step (fast) to see whether the
%   liquid stock share pi ever wants to be > 0, especially at liquid-rich nodes.
repo = 'C:\Users\Quinn\Desktop\claudecodetest\OwnersrentersDSRI-rentproc';
addpath(repo); cd(repo);
d = load('combined_owner_lna.mat');   % skip_polish solve (has sol.V on 16x12x10)
p = d.p; profile = d.profile; shocks = d.shocks; ann = d.ann_price;
p.skip_polish = false;                % POLISH ON for this step

t = 20;                               % age 44, working
Vn = d.sol.V(:,:,:,t+1);
pol_next = struct('c', d.sol.c_pol(:,:,:,t+1), 'pi', d.sol.pi_pol(:,:,:,t+1), 'tau', []);
tic;
[~, c_pol, pi_pol] = solver.bellman_step_lna(t, Vn, p, profile, shocks, ann, pol_next);
fprintf('one polished step: %.1fs\n', toc);

fprintf('pi_pol range [%.4f, %.4f]  mean %.4f  frac>0.01 %.3f\n', ...
    min(pi_pol(:)), max(pi_pol(:)), mean(pi_pol(:)), mean(pi_pol(:)>0.01));
fprintf('c_pol  range [%.4f, %.4f]  mean %.4f\n', ...
    min(c_pol(:)), max(c_pol(:)), mean(c_pol(:)));

% Liquid-rich slice: u2 (illiquid share) smallest -> mostly liquid wealth.
% pi should matter most here. Report pi across u1 for the lowest-u2 plane.
[~, j2] = min(p.u2_grid);            % most-liquid plane
fprintf('\npi at the most-liquid plane (u2=%.2f), rows=u1, cols=u3:\n', p.u2_grid(j2));
disp(round(squeeze(pi_pol(:, j2, :)), 3));
fprintf('\nc at that plane:\n');
disp(round(squeeze(c_pol(:, j2, :)), 3));
end
