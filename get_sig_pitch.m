function [pitchsig,pitch_taxis] = ...
    get_sig_pitch(sig,fs,params,yanalframe_ms,yanalstep_ms,yes_verbose)
% Takes in a signal and returns its pitch (f0). 
%
% If params.ptrack_method is set to 'praat' (the default), other Praat
% settings stored in input arg `params` will be used during the Praat call.
% `params` is assumed to be a structure.
%
% If params.ptrack_method is not 'praat', the legacy functionality will be
% used: pitch is calculated within this function. `params` can be either
% a struct with pitchlimits as a field (new way), or
% a vector containing pitch limits (old way).
%
% The output arguments are:
% 1.) `pitchsig`. Pitch values. Where Praat did not detect pitch, value is NaN
% 2.) `pitch_taxis`. Vector of time points (in seconds) aligned with output arg 1

if nargin < 6 || isempty(yes_verbose)
    yes_verbose = 0;
end
if nargin < 5 || isempty(yanalstep_ms)
    yanalstep_ms = 10;
end
if nargin < 4 || isempty(yanalframe_ms)
    yanalframe_ms = 30;
end
if nargin < 3 || isempty(params)
    params = struct;
    
    % these same pitch tracking settings are also stored in:
    %   free-speech\speech\get_sigproc_defaults.m
    %   wave_viewer\wave_viewer.m\get_sigproc_params
    defaultParams.pitchlimits = [75 300];
    defaultParams.ptrack_method = 'praat';
    defaultParams.ptrack_max_candidates = 15;
    defaultParams.ptrack_pitch_very_accurate_checkbox = 'no';
    defaultParams.ptrack_silence_thresh = 0.03;
    defaultParams.ptrack_voicing_thresh = 0.45;
    defaultParams.ptrack_octave_cost = 0.01;
    defaultParams.ptrack_octave_jump_cost = 0.35;
    defaultParams.ptrack_voiced_unvoiced_cost = 0.14;
    params = set_missingFields(params, defaultParams, 0);
end

if isstruct(params) && isfield(params, 'ptrack_method')
    ptrack_method = params.ptrack_method;
else
    ptrack_method = 'not_specified';
end

%%
switch ptrack_method
    case 'praat'
        % execute Praat script using params
        %must be in git repo folder to run praat function, so save current location and go there
        curr_dir = pwd;
        temp_str = which('get_pitch_tracks.praat');
        wave_viewer_path = fileparts(temp_str);
        cd(wave_viewer_path)

        %% Praat wrapper code here
        % write y to file (this will be deleted later, it is just written to the
        % current directory)

        % rescale if necessary to avoid clipping
        maxSigVal = max(abs(sig));
        if maxSigVal > .99
            scaleRatio = .99/maxSigVal;
            sig = sig.*scaleRatio;
        end

        audiowrite('temp_wav.wav',sig,fs)

        if ismac
            praat_path = '/Applications/Praat.app/Contents/MacOS/Praat';
        else
            praat_path = 'C:\Users\Public\Desktop\Praat.exe';
        end
        praatCmd = sprintf('"%s" --run get_pitch_tracks.praat "%s" "temp_wav" %d %d %s %.4f %.4f %.4f %.4f %.4f %d', ...
            praat_path, pwd, params.pitchlimits(1), params.ptrack_max_candidates, params.ptrack_pitch_very_accurate_checkbox, ...
            params.ptrack_silence_thresh, params.ptrack_voicing_thresh, params.ptrack_octave_cost, params.ptrack_octave_jump_cost, ...
            params.ptrack_voiced_unvoiced_cost, params.pitchlimits(2));
        status = system(praatCmd);
        if status ~= 0
            error('Something went wrong in Praat analysis')
        end

        % load pitch track from file written by Praat 
        ptrack_table = readtable('temp_wav_pitch.txt', 'Delimiter', ',', 'TreatAsMissing', '--undefined--');

        % set output variables
        pitchsig = round(ptrack_table.pitch', 2);
        pitch_taxis = round(ptrack_table.time', 5);  %round to one hundredth of a millisecond, which is praat's actual precision

        % clean up by deleting files that were created and return to previous
        % directory
        delete temp_wav.wav temp_wav_pitch.txt
        cd(curr_dir)
    

    otherwise % if ptrack_method is anything other than 'praat', use legacy pitch tracking code
        if isstruct(params) && isfield(params, 'pitchlimits')
            pitchlimits = params.pitchlimits;
        else
            pitchlimits = params;
        end

        [rows_sig,cols_sig] = size(sig);
        yes_transpose = 0;
        if cols_sig > 1
            if rows_sig > 1
                error('sig cannot be a matrix');
            else
                yes_transpose = 1;
            end
        end

        if yes_transpose
            sig = sig';
        end

        yanalframelen = round(fs*yanalframe_ms/1000);
        ystep = round(fs*yanalstep_ms/1000);
        nsamps = length(sig);
        nframes = floor(nsamps/ystep);

        nfft_choices = 2.^(9:15);
        idx_choices = find(nfft_choices > 2*yanalframelen);
        nfft = nfft_choices(idx_choices(1));
        nchan = nfft/2;
        freqsep = (fs/2)/nchan;

        yacfft_ifreq_llim = round(pitchlimits(1)/(2*freqsep)); % try limiting llim to half the lowest pitch limit
        if yacfft_ifreq_llim < 1, yacfft_ifreq_llim = 1; end
        if yacfft_ifreq_llim > nchan, yacfft_ifreq_llim = nchan; end
        yacfft_ifreq_ulim = round(pitchlimits(2)/freqsep);
        if yacfft_ifreq_ulim < 1, yacfft_ifreq_ulim = 1; end
        if yacfft_ifreq_ulim > nchan, yacfft_ifreq_ulim = nchan; end
        ishortest_period = round(fs/pitchlimits(2));
        ilongest_period = round(fs/pitchlimits(1));

        Yanalframe = zeros(yanalframelen,1);
        zeroimag = zeros(nfft,1);
        pitch = zeros(1,nframes);
        if yes_verbose
            fprintf('getting sig pitch:\n');
            fprintf('%d frames to process\n',nframes);
        end
        for ifr = 1:nframes
            if yes_verbose
                if ~rem(ifr, 100), fprintf('.'); end
                if ~rem(ifr,5000), fprintf('%d\n',ifr); end
            end
            Ynewchunk = sig(((ifr-1)*ystep + 1):(ifr*ystep));
            imidframe(ifr) = mean(((ifr-1)*ystep + 1):(ifr*ystep));
            Yanalframe = [Yanalframe((ystep+1):yanalframelen); Ynewchunk];

            % following is based on e:/acad/fusp/matlab/harm_noise_quat/getpitch5.m
            yfft = fft(Yanalframe,nfft);
            fullmagyfft = abs(yfft);          % the word 'full' indicates nfft sized,
            fullpspecy = fullmagyfft.^2;      % instead of the usual nchan sized
            filt_fullpspecy = fullpspecy;                 % don't try to use only half of fullpspecy:
            filt_fullpspecy(1:(yacfft_ifreq_llim-1)) = 0; % it won't give an accurate pitch period
            filt_fullpspecy((end-yacfft_ifreq_llim+1):end) = 0;
            filt_fullpspecy((yacfft_ifreq_ulim+1):(end-yacfft_ifreq_ulim)) = 0;
            yacfft = complex(filt_fullpspecy,zeroimag);
            pre_acorr = ifft(yacfft);
            yac = real(pre_acorr(1:yanalframelen)); % real(...) gets rid of tiny imaginary values
            yacsel = yac(ishortest_period:ilongest_period);
            [ipyac,npyac] = peakfind(yacsel);
            if npyac > 0
                apyac = yacsel(ipyac);
                [max_apyac,imax_apyac] = max(apyac);
                ipyac2use = ipyac(imax_apyac);
                [pyac2use,duh] = fitpeak(yacsel,ipyac2use);
                % the final '- 1' below is because yac(1) represents lag 0 in the autocorrelation
                pitch_period = (pyac2use + ishortest_period - 1) - 1;
                pitch(ifr) = fs/pitch_period;
                % in magspec, ipitch = pitch/freqsep (ipitch is a fractional number)
                % then pitch harmonics at n*ipitch + 1, for n = 1,2,...
                % use this to compute harmonics-to-noise ratio from magspec
            else
                apyac = [];
                max_apyac = 0;
                imax_apyac = 0;
                ipyac2use = 0;
                pyac2use = 0;
                pitch_period = NaN;
                pitch(ifr) = NaN;
            end
        end
        if yes_verbose
            fprintf('%d\n',ifr);
        end

        if yes_verbose, fprintf('interpolating...'); end
        imidframe4interp = [1 imidframe nsamps];
        pitch4interp = [0 pitch 0];
        w = warning('off','MATLAB:interp1:NaNinY'); % turns off warning
        pre_pitchsig = interp1(imidframe4interp,pitch4interp,1:nsamps);
        warning(w);                                 % restores old warning prefs
        if yes_verbose, fprintf('done\n'); end

        if yes_verbose, fprintf('lowpass filtering...'); end
        [B,A] = butter(5,((1000/(2*yanalframe_ms))/(fs/2)));
        % pitchsig = filtfilt(B,A,pre_pitchsig);
        pitchsig = pre_pitchsig;
        if yes_verbose, fprintf('done\n'); end
        if yes_verbose, fprintf('done getting sig pitch\n'); end

        len_pitchsig = length(pitchsig);
        pitch_taxis = (0:(len_pitchsig-1))/fs;

end


end %EOF
