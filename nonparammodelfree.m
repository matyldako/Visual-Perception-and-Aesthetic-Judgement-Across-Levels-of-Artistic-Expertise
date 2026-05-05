% RQ2 — Non-parametric psychometric functions
% Features: ModelFree local polynomial estimation,
%            Raw Table Permutation Inference (unchanged from original)
%
% SETUP REQUIRED:
%   1. Download ModelFree from:
%      https://personalpages.manchester.ac.uk/staff/d.h.foster/software-modelfree/latest/downloads.html
%   2. Unzip and add to your MATLAB path:
%      addpath(genpath('/path/to/modelfree'))
%   3. The key functions used here are (ModelFree v1.1 actual names):
%        locglmfit(xfit,x,r,m,h,link)       -> local polynomial PF fit
%        threshold_slope(pfit,xfit,0.5)      -> PSE + slope
%        bandwidth_cross_validation(x,r,m,link) -> auto bandwidth
%        bootstrap_ci_th(x,r,m,h,link,B,0.5)   -> threshold CI
%        bootstrap_ci_sl(x,r,m,h,link,B,0.5)   -> slope CI
%
% IMPORTANT NOTE ON X-AXIS:
%   ModelFree expects objective stimulus levels. Here, 'x' is a signed
%   rank derived from sorting each participant's P(test>ref) values. This
%   means the x-axis is data-driven (not a fixed stimulus scale), so
%   threshold estimates are on the signed-rank scale, not a physical unit.
%   This is inherited from the original LLE.m design (previous script
%   using local linear estimation

clear; clc; close all;
warning('off','all');
%%
addpath(genpath('/Users//Desktop/DATA_DISS/modelfree1.1'))


%% 0. ModelFree availability check
% Check for the actual ModelFree v1.1 entry-point function
MF_AVAILABLE = (exist('locglmfit','file') == 2);
if ~MF_AVAILABLE
    warning(['ModelFree v1.1 not found on MATLAB path.\n' ...
             'Expected function: locglmfit.m\n' ...
             'Run: addpath(genpath(''/path/to/modelfree1.1''))\n' ...
             'Falling back to manual LLE (original behaviour).']);
end

%% Paths & Definitions
DATA_DIR       = '/Users//Desktop/DATA_DISS/AllData';
OUT_DIR        = '/Users//Desktop/DATA_DISS/RQ2_MF_FixedRef';
REF_TYPE_FIXED = 2;   % col 3 of ResFile == 2 -> Refb = object image 7
% Filtering to REF_TYPE_FIXED==2 throughout places all four categories on a
% common measuring scale: every test image is compared against object image 7.
if ~exist(OUT_DIR, 'dir'), mkdir(OUT_DIR); end

ART_COL  = [0.20, 0.45, 0.75];
CTRL_COL = [0.95, 0.55, 0.10];

BLOCKS = {
    'Face',   'FaceObject', 1, 'CONDA_faceStimSelectedTestINDX';
    'Object', 'FaceObject', 2, 'CONDB_objectStimSelectedTestINDX';
    'Flower', 'FlowerBug',  1, 'CONDC_flowerStimSelectedTestINDX';
    'Bug',    'FlowerBug',  2, 'CONDD_bugStimSelectedTestINDX'
};

QUES_DICT = containers.Map({1, 2, 3}, {'Skill', 'Beauty', 'Symmetry'});
RANKS = -6:6;
CATS = {'Face', 'Object', 'Flower', 'Bug'};
QUES = {'Skill', 'Beauty', 'Symmetry'};

% ModelFree options
% 'probit' or 'logit' — the link function for local polynomial fitting.
% 'probit' is standard; 'logit' is equivalent to a local logistic.
MF_LINK = 'logit';
% Number of bootstrap resamples for CIs (increase to 2000 for final analysis)
MF_NBOOT = 1000;
% Fixed LLE bandwidth (only used if ModelFree is unavailable)
h_bw = 1.5;

%% 1. Data loading  (unchanged)
matFiles = dir(fullfile(DATA_DIR, '*_AesSymPer_*.mat'));
recs = struct('pid', {}, 'group', {}, 'FO', {}, 'FB', {});
seen = containers.Map();

for i = 1:length(matFiles)
    fpath = fullfile(matFiles(i).folder, matFiles(i).name);
    data = load(fpath, 'S');
    S = data.S;

    pid = strtrim(S.ParticipantAndTaskInfo.PartID);
    if isKey(seen, pid), continue; end
    seen(pid) = true;

    if startsWith(pid, 'A') || strcmp(pid, 'S11') % mislabelled as ctrl is artist
        grp = 'Artist';
    else
        grp = 'Control';
    end

    recs(end+1).pid   = pid;
    recs(end).group   = grp;
    recs(end).FO      = S.AestheticJudgmentTask.FaceObject;
    recs(end).FB      = S.AestheticJudgmentTask.FlowerBug;
end
fprintf('Loaded %d participants\n', length(recs));

%% 2 & 3. Psychometric function fitting (ModelFree or LLE fallback)
if MF_AVAILABLE
    disp('Fitting psychometric functions using ModelFree (local polynomial)...');
else
    disp('Fitting psychometric functions using fallback LLE (Gaussian kernel)...');
end

eval_grid = linspace(-6.5, 6.5, 200); % Used only for the LLE fallback

indiv_rows   = {};
pooled_rows  = {};
raw_trial_data = {};  % For the permutation test

for r_idx = 1:length(recs)
    r = recs(r_idx);

    for b_idx = 1:size(BLOCKS, 1)
        cat_name = BLOCKS{b_idx, 1};  tname   = BLOCKS{b_idx, 2};
        cat_code = BLOCKS{b_idx, 3};  field   = BLOCKS{b_idx, 4};

        if strcmp(tname, 'FaceObject'), task = r.FO; else, task = r.FB; end
        rf  = task.ResponseFileFull;
        ids = task.StimulusInfo.(field);

        for qnum = 1:3
            qname = QUES_DICT(qnum);
            mask  = (rf(:, 2) == cat_code) & (rf(:, 4) == qnum) & (rf(:, 3) == REF_TYPE_FIXED);

            % Aggregate counts per stimulus level
            P_vals = [];
            for lv = 1:length(ids)
                m_mask = mask & (rf(:, 1) == lv);
                if any(m_mask)
                    n_test  = sum(rf(m_mask, 7));
                    n_total = sum(m_mask);
                    P_vals(end+1, :) = [ids(lv), n_test / n_total, n_test, n_total];
                end
            end

            if isempty(P_vals), continue; end

            % Assign signed ranks  (identical logic to original LLE.m)
            P_sort = sortrows(P_vals, 2);
            below  = P_sort(P_sort(:,2) < 0.5, :);
            above  = P_sort(P_sort(:,2) > 0.5, :);
            equal  = P_sort(P_sort(:,2) == 0.5, :);

            % Anchor at rank 0, P = 0.5
            ranks_arr = 0;  p_arr = 0.5;
            n_test_arr  = 1;   % anchor: 1 "test" out of 2 trials (probability = 0.5)
            n_total_arr = 2;

            raw_trial_data(end+1,:) = {r.group, cat_name, qname, 0, 1, 2};

            for j = 1:size(below, 1)
                rk = -(size(below,1) - j + 1);
                ranks_arr(end+1)  = rk;
                p_arr(end+1)      = below(j,2);
                n_test_arr(end+1) = below(j,3);
                n_total_arr(end+1) = below(j,4);
                raw_trial_data(end+1,:) = {r.group, cat_name, qname, rk, below(j,3), below(j,4)};
            end
            for j = 1:size(equal, 1)
                ranks_arr(end+1)  = 0;
                p_arr(end+1)      = equal(j,2);
                n_test_arr(end+1) = equal(j,3);
                n_total_arr(end+1) = equal(j,4);
                raw_trial_data(end+1,:) = {r.group, cat_name, qname, 0, equal(j,3), equal(j,4)};
            end
            for j = 1:size(above, 1)
                rk = j;
                ranks_arr(end+1)  = rk;
                p_arr(end+1)      = above(j,2);
                n_test_arr(end+1) = above(j,3);
                n_total_arr(end+1) = above(j,4);
                raw_trial_data(end+1,:) = {r.group, cat_name, qname, rk, above(j,3), above(j,4)};
            end

            % --- PSE and slope estimation ---
            pse = NaN;  slope = NaN;
            pse_ci = [NaN NaN];  slope_ci = [NaN NaN];

            if length(ranks_arr) >= 3
                if MF_AVAILABLE
                    % -------------------------------------------------------
                    % ModelFree v1.1 path
                    % locglmfit(xfit, x, r, m, h, link)
                    %   xfit : evaluation grid (where to evaluate the fit)
                    %   x    : data stimulus levels (sorted, unique)
                    %   r    : integer successes at each level
                    %   m    : integer trials at each level
                    %   h    : bandwidth (chosen by cross-validation below)
                    %   link : 'probit' | 'logit' | 'weibull' etc.
                    % Returns pfit: vector of fitted probabilities at xfit.
                    %
                    % threshold_slope(pfit, xfit, p) returns [threshold, slope]
                    % at the p=0.5 level (i.e. the PSE).
                    % -------------------------------------------------------

                    % Sort and pool duplicate ranks
                    [x_sort, si] = sort(ranks_arr(:));
                    r_counts = round(n_test_arr(si))';
                    m_counts = round(n_total_arr(si))';

                    [x_unique, ~, ic] = unique(x_sort);
                    r_unique = accumarray(ic, r_counts);
                    m_unique = accumarray(ic, m_counts);

                    % Evaluation grid for this participant's rank range
                    xfit = linspace(min(x_unique)-0.5, max(x_unique)+0.5, 200)';

                    try
                        % 1. Select bandwidth via leave-one-out cross-validation
                        h_mf = bandwidth_cross_validation(x_unique, r_unique, m_unique, MF_LINK);

                        % 2. Fit the local GLM psychometric function
                        pfit = locglmfit(xfit, x_unique, r_unique, m_unique, h_mf, MF_LINK);

                        % 3. Extract PSE (threshold at p=0.5) and slope
                        [pse, slope] = threshold_slope(pfit, xfit, 0.5);

                        % 4. Bootstrap confidence intervals
                        try
                            pse_ci   = bootstrap_ci_th(x_unique, r_unique, m_unique, ...
                                                        h_mf, MF_LINK, MF_NBOOT, 0.5);
                            slope_ci = bootstrap_ci_sl(x_unique, r_unique, m_unique, ...
                                                        h_mf, MF_LINK, MF_NBOOT, 0.5);
                        catch
                            % CI functions may have a different signature in
                            % some sub-versions — leave as NaN and continue.
                        end

                    catch me
                        warning('ModelFree fitting failed for %s/%s/%s: %s', ...
                                r.pid, cat_name, qname, me.message);
                        [pse, slope] = fit_lle(ranks_arr, p_arr, eval_grid, h_bw);
                    end

                else
                    % Fallback: original Gaussian-kernel LLE
                    [pse, slope] = fit_lle(ranks_arr, p_arr, eval_grid, h_bw);
                end
            end

            indiv_rows(end+1, :) = {r.pid, r.group, cat_name, qname, ...
                                    pse, slope, pse_ci(1), pse_ci(2), slope_ci(1), slope_ci(2)};
        end

        % Pooled (for Figure 1 — all questions combined, fixed object reference only)
        mask_all   = (rf(:, 2) == cat_code) & (rf(:, 3) == REF_TYPE_FIXED);
        P_vals_all = [];
        for lv = 1:length(ids)
            m_mask = mask_all & (rf(:, 1) == lv);
            if any(m_mask), P_vals_all(end+1, :) = [ids(lv), mean(rf(m_mask, 7))]; end
        end
        if ~isempty(P_vals_all)
            P_sort = sortrows(P_vals_all, 2);
            below = P_sort(P_sort(:,2) < 0.5, :);
            above = P_sort(P_sort(:,2) > 0.5, :);
            equal = P_sort(P_sort(:,2) == 0.5, :);
            for j = 1:size(below, 1)
                pooled_rows(end+1, :) = {r.pid, r.group, cat_name, -(size(below,1) - j + 1), below(j,2)};
            end
            for j = 1:size(equal, 1)
                pooled_rows(end+1, :) = {r.pid, r.group, cat_name, 0, equal(j,2)};
            end
            for j = 1:size(above, 1)
                pooled_rows(end+1, :) = {r.pid, r.group, cat_name, j, above(j,2)};
            end
        end
    end
end

% Build tables — note extra CI columns compared to original
indiv = cell2table(indiv_rows, 'VariableNames', ...
    {'pid', 'group', 'category', 'question', ...
     'PSE', 'slope', 'PSE_CI_lo', 'PSE_CI_hi', 'slope_CI_lo', 'slope_CI_hi'});
pooled    = cell2table(pooled_rows,    'VariableNames', {'pid','group','category','rank','P'});
raw_trials = cell2table(raw_trial_data, 'VariableNames', {'group','category','question','rank','n_test','n_total'});
writetable(indiv, fullfile(OUT_DIR, 'FIXEDREF_MF_participant_PSE_slope.csv'));

%% 4. Exact Permutation Test on Raw Frequency Tables  (unchanged from LLE.m)
% This section is independent of the fitting method and it operates on the
% raw trial counts, not on the derived PSE/slope values, so it remains
% valid regardless of whether ModelFree or LLE was used above. note.
% ModelFree was used. 
disp('Running Distribution-Free Table Permutation Inference...');

n_perms = 5000;
stat_rows = {};

for c = 1:length(CATS)
    for q = 1:length(QUES)
        cat = CATS{c};  qu = QUES{q};

        idx     = strcmp(raw_trials.category, cat) & strcmp(raw_trials.question, qu);
        sub_raw = raw_trials(idx, :);

        obs_tables = zeros(2, 2, length(RANKS));

        for rk_idx = 1:length(RANKS)
            rk      = RANKS(rk_idx);
            idx_art = strcmp(sub_raw.group,'Artist')  & sub_raw.rank == rk;
            idx_con = strcmp(sub_raw.group,'Control') & sub_raw.rank == rk;

            art_test = sum(sub_raw.n_test(idx_art));
            art_tot  = sum(sub_raw.n_total(idx_art));
            con_test = sum(sub_raw.n_test(idx_con));
            con_tot  = sum(sub_raw.n_total(idx_con));

            obs_tables(1,1,rk_idx) = art_tot  - art_test;
            obs_tables(1,2,rk_idx) = art_test;
            obs_tables(2,1,rk_idx) = con_tot  - con_test;
            obs_tables(2,2,rk_idx) = con_test;
        end

        obs_X2 = calculate_omnibus_X2(obs_tables);

        perm_X2 = zeros(1, n_perms);
        for p = 1:n_perms
            perm_tables = zeros(2, 2, length(RANKS));
            for rk_idx = 1:length(RANKS)
                tot_art    = sum(obs_tables(1,:,rk_idx));
                tot_con    = sum(obs_tables(2,:,rk_idx));
                n_test_pool = obs_tables(1,2,rk_idx) + obs_tables(2,2,rk_idx);
                n_tot_pool  = tot_art + tot_con;

                if n_tot_pool > 0
                    pool = [ones(n_test_pool,1); zeros(n_tot_pool - n_test_pool, 1)];
                    pool = pool(randperm(n_tot_pool));

                    art_fake_test = sum(pool(1:tot_art));
                    con_fake_test = sum(pool(tot_art+1:end));

                    perm_tables(1,1,rk_idx) = tot_art - art_fake_test;
                    perm_tables(1,2,rk_idx) = art_fake_test;
                    perm_tables(2,1,rk_idx) = tot_con - con_fake_test;
                    perm_tables(2,2,rk_idx) = con_fake_test;
                end
            end
            perm_X2(p) = calculate_omnibus_X2(perm_tables);
        end

        p_val = sum(perm_X2 >= obs_X2) / n_perms;
        stat_rows(end+1,:) = {'Curve_Homogeneity', cat, qu, obs_X2, p_val};
    end
end

stat_df = cell2table(stat_rows, ...
    'VariableNames', {'Test','category','question','Omnibus_X2','p_value'});
writetable(stat_df, fullfile(OUT_DIR, 'FIXEDREF_MF_table_inference.csv'));

%% 4b. Optional: permutation t-test on ModelFree-derived PSE/slope
% If you want a second layer of inference that tests the group difference
% in derived PSE/slope (analogous to RQ2_NONPPSYCHFINAL.m's approach),
% uncomment this section. This gives you a localized test on top of the
% omnibus curve-shape test above.
%
stat_rows2 = {};
metrics = {'PSE','slope'};
for m_idx = 1:2
    metric = metrics{m_idx};
    for c = 1:length(CATS)
        for q = 1:length(QUES)
            idxA = strcmp(indiv.category,CATS{c}) & strcmp(indiv.question,QUES{q}) ...
                   & strcmp(indiv.group,'Artist');
            idxC = strcmp(indiv.category,CATS{c}) & strcmp(indiv.question,QUES{q}) ...
                   & strcmp(indiv.group,'Control');
            valA = rmmissing(indiv.(metric)(idxA));
            valC = rmmissing(indiv.(metric)(idxC));
            if length(valA) > 1 && length(valC) > 1
                [p_perm, t_perm] = perm_ttest2_simple(valA, valC, 5000);
                stat_rows2(end+1,:) = {metric, CATS{c}, QUES{q}, ...
                    length(valA), mean(valA), length(valC), mean(valC), t_perm, p_perm};
            end
        end
    end
end
stat_df2 = cell2table(stat_rows2, 'VariableNames', ...
    {'metric','category','question','art_n','art_mean','con_n','con_mean','t_stat','p_value'});
writetable(stat_df2, fullfile(OUT_DIR,'FIXEDREF_MF_pse_slope_perm_ttest.csv'));

%% 5. Spaghetti plots  (BUG FIX: fname now includes current_q)
disp('Generating psychometric spaghetti curves per question...');

for q_idx = 1:length(QUES)
    current_q = QUES{q_idx};

    fig = figure('Position', [100, 100, 900, 700], 'Name', ['Curves: ', current_q]);
    tiledlayout(2, 2, 'Padding', 'compact');

    for c = 1:length(CATS)
        ax = nexttile; hold on;
        title(sprintf('%s - %s', CATS{c}, current_q));

        for g = 1:2
            if g == 1, grp = 'Artist'; col = ART_COL; else, grp = 'Control'; col = CTRL_COL; end

            all_ranks = [];
            all_P     = [];

            for ri = 1:length(recs)
                rr = recs(ri);
                if ~strcmp(rr.group, grp), continue; end

                for b_idx = 1:size(BLOCKS, 1)
                    if strcmp(BLOCKS{b_idx, 1}, CATS{c})
                        cat_code_plt = BLOCKS{b_idx, 3};
                        field_plt    = BLOCKS{b_idx, 4};
                        if strcmp(BLOCKS{b_idx, 2}, 'FaceObject')
                            task_plt = rr.FO;
                        else
                            task_plt = rr.FB;
                        end

                        rf_plt  = task_plt.ResponseFileFull;
                        ids_plt = task_plt.StimulusInfo.(field_plt);
                        mask_plt = (rf_plt(:,2) == cat_code_plt) & (rf_plt(:,4) == q_idx) & (rf_plt(:,3) == REF_TYPE_FIXED);

                        P_vals_plt = [];
                        for lv = 1:length(ids_plt)
                            m_mask = mask_plt & (rf_plt(:,1) == lv);
                            if any(m_mask)
                                P_vals_plt(end+1,:) = [ids_plt(lv), mean(rf_plt(m_mask,7))];
                            end
                        end

                        if isempty(P_vals_plt), continue; end

                        P_sort_plt = sortrows(P_vals_plt, 2);
                        bel = P_sort_plt(P_sort_plt(:,2) < 0.5, :);
                        abo = P_sort_plt(P_sort_plt(:,2) > 0.5, :);
                        equ = P_sort_plt(P_sort_plt(:,2) == 0.5, :);

                        indiv_ranks = 0; indiv_P = 0.5;
                        for j = 1:size(bel,1), indiv_ranks(end+1) = -(size(bel,1)-j+1); indiv_P(end+1) = bel(j,2); end
                        for j = 1:size(equ,1), indiv_ranks(end+1) = 0;                  indiv_P(end+1) = equ(j,2); end
                        for j = 1:size(abo,1), indiv_ranks(end+1) = j;                  indiv_P(end+1) = abo(j,2); end

                        [irk_s, si2] = sort(indiv_ranks);
                        plot(irk_s, indiv_P(si2), '-', 'Color', [col, 0.25], 'LineWidth', 0.5);

                        all_ranks = [all_ranks, indiv_ranks];
                        all_P     = [all_P,     indiv_P];
                    end
                end
            end

            % Group mean line
            m_group = zeros(1, length(RANKS));
            for ri = 1:length(RANKS)
                r_sel = all_ranks == RANKS(ri);
                if any(r_sel), m_group(ri) = mean(all_P(r_sel)); end
            end
            m_group(RANKS == 0) = 0.5;
            plot(RANKS, m_group, '-o', 'Color', col, 'MarkerSize', 6, 'LineWidth', 3);
        end

        yline(0.5, '--', 'Color', [0.65 0.65 0.65]);
        xline(0,   '--', 'Color', [0.65 0.65 0.65]);
        xlim([-6.5 6.5]); ylim([0 1]); xticks(-6:2:6);
        if c > 2, xlabel('Signed Rank'); end
        if mod(c,2) ~= 0, ylabel('P(Test > Ref)'); end
        if c == 1
            text(-5.8, 0.9, 'Artist Group',  'Color', ART_COL,  'FontWeight','bold','FontSize',10);
            text(-5.8, 0.8, 'Control Group', 'Color', CTRL_COL, 'FontWeight','bold','FontSize',10);
        end
    end

    % BUG FIX: original used sprintf without %s placeholder, so all 3
    % figures overwrote the same file. Now includes current_q in fname.
    fname = sprintf('FIXEDREF_MF_spaghetti_%s.png', current_q);
    exportgraphics(fig, fullfile(OUT_DIR, fname), 'Resolution', 200);
end

%% 6 & 7. Bar and boxplot figures  (unchanged from original LLE.m)
metrics_to_plot = {'PSE', 'slope'};
ylabels  = {'PSE (signed rank)', 'Slope (dP / d rank)'};
fnames_b = {'FIXEDREF_MF_fig2_PSE_bars.png', 'FIXEDREF_MF_fig3_slope_bars.png'};

for m_idx = 1:2
    metric_plt = metrics_to_plot{m_idx};
    fig2 = figure('Position', [100, 100, 1000, 400]);
    tiledlayout(1, 3, 'Padding', 'compact');

    for q = 1:length(QUES)
        nexttile; hold on; title(QUES{q});

        means_plt = zeros(2,4); errs_plt = zeros(2,4);
        for g = 1:2
            if g == 1, grp = 'Artist'; else, grp = 'Control'; end
            for c = 1:4
                idx_plt = strcmp(indiv.category, CATS{c}) & ...
                          strcmp(indiv.question,  QUES{q}) & ...
                          strcmp(indiv.group,     grp);
                vals_plt = rmmissing(indiv.(metric_plt)(idx_plt));
                means_plt(g,c) = mean(vals_plt);
                errs_plt(g,c)  = std(vals_plt) / sqrt(length(vals_plt));
            end
        end

        b_plt = bar(means_plt', 'grouped');
        b_plt(1).FaceColor = ART_COL; b_plt(2).FaceColor = CTRL_COL;

        ngroups = 4; nbars = 2;
        groupwidth = min(0.8, nbars/(nbars + 1.5));
        for i = 1:nbars
            x_eb = (1:ngroups) - groupwidth/2 + (2*i-1)*groupwidth/(2*nbars);
            errorbar(x_eb, means_plt(i,:), errs_plt(i,:), 'k', ...
                     'linestyle','none','LineWidth',1.2);
        end

        xticks(1:4); xticklabels(CATS);
        ylabel(ylabels{m_idx}); yline(0, '--', 'Color', [0.5 0.5 0.5]);
    end
    exportgraphics(fig2, fullfile(OUT_DIR, fnames_b{m_idx}), 'Resolution', 200);
end

fig4 = figure('Position', [100, 100, 1100, 450]);
tiledlayout(1, 3, 'Padding', 'compact');

for q = 1:length(QUES)
    nexttile; hold on; title(QUES{q}); yline(0, '--', 'Color', [0.5 0.5 0.5]);

    positions = []; groupData = []; colorData = [];

    for c = 1:4
        for g = 1:2
            if g == 1, grp = 'Artist'; col = ART_COL; else, grp = 'Control'; col = CTRL_COL; end
            idx_plt = strcmp(indiv.category, CATS{c}) & ...
                      strcmp(indiv.question,  QUES{q}) & ...
                      strcmp(indiv.group,     grp);
            vals_plt = rmmissing(indiv.PSE(idx_plt));

            pos = (c-1)*3 + g;
            positions = [positions, pos];
            x_jitter = pos + (rand(length(vals_plt),1) - 0.5)*0.3;
            scatter(x_jitter, vals_plt, 18, col, 'filled', 'MarkerFaceAlpha', 0.75);

            groupData = [groupData; vals_plt];
            colorData = [colorData; repmat(pos, length(vals_plt), 1)];
        end
    end

    boxplot(groupData, colorData, 'Positions', positions, 'Widths', 0.65, ...
            'Colors', 'k', 'Symbol', '');
    xticks([1.5, 4.5, 7.5, 10.5]); xticklabels(CATS);
    if q == 1, ylabel('Individual PSE (signed rank)'); end
end
exportgraphics(fig4, fullfile(OUT_DIR, 'FIXEDREF_MF_fig4_PSE_boxplots.png'), 'Resolution', 200);

disp('Fixed-reference ModelFree analysis complete. All CSVs and plots saved.');

%%  HELPER FUNCTIONS

function X2_total = calculate_omnibus_X2(tables_3D)
% Sum of Pearson chi-square across all K contingency tables.
    X2_total = 0;
    for k = 1:size(tables_3D, 3)
        tbl       = tables_3D(:,:,k);
        grand_tot = sum(tbl(:));
        if grand_tot == 0, continue; end

        row_sums = sum(tbl, 2);
        col_sums = sum(tbl, 1);
        expected = (row_sums * col_sums) / grand_tot;

        valid  = expected > 0;
        X2_k   = sum(sum((tbl(valid) - expected(valid)).^2 ./ expected(valid)));
        X2_total = X2_total + X2_k;
    end
end


function [pse, slope] = fit_lle(ranks_arr, p_arr, eval_grid, h_bw)
% Gaussian-kernel local linear estimation (original LLE.m logic).
% Used as a fallback when ModelFree is unavailable.
    pse = NaN; slope = NaN;
    if length(ranks_arr) < 3, return; end

    P_est     = zeros(size(eval_grid));
    slope_est = zeros(size(eval_grid));

    for g_idx = 1:length(eval_grid)
        x0 = eval_grid(g_idx);
        W  = diag(exp(-0.5 * ((ranks_arr - x0) / h_bw).^2));
        X  = [ones(length(ranks_arr), 1), (ranks_arr - x0)'];
        Y  = p_arr';
        beta         = (X' * W * X) \ (X' * W * Y);
        P_est(g_idx) = max(0, min(1, beta(1)));
        slope_est(g_idx) = beta(2);
    end

    [~, cross_idx] = min(abs(P_est - 0.5));
    pse   = eval_grid(cross_idx);
    slope = slope_est(cross_idx);
end


function [p_perm, t_obs] = perm_ttest2_simple(a, b, n_perms)
% Minimal two-sample permutation t-test (no PERMUTOOLS needed).
% Used by the optional section 4b above.
    pooled_vals = [a(:); b(:)];
    na = length(a);
    t_obs = (mean(a) - mean(b)) / sqrt(var(a)/na + var(b)/length(b));

    t_perm = zeros(1, n_perms);
    for p = 1:n_perms
        idx      = randperm(length(pooled_vals));
        fa       = pooled_vals(idx(1:na));
        fb       = pooled_vals(idx(na+1:end));
        nfb      = length(fb);
        t_perm(p) = (mean(fa) - mean(fb)) / sqrt(var(fa)/na + var(fb)/nfb);
    end

    p_perm = sum(abs(t_perm) >= abs(t_obs)) / n_perms; % two-tailed
end

%%
% After your fitting loop, summarise what you have
n_valid_pse   = sum(~isnan(indiv.PSE));
n_valid_ci    = sum(~isnan(indiv.PSE_CI_lo));
n_total       = height(indiv);
fprintf('Valid PSE: %d/%d\nValid CIs: %d/%d\n', n_valid_pse, n_total, n_valid_ci, n_total);
%%
%% =========================================================================
%  STATISTICAL ANALYSIS MODULE
%  Runs after the main fitting loop has populated the 'indiv' table.
%  Requires: indiv table with columns pid, group, category, question,
%            PSE, slope, PSE_CI_lo, PSE_CI_hi, slope_CI_lo, slope_CI_hi
%% =========================================================================

fprintf('\n=== STATISTICAL ANALYSIS ===\n');

% Parameters
N_PERM      = 5000;   % permutation draws
CI_MAX_WIDTH = 3.0;   % rank units — fits wider than this are excluded
ALPHA       = 0.05;

CATS  = {'Face','Object','Flower','Bug'};
QUES  = {'Skill','Beauty','Symmetry'};
METRICS = {'PSE','slope'};

% ── Stage 1: Flag unreliable individual fits ──────────────────────────────
% CI width = hi - lo. If CIs are NaN (bootstrap failed), width = NaN.
% Participants are excluded per cell, not globally.

indiv.PSE_CI_width   = indiv.PSE_CI_hi   - indiv.PSE_CI_lo;
indiv.slope_CI_width = indiv.slope_CI_hi - indiv.slope_CI_lo;

% Flag: reliable = CI width within threshold OR CI is NaN but PSE is valid.
% If bootstrap CIs are all NaN (the current situation), we skip the
% exclusion step and note this in the output. Once CIs are working,
% the exclusion kicks in automatically.

ci_available = ~all(isnan(indiv.PSE_CI_width));

if ci_available
    indiv.PSE_reliable   = indiv.PSE_CI_width   <= CI_MAX_WIDTH & ~isnan(indiv.PSE);
    indiv.slope_reliable = indiv.slope_CI_width <= CI_MAX_WIDTH & ~isnan(indiv.slope);
    fprintf('Bootstrap CIs available. Exclusion threshold: %.1f rank units.\n', CI_MAX_WIDTH);
else
    % CIs not yet working — include all valid PSE/slope estimates
    indiv.PSE_reliable   = ~isnan(indiv.PSE);
    indiv.slope_reliable = ~isnan(indiv.slope);
    fprintf(['WARNING: Bootstrap CIs are all NaN.\n' ...
             'Proceeding without CI-based exclusion.\n' ...
             'Fix bootstrap_ci_th/sl before final analysis.\n']);
end

% ── Stage 2: Permutation t-tests ─────────────────────────────────────────
% Pre-allocate results table
n_tests = length(CATS) * length(QUES) * length(METRICS);
results = table(...
    repmat({''},n_tests,1), repmat({''},n_tests,1), repmat({''},n_tests,1), ...
    zeros(n_tests,1), zeros(n_tests,1), zeros(n_tests,1), ...
    zeros(n_tests,1), zeros(n_tests,1), zeros(n_tests,1), ...
    zeros(n_tests,1), zeros(n_tests,1), zeros(n_tests,1), ...
    'VariableNames', {'metric','category','question',...
                      'artist_n','artist_M','artist_SD',...
                      'control_n','control_M','control_SD',...
                      't_obs','cohens_d','p_perm'});

row = 0;

for m_idx = 1:length(METRICS)
    metric = METRICS{m_idx};
    
    if strcmp(metric,'PSE')
        reliable_col = 'PSE_reliable';
    else
        reliable_col = 'slope_reliable';
    end
    
    for c = 1:length(CATS)
        for q = 1:length(QUES)
            row = row + 1;
            
            % Select reliable estimates for this cell
            idx_art = strcmp(indiv.group,'Artist') & ...
                      strcmp(indiv.category,CATS{c}) & ...
                      strcmp(indiv.question,QUES{q}) & ...
                      indiv.(reliable_col);
            
            idx_con = strcmp(indiv.group,'Control') & ...
                      strcmp(indiv.category,CATS{c}) & ...
                      strcmp(indiv.question,QUES{q}) & ...
                      indiv.(reliable_col);
            
            vals_art = indiv.(metric)(idx_art);
            vals_con = indiv.(metric)(idx_con);
            
            n_art = length(vals_art);
            n_con = length(vals_con);
            
            % Store descriptives
            results.metric{row}    = metric;
            results.category{row}  = CATS{c};
            results.question{row}  = QUES{q};
            results.artist_n(row)  = n_art;
            results.control_n(row) = n_con;
            
            if n_art < 2 || n_con < 2
                % Too few observations to test
                results.artist_M(row) = NaN; results.artist_SD(row) = NaN;
                results.control_M(row)= NaN; results.control_SD(row) = NaN;
                results.t_obs(row)    = NaN;
                results.cohens_d(row) = NaN;
                results.p_perm(row)   = NaN;
                fprintf('SKIPPED: %s / %s / %s — insufficient n\n', ...
                        metric, CATS{c}, QUES{q});
                continue
            end
            
            results.artist_M(row)  = mean(vals_art);
            results.artist_SD(row) = std(vals_art);
            results.control_M(row) = mean(vals_con);
            results.control_SD(row)= std(vals_con);
            
            % Run permutation t-test
            [p_perm, t_obs, cohens_d] = permutation_ttest2(vals_art, vals_con, N_PERM);
            
            results.t_obs(row)    = t_obs;
            results.cohens_d(row) = cohens_d;
            results.p_perm(row)   = p_perm;
        end
    end
end

% ── Print results to command window ──────────────────────────────────────
fprintf('\n%-8s %-8s %-10s  %5s  %6s  %6s  %6s  %6s  %6s  %6s  %6s\n', ...
    'Metric','Cat','Question','nA','M_A','nC','M_C','t','d','p_perm','sig');
fprintf('%s\n', repmat('-',1,85));

for r = 1:height(results)
    if isnan(results.p_perm(r)), continue; end
    sig = '';
    if results.p_perm(r) < .001, sig = '***';
    elseif results.p_perm(r) < .01, sig = '**';
    elseif results.p_perm(r) < .05, sig = '*';
    elseif results.p_perm(r) < .10, sig = '.';
    end
    fprintf('%-8s %-8s %-10s  %5d  %6.3f  %5d  %6.3f  %6.2f  %5.2f  %6.4f  %s\n', ...
        results.metric{r}, results.category{r}, results.question{r}, ...
        results.artist_n(r), results.artist_M(r), ...
        results.control_n(r), results.control_M(r), ...
        results.t_obs(r), results.cohens_d(r), results.p_perm(r), sig);
end

% ── Save results ──────────────────────────────────────────────────────────
writetable(results, fullfile(OUT_DIR, 'FIXEDREF_MF_group_comparison_results.csv'));
fprintf('\nResults saved to FIXEDREF_MF_group_comparison_results.csv\n');

% ── Stage 3: Summary of excluded fits ─────────────────────────────────────
if ci_available
    n_excluded_pse   = sum(~indiv.PSE_reliable   & ~isnan(indiv.PSE));
    n_excluded_slope = sum(~indiv.slope_reliable & ~isnan(indiv.slope));
    fprintf('\nExcluded due to wide CIs: PSE=%d, Slope=%d fits\n', ...
            n_excluded_pse, n_excluded_slope);
end

%% =========================================================================
%  HELPER: Two-sample permutation t-test
%  Inputs:  a, b — vectors of participant-level values (e.g. PSEs)
%           n_perm — number of permutation draws
%  Outputs: p_perm — two-tailed permutation p-value
%           t_obs  — observed Welch t-statistic
%           d      — Cohen's d (pooled SD)
%% =========================================================================

function [p_perm, t_obs, d] = permutation_ttest2(a, b, n_perm)

a = a(:); b = b(:);
na = length(a); nb = length(b);

% Observed Welch t-statistic
mean_diff = mean(a) - mean(b);
se        = sqrt(var(a)/na + var(b)/nb);
t_obs     = mean_diff / se;

% Cohen's d using pooled SD
pooled_sd = sqrt(((na-1)*var(a) + (nb-1)*var(b)) / (na+nb-2));
d         = mean_diff / pooled_sd;

% Permutation null distribution
pooled = [a; b];
n_total = na + nb;
t_perm  = zeros(1, n_perm);

for i = 1:n_perm
    idx       = randperm(n_total);
    perm_a    = pooled(idx(1:na));
    perm_b    = pooled(idx(na+1:end));
    m_diff    = mean(perm_a) - mean(perm_b);
    se_perm   = sqrt(var(perm_a)/na + var(perm_b)/nb);
    t_perm(i) = m_diff / se_perm;
end

% Two-tailed p-value
p_perm = sum(abs(t_perm) >= abs(t_obs)) / n_perm;

end
