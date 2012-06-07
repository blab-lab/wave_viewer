function [leny,yes_rowvec] = get_len_yvec(y)
% function [leny,[yes_rowvec]] = get_len_yvec(y)

sizey = size(y);
if length(sizey) > 2 || ((sizey(1) > 1) && (sizey(2) > 1))
  error('y must be either a row or column vector');
end
leny = max(sizey);
if nargout > 1
  if sizey(1) > 1, yes_rowvec = 1; else, yes_rowvec = 0; end
end
