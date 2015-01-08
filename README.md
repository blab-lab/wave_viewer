wave_viewer
===========

Wave Viewer is a Matlab-based analysis tool for speech waveforms.

    viewer_end_state = wave_viewer(y, [options])
    
Wave Viewer takes a signal `y` and the following optional arguments:
*   `fs` sampling rate (default: 11025)
*   `ms_framespec_gram` (default: broadband)
*   `ms_framespec_form` (default: narrowband)
*   `nfft` number of FFT points/bins (default: 4096)
*   `nlpc` number of LPC coefficients (default: 15)
*   `nformants` number of formants to track (default: 3)
*   `preemph` pre-emphasis factor (default: 0.95)
*   `pitchlimits` low and high frequency cutoffs for pitch tracking (default: [50 300])
*   `ampl_thresh4voicing` voicing threshold (default: 0 (don't apply a voicing threshold))

or a single argument `sigproc_params`, a parameter struct from the `viewer_end_state` returned by the function.

Wave Viewer requires a few functions from Matlab's Signal Processing Toolbox (zp2ss and abcdchk).

v1.0
January 2015
UCSF Speech Neuroscience Lab
[![DOI](https://zenodo.org/badge/doi/10.5281/zenodo.13839.svg)](http://dx.doi.org/10.5281/zenodo.13839)
