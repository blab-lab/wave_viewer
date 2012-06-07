function lpc_magspec = get_lpc_magspec(lpc_coeffs,faxis,fs)

H_lpc = freqz(1,lpc_coeffs,faxis,fs);
lpc_magspec = abs(H_lpc);

