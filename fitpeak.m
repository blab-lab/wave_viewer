function [p,a] = fitpeak(S,ip)
% function [p,a] = fitpeak(S,ip)

[rs,duh] = size(S);
if ip == 1
  p = 1;
  a = S(1);
elseif ip == rs
  p = rs;
  a = S(rs);
else
  [p,a] = quadpeaks(ip,S);
end
