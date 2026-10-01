function factorial_plots(dir_in)
%FACTORIAL_PLOTS  Turn factorial_results.mat into a reviewable set of figures.
%
%   One figure per lever for the main effects, one per pair for the
%   interactions, a policy-function sheet, a convergence sheet and a summary
%   table. Runs on partial results, so it can be called while the solve queue is
%   still going.
%
%   Baseline (the centre of the design) is drawn heavier and darker in every
%   panel, so "what moves when I push this lever" is read against a fixed point.

if nargin < 1 || isempty(dir_in)
    dir_in = fileparts(mfilename('fullpath'));
end
L = load(fullfile(dir_in, 'factorial_results.mat'));
R = L.R;
fprintf('%d cells available\n', numel(R));
fig_dir = fullfile(dir_in, 'factorial_figs');
if ~isfolder(fig_dir), mkdir(fig_dir); end

BASE = struct('grid','designed','nodes',2,'b0',0.0791,'hc',1.00, ...
              'phi',1e-6,'cff',0.01,'ghn',3);
LEV = { 'grid',  'grid placement',        {'default','designed'}
        'nodes', 'grid points',           {1,2,3,4}
        'b0',    'entry wealth (years)',  {0.0791,0.5,1.0}
        'hc',    'housing cost (x)',      {1.00,0.50,0.25}
        'phi',   'consumption floor',     {1e-6,0.05,0.10,0.20}
        'cff',   'floor mechanism (c\_floor)', {0.01,0.001}
        'ghn',   'quadrature gh\_n',      {3,5} };
NODE_N = [1152 2560 4800 8064];

% ---------------------------------------------------------------- summary
fid = fopen(fullfile(dir_in,'factorial_summary.txt'),'w');
fprintf(fid, '%-46s %6s %8s %8s %8s %6s %6s %6s %7s %7s %5s %5s\n', 'cell','nodes', ...
    'C25','C45','C70','pi25','pi45','pi75','fl%','d2pi_ret','off','cbnd');
[~, ordk] = sort({R.key});
for i = ordk
    o = R(i).out;
    fprintf(fid, '%-46s %6d %8.0f %8.0f %8.0f %6.2f %6.2f %6.2f %6.2f%% %6.2f%% %5d %5d\n', ...
        R(i).key, o.n, o.C(1), o.C(21), o.C(46), o.pi(1), o.pi(21), o.pi(51), ...
        o.floored, o.rough_ret, o.off, o.c_binds25);
end
fclose(fid);

% ------------------------------------------------------- main effect sheets
for ten = {'renter','owner'}
    for what = {'C','pi'}
        f = figure('Position',[40 40 1500 820],'Color','w','Visible','off');
        tl = tiledlayout(f,2,4,'Padding','compact','TileSpacing','compact');
        any_drawn = false;
        for j = 1:size(LEV,1)
            ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
            lv = LEV{j,3}; cols = lines(numel(lv)); leg = {};
            for m = 1:numel(lv)
                sp = BASE; sp.(LEV{j,1}) = lv{m}; sp.ten = ten{1};
                i = find_cell(R, sp);
                if isempty(i), continue; end
                any_drawn = true;
                v = R(i).out.(what{1});
                isb = isequal(lv{m}, BASE.(LEV{j,1}));
                plot(ax, R(i).out.ages(1:numel(v)), v, 'Color', cols(m,:), ...
                     'LineWidth', 1.2 + 1.4*isb);
                leg{end+1} = lev_label(LEV{j,1}, lv{m}, NODE_N);          %#ok<AGROW>
            end
            xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 99]);
            if strcmp(what{1},'pi'), ylim(ax,[0 1.05]); end
            title(ax, LEV{j,2}, 'FontWeight','normal');
            if ~isempty(leg), legend(ax, leg, 'Box','off','Location','best','FontSize',8); end
            if j > 4, xlabel(ax,'age'); end
        end
        if ~any_drawn, close(f); continue; end
        nm = ternary(strcmp(what{1},'C'),'median consumption','mean equity share');
        sgtitle(f, sprintf('%s -- %s, one lever at a time (thick = baseline)', ten{1}, nm), ...
                'FontWeight','normal','FontSize',13);
        save_fig(f, fullfile(fig_dir, sprintf('F1_main_%s_%s.png', ten{1}, what{1})));
    end
end

% --------------------------------------------------------- interaction grids
PAIRS = { 'hc','phi'; 'hc','nodes'; 'phi','nodes'; 'grid','nodes'; ...
          'ghn','nodes'; 'cff','hc'; 'cff','phi'; 'b0','hc'; 'grid','phi'; 'hc','ghn' };
for pp = 1:size(PAIRS,1)
    fa = PAIRS{pp,1}; fb = PAIRS{pp,2};
    ja = find(strcmp(LEV(:,1),fa)); jb = find(strcmp(LEV(:,1),fb));
    la = LEV{ja,3}; lb = LEV{jb,3};
    for ten = {'renter','owner'}
        f = figure('Position',[40 40 1500 760],'Color','w','Visible','off');
        tl = tiledlayout(f,2,numel(la),'Padding','compact','TileSpacing','compact');
        cols = lines(numel(lb)); drew = false;
        for wrow = 1:2
            what = ternary(wrow==1,'C','pi');
            for m = 1:numel(la)
                ax = nexttile(tl, (wrow-1)*numel(la) + m); hold(ax,'on');
                grid(ax,'on'); ax.GridAlpha=.12; leg={};
                for q = 1:numel(lb)
                    sp = BASE; sp.(fa)=la{m}; sp.(fb)=lb{q}; sp.ten=ten{1};
                    i = find_cell(R, sp); if isempty(i), continue; end
                    drew = true; v = R(i).out.(what);
                    plot(ax, R(i).out.ages(1:numel(v)), v, 'Color', cols(q,:), 'LineWidth',1.4);
                    leg{end+1} = lev_label(fb, lb{q}, NODE_N);            %#ok<AGROW>
                end
                xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 99]);
                if strcmp(what,'pi'), ylim(ax,[0 1.05]); xlabel(ax,'age'); end
                if wrow==1, title(ax, sprintf('%s = %s', LEV{ja,2}, ...
                        lev_label(fa, la{m}, NODE_N)), 'FontWeight','normal','FontSize',10); end
                if m==1, ylabel(ax, ternary(wrow==1,'median consumption','equity share')); end
                if m==numel(la) && ~isempty(leg)
                    legend(ax, leg, 'Box','off','Location','best','FontSize',8);
                end
            end
        end
        if ~drew, close(f); continue; end
        sgtitle(f, sprintf('%s -- %s across %s', ten{1}, LEV{jb,2}, LEV{ja,2}), ...
                'FontWeight','normal','FontSize',13);
        save_fig(f, fullfile(fig_dir, sprintf('F2_int_%s_%s_x_%s.png', ten{1}, fa, fb)));
    end
end

% ------------------------------------------------------------ policy sheets
for ten = {'renter','owner'}
    f = figure('Position',[40 40 1500 820],'Color','w','Visible','off');
    tl = tiledlayout(f,2,4,'Padding','compact','TileSpacing','compact'); drew=false;
    for j = 1:size(LEV,1)
        ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
        lv = LEV{j,3}; cols = lines(numel(lv)); leg={};
        for m = 1:numel(lv)
            sp = BASE; sp.(LEV{j,1})=lv{m}; sp.ten=ten{1};
            i = find_cell(R,sp); if isempty(i), continue; end
            drew = true; o = R(i).out;
            plot(ax, o.u2_grid, o.pol_pi(2,:), 'Color', cols(m,:), ...
                 'LineWidth', 1.2 + 1.4*isequal(lv{m}, BASE.(LEV{j,1})));
            leg{end+1} = lev_label(LEV{j,1}, lv{m}, NODE_N);              %#ok<AGROW>
        end
        ylim(ax,[0 1.05]); xlim(ax,[0.4 1]);
        title(ax, LEV{j,2},'FontWeight','normal');
        if j>4, xlabel(ax,'u2 = illiquid share  (right edge = no liquid wealth)'); end
        if mod(j-1,4)==0, ylabel(ax,'equity share, age 50'); end
        if ~isempty(leg), legend(ax,leg,'Box','off','Location','best','FontSize',8); end
    end
    if ~drew, close(f); continue; end
    sgtitle(f, sprintf('%s -- POLICY: equity share against liquid wealth at age 50', ten{1}), ...
            'FontWeight','normal','FontSize',13);
    save_fig(f, fullfile(fig_dir, sprintf('F3_policy_pi_%s.png', ten{1})));

    f = figure('Position',[40 40 1500 820],'Color','w','Visible','off');
    tl = tiledlayout(f,2,4,'Padding','compact','TileSpacing','compact'); drew=false;
    for j = 1:size(LEV,1)
        ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
        lv = LEV{j,3}; cols = lines(numel(lv)); leg={};
        for m = 1:numel(lv)
            sp = BASE; sp.(LEV{j,1})=lv{m}; sp.ten=ten{1};
            i = find_cell(R,sp); if isempty(i), continue; end
            drew = true; o = R(i).out;
            plot(ax, o.u2_grid, o.pol_c(2,:), 'Color', cols(m,:), ...
                 'LineWidth', 1.2 + 1.4*isequal(lv{m}, BASE.(LEV{j,1})));
            leg{end+1} = lev_label(LEV{j,1}, lv{m}, NODE_N);              %#ok<AGROW>
        end
        ylim(ax,[0 1.05]); xlim(ax,[0.4 1]);
        title(ax, LEV{j,2},'FontWeight','normal');
        if j>4, xlabel(ax,'u2 = illiquid share'); end
        if mod(j-1,4)==0, ylabel(ax,'consumption share, age 50'); end
        if ~isempty(leg), legend(ax,leg,'Box','off','Location','best','FontSize',8); end
    end
    if ~drew, close(f); continue; end
    sgtitle(f, sprintf('%s -- POLICY: consumption share against liquid wealth at age 50', ten{1}), ...
            'FontWeight','normal','FontSize',13);
    save_fig(f, fullfile(fig_dir, sprintf('F4_policy_c_%s.png', ten{1})));
end

% ------------------------------------------- convergence under each lever
f = figure('Position',[40 40 1500 760],'Color','w','Visible','off');
tl = tiledlayout(f,2,3,'Padding','compact','TileSpacing','compact'); drew=false;
CONV = {'hc','phi','grid','ghn','b0','cff'};
for j = 1:numel(CONV)
    ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    jj = find(strcmp(LEV(:,1),CONV{j})); lv = LEV{jj,3};
    mk = {'-o','--s'}; cols = lines(numel(lv)); leg={}; hnd = gobjects(0);
    for ti = 1:2
        ten = ternary(ti==1,'renter','owner');
        for m = 1:numel(lv)
            d = nan(1,3);
            for n = 1:3
                sp1 = BASE; sp1.(CONV{j})=lv{m}; sp1.ten=ten; sp1.nodes=n;
                sp2 = sp1; sp2.nodes = n+1;
                i1 = find_cell(R,sp1); i2 = find_cell(R,sp2);
                if isempty(i1)||isempty(i2), continue; end
                a = R(i1).out.C(1:15); b = R(i2).out.C(1:15);
                d(n) = 100*mean(abs(b-a)./max(abs(a),eps));
            end
            if all(isnan(d)), continue; end
            drew = true;
            hh = plot(ax, NODE_N(2:4), d, mk{ti}, 'Color', cols(m,:), 'LineWidth',1.5, ...
                 'MarkerFaceColor', cols(m,:), 'MarkerSize',4);
            if ti==1
                hnd(end+1) = hh; leg{end+1} = lev_label(CONV{j}, lv{m}, NODE_N); %#ok<AGROW>
            end
        end
    end
    set(ax,'XScale','log'); xlabel(ax,'nodes at the finer grid');
    ylabel(ax,'|dC|/C ages 25-39, %'); title(ax, LEV{jj,2},'FontWeight','normal');
    if ~isempty(leg), legend(ax, hnd, leg, 'Box','off','Location','best','FontSize',8); end
end
if drew
    sgtitle(f,'Does early life converge? drift between successive grids (solid = renter, dashed = owner)', ...
            'FontWeight','normal','FontSize',13);
    save_fig(f, fullfile(fig_dir,'F5_convergence.png'));
else
    close(f);
end

% ------------------------------------------------- effect-size scoreboard
f = figure('Position',[40 40 1400 620],'Color','w','Visible','off');
tl = tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');
STAT = {'C25','floored','rough_ret'};
SLAB = {'consumption at 25','% of years floored','retirement pi roughness'};
for s = 1:3
    ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    names = {}; vals = [];
    for j = 1:size(LEV,1)
        lv = LEV{j,3}; rng_v = [];
        for ten = {'renter','owner'}
            vv = [];
            for m = 1:numel(lv)
                sp = BASE; sp.(LEV{j,1})=lv{m}; sp.ten=ten{1};
                i = find_cell(R,sp); if isempty(i), continue; end
                o = R(i).out;
                switch STAT{s}
                    case 'C25', vv(end+1)=o.C(1);                        %#ok<AGROW>
                    case 'floored', vv(end+1)=o.floored;                 %#ok<AGROW>
                    case 'rough_ret', vv(end+1)=o.rough_ret;             %#ok<AGROW>
                end
            end
            if numel(vv)>=2, rng_v(end+1) = (max(vv)-min(vv))/max(abs(mean(vv)),eps); end %#ok<AGROW>
        end
        if isempty(rng_v), continue; end
        names{end+1} = LEV{j,2}; vals(end+1) = 100*mean(rng_v);          %#ok<AGROW>
    end
    if isempty(vals), continue; end
    [vals, ix] = sort(vals); names = names(ix);
    barh(ax, vals, 'FaceColor',[.20 .35 .75],'EdgeColor','none');
    set(ax,'YTick',1:numel(names),'YTickLabel',names,'FontSize',9);
    xlabel(ax,'spread across the lever, % of its mean');
    title(ax, SLAB{s},'FontWeight','normal');
end
sgtitle(f,'Which lever moves what, averaged over both tenures','FontWeight','normal','FontSize',13);
save_fig(f, fullfile(fig_dir,'F6_effect_sizes.png'));

fprintf('figures written to %s\n', fig_dir);
end

% ------------------------------------------------------------------ helpers
function i = find_cell(R, sp)
i = [];
for k = 1:numel(R)
    c = R(k).cfg;
    if strcmp(c.ten,sp.ten) && strcmp(c.grid,sp.grid) && c.nodes==sp.nodes ...
       && abs(c.b0-sp.b0)<1e-9 && abs(c.hc-sp.hc)<1e-9 ...
       && abs(c.phi-sp.phi)<1e-12 && abs(c.cff-sp.cff)<1e-12 && c.ghn==sp.ghn
        i = k; return
    end
end
end

function s = lev_label(f, v, NODE_N)
switch f
    case 'grid',  s = v;
    case 'nodes', s = sprintf('%d nodes', NODE_N(v));
    case 'b0',    s = sprintf('b0 = %.3g yr', v);
    case 'hc',    s = sprintf('housing x%.2f', v);
    case 'phi',   s = sprintf('phi = %.3g', v);
    case 'cff',   s = sprintf('c\\_floor %.3g', v);
    case 'ghn',   s = sprintf('gh\\_n = %d', v);
    otherwise,    s = num2str(v);
end
end

function y = ternary(c,a,b), if c, y=a; else, y=b; end, end

function save_fig(f, path)
exportgraphics(f, path, 'Resolution', 140); close(f);
fprintf('  %s\n', path);
end
