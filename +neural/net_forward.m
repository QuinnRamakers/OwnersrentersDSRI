function out = net_forward(net, X)
%NET_FORWARD  The raw outputs of an exported network for inputs X (inputs x N).
%
%   out = neural.net_forward(net, X)
%
%   Hidden layers tanh(W x + b), the last layer W x + b, as Flux's Dense.

h = X;
L = double(net.n_layers);
for i = 1:L
    h = net.(sprintf('W%d', i)) * h + net.(sprintf('b%d', i))(:);
    if i < L, h = tanh(h); end
end
out = h;
end
