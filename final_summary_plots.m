function final_summary_plots(opts)
%FINAL_SUMMARY_PLOTS  The no-DC vs DC review figures, at a chosen initial buffer.
%
%   final_summary_plots                        % 1-year buffer, both markers
%   final_summary_plots(buffer=0.5)
%   final_summary_plots(resimulate=false)      % the runs' own sims, corner buffer
%   final_summary_plots(marks="anchors")       % mark b0/b_alt instead
%   final_summary_plots(figs=["lifecycle"])    % just the life-cycle panels
%
%   Produces, into utility.output_dir(), tagged with the active grid:
%     summary_lifecycle_{renter,owner}[_lna].png   6-panel life cycle
%     summary_dc_equity_share[_lna].png            free vs glide DC share
%     summary_welfare_by_buffer[_lna].png          CEV against initial buffer
%   and prints the CEV table (DC-free and DC-glide against no-DC) at the buffer.
%
%   WHY THIS TAKES ARGUMENTS. Three scripts used to produce these figures.
%   plot_nodc_vs_dcchoice drew the life-cycle panels from each run's stored
%   simulation; this drew the identical panels after re-simulating at a
%   one-year buffer; plot_welfare_vs_buffer drew the same CEV curve as the
%   block below with b0/b_alt marked instead of the chosen buffer. Three files,
%   three copies of the drawing code, and between them exactly two real
%   parameters: which buffer, and which markers. Both are now arguments, and
%   the drawing lives in +figures where a change lands in every caller at once.
%
%   ON resimulate=false. The stored sims come from run_combined, which
%   simulates at X0_frac = 0, so they sit at the zero-buffer corner. That is
%   the degenerate anchor -- with gamma = 5 the mandatory contribution cuts an
%   already near-zero consumption and CRRA marginal utility there dominates
%   lifetime value, which is why the DC pension can look welfare-negative at
%   the corner while raising consumption at almost every later age. The buffer
%   is forced to 0 in that mode so the printed CEV describes the same household
%   the panels do. Use it to reproduce the old figures, not to read welfare.

arguments
    opts.buffer     (1,1) double  {mustBeNonnegative} = 1.0
    opts.n_sim      (1,1) double  {mustBePositive}    = 10000
    opts.resimulate (1,1) logical = true
    opts.marks      (1,1) string ...
        {mustBeMember(opts.marks, ["buffer","anchors","both","none"])} = "both"
    opts.figs       (1,:) string = ["lifecycle","equity","welfare"]
end

out_dir = utility.output_dir();
gs      = utility.grid_suffix();     % '' simplex, '_lna' cube
tenures = {'renter', 'owner'};

% Stored sims are the runs' own, produced at X0_frac = 0; reading welfare at
% any other buffer would describe a different household than the panels show.
X0 = opts.buffer;
if ~opts.resimulate && X0 ~= 0
    warning('final_summary_plots:stored_buffer', ...
        ['resimulate=false uses the runs'' stored sims, which sit at the zero ' ...
         'buffer; ignoring buffer=%g so the panels and the CEV agree.'], X0);
    X0 = 0;
end

want = @(k) any(strcmp(opts.figs, k));

fprintf('=== %s grid, X0 = %.2f yr initial liquid buffer ===\n', ...
    utility.active_grid(), X0);

S = struct();
for i = 1:numel(tenures)
    ten = tenures{i};
    B = load(fullfile(out_dir, sprintf('combined_%s_nodc%s.mat',    ten, gs)));  % no DC
    G = load(fullfile(out_dir, sprintf('combined_%s%s.mat',         ten, gs)));  % DC glide
    D = load(fullfile(out_dir, sprintf('combined_%s_freetau%s.mat', ten, gs)));  % DC free

    % Only the no-DC and free-choice arms are simulated. The glide arm enters
    % this script through its VALUE function alone -- the CEV column below --
    % and never through a path, so simulating it was 10,000 households of work
    % per tenure thrown away. It was, in the version this replaces, too.
    if opts.resimulate
        simB = simulate.forward(B.p, B.profile, B.sol, B.ann_price, opts.n_sim, [], X0);
        simD = simulate.forward(D.p, D.profile, D.sol, D.ann_price, opts.n_sim, [], X0);
    else
        simB = B.sim;  simD = D.sim;
    end

    if want('lifecycle')
        f = figures.lifecycle_panels(simB, simD, D.p, ...
            sprintf('%s: no-DC vs DC + free choice  (X_0 = %.2f yr buffer, %s grid)', ...
                    ten, X0, D.p.grid_type), ...
            {'no DC account', 'DC + free choice'});
        saveas(f, fullfile(out_dir, sprintf('summary_lifecycle_%s%s.png', ten, gs)));
        close(f);
    end

    % utility.welfare_anchor knows both coordinate systems, converts the buffer
    % into whichever one each file was solved on, and NaN-fills the simplex's
    % infeasible corners on the way -- so this reads the same quantity on either.
    gamma = D.p.gamma;
    vB = utility.welfare_anchor(B.p, B.sol.V(:,:,:,1), X0);
    vG = utility.welfare_anchor(G.p, G.sol.V(:,:,:,1), X0);
    vD = utility.welfare_anchor(D.p, D.sol.V(:,:,:,1), X0);
    cev = @(vf, vg) (vf/vg)^(1/(1-gamma)) - 1;
    fprintf('  %-7s: DC-free vs no-DC = %+6.2f%% | DC-glide vs no-DC = %+6.2f%% | free vs glide = %+5.2f%%\n', ...
        ten, 100*cev(vD,vB), 100*cev(vG,vB), 100*cev(vD,vG));

    % pi is recorded every period, tau_A only for the T-1 transitions.
    ages = double(simD.ages);
    S.(ten).ages     = ages;
    S.(ten).ages_tr  = ages(1:end-1);
    S.(ten).tau_free = mean(simD.tau_A, 1);
    S.(ten).pi_free  = mean(simD.pi(:, 1:end-1), 1);
    last_p = D.p;
end

if want('equity')
    f = figures.dc_equity_share(S, last_p, X0);
    set(f, 'Visible', 'off');
    exportgraphics(f, fullfile(out_dir, sprintf('summary_dc_equity_share%s.png', gs)), ...
                   'Resolution', 300);
    close(f);
end

if want('welfare')
    buffers = linspace(0, 10, 41);
    curves  = struct('label', {}, 'cev', {});
    for i = 1:numel(tenures)
        ten = tenures{i};
        Bs = load(fullfile(out_dir, sprintf('combined_%s_nodc%s.mat',    ten, gs)), 'sol','p');
        Ds = load(fullfile(out_dir, sprintf('combined_%s_freetau%s.mat', ten, gs)), 'sol','p');
        g  = Ds.p.gamma;
        % welfare_anchor takes the whole sweep at once and builds its
        % interpolant (and the simplex NaN fill, the expensive part) only once.
        vB = utility.welfare_anchor(Bs.p, Bs.sol.V(:,:,:,1), buffers);
        vD = utility.welfare_anchor(Ds.p, Ds.sol.V(:,:,:,1), buffers);
        curves(end+1) = struct('label', ten, ...
                               'cev', (vD ./ vB).^(1/(1-g)) - 1);  %#ok<AGROW>
    end

    marks = build_marks(opts.marks, X0, last_p);
    f = figures.welfare_buffer(buffers, curves, marks, ...
        'Value of the mandatory DC pension depends on initial liquidity');
    saveas(f, fullfile(out_dir, sprintf('summary_welfare_by_buffer%s.png', gs)));
    close(f);
end

fprintf('Saved into %s\n', out_dir);
end

% -------------------------------------------------------------------------
function marks = build_marks(which_marks, X0, p)
%BUILD_MARKS  Vertical reference lines for the buffer curve.
%   b0 and b_alt are the two buffers config.insert_anchor_nodes forces onto the
%   grid as exact nodes, so the CEV read there is solved rather than
%   interpolated -- which is the whole reason they are worth marking.
marks = struct('x', {}, 'label', {}, 'style', {});
if which_marks == "none", return; end

if any(which_marks == ["anchors","both"]) && all(isfield(p, {'b0','b_alt'}))
    marks(end+1) = struct('x', p.b0, ...
        'label', sprintf('calibrated (b_0 = %.3f)', p.b0), 'style', '-');
    marks(end+1) = struct('x', p.b_alt, ...
        'label', sprintf('sensitivity (b = %.3f)', p.b_alt), 'style', '--');
end
if any(which_marks == ["buffer","both"])
    marks(end+1) = struct('x', X0, ...
        'label', sprintf('chosen anchor X_0 = %.2f yr', X0), 'style', '-.');
end
end
