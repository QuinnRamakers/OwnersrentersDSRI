function f = welfare_buffer(buffers, curves, marks, ttl)
%WELFARE_BUFFER  CEV against the initial liquid buffer, one line per arm.
%
%   f = figures.welfare_buffer(buffers, curves, marks, ttl)
%
%   buffers  1 x N, initial liquid buffer in years of income.
%   curves   struct array, one per line, with
%              .label  legend entry
%              .cev    1 x N consumption-equivalent variation, as a fraction
%                      (0.05 = +5%); converted to per cent here.
%   marks    struct array of vertical reference lines (possibly empty), with
%              .x      buffer value
%              .label  text drawn on the line
%              .style  optional line style, default '-.'
%   ttl      figure title.
%
%   Returns an invisible figure handle; the caller saves and closes it. The
%   reference markers are passed in so the caller chooses which buffers to flag.

if nargin < 3, marks = struct('x', {}, 'label', {}, 'style', {}); end
if nargin < 4 || isempty(ttl), ttl = 'Welfare gain against the initial liquid buffer'; end

% Okabe-Ito, colour-blind safe, and stable across callers so the renter line is
% the same colour in every figure that uses this.
cols = [0.00 0.45 0.70;
        0.85 0.33 0.10;
        0.00 0.62 0.45;
        0.80 0.47 0.65];

f = figure('Visible','off', 'Position',[100 100 820 500]);
hold on; grid on;

h = gobjects(1, numel(curves));
for i = 1:numel(curves)
    c = cols(mod(i-1, size(cols,1)) + 1, :);
    h(i) = plot(buffers, 100 * curves(i).cev, '-', 'LineWidth', 1.8, 'Color', c);
end

yline(0, ':k', 'LineWidth', 1.2);

for i = 1:numel(marks)
    style = '-.';
    if isfield(marks, 'style') && ~isempty(marks(i).style), style = marks(i).style; end
    % Alternate the label above and below the line so two nearby markers -- b0
    % and b_alt sit close together at the low end -- do not overprint.
    if mod(i, 2) == 1, valign = 'top'; else, valign = 'bottom'; end
    xline(marks(i).x, style, marks(i).label, ...
          'Color', [0.35 0.35 0.35], 'LineWidth', 1.4, ...
          'LabelOrientation', 'horizontal', 'LabelVerticalAlignment', valign);
end

xlabel('initial liquid buffer X_0 (years of income)');
ylabel('welfare gain vs the no-pension arm  (% CEV)');
title(ttl);
legend(h, {curves.label}, 'Location', 'southeast');
end
