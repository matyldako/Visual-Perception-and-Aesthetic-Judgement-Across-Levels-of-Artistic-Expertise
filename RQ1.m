%% script for answering RQ1 
% author: k22023335
% this is my 4th coding script, with versions preceding this one. I decided
% to organise my code by RQ so it's easier to use for the dissertation. 

%% RQ1: Does art training sharpen sensitivity to symmetry?
% (artists vs non-artsists)
% this is answered by the first experiment - the SymmmetryThresholdTask->
% Data-> ResFile (180 x 8) x 31 (bc 13 artists and 18 controls)

% hypotheses: 
% H1: artists will be better at detecting symmetry at the lower
% threshold of contrast compared to controls 
% H2: artists will have a higher RT than controls 
% H3: artists will be better (accuarcy) in detecting symmetry (proportion
% of symmetry correct)

% SENSITIVITY : here i am referring to three separate things: sensitivity
% as the slope of the function, sensitivity to the threshold (meaning here
% contrast) and sensitivity to symmetry as a whole - out of symm and asymm 

% the measures i want to focus on are: 
% 0: demographics/ descriptive stats for the first experiment and the
% questionnaire too - might do more on qs here as this script should be
% quite short 
% 1: psychometric functions: i want to focus on symmtery plots as the
% asymmetrical plots are redundant for my rq and also quite confusing -
% extract PSE and JND for the controls vs artists from the psychometric
% fucntions 
% psychometric fucntions are already plotted when the data loads but need
% to make them more formal for the diss and also plot a mean symmetry
% psychometric plot 

% the plot here is for thresholds log (6 12 24 48 96)% so visibility/
% luminance/ contrast so can be confusing becasue i need to extract
% threshold(this is for the psychometric curve itself)/ slope/ pse/ jnd/ overall accuracy and reaction time (RT)
% 2: for the eye movement data i can focus on something that could indicate
% sensitivity so maybe number of saccades 

% note: here Direction Selectivity Index is redundant, as the stimuli were
% presented for a very short time 

% 2: gaze heatmaps are worth plotting but eye analysis is kind of better
% for the third RQ which is not a focus of this script. 
% in any case (inside P - for each of the 31 columns -> 1x1 struct ->
% EyeMovementForAllTasks -> SymThrsh -> TrialLevelData or GazeMap or
% Saccades

% for the psychometric function IMPORTANT on the y axis a line at 0.5 -
% dictates the chance threshold "reference line"

% also maybe take into account that within symmetry there is Horizontal and
% Vertical symmetry.

% plan for the script:
% core setup and feeding data into script 
% individual level plots - psychometric fucntions - pool mean for
% horizontal and vertical within symmetry 
% plot the mean psychometric fucntions for both artists and controls for
% symmetry 
% PSE boxplots for artists and controls within symmtery as a whole (both
% horizontal and vertical) 
% create a matlab table with the slope, threshold (of the psych fn),
% overall accuracy, RT
% calculate a mean reaction time for n =13 artists and n=18 controls and
% compare with a ttest - also account for diff variance because groups are
% diff numbers 
% so statistical analysis at the end 
% plot everything 

%% making sure we're starting clean 

clear; clc; close all;
%% core setup -  n=13 Artists and n=18 Controls 
% repeating this all across scripts to load all the required data first, 
% and then i will create separate dataframes if needed 

% data directory on local machine 
data_dir = '/Users/matyldakornacka/Desktop/DATA_DISS/AllData'; 

% Define Group Colours for Consistency - orange good bc colourblind ppl can
% see the difference still
% Modern Hex Code usage in R2025b
ArtCol = [0.00, 0.45, 0.70]; % Deep Sky Blue (Artists)
CtrlCol = [0.90, 0.60, 0.00]; % Bright Orange (Controls)

% contrast levels on the x-axis of the psychometric function
contrast_vals   = [0.06 0.12 0.24 0.48 0.96];
contrast_labels = {'6%','12%','24%','48%','96%'};
%% data loading 

% identifying the files 
flist = dir(fullfile(data_dir, '*_AesSymPer_*.mat')); 
fprintf('Found %d .mat files in %s\n\n', numel(flist), data_dir); % sanity checkk

% preallocating for storage and easy retrieval 
P     = {}; % Raw data structs 
IDs   = {}; % Participant ID strings 
Group = {}; % Group category 
Ages = []; 
Sexes = {};
ArtScores = []; % Total inventory scores 
loaded_ids = {}; % participant ids 

% the main loading loop 
for fi = 1:numel(flist)
    fname = fullfile(flist(fi).folder, flist(fi).name);
    tmp = load(fname);
    S = tmp.S; 
    
    % Get and clean Participant ID
    pid = strtrim(char(S.ParticipantAndTaskInfo.PartID)); 
    
    % Duplicate check - S11 
    if ismember(pid, loaded_ids)
        continue
    end
    loaded_ids{end+1} = pid;
    
    % the grouping logic 
    % A## = Artist, S## = Control 
    % S11 = Artist Override, as labelled incorrctly in the file but
    % actually is A01 NOT S11
    if pid(1) == 'A'
        grp = 'Artist';
    elseif strcmp(pid, 'S11')
        grp = 'Artist';
    else
        grp = 'Control';
    end
    
    % Store data
    P{end+1}     = S;
    IDs{end+1}   = pid;
    Group{end+1} = grp;
    Ages(end+1)      = double(S.ParticipantAndTaskInfo.Age);           
    Sexes{end+1}     = strtrim(char(S.ParticipantAndTaskInfo.Sex)); 
    ArtScores(end+1) = double(S.ParticipantAndTaskInfo.ScoreTotal); 
end

% Create Group Indices
% These are used for all subsequent group-level tests
art_idx = find(strcmp(Group, 'Artist'));
con_idx = find(strcmp(Group, 'Control'));
n_art = numel(art_idx);
n_con = numel(con_idx);
N = numel(P);

fprintf('Core loaded: %d participants (%d Artists, %d Controls)\n', ...
    N, n_art, n_con);
%% checking that everyhting loaded correctly and displaying main info per participant 
% Display participant IDs and their corresponding scores
for i = 1:numel(IDs)
    fprintf('Participant ID: %s, Group: %s, Score: %.2f\n', IDs{i}, Group{i}, ArtScores(i));
end
%% some descriptives about the questionnaire 

% age 
fprintf('\nAge (years):\n');
fprintf('  Artists   (n = %2d): mean = %.2f  SD = %.2f  range = %d to %d\n', n_art, mean(Ages(art_idx)), std(Ages(art_idx)), min(Ages(art_idx)), max(Ages(art_idx)));
fprintf('  Controls  (n = %2d): mean = %.2f  SD = %.2f  range = %d to %d\n', n_con, mean(Ages(con_idx)), std(Ages(con_idx)), min(Ages(con_idx)), max(Ages(con_idx)));

% sex
fprintf('\nSex distribution:\n');
fprintf('  Artists:  %s\n',  strjoin(Sexes(art_idx), ' '));
fprintf('  Controls: %s\n',  strjoin(Sexes(con_idx), ' '));

% total score \15
fprintf('\nArt Inventory total score (0 to 15):\n');
fprintf('  Artists   (n = %2d): mean = %.2f  SD = %.2f\n', n_art, mean(ArtScores(art_idx)), std(ArtScores(art_idx)));
fprintf('  Controls  (n = %2d): mean = %.2f  SD = %.2f\n', n_con, mean(ArtScores(con_idx)), std(ArtScores(con_idx)));

[~, p_art, ~, st_art] = ttest2(ArtScores(art_idx), ArtScores(con_idx), 'Vartype', 'unequal');
fprintf('  Welch t-test: t(%.1f) = %.3f,  p = %.4g\n', st_art.df, st_art.tstat, p_art);

%% extracting exp1 data per participant

%  For each participant we store:
%      - symPC(i, 1:5)   = proportion correct at each contrast level,
%                          POOLED across H and V symmetry axes
%      - asymPC(i, 1:5)  = same for asymmetric trials (supplementary - not neccessary for this RQ )
%      - symPC_H, symPC_V = symmetry P(correct) broken by axis
%                           (kept for optional sub-analysis)
%      - acc_overall(i)  = mean correct across all 180 trials
%      - rt_overall(i)   = mean RT across all 180 trials
%      - rt_sym(i)       = mean RT on symmetric trials only
%
%  ResFile columns:
%      1  = 1 asym / 2 sym
%      2  = contrast level (1 low - 5 high)
%      3  = axis (1 horizontal / 2 vertical)
%      5  = correct (0/1)
%      6  = RT in seconds

symPC        = nan(N, 5);
asymPC       = nan(N, 5);
symPC_H      = nan(N, 5);
symPC_V      = nan(N, 5);
acc_overall  = nan(N, 1);
rt_overall   = nan(N, 1);
rt_sym       = nan(N, 1);
acc_sym      = nan(N, 1);
acc_asym     = nan(N, 1);

for i = 1:N
    rf = double(P{i}.SymmetryThresholdTask.Data.ResFile);
 
    % Overall
    acc_overall(i) = mean(rf(:,5));
    rt_overall(i)  = mean(rf(:,6));
 
    % Split by stimulus type
    sym_mask  = rf(:,1) == 2;
    asym_mask = rf(:,1) == 1;
 
    acc_sym(i)  = mean(rf(sym_mask,  5));
    acc_asym(i) = mean(rf(asym_mask, 5));
    rt_sym(i)   = mean(rf(sym_mask,  6));
 
    % Proportion correct at each contrast level (pooled sym / pooled asym)
   for lv = 1:5
        s   = sym_mask  & (rf(:, 2) == lv);
        a   = asym_mask & (rf(:, 2) == lv);
        s_H = sym_mask  & (rf(:, 2) == lv) & (rf(:, 3) == 1);
        s_V = sym_mask  & (rf(:, 2) == lv) & (rf(:, 3) == 2);
 
        if any(s),   symPC(i, lv)    = mean(rf(s, 5));    end
        if any(a),   asymPC(i, lv)   = mean(rf(a, 5));    end
        if any(s_H), symPC_H(i, lv)  = mean(rf(s_H, 5));  end
        if any(s_V), symPC_V(i, lv)  = mean(rf(s_V, 5));  end
    end
end
 
%% --- 1. PSYCHOMETRIC FITTING LOOP ----------------------------

PSE   = nan(N, 1);   % contrast at P = 0.5  (threshold)
JND   = nan(N, 1);   % contrast increment for 1 slope-unit above PSE
Slope = nan(N, 1);   % b parameter (log-contrast units)

% Smooth x-grid for drawing fitted curves
x_grid_log = linspace(log(contrast_vals(1)) - 0.5, ...
                       log(contrast_vals(end)) + 0.5, 200);
x_grid     = exp(x_grid_log);
fit_curves = nan(N, numel(x_grid));

% Unconstrained logistic in log-contrast space
%   p(1) = log(PSE),  p(2) = slope b
model_fn = @(p, xx) 1 ./ (1 + exp( -p(2) .* (xx - p(1)) ));
opts     = optimset('Display','off','MaxIter',3000,'TolFun',1e-9,'TolX',1e-9);

for i = 1:N
    y  = symPC(i, :)';
    ok = isfinite(y);
    if sum(ok) < 3
        continue   % need at least 3 points to fit two parameters
    end

    x_log = log(contrast_vals(ok))';
    yv    = y(ok);

    sse_fn = @(p) sum( (model_fn(p, x_log) - yv).^2 );

    % Starting point: log-midpoint of contrast range, moderate slope
    p0 = [mean(x_log), 3.0];

    try
        p_hat    = fminsearch(sse_fn, p0, opts);
        log_pse  = p_hat(1);
        b        = p_hat(2);

        % PSE: contrast at which P = 0.5
        PSE(i)   = exp(log_pse);

        % Slope: steeper b = sharper discrimination
        Slope(i) = b;

        % JND: contrast increment corresponding to one slope-unit
        % from the PSE in log space, back-transformed to linear contrast.
        % A larger JND means worse sensitivity (needs a bigger change
        % to detect a difference).
        if b > 0
            JND(i) = PSE(i) * (exp(1 / b) - 1);
        end

        % Store fitted curve for plotting
        fit_curves(i, :) = model_fn(p_hat, log(x_grid));
    catch
        % fit failed — leave NaNs
    end
end

% Plausibility filter: PSE must lie within the tested contrast range
% (allow a modest margin either side — avoids excluding too many Ps)
pse_lo = contrast_vals(1)  * 0.5;   % 3%
pse_hi = contrast_vals(end) * 2.0;  % 192%

good_fit = isfinite(PSE) & (PSE >= pse_lo) & (PSE <= pse_hi);
fprintf('\n%d / %d psychometric fits returned a PSE within range [%.2f, %.2f].\n', ...
    sum(good_fit), N, pse_lo, pse_hi);

% Report participants whose fit fell outside range (do NOT exclude
% them from other analyses — only flag for psychometric measures)
bad_idx = find(~good_fit);
if ~isempty(bad_idx)
    fprintf('  Out-of-range PSE participants:\n');
    for k = 1:numel(bad_idx)
        fprintf('    %s  (PSE = %.4f)\n', IDs{bad_idx(k)}, PSE(bad_idx(k)));
    end
end

% Set out-of-range PSE/JND/Slope to NaN so they are skipped in stats
PSE(~good_fit)   = NaN;
JND(~good_fit)   = NaN;
Slope(~good_fit) = NaN;


%% --- 2. INDIVIDUAL PSYCHOMETRIC FUNCTIONS (Fig 1) ------------

ncols = 7;
nrows = ceil(N / ncols);
figure('Color','w','Position',[30 30 1400 850],'Name','Fig 1 - Individual Fits');

for i = 1:N
    ax = subplot(nrows, ncols, i);
    hold(ax, 'on');

    use_col = ArtCol;
    if strcmp(Group{i}, 'Control'), use_col = CtrlCol; end

    % Raw symmetry data
    y_raw = symPC(i, :);
    plot(ax, contrast_vals, y_raw, 'o', ...
        'MarkerFaceColor', use_col, 'MarkerEdgeColor', use_col, 'MarkerSize', 3);

    % Fitted curve (if available)
    if isfinite(PSE(i))
        plot(ax, x_grid, fit_curves(i, :), '-', 'Color', use_col, 'LineWidth', 1.3);

        % Annotate with PSE and Slope
        txt = sprintf('PSE=%.2f\nS=%.1f', PSE(i), Slope(i));
        text(ax, 0.05, 0.08, txt, 'Units','normalized', ...
            'FontSize', 5.5, 'Color', [0.35 0.35 0.35]);
    end

    % Reference line at 0.5 (chance / PSE criterion)
    yline(ax, 0.5, 'k:', 'LineWidth', 0.8);

    set(ax, 'XScale','log','YLim',[0 1.05],'XLim',[0.04 1.5], ...
        'Box','off','FontSize',7);
    set(ax, 'XTick', contrast_vals, 'XTickLabel', {'6','12','24','48','96'});
    title(ax, sprintf('%s %d', label, plot_count), 'Color', use_col, 'FontWeight','bold','FontSize',7);
    if mod(i-1, ncols) ~= 0
        set(ax, 'YTickLabel', []);
    end

    grid(ax, 'on');
    ax.GridAlpha = 0.05;
    hold(ax, 'off');
end

sgtitle('Figure 1.  Individual Symmetry Detection Functions  (Blue = Artist, Orange = Control)', ...
    'FontWeight','bold','FontSize',13);
%% --- 2. INDIVIDUAL PSYCHOMETRIC FUNCTIONS (Fig 1) ------------
ncols = 5;
nrows = ceil(sum(good_fit) / ncols);
figure('Color','w','Position',[30 30 1000 900],'Name','Fig 1 - Individual Fits');

plot_count = 0; h_art = []; h_con = [];
for i = 1:N
    if ~good_fit(i), continue; end
    plot_count = plot_count + 1;
    ax = subplot(nrows, ncols, plot_count); hold(ax, 'on');

    is_art  = strcmp(Group{i}, 'Artist');
    use_col = ArtCol; if ~is_art, use_col = CtrlCol; end
    label   = 'Art Expert'; if ~is_art, label = 'Control'; end

    h = plot(ax, contrast_vals, symPC(i,:), 'o', ...
        'MarkerFaceColor', use_col, 'MarkerEdgeColor', use_col, 'MarkerSize', 4, ...
        'DisplayName', label);
    plot(ax, x_grid, fit_curves(i,:), '-', 'Color', use_col, 'LineWidth', 1.5, ...
        'HandleVisibility','off');
    if is_art && isempty(h_art), h_art = h; elseif ~is_art && isempty(h_con), h_con = h; end

    text(ax, 0.05, 0.08, sprintf('PSE=%.2f\nb=%.1f', PSE(i), Slope(i)), ...
        'Units','normalized','FontSize',6,'Color',[0.3 0.3 0.3]);
    yline(ax, 0.5, 'k:', 'LineWidth', 0.8, 'HandleVisibility','off');
    set(ax,'XScale','log','YLim',[0 1.05],'XLim',[0.04 1.5],'Box','off','FontSize',7);
    set(ax,'XTick',contrast_vals,'XTickLabel',{'6%','12%','24%','48%','96%'});
    xlabel(ax,'Contrast (%)','FontSize',6); ylabel(ax,'P(correct)','FontSize',6);
    title(ax, sprintf('%s %d', label, plot_count), 'Color', use_col, 'FontWeight','bold','FontSize',7);
    if mod(plot_count-1,ncols)~=0, set(ax,'YTickLabel',[]); end
    grid(ax,'on'); ax.GridAlpha = 0.08; hold(ax,'off');
end

lg = legend([h_art h_con], {'Art Expert','Control'}, 'Orientation','horizontal', ...
    'Box','off','FontSize',11);
lg.Position = [0.35 0.01 0.3 0.03];
sgtitle(' Individual Symmetry Detection Psychometric Functions', ...
    'FontWeight','bold','FontSize',13);
%% --- 2. INDIVIDUAL PSYCHOMETRIC FUNCTIONS (Fig 1) ------------
ncols = 7;
nrows = ceil(sum(good_fit) / ncols);
figure('Color','w','Position',[30 30 1400 850],'Name','Fig 1 - Individual Fits');

plot_count = 0;
for i = 1:N
    if ~good_fit(i), continue; end  % skip out-of-range participants
    plot_count = plot_count + 1;
    ax = subplot(nrows, ncols, plot_count);
    hold(ax, 'on');

    use_col = ArtCol;
    if strcmp(Group{i}, 'Control'), use_col = CtrlCol; end

    plot(ax, contrast_vals, symPC(i,:), 'o', ...
        'MarkerFaceColor', use_col, 'MarkerEdgeColor', use_col, 'MarkerSize', 3);
    plot(ax, x_grid, fit_curves(i,:), '-', 'Color', use_col, 'LineWidth', 1.3);
    text(ax, 0.05, 0.08, sprintf('PSE=%.2f\nS=%.1f', PSE(i), Slope(i)), ...
        'Units','normalized','FontSize',5.5,'Color',[0.35 0.35 0.35]);
    yline(ax, 0.5, 'k:', 'LineWidth', 0.8);
    set(ax,'XScale','log','YLim',[0 1.05],'XLim',[0.04 1.5],'Box','off','FontSize',7);
    set(ax,'XTick',contrast_vals,'XTickLabel',{'6','12','24','48','96'});
    title(ax, IDs{i}, 'Color', use_col, 'FontWeight','bold','FontSize',8);
    if mod(plot_count-1, ncols) ~= 0, set(ax,'YTickLabel',[]); end
    grid(ax,'on'); ax.GridAlpha = 0.05; hold(ax,'off');
end
sgtitle('Figure 1.  Individual Symmetry Detection Functions  (Blue = Artist, Orange = Control)', ...
    'FontWeight','bold','FontSize',13);

%% --- 3. GROUP MEAN PSYCHOMETRIC FUNCTION (Fig 2) -------------

figure('Color','w','Position',[100 100 900 600],'Name','Fig 2 - Group Psychometric');
ax = axes('Parent', gcf);
hold(ax, 'on');

model_grp = @(p, xl) 1 ./ (1 + exp( -p(2) .* (xl - p(1)) ));
x_smooth  = logspace(log10(0.04), log10(1.5), 200);
opts_grp  = optimset('Display','off');

% Faint individual traces in background
for i = 1:N
    y_raw = symPC(i, :);
    valid = isfinite(y_raw);
    if sum(valid) >= 3
        sse_i = @(p) sum( (model_grp(p, log(contrast_vals(valid))') - y_raw(valid)').^2 );
        try
            p_i  = fminsearch(sse_i, [log(0.2), 3], opts_grp);
            y_i  = model_grp(p_i, log(x_smooth));
            if strcmp(Group{i}, 'Artist')
                pl = plot(ax, x_smooth, y_i, '-', 'Color', [ArtCol, 0.12], 'LineWidth', 0.8);
            else
                pl = plot(ax, x_smooth, y_i, '-', 'Color', [CtrlCol, 0.12], 'LineWidth', 0.8);
            end
            pl.HandleVisibility = 'off';
        catch
        end
    end
end

% Group mean proportions and SEM
m_art   = nanmean(symPC(art_idx, :), 1);
m_con   = nanmean(symPC(con_idx, :), 1);
sem_art = nanstd(symPC(art_idx, :), 0, 1) ./ sqrt(n_art);
sem_con = nanstd(symPC(con_idx, :), 0, 1) ./ sqrt(n_con);

% Fit to group mean data
sse_art   = @(p) sum( (model_grp(p, log(contrast_vals)) - m_art).^2 );
p_art_grp = fminsearch(sse_art, [log(0.2), 3], opts_grp);
h_art_fit = plot(ax, x_smooth, model_grp(p_art_grp, log(x_smooth)), '-', ...
    'Color', ArtCol, 'LineWidth', 3.5);

sse_con   = @(p) sum( (model_grp(p, log(contrast_vals)) - m_con).^2 );
p_con_grp = fminsearch(sse_con, [log(0.2), 3], opts_grp);
h_con_fit = plot(ax, x_smooth, model_grp(p_con_grp, log(x_smooth)), '-', ...
    'Color', CtrlCol, 'LineWidth', 3.5);

% Group mean data points (slightly offset on x for clarity)
h_art_data = errorbar(ax, contrast_vals * 0.95, m_art, sem_art, 'o', ...
    'Color', ArtCol,  'MarkerFaceColor', ArtCol,  ...
    'LineWidth', 2, 'MarkerSize', 10, 'CapSize', 6);
h_con_data = errorbar(ax, contrast_vals * 1.05, m_con, sem_con, 's', ...
    'Color', CtrlCol, 'MarkerFaceColor', CtrlCol, ...
    'LineWidth', 2, 'MarkerSize', 10, 'CapSize', 6);

% Reference line at 0.5 ONLY (no 0.75 line)
yline(ax, 0.5, 'k:', 'LineWidth', 1.2, ...
    'Label', 'P = 0.50  (PSE criterion)', ...
    'LabelHorizontalAlignment', 'right', ...
    'LabelVerticalAlignment',   'bottom', ...
    'FontSize', 10, 'HandleVisibility', 'off');

set(ax, 'XScale','log', 'YLim',[0.15 0.80], 'XLim',[0.04 1.5], ...
    'Box','off', 'FontSize',12, 'Color','w', ...
    'GridColor',[0.8 0.8 0.8], 'XColor','k', 'YColor','k');
set(ax, 'XTick', contrast_vals, 'XTickLabel', {'6%','12%','24%','48%','96%'});
xlabel(ax, 'Luminance Contrast (%)',  'FontSize', 14, 'FontWeight', 'bold');
ylabel(ax, 'Proportion Correct',      'FontSize', 14, 'FontWeight', 'bold');
title(ax,  'Group Psychometric Functions -Symmetry Detection', ...
    'FontSize', 14, 'FontWeight', 'bold');

lbl_art = sprintf('Art Experts \\pm SEM  (n = %d)', n_art);
lbl_con = sprintf('Controls \\pm SEM  (n = %d)', n_con);
legend(ax, [h_art_data, h_con_data, h_art_fit, h_con_fit], ...
    {lbl_art, lbl_con, 'Art experts fit', 'Controls fit'}, ...
    'Location','southeast','Box','off','FontSize',11);
text(ax, 0.05, 0.25, sprintf('Art Expert: PSE=%.2f, b=%.2f, JND=%.2f', ...
    PSE_art_grp, Slope_art_grp, JND_art_grp), ...
    'Units','normalized','FontSize',10,'Color',ArtCol);
text(ax, 0.05, 0.18, sprintf('Control:    PSE=%.2f, b=%.2f, JND=%.2f', ...
    PSE_con_grp, Slope_con_grp, JND_con_grp), ...
    'Units','normalized','FontSize',10,'Color',CtrlCol);
grid(ax, 'on');
ax.GridAlpha = 0.15;
hold(ax, 'off');

%%
% Extract and display group-level psychometric parameters
PSE_art_grp   = exp(p_art_grp(1));
Slope_art_grp = p_art_grp(2);
JND_art_grp   = PSE_art_grp * (exp(1/Slope_art_grp) - 1);

PSE_con_grp   = exp(p_con_grp(1));
Slope_con_grp = p_con_grp(2);
JND_con_grp   = PSE_con_grp * (exp(1/Slope_con_grp) - 1);

fprintf('\n=== Group Mean Psychometric Parameters ===\n');
fprintf('              PSE      Slope     JND\n');
fprintf('Art Experts:  %.3f    %.3f     %.3f\n', PSE_art_grp, Slope_art_grp, JND_art_grp);
fprintf('Controls:     %.3f    %.3f     %.3f\n', PSE_con_grp, Slope_con_grp, JND_con_grp);
%%
fprintf('\n=== Group Mean Curve Parameters (descriptive only) ===\n');
fprintf('Art Experts:  PSE=%.3f, Slope=%.3f, JND=%.3f\n', PSE_art_grp, Slope_art_grp, JND_art_grp);
fprintf('Controls:     PSE=%.3f, Slope=%.3f, JND=%.3f\n', PSE_con_grp, Slope_con_grp, JND_con_grp);

fprintf('\n=== Individual-level Welch t-tests: Artists vs Controls ===\n');
[~,p_PSE,~,st_PSE]     = ttest2(PSE(art_idx),   PSE(con_idx),   'Vartype','unequal');
[~,p_Slope,~,st_Slope] = ttest2(Slope(art_idx), Slope(con_idx), 'Vartype','unequal');
[~,p_JND,~,st_JND]     = ttest2(JND(art_idx),   JND(con_idx),   'Vartype','unequal');
fprintf('PSE:   t(%.1f) = %.3f, p = %.4g (Art M=%.3f, Ctrl M=%.3f)\n', st_PSE.df,   st_PSE.tstat,   p_PSE,   nanmean(PSE(art_idx)),   nanmean(PSE(con_idx)));
fprintf('Slope: t(%.1f) = %.3f, p = %.4g (Art M=%.3f, Ctrl M=%.3f)\n', st_Slope.df, st_Slope.tstat, p_Slope, nanmean(Slope(art_idx)), nanmean(Slope(con_idx)));
fprintf('JND:   t(%.1f) = %.3f, p = %.4g (Art M=%.3f, Ctrl M=%.3f)\n', st_JND.df,   st_JND.tstat,   p_JND,   nanmean(JND(art_idx)),   nanmean(JND(con_idx)));
%% --- 4. BOXPLOTS: PSE, JND, SLOPE (Fig 3) --------------------

figure('Color','w','Position',[150 150 1100 380],'Name','Fig 3 - PSE JND Slope');

measures      = {PSE,   JND,   Slope};
measure_names = {'Contrast at P = 0.50  (PSE)', ...
                 'JND  (contrast increment, linear units)', ...
                 'Slope  b  (log-contrast units)'};
panel_titles  = {'A.   Point of Subjective Equality (PSE)', ...
                 'B.   Just Noticeable Difference (JND)', ...
                 'C.   Psychometric Slope'};

for m = 1:3
    ax   = subplot(1, 3, m);
    hold(ax, 'on');
    vals   = measures{m};
    groups = categorical(Group(:), {'Art Expert','Control'});

    boxchart(ax, groups, vals, ...
        'BoxFaceColor', [0.4 0.4 0.4], ...
        'MarkerColor',  [0.3 0.3 0.3], ...
        'LineWidth', 1.1);

    xA = 1 + (rand(n_art, 1) - 0.5) * 0.25;
    xC = 2 + (rand(n_con, 1) - 0.5) * 0.25;
    scatter(ax, xA, vals(art_idx), 45, ArtCol,  'filled', 'MarkerFaceAlpha', 0.8);
    scatter(ax, xC, vals(con_idx), 45, CtrlCol, 'filled', 'MarkerFaceAlpha', 0.8);

    set(ax, 'FontSize', 11, 'Box', 'off');
    ylabel(ax, measure_names{m}, 'FontSize', 11);
    title(ax, panel_titles{m}, 'FontSize', 10, 'FontWeight', 'bold');
    hold(ax, 'off');
end

sgtitle(' Sensitivity measures by group  (box = median ± IQR, dots = individuals)', ...
    'FontSize', 12, 'FontWeight', 'bold');

%% counting saccades for everyone - that's eye behaviour -RQ3   
n_sacc_exp1 = zeros(N, 1);
for i = 1:N
    tld   = P{i}.EyeMovementForAllTasks.SymThrsh.TrialLevelData;
    total = 0;
    for tr = 1:numel(tld)
        sc = tld(tr).Saccades;
        if ~isempty(sc)
            total = total + size(sc, 1);
        end
    end
    n_sacc_exp1(i) = total;
end
 
sacc_per_trial = n_sacc_exp1 / 180;

%% Figure 1: Individual Symmetry Psychometric Functions (Unconstrained)
% although already plotted, this version is good for visualising people
% because it includes everyone 
ncols = 7;
nrows = ceil(N / ncols);
figure('Color', 'w', 'Position', [30, 30, 1400, 850], 'Name', 'Individual Fits');

% 1. Unconstrained Logistic Model: Starts at 0, ends at 1
% p(1) = log(Threshold), p(2) = Slope
model_ind = @(p, x_log) 1 ./ (1 + exp(-p(2) * (x_log - p(1))));
opts_ind = optimset('Display', 'off', 'MaxIter', 500);

for i = 1:N
    ax = subplot(nrows, ncols, i);
    hold(ax, 'on');
    
    % Use existing color variables
    if strcmp(Group{i}, 'Artist')
        use_col = ArtCol;
    else
        use_col = CtrlCol;
    end
    
    % Plot raw symmetry data points
    y_raw = symPC(i, :);
    plot(ax, contrast_vals, y_raw, 'o', 'MarkerFaceColor', use_col, 'MarkerEdgeColor', use_col, 'MarkerSize', 3);
    
    % Fit and plot the curve
    valid = isfinite(y_raw);
    if sum(valid) >= 3
        x_log_data = log(contrast_vals(valid))';
        y_val_data = y_raw(valid)';
        sse_fn = @(p) sum((model_ind(p, x_log_data) - y_val_data).^2);
        try
            % Start fit with reasonable priors
            p_hat = fminsearch(sse_fn, [log(0.2), 5], opts_ind);
            
            % Generate smooth curve for plotting
            y_fit_line = model_ind(p_hat, log(x_grid));
            plot(ax, x_grid, y_fit_line, '-', 'Color', use_col, 'LineWidth', 1.3);
            
            % Extract and display individual Threshold (T) and Slope (S)
            % T is the contrast where P=0.5 in this unconstrained model
            ind_T = exp(p_hat(1));
            ind_S = p_hat(2);
            txt = sprintf('T=%.2f, S=%.1f', ind_T, ind_S);
            text(ax, 0.05, 0.1, txt, 'Units', 'normalized', 'FontSize', 6, 'Color', [0.4 0.4 0.4]);
        catch
        end
    end
    
    % Reference Line at 0.5 (Chance)
    yline(ax, 0.5, 'k:', 'LineWidth', 0.5);
    
    % Professional Axis Styling
    set(ax, 'XScale', 'log', 'YLim', [0, 1.05], 'XLim', [0.04, 1.5], 'Box', 'off', 'FontSize', 7);
    set(ax, 'XTick', contrast_vals, 'XTickLabel', {'6','12','24','48','96'});
    title(ax, IDs{i}, 'Color', use_col, 'FontWeight', 'bold', 'FontSize', 8);
    
    % Clean up formatting: only show Y-labels on the first column
    if mod(i-1, ncols) ~= 0
        set(ax, 'YTickLabel', []);
    end
    
    grid(ax, 'on');
    ax.GridAlpha = 0.05;
    hold(ax, 'off');
end

sgtitle('Figure 1. Individual Symmetry Detection Functions (Blue=Artist, Orange=Control)', 'FontWeight', 'bold', 'FontSize', 14);
%% Figure 2: Group Mean Psychometric Function (Symmetry Only)
figure('Color', 'w', 'Position', [100, 100, 900, 600], 'Name', 'Group Psychometric');
ax = axes('Parent', gcf);
hold(ax, 'on');

% 1. Model: Unconstrained logistic (0 to 1) so it can dip below 0.5
model_grp = @(p, x_log) 1 ./ (1 + exp(-p(2) * (x_log - p(1))));
x_smooth = logspace(log10(0.04), log10(1.5), 200);
opts = optimset('Display', 'off');

% 2. Plot Faint Smooth Individual Traces in Background
for i = 1:N
    y_raw = symPC(i, :);
    valid = isfinite(y_raw);
    if sum(valid) >= 3
        x_log_data = log(contrast_vals(valid))';
        y_val_data = y_raw(valid)';
        sse_fn = @(p) sum((model_grp(p, x_log_data) - y_val_data).^2);
        try
            p_ind = fminsearch(sse_fn, [log(0.2), 5], opts);
            y_fit_ind = model_grp(p_ind, log(x_smooth));
            if strcmp(Group{i}, 'Artist')
                pl = plot(ax, x_smooth, y_fit_ind, '-', 'Color', [ArtCol, 0.12], 'LineWidth', 0.8);
            else
                pl = plot(ax, x_smooth, y_fit_ind, '-', 'Color', [CtrlCol, 0.12], 'LineWidth', 0.8);
            end
            pl.HandleVisibility = 'off';
        catch
        end
    end
end

% 3. Data Prep: Group Means and SEM
m_art = nanmean(symPC(art_idx, :), 1);
m_con = nanmean(symPC(con_idx, :), 1);
sem_art = nanstd(symPC(art_idx, :), 0, 1) ./ sqrt(n_art);
sem_con = nanstd(symPC(con_idx, :), 0, 1) ./ sqrt(n_con);

% 4. Fit and Plot Smooth Group Means
sse_art = @(p) sum((model_grp(p, log(contrast_vals)) - m_art).^2);
p_art_grp = fminsearch(sse_art, [log(0.2), 5], opts);
h_art_fit = plot(ax, x_smooth, model_grp(p_art_grp, log(x_smooth)), '-', 'Color', ArtCol, 'LineWidth', 4);

sse_con = @(p) sum((model_grp(p, log(contrast_vals)) - m_con).^2);
p_con_grp = fminsearch(sse_con, [log(0.2), 5], opts);
h_con_fit = plot(ax, x_smooth, model_grp(p_con_grp, log(x_smooth)), '-', 'Color', CtrlCol, 'LineWidth', 4);

% 5. Plot Group Mean Data Points (Jittered)
h_art_data = errorbar(ax, contrast_vals * 0.95, m_art, sem_art, 'o', 'Color', ArtCol, 'MarkerFaceColor', ArtCol, 'LineWidth', 2, 'MarkerSize', 10, 'CapSize', 6);
h_con_data = errorbar(ax, contrast_vals * 1.05, m_con, sem_con, 's', 'Color', CtrlCol, 'MarkerFaceColor', CtrlCol, 'LineWidth', 2, 'MarkerSize', 10, 'CapSize', 6);

% 6. Formatting and Reference Lines
yline(ax, 0.5, 'k:', 'Chance Floor (0.50)', 'LabelHorizontalAlignment', 'right', 'LabelVerticalAlignment', 'bottom', 'FontSize', 11, 'HandleVisibility', 'off');
yline(ax, 0.75, 'k--', 'PSE Criterion (0.75)', 'LabelHorizontalAlignment', 'right', 'LabelVerticalAlignment', 'bottom', 'FontSize', 11, 'HandleVisibility', 'off');

set(ax, 'XScale', 'log', 'YLim', [0.4, 1.02], 'XLim', [0.04, 1.5], 'Box', 'off', 'FontSize', 12);
set(ax, 'XTick', contrast_vals, 'XTickLabel', {'6%','12%','24%','48%','96%'});

xlabel(ax, 'Luminance Contrast (%)', 'FontSize', 14, 'FontWeight', 'bold');
ylabel(ax, 'Proportion Correct', 'FontSize', 14, 'FontWeight', 'bold');
title(ax, 'Figure 2. Experiment 1 Group Psychometric Function (Symmetry)', 'FontSize', 15, 'FontWeight', 'bold');

% Legend
lbl_art = sprintf('Artists Mean \\pm SEM (n=%d)', n_art);
lbl_con = sprintf('Controls Mean \\pm SEM (n=%d)', n_con);
legend(ax, [h_art_data, h_con_data, h_art_fit, h_con_fit], {lbl_art, lbl_con, 'Artists Group fit', 'Controls Group fit'}, 'Location', 'southeast', 'Box', 'off', 'FontSize', 11);

grid(ax, 'on');
ax.GridAlpha = 0.15;
hold(ax, 'off');
%% accuracy and RT 
figure('Color', 'w', 'Position', [200 200 900 380], 'Name', 'Fig 4 - Accuracy and RT');
 
% Panel A: Accuracy
ax1 = subplot(1, 2, 1); hold(ax1, 'on');
 
bar_vals = [mean(acc_overall(art_idx)) mean(acc_overall(con_idx));
            mean(acc_sym(art_idx))     mean(acc_sym(con_idx));
            mean(acc_asym(art_idx))    mean(acc_asym(con_idx))];
 
bar_sem  = [std(acc_overall(art_idx))/sqrt(n_art)  std(acc_overall(con_idx))/sqrt(n_con);
            std(acc_sym(art_idx))/sqrt(n_art)      std(acc_sym(con_idx))/sqrt(n_con);
            std(acc_asym(art_idx))/sqrt(n_art)     std(acc_asym(con_idx))/sqrt(n_con)];
 
bh = bar(ax1, bar_vals, 'grouped');
bh(1).FaceColor = ArtCol;   bh(1).FaceAlpha = 0.85;
bh(2).FaceColor = CtrlCol;  bh(2).FaceAlpha = 0.85;
 
for g = 1:2
    errorbar(ax1, bh(g).XEndPoints, bar_vals(:, g), bar_sem(:, g), 'k.', 'LineWidth', 1.2, 'CapSize', 6);
end
 
yline(ax1, 0.5, 'k:', 'chance', 'FontSize', 9);
set(ax1, 'XTick', 1:3, 'XTickLabel', {'Overall','Symmetric','Asymmetric'}, 'YLim', [0 1], 'FontSize', 11, 'Box', 'off');
ylabel(ax1, 'Proportion correct', 'FontSize', 11);
title(ax1, 'A.   Accuracy', 'FontSize', 11, 'FontWeight', 'bold');
legend(ax1, {'Artists','Controls'}, 'Location', 'northeast', 'FontSize', 10, 'Box', 'off');
grid(ax1, 'on'); hold(ax1, 'off');
 
% Panel B: Reaction time
ax2 = subplot(1, 2, 2); hold(ax2, 'on');
 
rt_vals = [mean(rt_overall(art_idx)) mean(rt_overall(con_idx));
           mean(rt_sym(art_idx))     mean(rt_sym(con_idx))];
 
rt_sem  = [std(rt_overall(art_idx))/sqrt(n_art)  std(rt_overall(con_idx))/sqrt(n_con);
           std(rt_sym(art_idx))/sqrt(n_art)      std(rt_sym(con_idx))/sqrt(n_con)];
 
bh = bar(ax2, rt_vals, 'grouped');
bh(1).FaceColor = ArtCol;   bh(1).FaceAlpha = 0.85;
bh(2).FaceColor = CtrlCol;  bh(2).FaceAlpha = 0.85;
 
for g = 1:2
    errorbar(ax2, bh(g).XEndPoints, rt_vals(:, g), rt_sem(:, g), 'k.', 'LineWidth', 1.2, 'CapSize', 6);
end
 
set(ax2, 'XTick', 1:2, 'XTickLabel', {'Overall','Symmetric only'}, 'FontSize', 11, 'Box', 'off');
ylabel(ax2, 'Reaction time (s)', 'FontSize', 11);
title(ax2, 'B.   Reaction time', 'FontSize', 11, 'FontWeight', 'bold');
grid(ax2, 'on'); hold(ax2, 'off');
 
sgtitle('Figure 4.   Group comparison of accuracy and reaction time (mean +/- SEM)', 'FontSize', 12, 'FontWeight', 'bold');
 
% according to this figure, it's interesting to see the ttest for symmetric
% vs asymmetric proportion of correct 
%%
fprintf('\n=== Accuracy and Reaction Time Descriptives ===\n');
fprintf('                    Artists (n=%d)           Controls (n=%d)\n', n_art, n_con);
fprintf('                    M        SD              M        SD\n');
fprintf('Overall Accuracy:   %.3f    %.3f           %.3f    %.3f\n', ...
    mean(acc_overall(art_idx)), std(acc_overall(art_idx)), ...
    mean(acc_overall(con_idx)), std(acc_overall(con_idx)));
fprintf('Symmetry Accuracy:  %.3f    %.3f           %.3f    %.3f\n', ...
    mean(acc_sym(art_idx)), std(acc_sym(art_idx)), ...
    mean(acc_sym(con_idx)), std(acc_sym(con_idx)));
fprintf('Asymmetry Accuracy: %.3f    %.3f           %.3f    %.3f\n', ...
    mean(acc_asym(art_idx)), std(acc_asym(art_idx)), ...
    mean(acc_asym(con_idx)), std(acc_asym(con_idx)));
fprintf('Overall RT (s):     %.3f    %.3f           %.3f    %.3f\n', ...
    mean(rt_overall(art_idx)), std(rt_overall(art_idx)), ...
    mean(rt_overall(con_idx)), std(rt_overall(con_idx)));
fprintf('Symmetry RT (s):    %.3f    %.3f           %.3f    %.3f\n', ...
    mean(rt_sym(art_idx)), std(rt_sym(art_idx)), ...
    mean(rt_sym(con_idx)), std(rt_sym(con_idx)));
%%
fprintf('\n=== Cohens d (Art Experts vs Controls) ===\n');

measures_d = {acc_overall, acc_sym, acc_asym, rt_overall, rt_sym, PSE, JND, Slope, n_sacc_exp1, sacc_per_trial};
names_d    = {'Overall accuracy', 'Symmetry accuracy', 'Asymmetry accuracy', ...
              'Overall RT', 'Symmetry RT', 'PSE', 'JND', 'Slope', ...
              'Total saccades', 'Saccades per trial'};

for m = 1:numel(names_d)
    a = measures_d{m}(art_idx); a = a(isfinite(a));
    b = measures_d{m}(con_idx); b = b(isfinite(b));
    pooled_sd = sqrt((std(a)^2 + std(b)^2) / 2);
    d = (mean(a) - mean(b)) / pooled_sd;
    fprintf('  %-22s  d = %+.3f\n', names_d{m}, d);
end

%% fig 5 - saccade count RQ3 but here for convenience 
figure('Color', 'w', 'Position', [250 250 820 380], 'Name', 'Fig 5 - Number of saccades');
 
groups_cat = categorical(Group(:), {'Artist','Control'});
 
% Panel A: total saccades
ax1 = subplot(1, 2, 1); hold(ax1, 'on');
boxchart(ax1, groups_cat, n_sacc_exp1, 'BoxFaceColor', [0.4 0.4 0.4], 'LineWidth', 1.1);
xA = 1 + (rand(n_art, 1) - 0.5) * 0.25;
xC = 2 + (rand(n_con, 1) - 0.5) * 0.25;
scatter(ax1, xA, n_sacc_exp1(art_idx), 45, ArtCol,  'filled', 'MarkerFaceAlpha', 0.8);
scatter(ax1, xC, n_sacc_exp1(con_idx), 45, CtrlCol, 'filled', 'MarkerFaceAlpha', 0.8);
set(ax1, 'FontSize', 11, 'Box', 'off');
ylabel(ax1, 'Total saccades across 180 trials', 'FontSize', 11);
title(ax1, 'A.   Total saccades', 'FontSize', 11, 'FontWeight', 'bold');
grid(ax1, 'on'); hold(ax1, 'off');
 
% Panel B: saccades per trial
ax2 = subplot(1, 2, 2); hold(ax2, 'on');
boxchart(ax2, groups_cat, sacc_per_trial, 'BoxFaceColor', [0.4 0.4 0.4], 'LineWidth', 1.1);
scatter(ax2, xA, sacc_per_trial(art_idx), 45, ArtCol,  'filled', 'MarkerFaceAlpha', 0.8);
scatter(ax2, xC, sacc_per_trial(con_idx), 45, CtrlCol, 'filled', 'MarkerFaceAlpha', 0.8);
set(ax2, 'FontSize', 11, 'Box', 'off');
ylabel(ax2, 'Saccades per trial', 'FontSize', 11);
title(ax2, 'B.   Saccades per trial', 'FontSize', 11, 'FontWeight', 'bold');
grid(ax2, 'on'); hold(ax2, 'off');
 
sgtitle('Figure 5.   Eye-movement activity during Experiment 1', 'FontSize', 12, 'FontWeight', 'bold');
%saveas(gcf, fullfile(fig_dir, 'Fig5_Saccades.png'));
 %%
 fprintf('\n=========== STATISTICAL TESTS (Welch t-tests) ===========\n');
fprintf('  measure                 t          df     p         direction\n');
fprintf('  --------------------------------------------------------------\n');
 
stat_names = {'Art score', 'Overall accuracy', 'Symmetry accuracy', 'Asym accuracy', 'Overall RT', 'Symmetry RT', 'PSE', 'JND', 'Slope', 'Total saccades', 'Saccades per trial'};
stat_data  = { ArtScores, acc_overall, acc_sym, acc_asym, rt_overall, rt_sym, PSE, JND, Slope, n_sacc_exp1, sacc_per_trial };
 
for m = 1:numel(stat_names)
    d = stat_data{m};
    d = d(:);                 % ensure column vector
    a = d(art_idx);
    b = d(con_idx);
    a = a(isfinite(a));
    b = b(isfinite(b));
 
    if numel(a) < 2 || numel(b) < 2
        fprintf('  %-22s (too few values for a t-test)\n', stat_names{m});
        continue;
    end
 
    [~, pv, ~, st] = ttest2(a, b, 'Vartype', 'unequal');
 
    if mean(a) > mean(b)
        direction = 'Art > Ctrl';
    else
        direction = 'Art < Ctrl';
    end
 
    star = '';
    if pv < 0.05,  star = '*';   end
    if pv < 0.01,  star = '**';  end
    if pv < 0.001, star = '***'; end
 
    fprintf('  %-22s  %+7.3f   %5.1f  %8.4g %-3s  %s\n', stat_names{m}, st.tstat, st.df, pv, star, direction);
end
 
 
%% Spearman correlations between Art score and main measures 

fprintf('Spearman correlation between Art score and sensitivity measures:\n');
 
corr_names = {'PSE', 'JND', 'Slope', 'AccSym', 'RT overall'};
corr_data  = { PSE, JND, Slope, acc_sym, rt_overall };
 
art_score_col = ArtScores(:);
 
for m = 1:numel(corr_names)
    d   = corr_data{m};
    d   = d(:);
    ok  = isfinite(d);
    if sum(ok) < 3
        continue;
    end
    [rho, p_rho] = corr(art_score_col(ok), d(ok), 'Type', 'Spearman');
    fprintf('  Art score vs %-12s :  rho = %+.3f,  p = %.4g\n', corr_names{m}, rho, p_rho);
end
%%
% Within-group: sym vs asym (paired t-test)
[~,p_art_within, ~,st_art_within] = ttest(acc_sym(art_idx),  acc_asym(art_idx));
[~,p_con_within, ~,st_con_within] = ttest(acc_sym(con_idx),  acc_asym(con_idx));

% Between-group: sym accuracy and asym accuracy separately (Welch)
[~,p_sym_btwn,  ~,st_sym_btwn]  = ttest2(acc_sym(art_idx),  acc_sym(con_idx),  'Vartype','unequal');
[~,p_asym_btwn, ~,st_asym_btwn] = ttest2(acc_asym(art_idx), acc_asym(con_idx), 'Vartype','unequal');

fprintf('Within Artists accuracy  sym vs asym: t(%d)=%.3f, p=%.4f\n', st_art_within.df, st_art_within.tstat, p_art_within);
fprintf('Within Controls -ii- sym vs asym: t(%d)=%.3f, p=%.4f\n', st_con_within.df, st_con_within.tstat, p_con_within);
fprintf('Between groups   sym acc:     t(%.1f)=%.3f, p=%.4f\n', st_sym_btwn.df,  st_sym_btwn.tstat,  p_sym_btwn);
fprintf('Between groups   asym acc:    t(%.1f)=%.3f, p=%.4f\n', st_asym_btwn.df, st_asym_btwn.tstat, p_asym_btwn);
%%
% Within-group: H vs V accuracy (paired)
acc_H = nanmean(symPC_H, 2);  acc_V = nanmean(symPC_V, 2);
[~,p_art_HV,~,st_art_HV] = ttest(acc_H(art_idx), acc_V(art_idx));
[~,p_con_HV,~,st_con_HV] = ttest(acc_H(con_idx), acc_V(con_idx));

% Between-group: H accuracy and V accuracy separately (Welch)
[~,p_H_btwn,~,st_H_btwn] = ttest2(acc_H(art_idx), acc_H(con_idx), 'Vartype','unequal');
[~,p_V_btwn,~,st_V_btwn] = ttest2(acc_V(art_idx), acc_V(con_idx), 'Vartype','unequal');

% Between-group: H-V difference score (does axis advantage differ by group?)
[~,p_diff,~,st_diff] = ttest2(acc_H(art_idx)-acc_V(art_idx), acc_H(con_idx)-acc_V(con_idx), 'Vartype','unequal');

fprintf('Within Artists   H vs V: t(%d)=%.3f, p=%.4f\n',   st_art_HV.df, st_art_HV.tstat, p_art_HV);
fprintf('Within Controls  H vs V: t(%d)=%.3f, p=%.4f\n',   st_con_HV.df, st_con_HV.tstat, p_con_HV);
fprintf('Between groups   H acc:  t(%.1f)=%.3f, p=%.4f\n', st_H_btwn.df, st_H_btwn.tstat, p_H_btwn);
fprintf('Between groups   V acc:  t(%.1f)=%.3f, p=%.4f\n', st_V_btwn.df, st_V_btwn.tstat, p_V_btwn);
fprintf('Between groups   H-V diff: t(%.1f)=%.3f, p=%.4f\n', st_diff.df, st_diff.tstat, p_diff);
%%
% Between-group: PSE for symmetry (Welch)
[~,p_PSE,~,st_PSE] = ttest2(PSE(art_idx), PSE(con_idx), 'Vartype','unequal');
fprintf('Between groups PSE (sym): t(%.1f)=%.3f, p=%.4f\n', st_PSE.df, st_PSE.tstat, p_PSE);

%%
Slope_H = nan(N,1); Slope_V = nan(N,1);
model_fn = @(p,xx) 1./(1+exp(-p(2).*(xx-p(1))));
opts = optimset('Display','off','MaxIter',3000,'TolFun',1e-9,'TolX',1e-9);
for i = 1:N
    for ax = 1:2
        y = symPC_H(i,:)'; if ax==2, y = symPC_V(i,:)'; end
        ok = isfinite(y); if sum(ok)<3, continue; end
        try
            p_hat = fminsearch(@(p) sum((model_fn(p,log(contrast_vals(ok))')-y(ok)).^2), [mean(log(contrast_vals(ok))),3], opts);
            if ax==1, Slope_H(i)=p_hat(2); else, Slope_V(i)=p_hat(2); end
        catch; end
    end
end

% Between-group: Slope (Welch)
[~,p_Slope,~,st_Slope] = ttest2(Slope(art_idx), Slope(con_idx), 'Vartype','unequal');
fprintf('Between groups Slope (sym): t(%.1f)=%.3f, p=%.4f\n', st_Slope.df, st_Slope.tstat, p_Slope);

% Within-group: H vs V slope (paired)
[~,p_art_SHV,~,st_art_SHV] = ttest(Slope_H(art_idx), Slope_V(art_idx));
[~,p_con_SHV,~,st_con_SHV] = ttest(Slope_H(con_idx), Slope_V(con_idx));
fprintf('Within Artists   Slope H vs V: t(%d)=%.3f, p=%.4f\n', st_art_SHV.df, st_art_SHV.tstat, p_art_SHV);
fprintf('Within Controls  Slope H vs V: t(%d)=%.3f, p=%.4f\n', st_con_SHV.df, st_con_SHV.tstat, p_con_SHV);
%% 2(Group: Artist/Control) x 2(Condition: Sym/Asym) mixed ANOVA
acc_all   = [acc_sym(:); acc_asym(:)];
grp_label = [Group(:); Group(:)];
cond_label = [repmat({'Sym'},N,1); repmat({'Asym'},N,1)];
subj_label = [(1:N)'; (1:N)'];
T = table(acc_all, categorical(grp_label), categorical(cond_label), subj_label, ...
    'VariableNames', {'Accuracy','Group','Condition','Subject'});
rm = fitrm(T, 'Accuracy ~ Group', 'WithinDesign', table(categorical({'Sym';'Asym'}),'VariableNames',{'Condition'}));
ranova(rm)
%%
[~,p_JND,~,st_JND] = ttest2(JND(art_idx), JND(con_idx), 'Vartype','unequal');
fprintf('\n=== Psychometric Sensitivity: Artists vs Controls ===\n');
fprintf('PSE:   t(%.1f) = %.3f, p = %.4g  (Art M=%.3f, Ctrl M=%.3f)\n', ...
    st_PSE.df,   st_PSE.tstat,   p_PSE,   nanmean(PSE(art_idx)),   nanmean(PSE(con_idx)));
fprintf('JND:   t(%.1f) = %.3f, p = %.4g  (Art M=%.3f, Ctrl M=%.3f)\n', ...
    st_JND.df,   st_JND.tstat,   p_JND,   nanmean(JND(art_idx)),   nanmean(JND(con_idx)));
fprintf('Slope: t(%.1f) = %.3f, p = %.4g  (Art M=%.3f, Ctrl M=%.3f)\n', ...
    st_Slope.df, st_Slope.tstat, p_Slope, nanmean(Slope(art_idx)), nanmean(Slope(con_idx)));