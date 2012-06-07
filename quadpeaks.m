function [Xmax,Ymax] = quadpeaks(X2,Magspec)
% function [Xmax,Ymax] = quadpeaks(X2,Magspec) uses quadratic interpolation
% to create refined estimates (Xmax,Ymax) of original peak estimates X2 in
% spectrum Magspec.

X1 = X2 - 1; X3 = X2 + 1;
Y1 = Magspec(X1); Y2 = Magspec(X2); Y3 = Magspec(X3);
A = 0.5*(Y3 - 2*Y2 + Y1);
B = Y2 - Y1 - A.*(X2 + X1);
C = Y1 - X1.*(A.*X1 + B);
Xmax = -B./(2*A); Ymax = (B/2).*Xmax + C;
