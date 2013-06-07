function [arg1,arg2,arg3] = peakfind(S)
% function [IP,np] = peakfind(S)
%  --- or ---
% function [IP,AP,np] = peakfind(S)
%
% where AP = S(IP)

IP = find((diff(sign(diff(S))))<0)+1;
AP = S(IP);

[rs,cs] = size(S);
if rs == 1
  if cs == 1
    error('cannot find peaks of a single number');
  else
    [duh,np] = size(IP);
  end
else
  if cs == 1
    [np,duh] = size(IP);
  else
    error('cannot find peaks of a matrix');
  end
end

arg1 = IP;
if nargout == 3
  arg2 = AP;
  arg3 = np;
else
  arg2 = np;
end
