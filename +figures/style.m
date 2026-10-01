function st = style()
%STYLE  Colours and line settings shared by the figures.
%   Series colours follow a fixed order (blue, orange, aqua); text and axes
%   use neutral inks so that colour only ever marks a series.
hex = @(h) sscanf(h(2:end), '%2x%2x%2x', [1 3]) / 255;
st.series   = [hex('#2a78d6'); hex('#eb6834'); hex('#1baf7a')];
st.previous = hex('#898781');
st.ink      = hex('#0b0b0b');
st.ink2     = hex('#52514e');
st.muted    = hex('#898781');
st.grid     = hex('#e1e0d9');
st.lw       = 1.5;
st.band_alpha = 0.15;
st.font     = 10;
end
