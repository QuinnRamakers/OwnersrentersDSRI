function landscape_scan(out_dir)
%LANDSCAPE_SCAN  Picture of why the equity share is hard to find.
%
%   Solves the renter case with the production (baseline) optimiser settings
%   and dumps, at a spread of retirement nodes, the Bellman objective on a
%   dense (c, pi) grid together with
%     - the seed fmincon was given (the warm start),
%     - where the production solve landed,
%     - where active-set / sqp / interior-point / wide-FD / pi-multistart land,
%     - the global maximum of the dense grid.
%
%   Everything is measured on the same objective, so the figure shows directly
%   which methods escape the seed's basin and which do not.

if nargin < 1 || isempty(out_dir)
    out_dir = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad';
end
sd = fullfile(out_dir,'scans');
if isfolder(sd), rmdir(sd,'s'); end
mkdir(sd);

p = config.params(); p.is_owner = false;
p.grid_mode='none'; p.polish_ver=2; p.use_refine=0; p.polish_algo='active-set';
p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
p.u2_lo=0.40; p.grid_pow_u2=1; p.u3_lo=0.02; p.u3_hi=0.98;
p = utility.build_state_grids(p, [12 12 8], 3);
N = [p.N_u1, p.N_u2, p.N_u3];
fprintf('cube %d x %d x %d\n', N);

% Scan EVERY node, at ages spread down the backward recursion, so the first
% place the solver parts company with the global optimum can be located
% rather than guessed at.
nodes = (1:prod(N)).';
p.scan = struct('t', [70 65 60 55 50 45], 'nodes', nodes, 'c_n', 81, 'pi_n', 61, 'dir', sd);

[~,mg,sl]=config.income_profile(p);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
tic; sol=solver.solve_lifecycle_lna(p,pf,sk,an); fprintf('solve %.0f s\n', toc);

F = dir(fullfile(sd,'scan_*.mat'));
fprintf('%d scans written\n', numel(F));
save(fullfile(out_dir,'landscape_meta.mat'),'N','nodes','p','-v7.3');
make_figs(sd, out_dir, N);
end

% ------------------------------------------------------------------------
function make_figs(sd, out_dir, N)
F = dir(fullfile(sd,'scan_*.mat'));
if isempty(F), fprintf('no scans\n'); return; end
% rank nodes by how far the production solve sits from the global max in pi
D = [];
for i=1:numel(F)
    S = load(fullfile(sd,F(i).name));
    D(i,:) = [i, abs(S.solver_opt(2)-S.gmax(2)), S.gmax(3)];               %#ok<AGROW>
end
[~,ord] = sort(D(:,2),'descend');
pick = ord(1:min(3,numel(ord)));

f = figure('Position',[30 30 1620 980],'Color','w','Visible','off');
tl = tiledlayout(f, 2, numel(pick), 'Padding','compact','TileSpacing','compact');
mcol = [0.85 0.33 0.10;   % active-set
        0.55 0.45 0.15;   % sqp
        0.45 0.30 0.70;   % interior-point
        0.95 0.65 0.30;   % active-set FD 1e-2
        0.20 0.35 0.75];  % pi multistart
for q = 1:numel(pick)
    S = load(fullfile(sd,F(pick(q)).name));
    tok = regexp(F(pick(q)).name,'scan_t(\d+)_k(\d+)','tokens'); tok=tok{1};
    t = str2double(tok{1}); k = str2double(tok{2});
    [a1,a2,a3] = ind2sub(N, k);

    % --- top: the (c,pi) surface with every landing point
    ax = nexttile(tl, q); hold(ax,'on');
    imagesc(ax, S.pi, S.c, S.rhs); axis(ax,'xy'); colormap(ax, parula);
    contour(ax, S.pi, S.c, S.rhs, 24, 'LineColor',[1 1 1],'LineWidth',.3);
    plot(ax, S.seed(2), S.seed(1), 'w o','MarkerSize',11,'LineWidth',2);
    plot(ax, S.gmax(2), S.gmax(1), 'w p','MarkerSize',18,'LineWidth',1.6,'MarkerFaceColor',[1 1 1]);
    for m=1:size(S.land,1)
        if isfinite(S.land(m,1))
            plot(ax, S.land(m,2), S.land(m,1),'o','MarkerSize',7, ...
                 'MarkerFaceColor',mcol(m,:),'MarkerEdgeColor','k','LineWidth',.6);
        end
    end
    xlabel(ax,'equity share \pi'); ylabel(ax,'consumption share c');
    title(ax, sprintf('age %d, node (%d,%d,%d)', 24+t, a1,a2,a3),'FontWeight','normal');
    xlim(ax,[0 1]); ylim(ax,[min(S.c) max(S.c)]);

    % --- bottom: the pi slice at the global-max c, which is where the
    %     multi-modality is visible
    [~,ic] = min(abs(S.c - S.gmax(1)));
    sl = S.rhs(ic,:);
    ax = nexttile(tl, q + numel(pick)); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    plot(ax, S.pi, sl, 'Color',[.15 .15 .15],'LineWidth',1.8);
    yl = [min(sl) max(sl)]; pad = 0.06*(yl(2)-yl(1)); if pad==0, pad=1e-12; end
    ylim(ax, [yl(1)-pad, yl(2)+pad]);
    xline(ax, S.seed(2), '-', 'Color',[.5 .5 .5],'LineWidth',1.4);
    xline(ax, S.gmax(2), '-', 'Color',[.1 .1 .1],'LineWidth',1.4);
    for m=1:size(S.land,1)
        if isfinite(S.land(m,2))
            xline(ax, S.land(m,2), '--','Color',mcol(m,:),'LineWidth',1.6);
        end
    end
    xlabel(ax,'equity share \pi'); ylabel(ax,'Bellman objective');
    title(ax,'objective along \pi at the best c','FontWeight','normal');
    if q==1
        legend(ax, [{'objective','seed (warm start)','global max'}, S.methods], ...
               'Box','off','Location','southoutside','NumColumns',3,'FontSize',7);
    end
end
sgtitle(f, ['The search problem in the equity share. Top: objective over (c, pi) with every method''s landing point. ' ...
            'Bottom: the same objective sliced along pi -- flat stretches and several local peaks, ' ...
            'so a solver started at the warm start stays in its basin.'], ...
        'FontWeight','normal','FontSize',11,'Interpreter','none');
fp = fullfile(out_dir,'landscape_scan.png');
exportgraphics(f, fp,'Resolution',130); close(f);
fprintf('figure: %s\n', fp);

% numeric summary across all scanned nodes
M = numel(F); nm = nan(M,5); sv = nan(M,1); tt = nan(M,1); gapv = nan(M,1);
for i=1:M
    S = load(fullfile(sd,F(i).name));
    nm(i,:) = abs(S.land(:,2).' - S.gmax(2));
    sv(i)   = abs(S.solver_opt(2) - S.gmax(2));
    tok = regexp(F(i).name,'scan_t(\d+)','tokens'); tt(i) = str2double(tok{1}{1});
    % value left on the table by the production solve, relative to global max
    [~,ic] = min(abs(S.c - S.solver_opt(1)));
    [~,ip] = min(abs(S.pi - S.solver_opt(2)));
    gapv(i) = (S.gmax(3) - S.rhs(ic,ip)) / max(abs(S.gmax(3)), eps);
end
S = load(fullfile(sd,F(1).name));
fprintf('\nAcross %d scanned node-ages\n', M);
fprintf('%-22s %12s %10s %12s\n','method','med |dpi|','p90 |dpi|','frac >2pp off');
fprintf('%-22s %12.4f %10.4f %11.1f%%\n','production solve', median(sv), prctile(sv,90), 100*mean(sv>0.02));
for m=1:numel(S.methods)
    fprintf('%-22s %12.4f %10.4f %11.1f%%\n', S.methods{m}, ...
        median(nm(:,m),'omitnan'), prctile(nm(:,m),90), 100*mean(nm(:,m)>0.02));
end
fprintf('\nProduction solve, by age: frac of nodes >2pp from the global optimum\n');
for t = unique(tt).'
    s = sv(tt==t);
    fprintf('  age %2d : %5.1f%% of nodes   (median |dpi| %.4f, worst %.3f)\n', ...
        24+t, 100*mean(s>0.02), median(s), max(s));
end
fprintf('\nvalue left on the table by the production solve (relative to global max at that node)\n');
fprintf('  median %.3e   p90 %.3e   max %.3e\n', median(gapv), prctile(gapv,90), max(gapv));
end
