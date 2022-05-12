function viewer_end_state = wave_viewer(y,varargin)
%WAVEVIEWER  Acoustic analysis viewer.
%   [VIEWER_END_STATE] = WAVEVIEWER(Y, [options...]) If the output argument
%   VIEWER_END_STATE is provided, wave_viewer() will start blocked, otherwise command prompt is returned

yes_profile = 0;
if yes_profile, profile on; end %#ok<*UNRCH> 

%% param defaults

p.plot_params = get_plot_params;
p.sigproc_params = get_sigproc_params;
p.event_params = get_event_params;
all_ms_framespecs = get_all_ms_framespecs();

%% set options from command line

param_struct_names = fieldnames(p);
n_param_structs = length(param_struct_names);

[option_names,option_values] = make_option_specs(varargin{:});

% Change this to first loop through param_struct_names looking for those
% args (removing them from option_names and option_values) and then loop
% through the rest of option names.
% e.g.
% % set param structs
% for i=1:n_param_structs
%     % check if value exists
%     % set param struct to value
%     % remove param struct name from option_names
%     % remove param struct val from option_values
% end
% % set individual params
% for iopts = 1:length(option_names)
%     optname = option_names{iopt};
%     optval = option_values{iopt};
% end
% 

%get data
iopt = 0;
while 1
    nopts_left = length(option_names);
    iopt = iopt + 1;
    if iopt > nopts_left
        break;
    end
    the_opt_name = option_names{iopt}; the_opt_val = option_values{iopt};
    opt_idx = find(matches('sigmat',the_opt_name));
    if opt_idx
        sigmat = the_opt_val;
        option_names(iopt) = []; option_values(iopt) = []; iopt = iopt - 1;
    end
end
if ~exist('sigmat','var')
    sigmat = [];
end

iopt = 0;
while 1
    nopts_left = length(option_names);
    iopt = iopt + 1;
    if iopt > nopts_left
        break;
    end
    the_opt_name = option_names{iopt}; the_opt_val = option_values{iopt};
    opt_idx = find(matches(param_struct_names,the_opt_name));
    if opt_idx
        if ~isempty(the_opt_val)
            the_opt_val_fields = fieldnames(the_opt_val);
            nfields = length(the_opt_val_fields);
            for ifield = 1:nfields
                the_field_name = the_opt_val_fields{ifield};
                the_field_val = the_opt_val.(the_field_name);
                if ~isempty(the_field_val), p.(the_opt_name).(the_field_name) = the_field_val; end
            end
        end
        option_names(iopt) = []; option_values(iopt) = []; iopt = iopt - 1;
    end
end
% notice how the ordering here allows command line params to override values of params in command line param structures
for i_param_struct = 1:n_param_structs
    iopt = 0;
    while 1
        nopts_left = length(option_names);
        iopt = iopt + 1; if iopt > nopts_left, break; end
        the_opt_name = option_names{iopt}; the_opt_val = option_values{iopt};
        the_params_struct_name = param_struct_names{i_param_struct};
        opt_idx = find(matches(fieldnames(p.(the_params_struct_name)),the_opt_name));
        if opt_idx
            if ~isempty(the_opt_val), p.(the_params_struct_name).(the_opt_name) = the_opt_val; end
            option_names(iopt) = []; option_values(iopt) = []; iopt = iopt - 1;
        end
    end
end
nopts_left = length(option_names);
for iopt = 1:nopts_left
    the_opt_name = option_names{iopt};
    warning('option(%s) not recognized',the_opt_name);
end

%% validation check of params

if isempty(p.plot_params.hzbounds4plot), p.plot_params.hzbounds4plot = [0 p.sigproc_params.fs/2]; end

%%% convert v1.0 params to v2.0
% axfracts: make compatible with only 4 (time-based) axes
if ~isempty(p.plot_params.axfracts) && p.plot_params.axfracts.n == 5
    p.plot_params.axfracts = [];
end
% figpos: change to normalized units
if any(p.plot_params.figpos > 3)
    fig_params = get_fig_params;
    p.plot_params.figpos = fig_params.figpos_default;
end

%% blocking?

if nargout >= 1, yes_start_blocking = 1; else, yes_start_blocking = 0; end
if nargout >= 1, viewer_end_state.name = 'running'; end
fprintf('yes_start_blocking(%d)\n',yes_start_blocking);

%% set up GUI

% create new figure
hf = figure('Name',p.plot_params.name,'Units','normalized','Position',p.plot_params.figpos);
set(hf,'DeleteFcn',@delete_func);

p.guidata = guihandles(hf);
p.guidata.f = hf;

%% panels
panelPad = .01;
panelFontSize = .1;

% create panel for buttons
buttonPanelXPos = panelPad;
buttonPanelYPos = panelPad;
buttonPanelXSpan = 0.1;
buttonPanelYSpan = 1 - panelPad*2;
buttonPanelPos = [buttonPanelXPos buttonPanelYPos buttonPanelXSpan buttonPanelYSpan];
p.guidata.buttonPanel = uipanel(p.guidata.f,'Units','Normalized',...
    'Position',buttonPanelPos,...
    'FontUnits','Normalized','FontSize',panelFontSize,...
    'Tag','button_panel',...
    'BorderType','none');

% create panel for frequency-based axes
faxesPanelXPos = buttonPanelXPos + buttonPanelXSpan + panelPad*.75;
faxesPanelYPos = panelPad*2; % extra pad on bottom
faxesPanelXSpan = 1 - faxesPanelXPos - panelPad;
faxesPanelYSpan = 0.2;
faxesPanelPos = [faxesPanelXPos faxesPanelYPos faxesPanelXSpan faxesPanelYSpan];
p.guidata.faxesPanel = uipanel(p.guidata.f,'Units','Normalized',...
    'Position',faxesPanelPos,...
    'FontUnits','Normalized','FontSize',panelFontSize,...
    'Title',' frequency (Hz) ','TitlePosition','CenterTop',...
    'Tag','faxes_panel');

% create panel for time-based axes
taxesPanelXPos = faxesPanelXPos;
taxesPanelYPos = faxesPanelYPos + faxesPanelYSpan + panelPad;
taxesPanelXSpan = faxesPanelXSpan;
taxesPanelYSpan = 1 - taxesPanelYPos - panelPad;
taxesPanelPos = [taxesPanelXPos taxesPanelYPos taxesPanelXSpan taxesPanelYSpan];
p.guidata.taxesPanel = uipanel(p.guidata.f,'Units','Normalized',...
    'Position',taxesPanelPos,...
    'FontUnits','Normalized','FontSize',panelFontSize*(faxesPanelYSpan/taxesPanelYSpan),...
    'Title',' time (s) ','TitlePosition','CenterTop',...
    'Tag','taxes_panel');

%% axes
% create new axes
wave_ax = new_wave_ax(y,p);
ampl_ax = new_ampl_ax(wave_ax,p,sigmat);
pitch_ax = new_pitch_ax(wave_ax,ampl_ax,p,sigmat);
gram_ax = new_gram_ax(wave_ax,ampl_ax,p,sigmat);
spec_ax = new_spec_ax(gram_ax,p);

update_wave_ax_tlims_from_gram_ax(wave_ax,gram_ax);

% reorder the axes with wave_ax on top
ntAx = 0;
ntAx = ntAx + 1; tAx(ntAx) = ampl_ax; set_ax_i(ampl_ax,ntAx);
ntAx = ntAx + 1; tAx(ntAx) = pitch_ax; set_ax_i(pitch_ax,ntAx);
ntAx = ntAx + 1; tAx(ntAx) = gram_ax; set_ax_i(gram_ax,ntAx);
ntAx = ntAx + 1; tAx(ntAx) = wave_ax; set_ax_i(wave_ax,ntAx);
if ~isempty(p.plot_params.axfracts)
    set_axfracts(tAx,ntAx,p.plot_params.axfracts);
    reposition_ax(tAx,ntAx);
else
    redistrib_ax(tAx,ntAx);
end
cur_ax = tAx(1);

nfAx = 0;
nfAx = nfAx + 1; fAx(nfAx) = spec_ax; set_ax_i(spec_ax,nfAx);
spec_ax_ypos = spec_ax.Position(2);     % correct for smaller faxes panel
spec_ax_height = spec_ax.Position(4);   %
redistrib_ax(fAx,nfAx);                 %
spec_ax.Position(2) = spec_ax_ypos;     %
spec_ax.Position(4) = spec_ax_height;   %

%% buttons

padL = .05;

padYButton = .01;
padYBig = .02;
padYSmall = .002;
horiz_orig = padYBig;

buttonWidth = .9;
buttonHeight = .045;
buttonFontSize = .4;
sliderHeight = .025;
dropdownHeight = .03;
dropdownFontSize = .5;
editHeight = .025;
editFontSize = .6;
textHeight = buttonHeight;
textFontSize = buttonFontSize;
textPosYOffset = 0.0240;
tinyHeight = textHeight*.75;
tinyPosYOffset = textPosYOffset*.75;

hbutton.calc = [];      % not sure why these are set: could be
normal_bgcolor = [];    % in case calcFx is somehow called by another
alert4calcFx = 0;       % function before the calc button is created

% jump-to trial text box and button
jumptoTrialTextBox = [padL horiz_orig buttonWidth/2 buttonHeight];
hbutton.jumptoTrialBox = uicontrol(p.guidata.buttonPanel,'Style','edit',...
    'String', num2str(hf.Name(7:end-1)), 'Units', 'Normalized', 'Position', jumptoTrialTextBox, ...
    'FontUnits', 'Normalized', 'FontSize', buttonFontSize, ...
    'Callback', @check4validTrialNum);
    function check4validTrialNum(hObject,eventdata) %#ok<*INUSD> 
        %validate positive numbers
        newTrialNum = str2double(hbutton.jumptoTrialBox.String);
        if newTrialNum < 1
            newTrialNum = 1;
        end
        if isnan(newTrialNum) % reset back to current trial if can't convert to double
            newTrialNum = hf.Name(7:end-1); 
        end
        % Can't validate upper limit of trial num here. wave_viewer doesn't know how many trial there are.
        % That validation happens in audioGUI.m
        set(hbutton.jumptoTrialBox, 'String', num2str(newTrialNum));
    end

jumptoTrialButton = [padL+(buttonWidth/2) horiz_orig buttonWidth/2 buttonHeight];
hbutton.jumptoTrialButton = uicontrol(p.guidata.buttonPanel,'Style','pushbutton',...
    'String', 'jump', 'Units', 'Normalized', 'Position', jumptoTrialButton, ...
    'FontUnits', 'Normalized', 'FontSize', buttonFontSize, ...
    'Callback', @jumptoProgram);
horiz_orig = horiz_orig + buttonHeight + padYButton; % increment horiz_orig only after text box AND button
    function jumptoProgram(hObject,eventdata) % callback for h_button_jumptoTrialButton
        if check4alert4calcFx('jumping')
            viewer_end_state.name = 'jump';
            viewer_end_state.jumpto_trial = str2double(hbutton.jumptoTrialBox.String);
            delete(hf);
        end
    end


% help button
helpButtonPos = [padL horiz_orig buttonWidth buttonHeight];
hbutton.help = uicontrol(p.guidata.buttonPanel,'Style','pushbutton',...
    'String','help',...
    'Units','Normalized','Position',helpButtonPos,...
    'FontUnits','Normalized','FontSize',buttonFontSize,...
    'Callback',@my_help_func);
horiz_orig = horiz_orig + buttonHeight + padYButton;
    function my_help_func(hObject,eventdata) % callback for help button
        helpstr = sprintf(['keyboard shortcuts:\n', ...
            '"v": if ampl_ax, set amplitude threshold for voicing (i.e., valid formants)\n', ...
            '"a": add a user event\n', ...
            '"d": delete a user event\n', ...
            '"rightarrow": advance tmarker_spec by one frame\n', ...
            '"leftarrow": retreat tmarker_spec by one frame\n', ...
            '"e": expand\n', ...
            '"q": quick-expand between first and last user events. If no UEVs, expands to show formants\n', ...
            '"w": widen\n', ...
            '"f": formant toggle on/off\n', ...
            '"h": heighten\n', ...
            '"u": unheighten = reduce\n']);
        helpdlg(helpstr);
    end

% play button
playButtonPos = [padL horiz_orig buttonWidth buttonHeight];
hbutton.play = uicontrol(p.guidata.buttonPanel,'Style','pushbutton',...
    'String','play',...
    'Units','Normalized','Position',playButtonPos,...
    'FontUnits','Normalized','FontSize',buttonFontSize,...
    'Callback',@playin);
horiz_orig = horiz_orig + buttonHeight + padYButton;
    function playin(hObject,eventdata) % callback for h_button_playin
        play_from_wave_ax(wave_ax);
    end

% end button
endButtonPos = [padL horiz_orig buttonWidth buttonHeight];
hbutton.end = uicontrol(p.guidata.buttonPanel,'Style','pushbutton',...
    'String','end',...
    'Units','Normalized','Position',endButtonPos,...
    'FontUnits','Normalized','FontSize',buttonFontSize,...
    'Callback',@endprogram);
horiz_orig = horiz_orig + buttonHeight + padYButton;
    function endprogram(hObject,eventdata) % callback for h_button_endprogram
        if check4alert4calcFx('ending')
            viewer_end_state.name = 'end';
            delete(hf);
        end
    end

% continue button
contButtonPos = [padL horiz_orig buttonWidth buttonHeight];
hbutton.cont = uicontrol(p.guidata.buttonPanel,'Style','pushbutton',...
    'String','continue',...
    'Units','Normalized','Position',contButtonPos,...
    'FontUnits','Normalized','FontSize',buttonFontSize,...
    'Callback',@contprogram);
horiz_orig = horiz_orig + buttonHeight + padYButton;
    function contprogram(hObject,eventdata) % callback for h_button_contprogram
        if check4alert4calcFx('continuing')
            viewer_end_state.name = 'cont';
            delete(hf);
        end
    end
    function yes_end = check4alert4calcFx(endcont_str)
        yes_end = 1;
        if alert4calcFx
            calc_quest_response = questdlg(sprintf('recalculate before %s?',endcont_str));
            switch calc_quest_response
                case 'Yes',  calcFx([],[]), yes_end = 1;
                case 'No', yes_end = 1;
                case 'Cancel', yes_end = 0;
            end
        end
    end

% clear events button
clearEventsButtonPos = [padL horiz_orig buttonWidth buttonHeight];
hbutton.clear_events = uicontrol(p.guidata.buttonPanel,'Style','pushbutton',...
    'String','clear events',...
    'Units','Normalized','Position',clearEventsButtonPos,...
    'FontUnits','Normalized','FontSize',buttonFontSize,...
    'Callback',@clear_events);
horiz_orig = horiz_orig + buttonHeight + padYButton;
    function clear_events(hObject,eventdata) % callback for h_button_clear_events
        clear_all_user_events(ntAx,tAx);
    end

% bad trial button
goodBGcolor = [0 0.9 0];
badBGcolor = [0.9 0 0];
badTrialButtonPos = [padL horiz_orig buttonWidth buttonHeight];
hbutton.bad_trial = uicontrol(p.guidata.buttonPanel,'Style','pushbutton',...
    'String','toggle good/bad trial',...
    'Units','Normalized','Position',badTrialButtonPos,...
    'FontUnits','Normalized','FontSize',buttonFontSize,...
    'Callback',@toggle_bad_trial);
horiz_orig = horiz_orig + buttonHeight + padYBig;
update_toggle_display;
    function toggle_bad_trial(hObject,eventdata) % callback for hbutton.bad_trial
        if p.event_params.is_good_trial
            p.event_params.is_good_trial = 0;
        else
            p.event_params.is_good_trial = 1;
        end
        update_toggle_display;
    end
    function update_toggle_display()
        if p.event_params.is_good_trial
            set(hbutton.bad_trial,'String','good');
            set(hbutton.bad_trial,'BackgroundColor',goodBGcolor);
        else
            set(hbutton.bad_trial,'String','bad');
            set(hbutton.bad_trial,'BackgroundColor',badBGcolor);
        end
    end

% pre-emphasis:
% pre-emphasis slider
preemphSliderPos = [padL horiz_orig buttonWidth sliderHeight];
hslider.preemph = uicontrol(p.guidata.buttonPanel,'Style','slider',...
    'Min',p.sigproc_params.preemph_range(1),...
    'Max',p.sigproc_params.preemph_range(2),...
    'SliderStep', [0.01 0.1],...
    'Value',p.sigproc_params.preemph, ...
    'Units','Normalized','Position',preemphSliderPos,...
    'Callback',@set_preemph);
horiz_orig = horiz_orig + sliderHeight + padYSmall;

% pre-emphasis edit
preemphEditPos = [padL horiz_orig buttonWidth editHeight];
hedit.preemph = uicontrol(p.guidata.buttonPanel,'Style','edit',...
    'String',p.sigproc_params.preemph, ...
    'Units','Normalized','Position',preemphEditPos,...
    'FontUnits','Normalized','FontSize',editFontSize,...
    'TooltipString','Default of 0 includes Praat preemph');
horiz_orig = horiz_orig + editHeight + padYSmall;

% pre-emphasis text
horiz_orig = horiz_orig - textPosYOffset;
preemphTextPos = [padL horiz_orig buttonWidth textHeight];
htext.preemph = uicontrol(p.guidata.buttonPanel,'Style','text',...
    'String','preemph',...
    'Units','Normalized','Position',preemphTextPos,...
    'FontUnits','Normalized','FontSize',textFontSize);
uistack(htext.preemph,'bottom'); % move to bottom
horiz_orig = horiz_orig + textHeight + padYBig;
last_sigproc_params.preemph = p.sigproc_params.preemph;
    function set_preemph(hObject,eventdata) % callback for h_slider_preemph
        p.sigproc_params.preemph = get(hObject, 'Value');
        set(hedit.preemph,'String',p.sigproc_params.preemph);
        set_alert4calcFx_if_true(last_sigproc_params.preemph ~= p.sigproc_params.preemph);
        calcFx(hObject,eventdata);
    end

% gram color:
% gram color: thresh gray slider
threshGraySliderPos = [padL horiz_orig buttonWidth sliderHeight];
hslider.thresh_gray = uicontrol(p.guidata.buttonPanel,'Style','slider',...
    'Min',0,'Max',1,'SliderStep', [0.01 0.1],...
    'Value',p.plot_params.thresh_gray, ...
    'Units','Normalized','Position',threshGraySliderPos,...
    'Callback',@set_thresh_gray);
horiz_orig = horiz_orig + sliderHeight + padYSmall;
    function set_thresh_gray(hObject,eventdata) % callback for h_slider_thresh_gray
        p.plot_params.thresh_gray = get(hObject, 'Value');
        if p.plot_params.yes_gray
            my_colormap('my_gray',1,p.plot_params.thresh_gray,p.plot_params.max_gray);
        end
    end

% gram color: max gray slider
maxGraySliderPos = [padL horiz_orig buttonWidth sliderHeight];
hslider.max_gray = uicontrol(p.guidata.buttonPanel,'Style','slider',...
    'Min',0,'Max',1,'SliderStep', [0.01 0.1],...
    'Value',p.plot_params.max_gray, ...
    'Units','Normalized','Position',maxGraySliderPos,...
    'Callback',@set_max_gray); %#ok<STRNU> 
horiz_orig = horiz_orig + sliderHeight + padYSmall;

% gram color: text
horiz_orig = horiz_orig - textPosYOffset;
maxGrayTextPos = [padL horiz_orig buttonWidth textHeight];
htext.max_gray = uicontrol(p.guidata.buttonPanel,'Style','text',...
    'String','gram color',...
    'Units','Normalized','Position',maxGrayTextPos,...
    'FontUnits','Normalized','FontSize',textFontSize);
uistack(htext.max_gray,'bottom'); % move to bottom
horiz_orig = horiz_orig + textHeight + padYBig;
    function set_max_gray(hObject,eventdata) % callback for h_slider_max_gray
        p.plot_params.max_gray = get(hObject, 'Value');
        if p.plot_params.yes_gray
            my_colormap('my_gray',1,p.plot_params.thresh_gray,p.plot_params.max_gray);
        end
    end

% ms framespec:
n_framespecs = length(all_ms_framespecs.name);
framespec_choice_str = cell(1,n_framespecs);
for i_framespec = 1:n_framespecs
    framespec_choice_str{i_framespec} = sprintf('%.0f/%.1fms, %s',all_ms_framespecs.ms_frame(i_framespec),all_ms_framespecs.ms_frame_advance(i_framespec),all_ms_framespecs.name{i_framespec});
end

% ms framespec: gram dropdown
if ~ischar(p.sigproc_params.ms_framespec_gram)
    error('sorry: we only support named ms_framespecs right now');
end
initial_dropdown_value = find(matches(all_ms_framespecs.name,p.sigproc_params.ms_framespec_gram));
if isempty(initial_dropdown_value), initial_dropdown_value = 1; end
msFramespecGramDropdownPos = [padL horiz_orig buttonWidth dropdownHeight];
hdropdown.ms_framespec_gram = uicontrol(p.guidata.buttonPanel,'Style','popupmenu',...
    'String',framespec_choice_str,...
    'Value',initial_dropdown_value, ...
    'Units','Normalized','Position',msFramespecGramDropdownPos,...
    'FontUnits','Normalized','FontSize',dropdownFontSize,...
    'Callback',@set_ms_framespec_gram);
horiz_orig = horiz_orig + dropdownHeight + padYSmall;

% ms framespec: gram text
horiz_orig = horiz_orig - tinyPosYOffset;
msFramespecGramTextPos = [padL horiz_orig buttonWidth tinyHeight];
htext.ms_framespec_gram = uicontrol(p.guidata.buttonPanel,'Style','text',...
    'String','framespec: gram',...
    'Units','Normalized','Position',msFramespecGramTextPos,...
    'FontUnits','Normalized','FontSize',textFontSize);
uistack(htext.ms_framespec_gram,'bottom'); % move to bottom
horiz_orig = horiz_orig + tinyHeight + padYSmall;
last_sigproc_params.ms_framespec_gram = p.sigproc_params.ms_framespec_gram;
    function set_ms_framespec_gram(hObject,eventdata) % callback for hdropdown.ms_framespec_gram
        p.sigproc_params.ms_framespec_gram = all_ms_framespecs.name{get(hdropdown.ms_framespec_gram,'Value')};
        set_alert4calcFx_if_true(~strcmp(last_sigproc_params.ms_framespec_gram,p.sigproc_params.ms_framespec_gram));
    end

% ms framespec: formant dropdown
if ~ischar(p.sigproc_params.ms_framespec_form)
    error('sorry: we only support named ms_framespecs right now');
end
initial_dropdown_value = find(matches(all_ms_framespecs.name,p.sigproc_params.ms_framespec_form));
if isempty(initial_dropdown_value), initial_dropdown_value = 1; end
msFramespecFormDropdownPos = [padL horiz_orig buttonWidth dropdownHeight];
hdropdown.ms_framespec_form = uicontrol(p.guidata.buttonPanel,'Style','popupmenu',...
    'String',framespec_choice_str,...
    'Value',initial_dropdown_value, ...
    'Units','Normalized','Position',msFramespecFormDropdownPos,...
    'FontUnits','Normalized','FontSize',dropdownFontSize,...
    'Callback',@set_ms_framespec_form);
horiz_orig = horiz_orig + dropdownHeight + padYSmall;

% ms framespec: formant text
horiz_orig = horiz_orig - tinyPosYOffset;
msFramespecFormTextPos = [padL horiz_orig buttonWidth tinyHeight];
htext.ms_framespec_form = uicontrol(p.guidata.buttonPanel,'Style','text',...
    'String','framespec: formants',...
    'Units','Normalized','Position',msFramespecFormTextPos,...
    'FontUnits','Normalized','FontSize',textFontSize);
uistack(htext.ms_framespec_form,'bottom'); % move to bottom
horiz_orig = horiz_orig + tinyHeight + padYBig;
last_sigproc_params.ms_framespec_form = p.sigproc_params.ms_framespec_form;
    function set_ms_framespec_form(hObject,eventdata) % callback for hdropdown.ms_framespec_form
        p.sigproc_params.ms_framespec_form = all_ms_framespecs.name{get(hdropdown.ms_framespec_form,'Value')};
        set_alert4calcFx_if_true(~strcmp(last_sigproc_params.ms_framespec_form ,p.sigproc_params.ms_framespec_form));
    end

% nlpc dropdown
nchoices = length(p.sigproc_params.nlpc_choices);
for ichoice = 1:nchoices
    nlpc_choice_strs{ichoice} = sprintf('%d',p.sigproc_params.nlpc_choices(ichoice)); %#ok<*AGROW> 
end
initial_dropdown_value = find(p.sigproc_params.nlpc_choices == p.sigproc_params.nlpc);
if isempty(initial_dropdown_value), initial_dropdown_value = 1; end
nlpcDropdownPos = [padL horiz_orig buttonWidth dropdownHeight];
hdropdown.nlpc = uicontrol(p.guidata.buttonPanel,'Style','popupmenu',...
    'String',nlpc_choice_strs,...
    'Value',initial_dropdown_value, ...
    'Units','Normalized','Position',nlpcDropdownPos,...
    'FontUnits','Normalized','FontSize',dropdownFontSize,...
    'Callback',@set_nlpc_choice);
horiz_orig = horiz_orig + dropdownHeight + padYSmall;

% nlpc text
horiz_orig = horiz_orig - textPosYOffset;
nlpcTextPos = [padL horiz_orig buttonWidth textHeight];
htext.nlpc     = uicontrol(p.guidata.buttonPanel,'Style','text',...
    'String','LPC order',...
    'Units','Normalized','Position',nlpcTextPos,...
    'FontUnits','Normalized','FontSize',textFontSize);
uistack(htext.nlpc,'bottom'); % move to bottom
horiz_orig = horiz_orig + textHeight + padYBig;
last_sigproc_params.nlpc = p.sigproc_params.nlpc;
    function set_nlpc_choice(hObject,eventdata) % callback for hdropdown.nlpc
        p.sigproc_params.nlpc = p.sigproc_params.nlpc_choices(get(hdropdown.nlpc,'Value'));
        set_alert4calcFx_if_true(last_sigproc_params.nlpc ~= p.sigproc_params.nlpc)
    end

% amplitude threshold edit
amplThreshEditPos = [padL horiz_orig buttonWidth editHeight];
hedit.ampl_thresh4voicing = uicontrol(p.guidata.buttonPanel,'Style','edit',...
    'String',p.sigproc_params.ampl_thresh4voicing, ...
    'Units','Normalized','Position',amplThreshEditPos,...
    'FontUnits','Normalized','FontSize',editFontSize,...
    'Callback',@set_edit_ampl_thresh4voicing);
horiz_orig = horiz_orig + editHeight + padYSmall;

% amplitude threshold text
horiz_orig = horiz_orig - textPosYOffset;
amplThreshTextPos = [padL horiz_orig buttonWidth textHeight];
p.guidata.text_ampl_thresh4voicing = uicontrol(p.guidata.buttonPanel,'Style','text',...
    'String','ampl threshold',...
    'Units','Normalized','Position',amplThreshTextPos,...
    'FontUnits','Normalized','FontSize',textFontSize);
uistack(p.guidata.text_ampl_thresh4voicing,'bottom'); % move to bottom
horiz_orig = horiz_orig + textHeight + padYBig;
    function set_edit_ampl_thresh4voicing(hObject,eventdata) % callback for hedit.ampl_thresh4voicing
        set_ampl_thresh4voicing(str2double(get(hedit.ampl_thresh4voicing,'String')));
    end

last_sigproc_params.ampl_thresh4voicing = p.sigproc_params.ampl_thresh4voicing;
    function set_ampl_thresh4voicing(new_ampl_thresh4voicing)
        if ~isempty(new_ampl_thresh4voicing)
            p.sigproc_params.ampl_thresh4voicing = new_ampl_thresh4voicing;
            set(hedit.ampl_thresh4voicing,'String',new_ampl_thresh4voicing);
            update_ampl_ax(  ampl_ax,wave_ax,        p);
            set_alert4calcFx_if_true(last_sigproc_params.ampl_thresh4voicing ~= p.sigproc_params.ampl_thresh4voicing);
        end
    end

% show/hide formant button
calcButtonPos = [padL horiz_orig buttonWidth buttonHeight];
hbutton.toggle_formant = uicontrol(p.guidata.buttonPanel,'Style','pushbutton',...
    'String','toggle formants',...
    'Units','Normalized','Position',calcButtonPos,...
    'FontUnits','Normalized','FontSize',buttonFontSize,...
    'Callback',@toggle_formants);
horiz_orig = horiz_orig + buttonHeight + padYButton;
    function toggle_formants(hObject,eventdata) % callback for hbutton.toggle_formant
        axinfo = get(gram_ax,'UserData');
        locF1 = find(gram_ax.Children == axinfo.hply(2));
        locF2 = find(gram_ax.Children == axinfo.hply(3));
        if strcmp(gram_ax.Children(locF1).Visible,'on')
            set(gram_ax.Children(locF1),'Visible','off')
            set(axinfo.hply(2),'Visible','off')
            set(gram_ax.Children(locF2),'Visible','off')
            set(axinfo.hply(3),'Visible','off')
        else
            set(gram_ax.Children(locF1),'Visible','on')
            set(axinfo.hply(2),'Visible','on')
            set(gram_ax.Children(locF2),'Visible','on')
            set(axinfo.hply(3),'Visible','on')
        end
        set(gram_ax,'UserData',axinfo);
    end
% calc button
calcButtonPos = [padL horiz_orig buttonWidth buttonHeight];
hbutton.calc = uicontrol(p.guidata.buttonPanel,'Style','pushbutton',...
    'String','calc',...
    'Units','Normalized','Position',calcButtonPos,...
    'FontUnits','Normalized','FontSize',buttonFontSize,...
    'Callback',@calcFx);
horiz_orig = horiz_orig + buttonHeight + padYButton; %#ok<NASGU> 
normal_bgcolor = get(hbutton.calc,'BackgroundColor');
    function calcFx(hObject,eventdata) % callback for hbutton.calc
        update_ampl_ax(  ampl_ax,wave_ax,        p);
        update_pitch_ax(pitch_ax,wave_ax,ampl_ax,p);
        update_gram_ax(  gram_ax,wave_ax,ampl_ax,p);
        update_spec_ax(  spec_ax,gram_ax);
        last_sigproc_params = p.sigproc_params;
        set(hbutton.calc,'BackgroundColor',normal_bgcolor);
        alert4calcFx = 0;
    end
    function set_alert4calcFx_if_true(yes_true)
        alert4calcFx = yes_true;
        if alert4calcFx
            set(hbutton.calc,'BackgroundColor',badBGcolor);
        else
            set(hbutton.calc,'BackgroundColor',normal_bgcolor);
        end
    end

%% key press events
marker_captured = 0;

    function key_press_func(~,event)
        the_ax = cur_ax_from_curpt(ntAx,tAx);
        the_axinfo = get(the_ax,'UserData');
        if ~isempty(the_ax) && ~isempty(the_axinfo.h_tmarker_low)
            switch(event.Key)
                case 'v' % if ampl_ax, set amplitude threshold for voicing (i.e., valid formants)
                    ampl_thresh4voicing = get_ampl_thresh4voicing(the_ax,ntAx,tAx);
                    set_ampl_thresh4voicing(ampl_thresh4voicing);
                case 'a' % add a user event
                    add_user_event(the_ax,ntAx,tAx);
                case 'd' % delete a user event
                    delete_user_event(the_ax,ntAx,tAx);
                case 'rightarrow' % advance tmarker_spec by one frame
                    incdec_tmarker_spec(1,the_ax);
                case 'leftarrow'  % retreat tmarker_spec by one frame
                    incdec_tmarker_spec(0,the_ax);
                case 'e' % expand
                    expand_btw_ax_tmarkers(the_ax,tAx,fAx);
                case 'q' % expand between first and last user events
                    expand_btw_ax_uev(the_ax,tAx,fAx);
                case 'w' % widen
                    widen_ax_view(the_ax,tAx,fAx);
                case 'f' % toggle show/hide formants
                    toggle_formants;
                case 'h' % heighten
                    heighten_ax(the_ax);
                case 'u' % unheighten = reduce
                    unheighten_ax(the_ax);
                case 'c' % shortcut for "continue" button
                    contprogram([],[]);
                otherwise
                    fprintf('len(%d)\n',length(event.Key));
                    fprintf('%d,',event.Key);
                    fprintf('\n');
                    fprintf('%c',event.Key);
                    fprintf('\n');
            end
        end
        
        
        function incdec_tmarker_spec(yes_inc,the_ax)
            the_axinfo = get(the_ax,'UserData');
            [t_low,t_spec,t_hi] = get_ax_tmarker_times(the_ax);
            t_spec = incdec_t_spec(yes_inc,t_low,t_spec,t_hi,the_ax);
            switch the_axinfo.type
                case 'spec'
                    update_ax_tmarkers(spec_ax,t_low,t_spec,t_hi);
                otherwise
                    update_ax_tmarkers(wave_ax,t_low,t_spec,t_hi);
                    update_ax_tmarkers(gram_ax,t_low,t_spec,t_hi);
                    update_ax_tmarkers(pitch_ax,t_low,t_spec,t_hi);
                    update_ax_tmarkers(ampl_ax,t_low,t_spec,t_hi);
                    update_spec_ax(spec_ax,gram_ax);
            end
        end
        
        
        
    end

%% when figure is deleted
    function delete_func(src,event)
        iaxfr = 0;
        viewer_end_state.spec_axinfo  = get(spec_ax,'UserData');  %iaxfr = iaxfr + 1; [axfracts.x(iaxfr),axfracts.y(iaxfr)] = get_axfract(spec_ax);
        viewer_end_state.ampl_axinfo  = get(ampl_ax,'UserData');  iaxfr = iaxfr + 1; [axfracts.x(iaxfr),axfracts.y(iaxfr)] = get_axfract(ampl_ax);
        viewer_end_state.pitch_axinfo = get(pitch_ax,'UserData'); iaxfr = iaxfr + 1; [axfracts.x(iaxfr),axfracts.y(iaxfr)] = get_axfract(pitch_ax);
        viewer_end_state.gram_axinfo  = get(gram_ax,'UserData');  iaxfr = iaxfr + 1; [axfracts.x(iaxfr),axfracts.y(iaxfr)] = get_axfract(gram_ax);
        viewer_end_state.wave_axinfo  = get(wave_ax,'UserData');  iaxfr = iaxfr + 1; [axfracts.x(iaxfr),axfracts.y(iaxfr)] = get_axfract(wave_ax);
        axfracts.n = iaxfr;
        p.plot_params.axfracts = axfracts;
        is_good_trial = p.event_params.is_good_trial;
        p.event_params = viewer_end_state.wave_axinfo.p.event_params;
        p.event_params.is_good_trial = is_good_trial;
        
        
        viewer_end_state.sigproc_params = p.sigproc_params;
        viewer_end_state.plot_params = p.plot_params;
        viewer_end_state.event_params = p.event_params;
    end

%% tmarkers

    function capture_tmarker(src,event)
        marker_captured = 0;
        switch(get(src,'SelectionType'))
            case 'normal'
                cur_ax = cur_ax_from_curpt(ntAx,tAx);
                if isempty(cur_ax)
                    cur_ax = cur_ax_from_curpt(nfAx,fAx);
                end
                cur_axinfo = get(cur_ax,'UserData');
                if ~isempty(cur_ax) && ~isempty(cur_axinfo.h_tmarker_low)
                    h_captured_tmarker = capture_ax_tmarker(cur_ax);
                    set(src,'WindowButtonMotionFcn',@move_tmarker);
                    marker_captured = 1;
                end
        end
        function move_tmarker(src,event)
            move_tmarker2ax_curpt(cur_ax,h_captured_tmarker);
        end
    end
     
    function release_tmarker(src,event)
        if marker_captured
            [t_low,t_spec,t_hi,t_user_events] = get_ax_tmarker_times(cur_ax);
            if t_spec < t_low || t_spec > t_hi
                t_spec = (t_low + t_hi)/2;
            end
            if ~(cur_ax == spec_ax)
                update_ax_tmarkers(wave_ax,t_low,t_spec,t_hi,t_user_events);
                update_ax_tmarkers(gram_ax,t_low,t_spec,t_hi,t_user_events);
                update_ax_tmarkers(pitch_ax,t_low,t_spec,t_hi,t_user_events);
                update_ax_tmarkers(ampl_ax,t_low,t_spec,t_hi,t_user_events);
                update_spec_ax(spec_ax,gram_ax);
                if ~isempty(t_user_events)
                    update_user_events(ntAx,tAx,t_user_events)
                end
            end
            marker_captured = 0;
        end
        set(src,'WindowButtonMotionFcn',@set_current_ax);
    end

    function set_current_ax(src,event)
        cur_ax = cur_ax_from_curpt(ntAx,tAx);
    end

    function heighten_ax(ax2heighten)
        iax2heighten = get_iax(ax2heighten,tAx,ntAx);
        heighten_iax(iax2heighten,tAx,ntAx);
    end

    function unheighten_ax(ax2heighten)
        iax2heighten = get_iax(ax2heighten,tAx,ntAx);
        unheighten_iax(iax2heighten,tAx,ntAx);
    end

    function fig_resize_func(src,event)
        p.plot_params.figpos = get(hf,'Position');
        reposition_ax(tAx,ntAx);
    end

set(hf,'WindowButtonDownFcn',@capture_tmarker);
set(hf,'WindowButtonUpFcn',@release_tmarker);
set(hf,'WindowButtonMotionFcn',@set_current_ax);
set(hf,'KeyPressFcn',@key_press_func);
set(hf,'ResizeFcn',@fig_resize_func);
if yes_profile, profile off; end
if yes_start_blocking, uiwait(hf); end
end

%%
% end of function wave_viewer

%% ax creation/update stuff

function wave_ax = new_wave_ax(y,p)
% ensure y is a row vector
[row_y,col_y] = size(y);
if row_y > 1
    if col_y > 1, error('cannot currently handle signals that are matrices');
    else, y = y'; % make y a row vector if it was a column vector
    end
end
fs = p.sigproc_params.fs;
name = p.plot_params.name;

axdat{1} = y;
params{1}.taxis = (0:(length(y)-1))/fs;
params{1}.fs = fs;
params{1}.player_started = 0;
params{1}.start_player_t = 0;
params{1}.stop_player_t = 0;
params{1}.current_player_t = 0;
params{1}.inc_player_t = 0.01;
h_player = audioplayer(0.5*y/max(abs(y)),fs); % the scaling of y is a bit of a hack to make audioplayer play like soundsc
params{1}.h_player = h_player;
params{1}.isamps2play_total = get(h_player,'TotalSamples');
set(h_player,'StartFcn',@player_start);
set(h_player,'StopFcn',@player_stop);
set(h_player,'TimerFcn',@player_runfunc);
set(h_player,'TimerPeriod',params{1}.inc_player_t);

% create wave ax in taxesPanel
wave_ax = axes(p.guidata.taxesPanel);
set(params{1}.h_player,'UserData',wave_ax); % set the audioplayer UserData to the wave ax handle?
axinfo = new_axinfo('wave',params{1}.taxis,[],axdat,wave_ax,[],name,params{1}.taxis(1),params{1}.taxis(end),params,p);
set(wave_ax,'UserData',axinfo);
end

function update_wave_ax_tlims_from_gram_ax(wave_ax,gram_ax)
wave_axinfo = get(wave_ax,'UserData');
gram_axinfo = get(gram_ax,'UserData');
t_min = gram_axinfo.t_llim;
t_max = gram_axinfo.t_hlim;
% t_range = t_max - t_min;
the_axdat = wave_axinfo.dat{1};
hax = wave_axinfo.h;
set_viewer_axlims(hax,t_min,t_max,the_axdat);
wave_axinfo.t_llim = t_min;
wave_axinfo.t_hlim = t_max;
set(wave_ax,'UserData',wave_axinfo);
update_tmarker(wave_axinfo.h_tmarker_low,[]);
update_tmarker(wave_axinfo.h_tmarker_spec,[]);
update_tmarker(wave_axinfo.h_tmarker_hi,[]);
set(wave_ax,'UserData',wave_axinfo);
end

function ampl_ax = new_ampl_ax(wave_ax,p,sigmat)
wave_axinfo = get(wave_ax,'UserData');
fs = wave_axinfo.params{1}.fs;
y = wave_axinfo.dat{1};
ampl_thresh4voicing = p.sigproc_params.ampl_thresh4voicing;

if ~isempty(sigmat) && isfield(sigmat,'ampl')
    axdat{1} = sigmat.ampl;
    params{1}.fs = fs;
    params{1}.taxis = sigmat.ampl_taxis;
else
    [axdat{1},params{1}] = make_ampl_axdat(y,fs);
end

% create ampl ax in taxesPanel
ampl_ax = axes(p.guidata.taxesPanel);
axinfo = new_axinfo('ampl',params{1}.taxis,[],axdat,ampl_ax,[],wave_axinfo.name,params{1}.taxis(1),params{1}.taxis(end),params,wave_axinfo.p);
axinfo.hl_ampl_thresh4voicing = set_ampl_thresh4voicing_line(ampl_thresh4voicing,axinfo,[]);
set(ampl_ax,'UserData',axinfo);
end

function update_ampl_ax(ampl_ax,wave_ax,p)
wave_axinfo = get(wave_ax,'UserData');
t_min = wave_axinfo.t_llim;
t_max = wave_axinfo.t_hlim;
fs = wave_axinfo.params{1}.fs;
y = wave_axinfo.dat{1};
ampl_thresh4voicing = p.sigproc_params.ampl_thresh4voicing;
old_ampl_axinfo = get(ampl_ax,'UserData');
old_hl_ampl_thresh4voicing = old_ampl_axinfo.hl_ampl_thresh4voicing;

[axdat{1},params{1}] = make_ampl_axdat(y,fs);

ampl_axinfo = get(ampl_ax,'UserData');
ampl_axinfo.dat = axdat;
ampl_axinfo.datlims = size(axdat{1});
ampl_axinfo.params = params;
ampl_axinfo.taxis = params{1}.taxis;
set(ampl_axinfo.hply(1),'XData',params{1}.taxis);
set(ampl_axinfo.hply(1),'YData',axdat{1});
set_viewer_axlims(ampl_ax,t_min,t_max,axdat{1});
ampl_axinfo.hl_ampl_thresh4voicing = set_ampl_thresh4voicing_line(ampl_thresh4voicing,ampl_axinfo,old_hl_ampl_thresh4voicing);
set(ampl_ax,'UserData',ampl_axinfo);
update_tmarker(ampl_axinfo.h_tmarker_low,[]);
update_tmarker(ampl_axinfo.h_tmarker_spec,[]);
update_tmarker(ampl_axinfo.h_tmarker_hi,[]);
set(ampl_ax,'UserData',ampl_axinfo);
end

function [the_axdat,the_params] = make_ampl_axdat(y,fs)
yampl = get_sig_ampl(y,fs);
the_axdat = yampl;
len_yampl = length(yampl);
ampl_taxis = (0:(len_yampl-1))/fs;
the_params.fs = fs;
the_params.taxis = ampl_taxis;
end

function  hl_ampl_thresh4voicing = set_ampl_thresh4voicing_line(ampl_thresh4voicing,ampl_axinfo,old_hl_ampl_thresh4voicing)
ylim = get(ampl_axinfo.h,'YLim');
if ylim(1) <= ampl_thresh4voicing && ampl_thresh4voicing < ylim(2)
    yes_inrange2plot = 1;
else
    yes_inrange2plot = 0;
end
if isempty(old_hl_ampl_thresh4voicing)
    if yes_inrange2plot
        hl_ampl_thresh4voicing = hline(ampl_thresh4voicing,'r');
        set(hl_ampl_thresh4voicing,'Visible','on');
    else
        hl_ampl_thresh4voicing = hline(mean(ylim),'r');
        set(hl_ampl_thresh4voicing,'Visible','off');
    end
else
    hl_ampl_thresh4voicing = old_hl_ampl_thresh4voicing;
    if yes_inrange2plot
        set(hl_ampl_thresh4voicing,'YData',ampl_thresh4voicing*[1 1]);
        set(hl_ampl_thresh4voicing,'Visible','on');
    else
        set(hl_ampl_thresh4voicing,'YData',mean(ylim)*[1 1]);
        set(hl_ampl_thresh4voicing,'Visible','off');
    end
end
end

function pitch_ax = new_pitch_ax(wave_ax,ampl_ax,p,sigmat)
wave_axinfo = get(wave_ax,'UserData');
ampl_axinfo = get(ampl_ax,'UserData');
fs = wave_axinfo.params{1}.fs;
y = wave_axinfo.dat{1};

pitchlimits = p.sigproc_params.pitchlimits;
ampl_thresh4voicing = p.sigproc_params.ampl_thresh4voicing;

thresh4voicing_spec.ampl = ampl_axinfo.dat{1};
thresh4voicing_spec.ampl_taxis = ampl_axinfo.params{1}.taxis;
thresh4voicing_spec.ampl_thresh4voicing = ampl_thresh4voicing;

if ~isempty(sigmat) && isfield(sigmat,'pitch')
    axdat{1} = sigmat.pitch;
    params{1}.fs = fs;
    params{1}.taxis = sigmat.pitch_taxis;
    params{1}.pitchlimits = pitchlimits;
else
    [axdat{1},params{1}] = make_pitch_axdat(y,fs,pitchlimits,thresh4voicing_spec);
end

% create pitch ax in taxesPanel
pitch_ax = axes(p.guidata.taxesPanel);
axinfo = new_axinfo('pitch',params{1}.taxis,[],axdat,pitch_ax,[],wave_axinfo.name,params{1}.taxis(1),params{1}.taxis(end),params,wave_axinfo.p);
set(pitch_ax,'UserData',axinfo);
end

function  update_pitch_ax(pitch_ax,wave_ax,ampl_ax,p)
wave_axinfo = get(wave_ax,'UserData');
ampl_axinfo = get(ampl_ax,'UserData');
t_min = wave_axinfo.t_llim;
t_max = wave_axinfo.t_hlim;
fs = wave_axinfo.params{1}.fs;
y = wave_axinfo.dat{1};

pitchlimits = p.sigproc_params.pitchlimits;
ampl_thresh4voicing = p.sigproc_params.ampl_thresh4voicing;

thresh4voicing_spec.ampl = ampl_axinfo.dat{1};
thresh4voicing_spec.ampl_taxis = ampl_axinfo.params{1}.taxis;
thresh4voicing_spec.ampl_thresh4voicing = ampl_thresh4voicing;

% include under if statement (only if params that affect pitch are changed)
% if pitch params changed
[axdat{1},params{1}] = make_pitch_axdat(y,fs,pitchlimits,thresh4voicing_spec);
% end

pitch_axinfo = get(pitch_ax,'UserData');
pitch_axinfo.dat = axdat;
pitch_axinfo.datlims = size(axdat{1});
pitch_axinfo.params = params;
pitch_axinfo.taxis = params{1}.taxis;
set(pitch_axinfo.hply(1),'XData',params{1}.taxis);
set(pitch_axinfo.hply(1),'YData',axdat{1});
set_viewer_axlims(pitch_ax,t_min,t_max,axdat{1});
set(pitch_ax,'UserData',pitch_axinfo);
update_tmarker(pitch_axinfo.h_tmarker_low,[]);
update_tmarker(pitch_axinfo.h_tmarker_spec,[]);
update_tmarker(pitch_axinfo.h_tmarker_hi,[]);
set(pitch_ax,'UserData',pitch_axinfo);
end

function [the_axdat,the_params] = make_pitch_axdat(y,fs,pitchlimits,thresh4voicing_spec)
[ypitch,window_size,frame_step,nframes] = get_sig_pitch(y,fs,pitchlimits);
len_ypitch = length(ypitch);
pitch_taxis = (0:(len_ypitch-1))/fs;
ampl4pitch = interp1(thresh4voicing_spec.ampl_taxis,thresh4voicing_spec.ampl,pitch_taxis);
ypitch(ampl4pitch < thresh4voicing_spec.ampl_thresh4voicing) = NaN;
the_axdat = ypitch;
the_params.fs = fs;
the_params.pitchlimits = pitchlimits;
the_params.taxis = pitch_taxis;
end

function gram_ax = new_gram_ax(wave_ax,ampl_ax,p,sigmat)
wave_axinfo = get(wave_ax,'UserData');
ampl_axinfo = get(ampl_ax,'UserData');
fs = wave_axinfo.params{1}.fs;
y = wave_axinfo.dat{1};

yes_gray = p.plot_params.yes_gray;
thresh_gray = p.plot_params.thresh_gray;
max_gray = p.plot_params.max_gray;
hzbounds4plot = p.plot_params.hzbounds4plot;
ms_framespec_gram = p.sigproc_params.ms_framespec_gram;
ms_framespec_form = p.sigproc_params.ms_framespec_form;
nfft = p.sigproc_params.nfft;
nlpc = p.sigproc_params.nlpc;
nformants = p.sigproc_params.nformants;
preemph = p.sigproc_params.preemph;
ampl_thresh4voicing = p.sigproc_params.ampl_thresh4voicing;
if isfield(p.sigproc_params,'ftrack_method')
    ftrack_method = p.sigproc_params.ftrack_method;
else
    ftrack_method = 'praat';
end

if yes_gray, my_colormap('my_gray',1,thresh_gray,max_gray); end

[axdat{1},params{1}] = make_spectrogram_axdat(y,fs,ms_framespec_gram,nfft,preemph,p.sigproc_params.ftrack_method);
thresh4voicing_spec.ampl = ampl_axinfo.dat{1};
thresh4voicing_spec.ampl_taxis = ampl_axinfo.params{1}.taxis;
thresh4voicing_spec.ampl_thresh4voicing = ampl_thresh4voicing;
if ~isempty(sigmat) && isfield(sigmat,'ftrack')
    axdat{2} = sigmat.ftrack;
    params{2}.fs = fs;
    params{2}.ms_framespec = ms_framespec_form;
    params{2}.nlpc = nlpc;
    params{2}.nformants = nformants;
    params{2}.preemph = preemph;
    params{2}.faxis = params{1}.faxis;
    params{2}.taxis = sigmat.ftrack_taxis;
    params{2}.lpc_coeffs = []; %will need to add this back at some point to make plotting of formant spectrum possible
else
    [axdat{2},params{2}] = make_ftrack_axdat(y,fs,params{1}.faxis,ms_framespec_form,nlpc,preemph,nformants,thresh4voicing_spec,ftrack_method);
end

% create gram ax in taxesPanel
gram_ax = axes(p.guidata.taxesPanel);
axinfo = new_axinfo('gram',params{1}.taxis,params{1}.faxis,axdat,gram_ax,hzbounds4plot,wave_axinfo.name,params{1}.taxis(1),params{1}.taxis(end),params,wave_axinfo.p);
set(gram_ax,'UserData',axinfo);
end

function update_gram_ax(gram_ax,wave_ax,ampl_ax,p)

fig_params = get_fig_params;

wave_axinfo = get(wave_ax,'UserData');
ampl_axinfo = get(ampl_ax,'UserData');
fs = wave_axinfo.params{1}.fs;
y = wave_axinfo.dat{1};

% hzbounds4plot = p.plot_params.hzbounds4plot;
ms_framespec_gram = p.sigproc_params.ms_framespec_gram;
ms_framespec_form = p.sigproc_params.ms_framespec_form;
nfft = p.sigproc_params.nfft;
nlpc = p.sigproc_params.nlpc;
nformants = p.sigproc_params.nformants;
preemph = p.sigproc_params.preemph;
ampl_thresh4voicing = p.sigproc_params.ampl_thresh4voicing;
if isfield(p.sigproc_params,'ftrack_method')
    ftrack_method = p.sigproc_params.ftrack_method;
else
    ftrack_method = 'praat';
end

[axdat{1},params{1}] = make_spectrogram_axdat(y,fs,ms_framespec_gram,nfft,preemph,p.sigproc_params.ftrack_method);
thresh4voicing_spec.ampl = ampl_axinfo.dat{1};
thresh4voicing_spec.ampl_taxis = ampl_axinfo.params{1}.taxis;
thresh4voicing_spec.ampl_thresh4voicing = ampl_thresh4voicing;
[axdat{2},params{2}] = make_ftrack_axdat(y,fs,params{1}.faxis,ms_framespec_form,nlpc,preemph,nformants,thresh4voicing_spec,ftrack_method);

taxis = params{1}.taxis;
faxis = params{1}.faxis;

gram_axinfo = get(gram_ax,'UserData');
gram_axinfo.dat = axdat;
gram_axinfo.datlims = size(axdat{1});
gram_axinfo.params = params;
gram_axinfo.taxis = taxis;
gram_axinfo.faxis = faxis;
absS = axdat{1};
absS2plot = 20*log10(absS+fig_params.wave_viewer_logshim);
set(gram_axinfo.hply(1),'CData',absS2plot);
set(gram_axinfo.hply(1),'XData',taxis);
set(gram_axinfo.hply(1),'YData',faxis);
ftrack = axdat{2};
frame_taxis_form = params{2}.taxis;
for iformant = 1:nformants
    set(gram_axinfo.hply(iformant+1),'XData',frame_taxis_form);
    set(gram_axinfo.hply(iformant+1),'YData',ftrack(iformant,:));
end
set(gram_ax,'UserData',gram_axinfo);
update_tmarker(gram_axinfo.h_tmarker_low,[]);
update_tmarker(gram_axinfo.h_tmarker_spec,[]);
update_tmarker(gram_axinfo.h_tmarker_hi,[]);
set(gram_ax,'UserData',gram_axinfo);
end

function [the_axdat,the_params] = make_spectrogram_axdat(y,fs,ms_framespec,nfft,preemph,ftrack_method)
if strcmp(ftrack_method, 'praat')
    preemph4display = preemph + 0.95;
else
    preemph4display = preemph;
end
[absS,F,msT,window_size,frame_size] = my_specgram(y,[],fs,ms_framespec,nfft,preemph4display,0);
[nchans,nframes_gram] = size(absS);
faxis_gram = F;
frame_taxis_gram = msT/1000;
the_axdat = absS;
the_params.fs = fs;
the_params.ms_framespec = ms_framespec;
the_params.nfft = nfft;
the_params.preemph = preemph;
the_params.faxis = faxis_gram;
the_params.taxis = frame_taxis_gram;
end

function [the_axdat,the_params] = make_ftrack_axdat(y,fs,faxis,ms_framespec,nlpc,preemph,nformants,thresh4voicing_spec,ftrack_method)
[ftrack,ftrack_msT,lpc_coeffs] = get_formant_tracks(y,fs,faxis,ms_framespec,nlpc,preemph,nformants,ftrack_method,0);
[nforms,nframes_form] = size(ftrack);
frame_taxis_form = ftrack_msT/1000;
ampl4form = interp1(thresh4voicing_spec.ampl_taxis,thresh4voicing_spec.ampl,frame_taxis_form);
for iformant = 1:nformants
    ftrack(iformant,ampl4form < thresh4voicing_spec.ampl_thresh4voicing) = NaN;
end
for i_lpc_coeff = 1:nlpc
    lpc_coeffs(i_lpc_coeff,ampl4form < thresh4voicing_spec.ampl_thresh4voicing) = NaN;
end
the_axdat = ftrack;
the_params.fs = fs;
the_params.ms_framespec = ms_framespec;
the_params.nlpc = nlpc;
the_params.nformants = nformants;
the_params.preemph = preemph;
the_params.faxis = faxis;
the_params.taxis = frame_taxis_form;
the_params.lpc_coeffs = lpc_coeffs;
end

function spec_ax = new_spec_ax(gram_ax,p)
gram_axinfo = get(gram_ax,'UserData');

t_spec = get_tmarker_time(gram_axinfo.h_tmarker_spec);

absS = gram_axinfo.dat{1};
frame_taxis_gram = gram_axinfo.taxis;
faxis = gram_axinfo.faxis;

ftrack = gram_axinfo.dat{2};
lpc_coeffs = gram_axinfo.params{2}.lpc_coeffs;
frame_taxis_form = gram_axinfo.params{2}.taxis;
fs = gram_axinfo.params{2}.fs;

[axdat{1},params{1}] = make_gram_spec_axdat(absS,frame_taxis_gram,faxis,t_spec);
[axdat{2},params{2}] = make_form_spec_axdat(ftrack,lpc_coeffs,frame_taxis_form,faxis,fs,t_spec);

% create spec ax in taxesPanel -- may move to faxesPanel later
spec_ax = axes(p.guidata.faxesPanel);
axinfo = new_axinfo('spec',params{1}.taxis,[],axdat,spec_ax,[],gram_axinfo.name,params{1}.taxis(1),params{1}.taxis(end),params,gram_axinfo.p);
set(spec_ax,'UserData',axinfo);
update_spec_ax(spec_ax,gram_ax);
end

function update_spec_ax(spec_ax,gram_ax)

gram_axinfo = get(gram_ax,'UserData');
spec_axinfo = get(spec_ax,'UserData');

t_spec = get_tmarker_time(gram_axinfo.h_tmarker_spec);

absS = gram_axinfo.dat{1};
frame_taxis_gram = gram_axinfo.taxis;
faxis = gram_axinfo.faxis;

ftrack = gram_axinfo.dat{2};
lpc_coeffs = gram_axinfo.params{2}.lpc_coeffs;
frame_taxis_form = gram_axinfo.params{2}.taxis;
fs = gram_axinfo.params{2}.fs;

[axdat{1},params{1}] = make_gram_spec_axdat(absS,frame_taxis_gram,faxis,t_spec);
[axdat{2},params{2}] = make_form_spec_axdat(ftrack,lpc_coeffs,frame_taxis_form,faxis,fs,t_spec);

spec_axinfo.dat = axdat;
spec_axinfo.datlims = size(axdat{1});
spec_axinfo.params = params;

update_spec_plots(spec_axinfo.h,spec_axinfo.hply,axdat,params);

set(spec_axinfo.htitl,'String',sprintf('frame(%d), %.2fsec:',params{1}.iframe,t_spec));
set(spec_ax,'UserData',spec_axinfo);
[t_low,t_spec,t_hi] = get_ax_tmarker_times(spec_ax);
update_tmarker(spec_axinfo.h_tmarker_low, t_low);
update_tmarker(spec_axinfo.h_tmarker_spec, t_spec);
update_tmarker(spec_axinfo.h_tmarker_hi,  t_hi);
set(spec_ax,'UserData',spec_axinfo);
end

function [the_axdat,the_params] = make_gram_spec_axdat(absS,frame_taxis_gram,faxis_gram,t_spec)
iframe_gram = dsearchn(frame_taxis_gram',t_spec);
gram_frame_spec = absS(:,iframe_gram)';

the_axdat = gram_frame_spec;
the_params.iframe = iframe_gram;
the_params.taxis = faxis_gram';
end

function [the_axdat,the_params] = make_form_spec_axdat(ftrack,~,frame_taxis_form,faxis_form,~,t_spec)

iframe_form = dsearchn(frame_taxis_form',t_spec);
form_frame_formants = ftrack(:,iframe_form);
% form_frame_lpc_spec = get_lpc_magspec(lpc_coeffs(:,iframe_form),faxis_form,fs)';

% the_axdat = form_frame_lpc_spec;
the_axdat = []; % change to plot lpc spectrum
the_params.iframe = iframe_form;
the_params.taxis = faxis_form';
the_params.formants = form_frame_formants;
end

function update_spec_plots(hax,hply,axdat,params)
% fig_params = get_fig_params;

min_axdat1 = min(axdat{1}); max_axdat1 = max(axdat{1});
range_axdat1 = max_axdat1 - min_axdat1;
norm_axdat{1} = (axdat{1} - min_axdat1)/range_axdat1;

min_axdat2 = min(axdat{2}); max_axdat2 = max(axdat{2});
range_axdat2 = max_axdat2 - min_axdat2;
norm_axdat{2} = (axdat{2} - min_axdat2)/range_axdat2;

haxlims = axis(hax);
t_min = haxlims(1); t_max = haxlims(2); 
% t_range = t_max - t_min;
dat4minmax = [norm_axdat{1} norm_axdat{2}];
set_viewer_axlims(hax,t_min,t_max,dat4minmax);
% haxlims = axis(hax);
set(hply(1),'YData',norm_axdat{1}); set(hply(1),'Color','b');
% set(hply(2),'YData',norm_axdat{2}); set(hply(2),'Color','r');
% formant = params{2}.formants;
% nformants = length(formant);
% for iformant = 1:nformants
%     formant_freq = formant(iformant);
%     iformant_freq = dsearchn(params{2}.taxis',formant_freq);
%     formant_ampl = norm_axdat{2}(iformant_freq);
%     set(hply(iformant+2),'XData',formant_freq*[1 1]);
%     set(hply(iformant+2),'YData',[haxlims(3) formant_ampl]);
%     set(hply(iformant+2),'Color',fig_params.formant_colors{iformant});
%     set(hply(iformant+2),'LineWidth',fig_params.formant_marker_width);
%     h_formant_name = get(hply(iformant+2),'UserData');
%     set(h_formant_name,'Position',[formant_freq formant_ampl 0]);
%     set(h_formant_name,'FontWeight','bold');
%     set(h_formant_name,'VerticalAlignment','top');
% end
end

function axinfo = new_axinfo(axtype,taxis,faxis,axdat,hax,hzbounds4plot,name,t_min,t_max,params,p)
% instead of new_axinfo (multi-use function with switch/case statement),
% change this to specific code for each axis type, called by each make or
% update axis function?

fig_params = get_fig_params;

t_range = t_max - t_min;

axinfo.i = 0;
axinfo.type = axtype;
axinfo.name = name;
axinfo.dat = axdat;
axinfo.datlims = size(axdat{1});
axinfo.params = params;
axinfo.taxis = taxis;
axinfo.faxis = faxis;

switch axinfo.type
    case 'wave'
        hply(1) = plot(taxis,axdat{1}); % hply = handle to the plotted y?
        titlstr = sprintf('waveform(%s): %.1f sec, %d samples',name,t_range,axinfo.datlims(2));
        hylab = ylabel('ampl');
        set_viewer_axlims(hax,t_min,t_max,axdat{1});
        yes_tmarker_play = 1;
        yes_add_user_events = 1;
        spec_marker_name.name = ' %.3f s ';
        spec_marker_name.vert_align = 'top';
        spec_marker_name.bgrect.color = 'same';
        
        hax.XTickLabel = [];
        
    case 'gram'
        absS = axdat{1};
%         gram_params = params{1};
        absS2plot = 20*log10(absS+fig_params.wave_viewer_logshim);
        hply(1) = imagesc(taxis,faxis,absS2plot);
        set(hax,'YDir','normal');
        
        ftrack = axdat{2};
        ftrack_params = params{2};
        nformants = ftrack_params.nformants;
        frame_taxis_form = ftrack_params.taxis;
        hold on
        for iformant = 1:nformants
            hply(iformant+1) = plot(frame_taxis_form,ftrack(iformant,:),fig_params.formant_colors{iformant});
            set(hply(iformant+1),'LineWidth',3);
            %set(hply(iformant+1),'Visible','off'); % RPK CHANGE DO NOT TRACK
        end
        hold off
        
        titlstr = sprintf('spectrogram(%s): %.1f sec, %d frames',name,t_range,axinfo.datlims(2));
        hylab = ylabel('Hz');
        set_viewer_axlims(hax,t_min,t_max,hzbounds4plot,0);
        yes_tmarker_play = 0;
        yes_add_user_events = 1;
        
        for iformant = 1:nformants
            spec_marker_name(iformant).name = ' %.0f Hz ';
            spec_marker_name(iformant).vert_align = 'top';
            spec_marker_name(iformant).idatsources = 2;
            spec_marker_name(iformant).iidatsource4ypos = 1;
            spec_marker_name(iformant).idatrows = iformant;
            spec_marker_name(iformant).bgrect.color = 'same';
        end
        
        hax.XTickLabel = [];
        
    case 'pitch'
        hply(1) = plot(taxis,axdat{1});
        titlstr = sprintf('pitch(%s): %.1f sec, %d samples',name,t_range,axinfo.datlims(2));
        hylab = ylabel('Hz');
        set_viewer_axlims(hax,t_min,t_max,axdat{1});
        yes_tmarker_play = 0;
        yes_add_user_events = 1;
        spec_marker_name.name = ' %.0f Hz ';
        spec_marker_name.vert_align = 'top';
        spec_marker_name.idatsources = 1;
        spec_marker_name.bgrect.color = 'same';
        
        hax.XTickLabel = [];
        
    case 'ampl'
        hply(1) = plot(taxis,axdat{1});
        titlstr = sprintf('ampl(%s): %.1f sec, %d samples',name,t_range,axinfo.datlims(2));
        hylab = ylabel('ampl');
        set_viewer_axlims(hax,t_min,t_max,axdat{1});
        yes_tmarker_play = 0;
        yes_add_user_events = 1;
        spec_marker_name.name = ' %.2f ';
        spec_marker_name.vert_align = 'top';
        spec_marker_name.idatsources = 1;
        spec_marker_name.bgrect.color = 'same';
    case 'spec'
        % first, do some dummy plotting to create the hlpy's
        hply(1) = plot(taxis,axdat{1});
        hold on;
%         hply(2) = plot(taxis,axdat{2});
        formant = params{2}.formants;
        nformants = length(formant);
        for iformant = 1:nformants
            hply(iformant+2) = line(formant(iformant)*[1 1],[0 1]);
            h_formant_name = text(t_min,0,sprintf(' F%d',iformant));
            set(hply(iformant+2),'UserData',h_formant_name);
        end
        set_viewer_axlims(hax,t_min,t_max,[0 1],0);
        hold off
        
        % then do the real plotting
        update_spec_plots(hax,hply,axdat,params);
        
        titlstr = 'you should never see this';
        hylab = ylabel('ampl');
        
        yes_tmarker_play = 0;
        yes_add_user_events = 0;
        spec_marker_name.name = ' %.0f Hz ';
        spec_marker_name.vert_align = 'top';
        spec_marker_name.bgrect.color = 'same';
    otherwise
        error('axtype(%d) not recognized',axinfo.type);
end
hold on;
axinfo.h = hax;
axinfo.hply = hply;
axinfo.hylab = hylab;
set(hax,'UserData',axinfo); % potentially need this for setting up tmarkers below

axinfo.htitl = title(titlstr);
set(axinfo.htitl,'FontWeight','bold');
set(axinfo.htitl,'Units','normalized');
set(axinfo.htitl,'HorizontalAlignment','left');
set(axinfo.htitl,'Position',fig_params.title_pos)

if ~isempty(p.event_params.event_names)
    nevents = length(p.event_params.event_names);
    axinfo.p.event_params.event_names = p.event_params.event_names;
    if length(p.event_params.event_times) ~= nevents, error('# of event_times(%d) ~= # of event names(%d)',length(p.event_params.event_times),nevents); end
    axinfo.p.event_params.event_times = p.event_params.event_times;
    for ievent = 1:nevents
        h_tmarker_event(ievent) = make_tmarker(hax,'m-',p.event_params.event_names{ievent});
        update_tmarker(h_tmarker_event(ievent),p.event_params.event_times(ievent));
    end
    axinfo.nevents = nevents;
    axinfo.h_tmarker_event = h_tmarker_event;
else
    axinfo.nevents = 0;
    axinfo.p.event_params.event_names = [];
    axinfo.p.event_params.event_times = [];
    axinfo.h_tmarker_event = [];
end
axinfo.yes_add_user_events = yes_add_user_events;
axinfo.p.event_params.user_event_name_prefix = p.event_params.user_event_name_prefix;
if yes_add_user_events && ~isempty(p.event_params.user_event_names)
    n_user_events = length(p.event_params.user_event_names);
    axinfo.p.event_params.user_event_names = p.event_params.user_event_names;
    if length(p.event_params.user_event_times) ~= n_user_events, error('# of user_event_times(%d) ~= # of user_event names(%d)',length(p.event_params.user_event_times),n_user_events); end
    axinfo.p.event_params.user_event_times = p.event_params.user_event_times;
    for i_user_event = 1:n_user_events
        h_tmarker_user_event(i_user_event) = make_tmarker(hax,'c-',p.event_params.user_event_names{i_user_event});
        update_tmarker(h_tmarker_user_event(i_user_event),p.event_params.user_event_times(i_user_event));
    end
    axinfo.n_user_events = n_user_events;
    axinfo.h_tmarker_user_event = h_tmarker_user_event;
else
    axinfo.n_user_events = 0;
    axinfo.p.event_params.user_event_names = [];
    axinfo.p.event_params.user_event_times = [];
    axinfo.h_tmarker_user_event = [];
end

h_tmarker_low = make_tmarker(hax,'g-');
update_tmarker(h_tmarker_low, t_min + fig_params.tmarker_init_border*t_range);
h_tmarker_spec = make_tmarker(hax,'y-',spec_marker_name);
update_tmarker(h_tmarker_spec, t_min + t_range/2);
h_tmarker_hi = make_tmarker(hax,'r-'); 
update_tmarker(h_tmarker_hi,  t_max - fig_params.tmarker_init_border*t_range);

if yes_tmarker_play
    h_tmarker_play = make_tmarker(hax,'c-',[],[],0); update_tmarker(h_tmarker_play, t_min + fig_params.tmarker_init_border*t_range);
else
    h_tmarker_play = [];
end
axinfo.h_tmarker_low = h_tmarker_low;
axinfo.h_tmarker_spec = h_tmarker_spec;
axinfo.h_tmarker_hi  = h_tmarker_hi;
axinfo.h_tmarker_play = h_tmarker_play;

axinfo.t_llim = t_min;
axinfo.t_hlim = t_max;
end


%% audioplayer callback functions

function play_from_wave_ax(wave_ax)
[start_player_t,duh,stop_player_t] = get_ax_tmarker_times(wave_ax);
wave_axinfo = get(wave_ax,'UserData');
fs = wave_axinfo.params{1}.fs;
isamps2play_total = wave_axinfo.params{1}.isamps2play_total;
h_player = wave_axinfo.params{1}.h_player;
current_player_t = start_player_t;
isamps2play_start = round(fs*start_player_t); if isamps2play_start < 1, isamps2play_start = 1; end
isamps2play_stop  = round(fs*stop_player_t);   if isamps2play_stop  > isamps2play_total, isamps2play_stop  = isamps2play_total; end
isamps2play = [isamps2play_start isamps2play_stop];
wave_axinfo.params{1}.current_player_t = current_player_t;
set(wave_ax,'UserData',wave_axinfo);
playblocking(h_player,isamps2play);
end

function player_start(hObject,eventdata)
wave_ax = get(hObject,'UserData');
wave_axinfo = get(wave_ax,'UserData');
h_tmarker_play = wave_axinfo.h_tmarker_play;
current_player_t = wave_axinfo.params{1}.current_player_t;
update_tmarker(h_tmarker_play,current_player_t);
set(h_tmarker_play,'Visible','on');
wave_axinfo.params{1}.player_started = 0;
set(wave_ax,'UserData',wave_axinfo);
% fprintf('player started\n');
end

function player_stop(hObject,eventdata)
wave_ax = get(hObject,'UserData');
wave_axinfo = get(wave_ax,'UserData');
h_tmarker_play = wave_axinfo.h_tmarker_play;
update_tmarker(h_tmarker_play,get_tmarker_time(wave_axinfo.h_tmarker_low));
set(h_tmarker_play,'Visible','off');
% fprintf('player stopped\n');
end

function player_runfunc(hObject,eventdata)
wave_ax = get(hObject,'UserData');
wave_axinfo = get(wave_ax,'UserData');
fs = wave_axinfo.params{1}.fs;
player_started = wave_axinfo.params{1}.player_started;
[start_player_t,duh,stop_player_t] = get_ax_tmarker_times(wave_ax);
isamp_playing = get(hObject,'CurrentSample');
current_player_t = isamp_playing/fs;
if current_player_t < start_player_t
    if ~player_started
        current_player_t = start_player_t;
    else
        current_player_t = stop_player_t;
    end
else
    player_started = 1;
end
wave_axinfo.params{1}.player_started = player_started;
update_tmarker(wave_axinfo.h_tmarker_play,current_player_t);
set(wave_ax,'UserData',wave_axinfo);
% fprintf('player running(%d)\n',isamp_playing);
end

%% generic ax stuff

function set_ax_i(ax,i)
axinfo = get(ax,'UserData');
axinfo.i = i;
set(ax,'UserData',axinfo);
end

function new_t_spec = incdec_t_spec(yes_inc,t_low,t_spec,t_hi,the_ax)
the_axinfo = get(the_ax,'UserData');
taxis = the_axinfo.taxis;
[duh,itaxis] = min(abs(taxis - t_spec));
if yes_inc
    itaxis = itaxis + 1; if itaxis > the_axinfo.datlims(2), itaxis = the_axinfo.datlims(2); end
else
    itaxis = itaxis - 1; if itaxis < 1, itaxis = 1; end
end
new_t_spec = taxis(itaxis);
if new_t_spec < t_low || new_t_spec > t_hi, new_t_spec = (t_low + t_hi)/2; end
end

% function [axtype,hax,hply,h_tmarker_low,h_tmarker_spec,h_tmarker_hi] = get_ax_info(ax)
% axinfo = get(ax,'UserData');
% axtype = axinfo.type;
% hax = axinfo.h;
% hply = axinfo.hply;
% h_tmarker_low = axinfo.h_tmarker_low;
% h_tmarker_spec = axinfo.h_tmarker_spec;
% h_tmarker_hi = axinfo.h_tmarker_hi;
% end

function h_tmarker = make_tmarker(hax,linestyle,marker_name,line_width,yes_visible)
fig_params = get_fig_params;
if nargin < 3, marker_name = []; end
if nargin < 4 || isempty(line_width), line_width = fig_params.default_tmarker_width; end
if nargin < 5 || isempty(yes_visible), yes_visible = 1; end
xlims = get(hax,'XLim');
t = xlims(1);
tmarker_xdat = t*[1 1];
tmarker_ydat = get(hax,'YLim');
h_tmarker = plot(hax,tmarker_xdat,tmarker_ydat,linestyle);
set(h_tmarker,'LineWidth',line_width);
if isempty(marker_name)
    h_marker_name = [];
else
    if ~isstruct(marker_name)
        marker_name_specs(1).name = marker_name;
    else
        marker_name_specs = marker_name;
    end
    n_marker_names = length(marker_name_specs);
    for i_marker_name = 1:n_marker_names
        marker_name_spec = marker_name_specs(i_marker_name);
        if ~isfield(marker_name_spec,'name'), error('marker_name_spec must have a "name" field'); end
        if ~isfield(marker_name_spec,'vert_align'), marker_name_spec.vert_align = 'bottom'; end
        if ~isfield(marker_name_spec,'color'), marker_name_spec.color = 'k'; end
        if ~isfield(marker_name_spec,'idatsources'), marker_name_spec.idatsources = 0; end
        if ~isfield(marker_name_spec,'idatrows'), marker_name_spec.idatrows = []; end
        if ~isfield(marker_name_spec,'bgrect'), marker_name_spec.bgrect = []; end
        if ~isfield(marker_name_spec,'iidatsource4ypos'), marker_name_spec.iidatsource4ypos = []; end
        marker_name_spec.h_tmarker = h_tmarker;
        marker_name_str = get_marker_name_str(marker_name_spec,t);
        cur_hax = gca;
        axes(hax); %#ok<*LAXES> % because the text() command only works with the current axes 
        h_marker_name(i_marker_name) = text(t,tmarker_ydat(2),marker_name_str);
        axes(cur_hax);
        set(h_marker_name(i_marker_name),'VerticalAlignment',marker_name_spec.vert_align);
        if strcmp(marker_name_spec.color,'same')
            set(h_marker_name(i_marker_name),'Color',get(h_tmarker,'Color'));
        else
            set(h_marker_name(i_marker_name),'Color',marker_name_spec.color);
        end
        set(h_marker_name(i_marker_name),'UserData',marker_name_spec);
        update_marker_name_bgrect(h_marker_name(i_marker_name));
    end
end
set(h_tmarker,'UserData',h_marker_name);
if ~yes_visible, set(h_tmarker,'Visible','off'); end
end

function update_tmarker(h_tmarker,t)
if isempty(t)
    tmarker_xdat = get(h_tmarker,'XData');
    t = tmarker_xdat(1);
end
tmarker_xdat = t*[1 1];
tmarker_ydat = get(get(h_tmarker,'Parent'),'YLim');
set(h_tmarker,'XData',tmarker_xdat);
set(h_tmarker,'YData',tmarker_ydat);
h_marker_name = get(h_tmarker,'UserData');
if ~isempty(h_marker_name)
    n_marker_names = length(h_marker_name);
    for i_marker_name = 1:n_marker_names
        marker_name_spec = get(h_marker_name(i_marker_name),'UserData');
        marker_name_str = get_marker_name_str(marker_name_spec,t);
        set(h_marker_name(i_marker_name),'String',marker_name_str);
        marker_name_xpos = tmarker_xdat(1);
        iidatsource4ypos = marker_name_spec.iidatsource4ypos;
        if isempty(iidatsource4ypos), iidatsource4ypos = 0; end
        switch iidatsource4ypos
            case 0, marker_name_ypos = tmarker_ydat(2);
            otherwise
                datsources = get_marker_name_datsources(marker_name_spec,t);
                marker_name_ypos = datsources{iidatsource4ypos};
        end
        set(h_marker_name(i_marker_name),'Position',[marker_name_xpos marker_name_ypos 0]);
        update_marker_name_bgrect(h_marker_name(i_marker_name));
    end
end
end

function marker_name_str = get_marker_name_str(marker_name_spec,t)
if any(marker_name_spec.name=='%') % is marker name a format string?
    datsources = get_marker_name_datsources(marker_name_spec,t);
    marker_name_str = sprintf(marker_name_spec.name,datsources{:});
else
    marker_name_str = marker_name_spec.name;
end
end

function datsources = get_marker_name_datsources(marker_name_spec,t)
idatsources = marker_name_spec.idatsources;
idatrows = marker_name_spec.idatrows;
ndatsources = length(idatsources);
if isempty(idatrows)
    idatrows = ones(1,ndatsources);
else
    if length(idatrows) ~= ndatsources
        error('length(idatrows)(%d) ~= ndatsources(%d)',length(idatrows),ndatsources);
    end
end
for ii = 1:ndatsources
    switch idatsources(ii)
        case 0, datsources{ii} = t;
        otherwise
            h_tmarker = marker_name_spec.h_tmarker;
            axinfo = get(get(h_tmarker,'Parent'),'UserData');
            the_dat = axinfo.dat{idatsources(ii)};
            the_taxis = axinfo.params{idatsources(ii)}.taxis;
            the_dat_idx = dsearchn(the_taxis',t);
            the_dat_irow = idatrows(ii);
            datsources{ii} = the_dat(the_dat_irow,the_dat_idx); % yes, this only works for dat's that are vectors
    end
end
end

function update_marker_name_bgrect(h_marker_name)
marker_name_spec = get(h_marker_name,'UserData');
if ~isempty(marker_name_spec.bgrect)
    m = get(h_marker_name,'Extent');
    xdat = [m(1) (m(1)+m(3)) (m(1)+m(3)) m(1)];
    ydat = [m(2) m(2) (m(2)+m(4)) (m(2)+m(4))];
    if ~isfield(marker_name_spec.bgrect,'color') || isempty(marker_name_spec.bgrect.color)
        marker_name_spec.bgrect.color = 'b';
    end
    bgrect_color = marker_name_spec.bgrect.color;
    if strcmp(bgrect_color,'same')
        h_tmarker = marker_name_spec.h_tmarker;
        bgrect_color = get(h_tmarker,'Color');
    end
    if ~isfield(marker_name_spec.bgrect,'h') || isempty(marker_name_spec.bgrect.h)
        marker_name_spec.bgrect.h = patch(xdat,ydat,bgrect_color);
        moveback(marker_name_spec.bgrect.h);
        set(marker_name_spec.bgrect.h,'LineStyle','none');
    else
        set(marker_name_spec.bgrect.h,'XData',xdat);
        set(marker_name_spec.bgrect.h,'YData',ydat);
        set(marker_name_spec.bgrect.h,'FaceColor',bgrect_color);
    end
end
set(h_marker_name,'UserData',marker_name_spec);
end

function t = get_tmarker_time(h_tmarker)
tmarker_xdat = get(h_tmarker,'XData');
t = tmarker_xdat(1);
end

% function [times,fields] = get_ax_tmarker_times(ax)
function [t_low,t_spec,t_hi,t_user_events] = get_ax_tmarker_times(ax)
axinfo = get(ax,'UserData');
t_low = get_tmarker_time(axinfo.h_tmarker_low);
t_spec = get_tmarker_time(axinfo.h_tmarker_spec);
t_hi  = get_tmarker_time(axinfo.h_tmarker_hi);
t_user_events = [];
for i = 1:length(axinfo.h_tmarker_user_event)
    t_user_events(i) = get_tmarker_time(axinfo.h_tmarker_user_event(i));
end

end

function update_ax_tmarkers(ax,t_low,t_spec,t_hi,t_user_events)
if nargin < 4, t_user_events = [];end
axinfo = get(ax,'UserData');
update_tmarker(axinfo.h_tmarker_low,t_low);
update_tmarker(axinfo.h_tmarker_spec,t_spec);
update_tmarker(axinfo.h_tmarker_hi,t_hi);

nevents = axinfo.nevents;
if nevents
    h_tmarker_event = axinfo.h_tmarker_event;
    event_times = axinfo.p.event_params.event_times;
    for ievent = 1:nevents
        update_tmarker(h_tmarker_event(ievent),event_times(ievent));
    end
end
n_user_events = axinfo.n_user_events;
if n_user_events && ~isempty(t_user_events)
    h_tmarker_user_event = axinfo.h_tmarker_user_event;
%     user_event_times = axinfo.p.event_params.user_event_times;
    for ievent = 1:n_user_events
        update_tmarker(h_tmarker_user_event(ievent),t_user_events(ievent));
    end
end
set(ax,'UserData',axinfo);
end

function ampl_thresh4voicing = get_ampl_thresh4voicing(the_ax,nax,ax)
axinfo = get(the_ax,'UserData');
if strcmp(axinfo.type,'ampl')
    ampl_ax = the_ax;
%     ampl_axinfo = axinfo;
    cp = get(ampl_ax,'CurrentPoint');
    ampl_thresh4voicing = cp(1,2);
else
    ampl_thresh4voicing = [];
end
end

function add_user_event(the_ax,nax,ax)
axinfo = get(the_ax,'UserData');
t = get_tmarker_time(axinfo.h_tmarker_spec);
if axinfo.yes_add_user_events
    for iax = 1:nax
        axinfo = get(ax(iax),'UserData');
        if axinfo.yes_add_user_events
            n_user_events = axinfo.n_user_events + 1;
            user_event_names = axinfo.p.event_params.user_event_names;
            user_event_times = axinfo.p.event_params.user_event_times;
            h_tmarker_user_event = axinfo.h_tmarker_user_event;
            
            n_prior_names = n_user_events - 1;
            for i_event_name = 1:n_user_events
                user_event_name = sprintf('%s%d',axinfo.p.event_params.user_event_name_prefix,i_event_name);
                name_taken = 0;
                for i_prior_names = 1:n_prior_names
                    if strcmp(user_event_names(i_prior_names),user_event_name)
                        name_taken = 1;
                    end
                end
                if ~name_taken
                    break;
                end
            end
            user_event_names{n_user_events} = user_event_name;
            user_event_times(n_user_events) = t;
            h_tmarker_user_event(n_user_events) = make_tmarker(ax(iax),'c-',user_event_names{n_user_events}); update_tmarker(h_tmarker_user_event(n_user_events),t);
            move2front(ax(iax),axinfo.h_tmarker_spec);
            
            axinfo.n_user_events = n_user_events;
            axinfo.p.event_params.user_event_names = user_event_names;
            axinfo.p.event_params.user_event_times = user_event_times;
            axinfo.h_tmarker_user_event = h_tmarker_user_event;
            set(ax(iax),'UserData',axinfo);
        end
    end
end
end

function update_user_events(nax,ax,t_user_events)
for iax = 1:nax
    axinfo = get(ax(iax),'UserData');
    if axinfo.yes_add_user_events
        n_user_events = axinfo.n_user_events;
        for i_event = 1:n_user_events
            axinfo.p.event_params.user_event_times(i_event) = t_user_events(i_event);  
        end

        set(ax(iax),'UserData',axinfo);
    end
end
end

function delete_user_event(the_ax,nax,ax)
fig_params = get_fig_params;
axinfo = get(the_ax,'UserData');
t = get_tmarker_time(axinfo.h_tmarker_spec);
if axinfo.yes_add_user_events
    user_event_times = axinfo.p.event_params.user_event_times;
    [ievent2del,dist2event2del] = dsearchn(user_event_times',t);
    the_ax_tlims = get(the_ax,'XLim');
    dist_fract = dist2event2del/(the_ax_tlims(2) - the_ax_tlims(1));
    if dist_fract < fig_params.max_dist_fract2del_event
        for iax = 1:nax
            axinfo = get(ax(iax),'UserData');
            if axinfo.yes_add_user_events
                n_user_events = axinfo.n_user_events;
                user_event_names = axinfo.p.event_params.user_event_names;
                user_event_times = axinfo.p.event_params.user_event_times;
                h_tmarker_user_event = axinfo.h_tmarker_user_event;
                
                user_event_names(ievent2del) = [];
                user_event_times(ievent2del) = [];
                h_marker_name = get(h_tmarker_user_event(ievent2del),'UserData');
                delete(h_marker_name);
                delete(h_tmarker_user_event(ievent2del));
                h_tmarker_user_event(ievent2del) = [];
                n_user_events = n_user_events - 1;
                
                axinfo.n_user_events = n_user_events;
                axinfo.p.event_params.user_event_names = user_event_names;
                axinfo.p.event_params.user_event_times = user_event_times;
                axinfo.h_tmarker_user_event = h_tmarker_user_event;
                set(ax(iax),'UserData',axinfo);
            end
        end
    end
end
end

function clear_all_user_events(nax,ax)
for iax = 1:nax
    axinfo = get(ax(iax),'UserData');
    if axinfo.yes_add_user_events
        n_user_events = axinfo.n_user_events;
        h_tmarker_user_event = axinfo.h_tmarker_user_event;
        for ievent2del = 1:n_user_events
            h_marker_name = get(h_tmarker_user_event(ievent2del),'UserData');
            delete(h_marker_name);
            delete(h_tmarker_user_event(ievent2del));
        end
        axinfo.n_user_events = 0;
        axinfo.p.event_params.user_event_names = [];
        axinfo.p.event_params.user_event_times = [];
        axinfo.h_tmarker_user_event = [];
        set(ax(iax),'UserData',axinfo);
    end
end
end

function cur_ax = cur_ax_from_curpt(nax,ax)
cur_ax_found = 0;
for iax = 1:nax
    the_ax = ax(iax);
    if ax_has_current_point(the_ax)
        cur_ax_found = 1;
        cur_ax = the_ax;
        break;
    end
end
if ~cur_ax_found, cur_ax = []; end
end

function yes_has_current_point = ax_has_current_point(ax)
cp = get(ax,'CurrentPoint');
x = cp(1,1); y = cp(1,2);
xl = get(ax,'XLim');
yl = get(ax,'YLim');
yes_has_current_point = ((xl(1) <= x) && (x <= xl(2))) && ((yl(1) <= y) && (y <= yl(2)));
end

function h_captured_tmarker = capture_ax_tmarker(ax)
axinfo = get(ax,'UserData');
cp = get(ax,'CurrentPoint');
t_pos = cp(1,1);
[t_tmarker_low,t_tmarker_spec,t_tmarker_hi,t_tuser_events] = get_ax_tmarker_times(ax); %#ok<*ASGLU> 
% absdiff_tmarker(1) = abs(t_pos - t_tmarker_low);
% absdiff_tmarker(2) = abs(t_pos - t_tmarker_spec);
% absdiff_tmarker(3)  = abs(t_pos - t_tmarker_hi);
% [duh,imin_tmarker] = min(absdiff_tmarker);
% switch imin_tmarker
%     case 1, h_captured_tmarker = axinfo.h_tmarker_low;
%     case 2, h_captured_tmarker = axinfo.h_tmarker_spec;
%     case 3, h_captured_tmarker = axinfo.h_tmarker_hi;
% end
absdiff_tmarker(1) = abs(t_pos - t_tmarker_low);
absdiff_tmarker(2)  = abs(t_pos - t_tmarker_hi);
for i = 1:length(t_tuser_events)
    absdiff_tmarker(end+1)  = abs(t_pos - t_tuser_events(i));
end
if any(absdiff_tmarker < 0.008)
    [~,imin_tmarker] = min(absdiff_tmarker);
    if imin_tmarker == 1
        h_captured_tmarker = axinfo.h_tmarker_low;
    elseif imin_tmarker == 2
        h_captured_tmarker = axinfo.h_tmarker_hi;
    else
        h_captured_tmarker = axinfo.h_tmarker_user_event(imin_tmarker-2);
    end
else
    h_captured_tmarker = axinfo.h_tmarker_spec;
end
update_tmarker(h_captured_tmarker,t_pos);
end

function move_tmarker2ax_curpt(ax,h_tmarker)
cp = get(ax,'CurrentPoint');
t_pos = cp(1,1);
update_tmarker(h_tmarker,t_pos);
end

% function output_interval_btw_ax_tmarkers(ax,fs)
% global yseg tseg yfs
% axinfo = get(ax,'UserData');
% taxis = get(axinfo.hply(1),'XData');
% y = get(axinfo.hply(1),'YData');
% [t_tmarker_low,t_tmarker_spec,t_tmarker_hi] = get_ax_tmarker_times(ax);
% [duh,ilow] = min(abs(taxis - t_tmarker_low));
% [duh,ihi]  = min(abs(taxis - t_tmarker_hi));
% yseg = y(ilow:ihi);
% tseg = taxis(ilow:ihi);
% yfs = fs;
% end

% function report_interval_btw_ax_tmarkers(ax,fs)
% axinfo = get(ax,'UserData');
% taxis = get(axinfo.hply(1),'XData');
% [t_tmarker_low,t_tmarker_spec,t_tmarker_hi] = get_ax_tmarker_times(ax);
% [duh,ilow] = min(abs(taxis - t_tmarker_low));
% [duh,ihi]  = min(abs(taxis - t_tmarker_hi));
% fprintf('t_low(%.3f sec), t_hi(%.3f sec), dur(%.3f sec, %d samples)\n', ...
%     t_tmarker_low,t_tmarker_hi,t_tmarker_hi-t_tmarker_low,ihi-ilow+1);
% end

function expand_btw_ax_tmarkers(ax,tAx,fAx)
fig_params = get_fig_params;
axinfo = get(ax,'UserData');
[t_tmarker_low,t_tmarker_spec,t_tmarker_hi] = get_ax_tmarker_times(ax);
t_tmarker_range = t_tmarker_hi - t_tmarker_low;
new_t_low = t_tmarker_low - fig_params.tmarker_init_border*t_tmarker_range;
new_t_hi  = t_tmarker_hi  + fig_params.tmarker_init_border*t_tmarker_range;

if any(ax == tAx)
    for i = 1:length(tAx)
        new_ax_tlims(tAx(i),new_t_low,new_t_hi);
    end
else
     for i = 1:length(fAx)
        new_ax_tlims(fAx(i),new_t_low,new_t_hi);
     end
end
    
if t_tmarker_spec < new_t_low || t_tmarker_spec > new_t_hi
    update_tmarker(axinfo.h_tmarker_spec,(new_t_low + new_t_hi)/2);
else
    update_tmarker(axinfo.h_tmarker_spec,[]);
end
end

function expand_btw_ax_uev(ax,tAx,fAx) 
[~,t_spec,~,t_user_events] = get_ax_tmarker_times(ax);

fig_params = get_fig_params;
if length(t_user_events) >= 2
    tmarker_buffer = 0.05;
    t_low = min(t_user_events) - tmarker_buffer; 
    t_hi = max(t_user_events) + tmarker_buffer; 
elseif length(t_user_events) == 1
    tmarker_buffer = 0.2;
    t_low = t_user_events(1) - tmarker_buffer;
    t_hi = t_user_events(1) + tmarker_buffer;
else
    % if no user events, find first and last time that formants are
    % present, based on ampl. threshold
    tmarker_buffer = 0.05;
    tAx_info = get(tAx,'UserData');

    f1_first = find(tAx_info{3}.dat{2}(1, :) > 0, 1, 'first');
    f1_last  = find(tAx_info{3}.dat{2}(1, :) > 0, 1, 'last');
    t_low = tAx_info{3}.params{2}.taxis(f1_first) - tmarker_buffer;
    t_hi  = tAx_info{3}.params{2}.taxis(f1_last)  + tmarker_buffer;
end

    %CWN 4/2020 -- The alignment checking in the next 19 lines could be
    %modularized and called whenever the time markers move. For now, just
    %calling it locally in the expand_btw_ax_uev function.
%finds proper axis boundaries and tmarker times
tAx_latest_start_time = intmin;
tAx_earliest_end_time = intmax;
for i = 1:length(tAx) %find the axis with the most restrictive start and end times
    if tAx(i).UserData.taxis(1) > tAx_latest_start_time
        tAx_latest_start_time = tAx(i).UserData.taxis(1);
    end
    if tAx(i).UserData.taxis(end) < tAx_earliest_end_time
        tAx_earliest_end_time = tAx(i).UserData.taxis(end);
    end
end
t_low_ax_min = tAx_latest_start_time + fig_params.tmarker_init_border*tmarker_buffer*2; %set floor and ceiling so all axes are aligned
t_hi_ax_max = tAx_earliest_end_time - fig_params.tmarker_init_border*tmarker_buffer*2;
if t_low <= t_low_ax_min %conform to floor and ceiling if necessary
    t_low = t_low_ax_min;
end
if t_hi >= t_hi_ax_max
    t_hi = t_hi_ax_max;
end
if t_low > t_hi
    warning('First user event must precede last user event.')
    return
end

%update axes with new tmarker times
if any(ax == tAx)
    for i = 1:length(tAx)
        update_ax_tmarkers(tAx(i),t_low,t_spec,t_hi,t_user_events);
    end
else
    for i = 1:length(fAx)
        update_ax_tmarkers(fAx(i),t_low,t_spec,t_hi,t_user_events);
    end
end

%adjust the axes' boundaries
expand_btw_ax_tmarkers(ax,tAx,fAx)

end

function widen_ax_view(ax,tAx,fAx)
axinfo = get(ax,'UserData');
cur_tlims = get(axinfo.h,'XLim');
cur_tlow = cur_tlims(1);
cur_thi  = cur_tlims(2);
cur_trange = cur_thi - cur_tlow;
new_t_low = cur_tlow - 0.5*cur_trange;
new_t_hi = cur_thi + 0.5*cur_trange;

if any(ax == tAx)
    for i = 1:length(tAx)
        new_ax_tlims(tAx(i),new_t_low,new_t_hi);
    end
else
     for i = 1:length(fAx)
        new_ax_tlims(fAx(i),new_t_low,new_t_hi);
     end
end
end

function new_ax_tlims(ax,new_tlow,new_thi)
axinfo = get(ax,'UserData');
t_llim = axinfo.t_llim;
t_hlim = axinfo.t_hlim;
if new_tlow < t_llim, new_tlow = t_llim; end
if new_thi > t_hlim, new_thi = t_hlim; end
set(ax,'XLim',[new_tlow new_thi]);
update_tmarker(axinfo.h_tmarker_spec,[]);
end

function redistrib_ax(ax,nax)
reinit_axfracts(ax,nax);
reposition_ax(ax,nax);
end

function set_axfracts(ax,nax,axfracts)
if nax ~= axfracts.n
    warning('nax(%d) ~= axfracts.n(%d)',nax,axfracts.n);
    reinit_axfracts(ax,nax);
else
    if abs(sum([axfracts.y]) - 1) > 0.000001
        warning('sum([axfracts.y]) ~= 1');
        reinit_axfracts(ax,nax);
    else
        for iax = 1:nax
            set_axfract(ax(iax),axfracts.x(iax),axfracts.y(iax));
        end
    end
end
end

function reinit_axfracts(ax,nax)
for iax = 1:nax
    set_axfract(ax(iax),1.0,1.0/nax);
end
end

function heighten_iax(iax2heighten,ax,nax)
fig_params = get_fig_params;
[the_axfract_x,the_axfract_y] = get_axfract(ax(iax2heighten));
the_new_axfract_y = (1+fig_params.ax_heighten_inc)*the_axfract_y;
if the_new_axfract_y > 1, the_new_axfract_y = the_axfract_y; end
set_axfract(ax(iax2heighten),the_axfract_x,the_new_axfract_y);
axfract_left = 1.0 - the_new_axfract_y;
reapportion_other_ax(iax2heighten,ax,nax,axfract_left);
reposition_ax(ax,nax);
end

function unheighten_iax(iax2heighten,ax,nax)
fig_params = get_fig_params;
[the_axfract_x,the_axfract_y] = get_axfract(ax(iax2heighten));
the_new_axfract_y = (1-fig_params.ax_heighten_inc)*the_axfract_y;
if the_new_axfract_y < 0, the_new_axfract_y = the_axfract_y; end
set_axfract(ax(iax2heighten),the_axfract_x,the_new_axfract_y);
axfract_left = 1.0 - the_new_axfract_y;
reapportion_other_ax(iax2heighten,ax,nax,axfract_left);
reposition_ax(ax,nax);
end

function reapportion_other_ax(iax2omit,ax,nax,axfract_left)
if nax > 1
    axfract_y_total = 0;
    for iax = 1:nax
        if iax ~= iax2omit
            [duh,axfract_y(iax)] = get_axfract(ax(iax));
            axfract_y_total = axfract_y_total + axfract_y(iax);
        end
    end
    for iax = 1:nax
        if iax ~= iax2omit
            new_axfract_y = (axfract_y(iax)/axfract_y_total)*axfract_left;
            [axfract_x,duh] = get_axfract(ax(iax));
            set_axfract(ax(iax),axfract_x,new_axfract_y);
        end
    end
end
end

function reposition_ax(ax,nax)
[axarea_xo,axarea_yo,axarea_xw,axarea_yw] = get_axarea();
axtile_xo = axarea_xo;
axtile_xw = axarea_xw;
axtile_yw_acc = 0;
for iax = 1:nax
    [axfract_x,axfract_y] = get_axfract(ax(iax));
    axtile_yo = axarea_yo + axtile_yw_acc;
    axtile_yw = axfract_y*axarea_yw;
    set_ax_pos(ax(iax),axtile_xo,axtile_yo,axtile_xw,axtile_yw);
    axtile_yw_acc = axtile_yw_acc + axtile_yw;
end
end

function [axarea_xo,axarea_yo,axarea_xw,axarea_yw] = get_axarea()
fig_params = get_fig_params;
axarea_xo = fig_params.figborder_xl;
axarea_yo = fig_params.figborder_yl;
axarea_xw = 1.0 - fig_params.figborder_xl - fig_params.figborder_xr;
axarea_yw = 1.0 - fig_params.figborder_yl - fig_params.figborder_yu;
end

function [axfract_x,axfract_y] = get_axfract(ax)
axinfo = get(ax,'UserData');
axfract = axinfo.axfract;
axfract_x = axfract(1);
axfract_y = axfract(2);
end

function set_axfract(ax,axfract_x,axfract_y)
axinfo = get(ax,'UserData');
axinfo.axfract = [axfract_x axfract_y];
set(ax,'UserData',axinfo);
end

function set_ax_pos(ax,axtile_xo,axtile_yo,axtile_xw,axtile_yw)
fig_params = get_fig_params;
axpos_xo  = axtile_xo + fig_params.axborder_xl*axtile_xw;
axpos_xw  = (1.0 - fig_params.axborder_xl - fig_params.axborder_xr)*axtile_xw;
axpos_yo  = axtile_yo + fig_params.axborder_yl*axtile_yw;
axpos_yw  = (1.0 - fig_params.axborder_yl - fig_params.axborder_yu)*axtile_yw;
set(ax,'Position',[axpos_xo axpos_yo axpos_xw axpos_yw]);
axinfo = get(ax,'UserData');
update_tmarker(axinfo.h_tmarker_spec,[]);
end

function iax = get_iax(the_ax,ax,nax)
iax_found = 0;
for iax = 1:nax
    if ax(iax) == the_ax
        iax_found = 1;
        break;
    end
end
if ~iax_found, error('could not find the_ax in ax list'); end
end

%% generic wavefig stuff

function set_viewer_axlims(hax,t_min,t_max,dat4minmax,yax_fact2use)
fig_params = get_fig_params;
if nargin < 5 || isempty(yax_fact2use), yax_fact2use = fig_params.yax_fact; end

if ~any(~isnan(dat4minmax))
    y_low = 0; y_hi = 1;
else
    y_low = min(dat4minmax); y_hi  = max(dat4minmax);
end
y_range = y_hi - y_low; if y_range == 0, y_range = 1; end

axis(hax,[t_min t_max (y_low-yax_fact2use*y_range) (y_hi +yax_fact2use*y_range)]);
end

%% get default param structs
function [plot_params] = get_plot_params()
plot_params.hzbounds4plot = []; % get from sigproc params
plot_params.name = 'signal';
plot_params.axfracts = [];
plot_params.yes_gray = 1;
plot_params.thresh_gray = 0;
plot_params.max_gray = 1;
fig_params = get_fig_params;
plot_params.figpos = fig_params.figpos_default;
end

function [event_params] = get_event_params()
event_params = struct('event_names', [], ...
    'event_times', [], ...
    'user_event_name_prefix','uev', ...
    'user_event_names', [], ...
    'user_event_times', [], ...
    'is_good_trial', 1);
end

function [sigproc_params] = get_sigproc_params()
sigproc_params = struct('fs', 11025, ...
    'ms_framespec_gram', 'broadband', ...
    'ms_framespec_form', 'narrowband', ...
    'nfft', 4096, ...
    'nlpc', 11, ...
    'nformants', 3, ...
    'preemph', 0.95, ...
    'pitchlimits', [50 300], ...
    'ampl_thresh4voicing', 0, ...
    'nlpc_choices', 7:20, ...
    'preemph_range', [-2 3]);
end

%% get figure params (used to be global vars)
function [fig_params] = get_fig_params()

fig_params.formant_colors = {'b','r','g','k','c','m'}; % colors for more formants than you'll ever use

fig_params.yax_fact = 0.05;
fig_params.tmarker_init_border = 0.025;

fig_params.axborder_xl = 0.075;
fig_params.axborder_xr = 0.05;
fig_params.axborder_yl = 0.02;
fig_params.axborder_yu = 0.075;

fig_params.figborder_xl = 0;
fig_params.figborder_xr = 0;
fig_params.figborder_yl = 0.05;
fig_params.figborder_yu = 0.01;

fig_params.ax_heighten_inc = 0.1;
fig_params.wave_viewer_logshim = 1; % makes 20*log10(0 + wave_viewer_logshim) = 0
fig_params.default_tmarker_width = 2;
fig_params.max_dist_fract2del_event = 0.03; % must be within 3% of ax_tlims of event marker to delete it
fig_params.formant_marker_width = 4;

fig_params.title_pos = [0.01 0.8 0];
fig_params.figpos_default = [.01 .045 .98 .85]; % fullscreen-ish, in normalized units

end
