% Owner, redone with bounds that actually hold, plus a housing-cost sweep.
%
% The first attempt clipped: 410 of 456,000 lookups fell off the designed grid
% because the bounds were set from the DEFAULT grid's occupancy and the policies
% then moved. Same mistake as the renter's u2 floor, made twice. The fix is a
% grid generous enough for every arm here, verified by off-grid = 0 rather than
% by argument.
%
% Housing costs enter the owner's budget only through h_cost_rate = theta +
% m_rate_t, so scaling theta and the mortgage rate together scales the committed
% outflow and nothing else -- the owner's counterpart of the renter's alpha
% instrument.
addpath('C:/Users/Quinn/Desktop/claudecodetest/OwnersrentersDSRI-rentproc');
clear
o = 'C:/Users/Quinn/AppData/Local/Temp/claude/C--Users-Quinn-Desktop-claudecodetest/436bd34a-d988-4e62-b323-3acd0f52035c/scratchpad/';

    function r = go(p, tag)
        p = utility.build_state_grids(p, [18 18 12], 5);
        [~,mg,sl]=config.income_profile(p);
        pf.mu_growth=mg; pf.sigma_l_log=sl; pf.p_surv=config.survival(p);
        sk=grids.shock_grid(p); an=pension.annuity_price(p,pf,sk);
        tic; sol=solver.solve_lifecycle_lna(p,pf,sk,an); el=toc;
        sm=simulate.forward(p,pf,sol,an,6000,20260511,p.b0);
        r.tag=tag; r.p=p; r.sim=sm; r.sec=el;
        r.off=sm.diagnostics.n_offgrid_u1+sm.diagnostics.n_offgrid_u2;
        tt=3:p.T-1;
        U1=sm.Y./sm.W; U2=(sm.A+sm.H)./max(sm.X+sm.A+sm.H,eps);
        r.rng=[min(min(U1(:,tt))) max(max(U1(:,tt))); min(min(U2(:,tt))) max(max(U2(:,tt)))];
        fprintf('%-16s %5.0fs off-grid %4d | u1 [%.4f %.4f] u2 [%.4f %.4f]\n', ...
            tag, el, r.off, r.rng(1,1), r.rng(1,2), r.rng(2,1), r.rng(2,2));
    end

% generous bounds, chosen to hold for every arm below
wide = @(p) setfield(setfield(setfield(setfield(setfield(setfield(p, ...
        'lambda_lo',0.0008),'lambda_hi',0.44),'grid_pow',1.6), ...
        'u2_lo',0.55),'grid_pow_u2',1),'u3_lo',0);
own  = @() setfield(setfield(setfield(setfield(config.params(),'is_owner',true), ...
        'grid_mode','none'),'polish_ver',2),'use_refine',false);

R = {};
R{end+1} = go(own(),                          'default grid');
R{end+1} = go(wide(own()),                    'designed grid');
for s = [0.5 0.25]
    q = wide(own());
    % h_cost_rate = theta + m_rate_t, so scaling both scales the committed
    % outflow and nothing else -- the owner's counterpart of scaling alpha.
    q.theta       = q.theta * s;
    q.m_rate_path = q.m_rate_path * s;
    R{end+1} = go(q, sprintf('housing cost x%.2f', s));
end
save([o 'owner_fixed.mat'],'R','-v7.3');

med=@(M) median(M,1,'omitnan'); mn=@(M) mean(M,1,'omitnan');
d2=@(v) 100*mean(abs(diff(v,2)))/mean(abs(v));
fprintf('\n%-22s', 'OWNER'); for k=1:numel(R), fprintf(' %14s', R{k}.tag); end
fprintf('\n');
lab={'C at 25','C at 40','C at 55','C at 70','C at 85','fin wealth 66', ...
     'pi at 25','pi at 45','pi at 75','|d2pi| mid','|d2pi| ret','floored %','housing cost/income 30'};
idx=[1 16 31 46 61];
for j=1:numel(lab)
    fprintf('%-22s', lab{j});
    for k=1:numel(R)
        s=R{k}.sim; p=R{k}.p;
        hc = p.theta + [p.m_rate_path(:); zeros(p.T,1)];
        switch j
            case {1,2,3,4,5}, v=med(s.C(:,idx(j)));            fprintf(' %14.0f', v);
            case 6, v=med(s.X(:,42)+s.A(:,42));                fprintf(' %14.0f', v);
            case 7, fprintf(' %14.2f', mn(s.pi(:,1)));
            case 8, fprintf(' %14.2f', mn(s.pi(:,21)));
            case 9, fprintf(' %14.2f', mn(s.pi(:,51)));
            case 10, fprintf(' %13.2f%%', d2(mn(s.pi(:,16:40))));
            case 11, fprintf(' %13.2f%%', d2(mn(s.pi(:,41:60))));
            case 12
                F=p.phi_floor*s.Y(:,1:size(s.C,2));
                fprintf(' %13.2f%%', 100*mean(mean(s.LW(:,1:size(F,2))<=F,1)));
            case 13
                fprintf(' %13.1f%%', 100*median(hc(6).*s.H(:,6)./s.disp_inc(:,6)));
        end
    end
    fprintf('\n');
end

ages=R{1}.sim.ages; K=1:75; cols=[.85 .33 .10; .20 .35 .75; .47 .67 .19; .60 .30 .70];
f=figure('Position',[80 60 1280 460],'Color','w');
tl=tiledlayout(f,1,3,'Padding','compact','TileSpacing','compact');
fld={'C','pi','fl'}; ttl={'median consumption','mean equity share','% at the floor'};
for k=1:3
    ax=nexttile(tl); hold(ax,'on'); grid(ax,'on'); ax.GridAlpha=.12;
    for m=1:numel(R)
        s=R{m}.sim; p=R{m}.p;
        switch k
            case 1, v=med(s.C(:,K));
            case 2, v=mn(s.pi(:,K));
            case 3, F=p.phi_floor*s.Y(:,1:size(s.C,2)); v=100*mean(s.LW(:,1:size(F,2))<=F,1); v=v(K);
        end
        plot(ax,ages(K),v,'Color',cols(m,:),'LineWidth',1.7);
    end
    xline(ax,67,':','Color',[.5 .5 .5]); xline(ax,25+R{1}.p.N_mort,'--','Color',[.65 .65 .65]);
    xlim(ax,[25 99]); xlabel(ax,'age'); title(ax,ttl{k},'FontWeight','normal');
    if k==2, ylim(ax,[0 1.05]); end
    if k==1, legend(ax,cellfun(@(x) x.tag, R,'uni',0),'Location','southeast','Box','off'); end
end
sgtitle(f,'Owner: node placement, then lower housing costs. Dashed = mortgage ends.','FontWeight','normal','FontSize',12);
exportgraphics(f,[o 'fig_owner_fixed.png'],'Resolution',150);
disp('done');
