function [ftrack_out,ftrack_mstaxis,ftrack_lpc_coeffs] = get_formant_tracks(y,fs,faxis,ms_framespec,nlpc_coeffs,yes_preemph,nformants,ftrack_method,yes_verbose)

if nargin < 2 || isempty(fs), fs = 11025; end
if nargin < 3 || isempty(faxis), faxis = linspace(0,fs/2,1025); end
if nargin < 4 || isempty(ms_framespec), ms_framespec = 'narrowband'; end
if nargin < 5 || isempty(nlpc_coeffs), nlpc_coeffs=14; end
if nargin < 6 || isempty(yes_preemph), yes_preemph = 1; end
if nargin < 7 || isempty(nformants), nformants = 0; end
if nargin < 8 || isempty(ftrack_method), ftrack_method = 'praat'; end
if nargin < 9 || isempty(yes_verbose), yes_verbose = 0; end

params.fs = fs;
params.nlpc = nlpc_coeffs;
switch ftrack_method
    case 'praat', ftrack_func = @praat_ftrack_func; params.nformants_max = 5; params.yes_trackperframe = 0;
    otherwise, error('formant tracking method(%s) unrecognized',ftrack_method);
end
if ~nformants, nformants = params.nformants_max; end
if nformants > params.nformants_max, error('nformants(%d) > nformants_max(%d)',nformants,nformants_max); end
params.nformants = nformants;
params.faxis = faxis;

[nsamps,~] = get_len_yvec(y);
[ms_awin,ms_astep,nsamps_frame,nsamps_astep] = get_ms_framespec(ms_framespec,fs);
y = my_preemph(y,yes_preemph);
nframes = floor((nsamps - nsamps_frame)/nsamps_astep);

params.window_size = ms_awin/1000;
params.step_size = ms_astep/1000;
params.nframes = nframes;
output = ftrack_func(y,params);
ftrack = output{1};
lpc_coeffs = output{2};
ftrack_mstaxis = output{3};

% ftrack_out(1:nformants,1:nframes) = ftrack(1:nformants,1:nframes);
ftrack_out(1:nformants,:) = ftrack(1:nformants,:); %removing nframes allows for praat tracking
if yes_verbose
  fprintf('%d\n',iframe);
end
if nargout >= 3, ftrack_lpc_coeffs = lpc_coeffs; end

function output = praat_ftrack_func(y,params)
%%% function which executes Fast Track script using params
    %must be in git repo folder to run praat function, so save current location and go there
    curr_dir = pwd;
    temp_str = which('get_fast_tracks.praat');
    praat_path = fileparts(temp_str);
    cd(praat_path)
    
    fs = params.fs;
    faxis = params.faxis;
    nlpc_coeffs = params.nlpc;
    nformants = params.nformants;

    %%% Praat wrapper code here
    % write y to file (this will be deleted later, it is just written to the
    % current directory)
    audiowrite('temp_wav.wav',y,fs)
    max_formant = 5500;
    preemphasis = 50;
    
    if ismac
        status = system(['"/Applications/Praat.app/Contents/MacOS/Praat" --run get_fast_tracks.praat "' pwd '" "temp_wav"']);
    else
        status = system(['"C:\Users\nomeland\Documents\Praat.exe" --run get_fast_tracks.praat "' pwd '" "temp_wav"']);
    end
    if status ~= 0
        error('Something went wrong in Praat analysis')
    end
    
    % clean up praat output text file to eliminate uninterpretable characters
    A = regexp( fileread('temp_wav_formants.txt'), '\n', 'split');
    headers = strsplit(A{1},'\t');
    if length(headers) == 1 % for some reason Praat sometimes uses a space to separate headers
        headers = strsplit(A{1},' ');
    end
    for i = 1:length(headers)
        curTxt = headers{i};
        startUnits = strfind(curTxt,'(');
        if ~isempty(startUnits)
            curTxt = curTxt(1:startUnits-1);
            headers{i} = curTxt;
        end
    end
    A{1} = strjoin(headers,'\t');
    fid = fopen('temp_wav_formants.txt','w');
    fprintf(fid, '%s\n', A{:});
    fclose(fid);
    
    % load formant tracks from file written by Praat and put in 'formant' output
    formant_vals = readtable('temp_wav_formants.txt','Delimiter','\t');
    
    %find number of formant values returned by praat
    for nf = 1:nformants
        form=['F' num2str(nf)]; % finds the particular formant number
        formant(nf,:) = formant_vals.(form)'; % updates row in formant
    end
    
    %find times of formants
    msaxis = formant_vals.time';
    
    % clean up by deleting files and return to previous directory
    delete temp_wav.wav 
    delete temp_wav_formants.txt
    cd(curr_dir)
    
    % establish outputs
    lpc_coeffs = [];
    output{1} = formant;
    output{2} = lpc_coeffs;
    output{3} = msaxis * 1000; %covert from s to ms
%%% end of Fast Track function
