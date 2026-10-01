function savings_decomp(out_dir)
%SAVINGS_DECOMP  Main-effect sweep keeping the full wealth decomposition.
%
%   The factorial stored liquid + DC as one number and did not keep the DC
%   equity share, so it cannot answer three things: consumption in euros,
%   TOTAL equity exposure, and where the savings actually sit. This re-runs the
%   one-lever-at-a-time cells keeping X, A, H, tau_A and W by age.
%
%   Produces:
%     G1  consumption in EUR against liquid wealth in EUR (the policy, age 50)
%     G2  total equity exposure by age, liquid and DC separately and combined
%     G3  savings composition by age -- DC pot, liquid account, housing

if nargin < 1 || isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
res = fullfile(out_dir, 'savings_decomp.mat');

BASE = struct('grid','designed','nodes',2,'b0',0.0791,'hc',1.00, ...
              'phi',1e-6,'cff',0.01,'ghn',3);
LEV = { 'grid',  'grid placement',        {'default','designed'}
        'nodes', 'grid points',           {1,2,3,4}
        'b0',    'entry wealth (years)',  {0.0791,0.5,1.0}
        'hc',    'housing cost (x)',      {1.00,0.50,0.25}
        'phi',   'consumption floor',     {1e-6,0.05,0.10,0.20}
        'cff',   'floor mechanism',       {0.01,0.001}
        'ghn',   'quadrature gh\_n',      {3,5} };

cells = {}; seen = {};
for ten = {'renter','owner'}
    for j = 1:size(LEV,1)
        for m = 1:numel(LEV{j,3})
            s = BASE; s.ten = ten{1}; s.(LEV{j,1}) = LEV{j,3}{m};
            k = sprintf('%s|%s|%d|%.4f|%.2f|%.5g|%.4g|%d', s.ten, s.grid, ...
                        s.nodes, s.b0, s.hc, s.phi, s.cff, s.ghn);
            if any(strcmp(k, seen)), continue; end
            seen{end+1} = k; s.key = k; cells{end+1} = s;                %#ok<AGROW>
        end
    end
end
fprintf('%d cells\n', numel(cells));

R = struct('key',{},'cfg',{},'out',{});
if isfile(res), L = load(res); R = L.R; end
done = {R.key}; t0 = tic;
for i = 1:numel(cells)
    c = cells{i};
    if any(strcmp(c.key, done)), continue; end
    o = run_one(c);
    R(end+1).key = c.key; R(end).cfg = c; R(end).out = o;                %#ok<AGROW>
    save(res, 'R', '-v7.3');
    fprintf('%2d/%2d %-44s  C50=%6.0f  DC/fin@66=%.2f  totEq@50=%.2f\n', ...
            numel(R), numel(cells), c.key, o.C(26), o.dcshare(42), o.tot_eq(26));
end
fprintf('done in %.2f h\n', toc(t0)/3600);
make_plots(R, LEV, BASE, out_dir);
end

% ------------------------------------------------------------------------
function o = run_one(c)
NODES = {[10 10 8],[14 14 10],[18 18 12],[22 22 14]};
p = config.params(); p.is_owner = strcmp(c.ten,'owner');
p.grid_mode='none'; p.polish_ver=2; p.use_refine=false;
p.b0=c.b0; p.phi_floor=c.phi; p.c_floor_frac=c.cff;
if p.is_owner
    p.theta = p.theta*c.hc; p.m_rate_path = p.m_rate_path*c.hc;
else
    p.alpha = p.alpha*c.hc;
end
if strcmp(c.grid,'designed')
    p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
    p.u2_lo=0.40; p.grid_pow_u2=1; p.u3_lo=0.02; p.u3_hi=0.98;
end
p = utility.build_state_grids(p, NODES{c.nodes}, c.ghn);
[~,mg,sl]=config.income_profile(p);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
sol=solver.solve_lifecycle_lna(p,pf,sk,an);
sim=simulate.forward(p,pf,sol,an,4000,20260511,p.b0);

med=@(M) median(M,1,'omitnan'); mn=@(M) mean(M,1,'omitnan');
K = 1:size(sim.tau_A,2);
o.ages = sim.ages(K);
o.C  = med(sim.C(:,K));      o.pi = mn(sim.pi(:,K));
o.X  = med(sim.X(:,K));      o.A  = med(sim.A(:,K));
o.H  = med(sim.H(:,K));      o.W  = med(sim.W(:,K));
o.tau = mn(sim.tau_A(:,K));
fin = sim.X(:,K) + sim.A(:,K);
o.fin = med(fin);
o.dcshare = mn(sim.A(:,K) ./ max(fin,eps));
o.tot_eq  = mn((sim.pi(:,K).*sim.X(:,K) + sim.tau_A(:,K).*sim.A(:,K)) ./ max(fin,eps));

% policy in EUR at age 50, against liquid wealth in EUR, at the median W
t = 26; Wref = med(sim.W(:,t));
u1 = 1/(1+p.h_mult+p.b0); [~,ia] = min(abs(p.u1_grid-u1)); u1 = p.u1_grid(ia);
u2 = p.u2_grid(:).'; u3 = p.u3_grid(1);
net = 1-p.tau_inc; kap = p.kappa(min(t,numel(p.kappa)));
if t >= p.t_ret, cf=(1-p.delta)*net; else, cf=(1-p.delta)*(1-kap)*net; end
if p.is_owner
    mr = 0; if t<=numel(p.m_rate_path), mr=p.m_rate_path(t); end
    hc = p.theta+mr;
else
    hc = p.alpha;
end
sX = (1-u1).*(1-u2); sA = u2.*(1-u1).*u3; sH = u2.*(1-u1).*(1-u3);
LW_W = sX + cf*u1 - hc*sH;                      % annuity term is zero at 50
o.pol_x   = sX * Wref;                           % liquid wealth, EUR
o.pol_lw  = LW_W * Wref;                         % liquid resources, EUR
o.pol_c   = reshape(sol.c_pol(ia,:,1,t),1,[]) .* LW_W * Wref;   % consumption, EUR
o.pol_pi  = reshape(sol.pi_pol(ia,:,1,t),1,[]);
o.Wref = Wref;
end

% ------------------------------------------------------------------------
function make_plots(R, LEV, BASE, out_dir)
fd = fullfile(out_dir,'factorial_figs'); if ~isfolder(fd), mkdir(fd); end
for ten = {'renter','owner'}
    for g = 1:3
        f = figure('Position',[40 40 1500 820],'Color','w','Visible','off');
        tl = tiledlayout(f,2,4,'Padding','compact','TileSpacing','compact'); drew=false;
        for j = 1:size(LEV,1)
            ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
            lv = LEV{j,3}; cols = lines(numel(lv)); leg={}; hnd=gobjects(0);
            for m = 1:numel(lv)
                sp = BASE; sp.ten = ten{1}; sp.(LEV{j,1}) = lv{m};
                k = sprintf('%s|%s|%d|%.4f|%.2f|%.5g|%.4g|%d', sp.ten, sp.grid, ...
                            sp.nodes, sp.b0, sp.hc, sp.phi, sp.cff, sp.ghn);
                i = find(strcmp({R.key}, k), 1); if isempty(i), continue; end
                o = R(i).out; drew = true;
                % pol_c was stored as an outer product by an earlier bug; the
                % correct vector is its diagonal. Harmless once re-solved.
                if ~isvector(o.pol_c), o.pol_c = diag(o.pol_c).'; end
                o.pol_pi = reshape(o.pol_pi,1,[]);
                lw = 1.2 + 1.4*isequal(lv{m}, BASE.(LEV{j,1}));
                switch g
                    case 1, h = plot(ax, o.pol_x/1000, o.pol_c/1000, 'Color',cols(m,:),'LineWidth',lw);
                    case 2, h = plot(ax, o.ages, o.tot_eq, 'Color',cols(m,:),'LineWidth',lw);
                    case 3, h = plot(ax, o.ages, o.dcshare, 'Color',cols(m,:),'LineWidth',lw);
                end
                hnd(end+1)=h; leg{end+1}=lab(LEV{j,1}, lv{m});            %#ok<AGROW>
            end
            title(ax, LEV{j,2},'FontWeight','normal');
            switch g
                case 1, xlabel(ax,'liquid wealth, EUR000'); if mod(j-1,4)==0, ylabel(ax,'consumption, EUR000'); end
                case 2, xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 95]); ylim(ax,[0 .8]);
                        xlabel(ax,'age'); if mod(j-1,4)==0, ylabel(ax,'total equity share'); end
                case 3, xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 95]); ylim(ax,[0 1]);
                        xlabel(ax,'age'); if mod(j-1,4)==0, ylabel(ax,'DC share of financial wealth'); end
            end
            if ~isempty(leg), legend(ax,hnd,leg,'Box','off','Location','best','FontSize',8); end
        end
        if ~drew, close(f); continue; end
        T = {'consumption in EUR against liquid wealth in EUR, age 50', ...
             'TOTAL equity exposure (liquid + DC) by age', ...
             'DC pot as a share of financial wealth'};
        sgtitle(f, sprintf('%s -- %s', ten{1}, T{g}),'FontWeight','normal','FontSize',13);
        n = {'G1_policy_eur','G2_total_equity','G3_dc_share'};
        exportgraphics(f, fullfile(fd, sprintf('%s_%s.png', n{g}, ten{1})),'Resolution',140);
        close(f);
    end
    % levels figure: where the money is, in euros
    f = figure('Position',[40 40 1300 520],'Color','w','Visible','off');
    tl = tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact'); drew=false;
    for m = 1:3
        hcv = {1.00,0.50,0.25}; ax = nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
        sp = BASE; sp.ten=ten{1}; sp.hc=hcv{m};
        k = sprintf('%s|%s|%d|%.4f|%.2f|%.5g|%.4g|%d', sp.ten, sp.grid, sp.nodes, ...
                    sp.b0, sp.hc, sp.phi, sp.cff, sp.ghn);
        i = find(strcmp({R.key},k),1); if isempty(i), continue; end
        o = R(i).out; drew = true;
        plot(ax,o.ages,o.A/1000,'LineWidth',2,'Color',[.20 .35 .75]);
        plot(ax,o.ages,o.X/1000,'LineWidth',2,'Color',[.85 .33 .10]);
        plot(ax,o.ages,o.H/1000,'LineWidth',1.5,'Color',[.47 .67 .19],'LineStyle','--');
        xline(ax,67,':','Color',[.5 .5 .5]); xlim(ax,[25 95]);
        title(ax,sprintf('housing cost x%.2f',hcv{m}),'FontWeight','normal');
        xlabel(ax,'age'); if m==1, ylabel(ax,'EUR000, median'); legend(ax, ...
            {'DC pot','liquid account','house / rent index'},'Box','off','Location','northwest'); end
    end
    if drew
        sgtitle(f,sprintf('%s -- where the savings sit', ten{1}),'FontWeight','normal','FontSize',13);
        exportgraphics(f, fullfile(fd, sprintf('G4_savings_levels_%s.png', ten{1})),'Resolution',140);
    end
    close(f);
end
fprintf('figures in %s\n', fd);
end

function s = lab(f,v)
switch f
    case 'grid',  s=v;
    case 'nodes', n=[1152 2560 4800 8064]; s=sprintf('%d nodes',n(v));
    case 'b0',    s=sprintf('b0 = %.3g yr',v);
    case 'hc',    s=sprintf('housing x%.2f',v);
    case 'phi',   s=sprintf('phi = %.3g',v);
    case 'cff',   s=sprintf('c\\_floor %.3g',v);
    case 'ghn',   s=sprintf('gh\\_n = %d',v);
    otherwise,    s=num2str(v);
end
end
