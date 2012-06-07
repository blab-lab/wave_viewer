function my_colormap(cmap_spec,yes_reversed)
% function my_colormap([cmap_spec],[yes_reversed])

if nargin < 1 || isempty(cmap_spec), cmap_spec = 'default'; end
if nargin < 2 || isempty(yes_reversed), yes_reversed = 0; end

if ~ischar(cmap_spec)
  size_cmap = size(cmap_spec);
  if (length(size_cmap) > 2) || (size_cmap(1) ~= 64) || (size_cmap(2) ~= 1)
    error('colormap array must be 64x3');
  end
  if (min(cmap_spec(:)) < 0) || (max(cmap_spec(:)) > 1)
    error('colormap array must can only have values between 0 and 1');
  end
  colormap(cmap_spec);
else
  switch cmap_spec
    case 'my_gray'
      rampvec = linspace(0,1,64)';
      c = [rampvec rampvec rampvec];
      colormap(c);
    otherwise
      colormap(cmap_spec);
  end
end
if yes_reversed
  c = colormap;
  c = c(end:-1:1,:);
  [rc,cc] = size(c);
  for j = 1:cc, for i = 1:rc, if c(i,j) > 1, c(i,j) = 1; end, end, end
  colormap(c);
end
