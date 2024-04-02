# get_fast_tracks.praat by Henry Nomeland, 21 Mar 2024
# adapted from get_formants.praat by Ben Parrell, 18 Dec 2017
#
# measures formants for a .wav file utilizing tools and utils of FastTrack
# FastTrack code available here: https://github.com/santiagobarreda/FastTrack/
# for use with wave_viewer

include utils/trackAutoselectProcedure.praat

#Inputs
form Measure formant values for segments in a textgrid
    sentence directory_name: /Users/Ben/Documents/MATLAB/wave_viewer
    sentence file_name: temp_wav
    positive minimum_formant 0
    positive maximum_formant 5500
    positive number_steps 100
    positive num_coefs 10
    positive num_formants 3
    sentence tracking_method: burg
endform

#open the sound and select it
wav_name$ = file_name$ + ".wav"
Read from file... 'directory_name$'/'wav_name$'
soundID1$ = selected$("Sound")

#extract formants
@trackAutoselectProcedure: soundID1$, directory_name$, minimum_formant, maximum_formant, number_steps, num_coefs, num_formants, tracking_method$, 0, soundID1$, 0, 5500, 2, 0, 0
selectObject: soundID1$
formant = selected ("Formant")

#write formants
formant_name$ = file_name$ + "_formants.txt"
Down to Table... yes yes 6 no 3 yes 3 no 
Save as tab-separated file... 'directory_name$'/'formant_name$'

#extract LPC parameters
#selectObject: formant
#To LPC... fs
#Down to Matrix (lpc)

#save LPC parameters
#lpc_name$ = file_name$ + "_lpc.txt"
#Save as headerless spreadsheet file... 'directory_name$'/'lpc_name$'
