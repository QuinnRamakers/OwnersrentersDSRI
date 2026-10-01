function policy_resolution(out_dir)
%POLICY_RESOLUTION  How the solved policy surface moves with grid and quadrature.
%
%   The resolution and quadrature tests so far looked at the objective at one
%   state. This looks at the policy itself: pi and c over the cube, solved at
%   four grid sizes crossed with two quadrature settings, every policy
%   interpolated onto one common grid so the surfaces can be laid side by side
%   and differenced.
%
%   The search is held at the corrected setting throughout (sweep both
%   variables, before fmincon), so what moves here is the model's answer, not
%   the solver's ability to find it.

if nargin<1||isempty(out_dir), out_dir = fileparts(mfilename('fullpath')); end
res  = fullfile(out_dir,'policy_resolution.mat');
dims = {[8 8 6],[12 12 8],[16 16 10],[20 20 12]};
ghs  = [3 5];
TS   = [10 50];                    % ages 34 and 74

R = struct('dim',{},'gh',{},'n',{},'sec',{},'pol',{});
if isfile(res), L=load(res); R=L.R; end
for i=1:numel(dims)
    for j=1:numel(ghs)
        done = arrayfun(@(r) isequal(r.dim,dims{i}) && r.gh==ghs(j), R);
        if any(done), continue; end
        fprintf('solving %s gh_n=%d ...\n', mat2str(dims{i}), ghs(j));
        tic; pol = run_one(dims{i}, ghs(j), TS); sec=toc;
        R(end+1).dim=dims{i}; R(end).gh=ghs(j); R(end).n=prod(dims{i});   %#ok<AGROW>
        R(end).sec=sec; R(end).pol=pol;
        save(res,'R','-v7.3'); fprintf('   %.0f s\n', sec);
    end
end
make_figs(R, TS, out_dir);
end

% ------------------------------------------------------------------------
function pol = run_one(dim, ghn, ts)
p = config.params(); p.is_owner=false;
p.grid_mode='none'; p.polish_ver=2; p.polish_algo='active-set';
p.use_refine=true; p.refine_stage='pre';
p.refine_pi_global=true; p.refine_c_global=true;
p.lambda_lo=0.0008; p.lambda_hi=0.44; p.grid_pow=1.6;
p.u2_lo=0.40; p.grid_pow_u2=1; p.u3_lo=0.02; p.u3_hi=0.98;
p = utility.build_state_grids(p, dim, ghn);
[~,mg,sl]=config.income_profile(p);
pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
shk=grids.shock_grid(p); an=pension.annuity_price(p,pf,shk);
sol=solver.solve_lifecycle_lna(p,pf,shk,an);
pol.u1=p.u1_grid(:); pol.u2=p.u2_grid(:); pol.u3=p.u3_grid(:);
pol.t=ts;
i3=round(numel(p.u3_grid)/2); pol.i3=i3; pol.u3_at=p.u3_grid(i3);
for a=1:numel(ts)
    pol.pi{a}=squeeze(sol.pi_pol(:,:,i3,ts(a)));
    pol.c{a} =squeeze(sol.c_pol (:,:,i3,ts(a)));
end
end

% ------------------------------------------------------------------------
function make_figs(R, ts, out_dir)
fd=fullfile(out_dir,'factorial_figs');
% common grid to compare on
U1=linspace(max(cellfun(@(x) x(1), {R.pol}.')*0+min(R(1).pol.u1),0), 0, 1); %#ok<NASGU>
u1c=linspace(R(end).pol.u1(1), R(end).pol.u1(end), 60);
u2c=linspace(R(end).pol.u2(1), R(end).pol.u2(end), 60);
[G1,G2]=ndgrid(u1c,u2c);

dims=unique(cellfun(@(d) prod(d), {R.dim}));
ghs =unique([R.gh]);
for a=1:numel(ts)
    for what={'pi','c'}
        f=figure('Position',[10 10 460*numel(ghs)+120, 330*numel(dims)],'Color','w','Visible','off');
        tl=tiledlayout(f,numel(dims),numel(ghs),'Padding','compact','TileSpacing','compact');
        lo=inf; hi=-inf; Z=cell(numel(dims),numel(ghs));
        for i=1:numel(dims)
            for j=1:numel(ghs)
                k=find(cellfun(@(d) prod(d),{R.dim})==dims(i) & [R.gh]==ghs(j),1);
                if isempty(k), continue; end
                P=R(k).pol.(what{1}){a};
                Z{i,j}=interpn(R(k).pol.u1,R(k).pol.u2,P,G1,G2,'linear',NaN);
                lo=min(lo,min(Z{i,j}(:))); hi=max(hi,max(Z{i,j}(:)));
            end
        end
        for i=1:numel(dims)
            for j=1:numel(ghs)
                ax=nexttile(tl);
                if isempty(Z{i,j}), axis(ax,'off'); continue; end
                imagesc(ax,u2c,u1c,Z{i,j}); axis(ax,'xy'); clim(ax,[lo hi]);
                colormap(ax,parula);
                if j==numel(ghs), cb=colorbar(ax); cb.Label.String=what{1}; end
                xlabel(ax,'u2  (illiquid share)'); ylabel(ax,'u1  (income share)');
                k=find(cellfun(@(d) prod(d),{R.dim})==dims(i) & [R.gh]==ghs(j),1);
                title(ax,sprintf('%s, gh\\_n=%d  (%.0f s)', mat2str(R(k).dim), ghs(j), R(k).sec), ...
                    'FontWeight','normal');
            end
        end
        nm = 'equity share \pi'; if strcmp(what{1},'c'), nm='consumption share c'; end
        sgtitle(f,sprintf(['%s at age %d, over (u1,u2) at u3 = %.2f. Rows refine the cube, columns add quadrature points. ' ...
            'All panels share one colour scale and one interpolation grid.'], nm, 24+ts(a), R(end).pol.u3_at), ...
            'FontWeight','normal','FontSize',11,'Interpreter','tex');
        exportgraphics(f,fullfile(fd,sprintf('S11_policy_%s_age%d.png',what{1},24+ts(a))),'Resolution',130);
        close(f);
    end
end

% ---- convergence against the finest solve
fprintf('\nPolicy change against the finest solve (%s, gh_n=%d), on the common grid\n', ...
    mat2str(R(end).dim), R(end).gh);
fprintf('%-14s %5s', 'cube','gh_n');
for a=1:numel(ts), fprintf('  age%d: RMS dpi  max dpi  RMS dc', 24+ts(a)); end
fprintf('\n');
kf=find(cellfun(@(d) prod(d),{R.dim})==max(dims) & [R.gh]==max(ghs),1);
for i=1:numel(dims)
    for j=1:numel(ghs)
        k=find(cellfun(@(d) prod(d),{R.dim})==dims(i) & [R.gh]==ghs(j),1);
        if isempty(k), continue; end
        fprintf('%-14s %5d', mat2str(R(k).dim), R(k).gh);
        for a=1:numel(ts)
            A=interpn(R(k).pol.u1,R(k).pol.u2,R(k).pol.pi{a},G1,G2,'linear',NaN);
            B=interpn(R(kf).pol.u1,R(kf).pol.u2,R(kf).pol.pi{a},G1,G2,'linear',NaN);
            Ac=interpn(R(k).pol.u1,R(k).pol.u2,R(k).pol.c{a},G1,G2,'linear',NaN);
            Bc=interpn(R(kf).pol.u1,R(kf).pol.u2,R(kf).pol.c{a},G1,G2,'linear',NaN);
            d=A-B; dc=Ac-Bc; ok=isfinite(d); okc=isfinite(dc);
            fprintf('   %9.4f %8.3f %8.4f', sqrt(mean(d(ok).^2)), max(abs(d(ok))), sqrt(mean(dc(okc).^2)));
        end
        fprintf('\n');
    end
end
fprintf('figures in %s\n', fd);
end
