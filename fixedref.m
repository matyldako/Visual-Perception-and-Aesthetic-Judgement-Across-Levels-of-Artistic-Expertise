%% Fixed-Reference Cross-Category Preference Analysis
%  Uses ONLY trials where the reference was object image 7 (RTp==2, col 3 of ResFile)
%  This puts all four categories on a common measuring scale.
%
%  ResFile columns (0-indexed in Python, 1-indexed here):
%    col 1: StimNo     (1-6, which test image)
%    col 2: StimType   (1=Face/Flower, 2=Object/Bug)
%    col 3: RefType    (1=Refa face/flower ref, 2=Refb object ref) <-- filter on this
%    col 4: QuesCond   (1=Skill, 2=Beauty, 3=Symmetry)
%    col 7: testRes    (1=test chosen, 0=reference chosen)
%
%  Image ID mapping (using StimulusInfo fields):
%    FO block, StimType==1: CONDA_faceStimSelectedTestINDX   -> face image IDs
%    FO block, StimType==2: CONDB_objectStimSelectedTestINDX -> object image IDs
%    FB block, StimType==1: CONDC_flowerStimSelectedTestINDX -> flower image IDs
%    FB block, StimType==2: CONDD_bugStimSelectedTestINDX    -> bug image IDs

clear; clc; close all;

%% 0. Paths and constants
DATA_DIR  = '/Users//Desktop/DATA_DISS/AllData';
OUT_DIR   = '/Users//Desktop/DATA_DISS/other';
if ~exist(OUT_DIR,'dir'), mkdir(OUT_DIR); end

ART_COL  = [0.20, 0.45, 0.75];
CTRL_COL = [0.85, 0.45, 0.00];

CATS     = {'Face','Object','Flower','Bug'};
QNAMES   = {'Skill','Beauty','Symmetry'};
GROUPS   = {'Artist','Control'};

REF_TYPE_FIXED = 2;   % column 3 value for object reference (Refb = object image 7)

%% 1. Load participant files
matFiles = dir(fullfile(DATA_DIR, '*_AesSymPer_*.mat'));
seen = containers.Map();
participants = struct('pid',{},'group',{},'FO',{},'FB',{});

for i = 1:length(matFiles)
    fpath = fullfile(DATA_DIR, matFiles(i).name);
    data  = load(fpath, 'S');
    S     = data.S;
    pid   = strtrim(S.ParticipantAndTaskInfo.PartID);
    if isKey(seen, pid), continue; end
    seen(pid) = true;
    if startsWith(pid,'A') || strcmp(pid,'S11')
        grp = 'Artist';
    else
        grp = 'Control';
    end
    participants(end+1).pid   = pid;
    participants(end).group   = grp;
    participants(end).FO      = S.AestheticJudgmentTask.FaceObject;
    participants(end).FB      = S.AestheticJudgmentTask.FlowerBug;
end
fprintf('Loaded %d participants\n', length(participants));

%% 2. Extract P(test chosen | object reference) per image, category, question
%  Block definitions: {cat_name, block_field, StimType_code, ImageID_field}
BLOCKS = {
    'Face',   'FO', 1, 'CONDA_faceStimSelectedTestINDX';
    'Object', 'FO', 2, 'CONDB_objectStimSelectedTestINDX';
    'Flower', 'FB', 1, 'CONDC_flowerStimSelectedTestINDX';
    'Bug',    'FB', 2, 'CONDD_bugStimSelectedTestINDX';
};

% Store: rows = participants, per entry = struct with P per image per question
all_data = {};   % {pid, group, cat, question, image_id, P, n_trials}

for p = 1:length(participants)
    pp = participants(p);
    for b = 1:size(BLOCKS,1)
        cat_name  = BLOCKS{b,1};
        blk_field = BLOCKS{b,2};
        stim_code = BLOCKS{b,3};
        id_field  = BLOCKS{b,4};

        if strcmp(blk_field,'FO')
            task = pp.FO;
        else
            task = pp.FB;
        end

        rf  = double(task.ResponseFileFull);   % N x 8
        ids = double(task.StimulusInfo.(id_field));  % image IDs for this category

        % Filter: correct StimType AND object reference only
        mask = (rf(:,2) == stim_code) & (rf(:,3) == REF_TYPE_FIXED);

        for q = 1:3
            q_mask = mask & (rf(:,4) == q);
            for img_idx = 1:length(ids)
                img_mask = q_mask & (rf(:,1) == img_idx);
                n = sum(img_mask);
                if n == 0, continue; end
                P = sum(rf(img_mask,7)) / n;
                all_data(end+1,:) = {pp.pid, pp.group, cat_name, ...
                    QNAMES{q}, ids(img_idx), P, n};
            end
        end
    end
end

T = cell2table(all_data, 'VariableNames', ...
    {'pid','group','category','question','image_id','P','n_trials'});
writetable(T, fullfile(OUT_DIR, 'fixed_ref_P_per_image.csv'));
fprintf('Saved per-image P table: %d rows\n', height(T));

%% 3. Signed rank assignment per participant x category x question
%  Same logic as RQ2: sort by P, assign ranks -n..-1, 0, +1..+n
rank_rows = {};

for p = 1:length(participants)
    pid = participants(p).pid;
    grp = participants(p).group;
    for b = 1:size(BLOCKS,1)
        cat_name = BLOCKS{b,1};
        for q = 1:3
            sub = T(strcmp(T.pid,pid) & strcmp(T.category,cat_name) & ...
                    strcmp(T.question,QNAMES{q}), :);
            if height(sub) < 2, continue; end

            % Sort ascending by P
            sub = sortrows(sub, 'P');
            below = sub(sub.P <  0.5,:);
            above = sub(sub.P >  0.5,:);
            equal = sub(sub.P == 0.5,:);

            % Assign ranks
            for j = 1:height(below)
                rk = -(height(below) - j + 1);
                rank_rows(end+1,:) = {pid, grp, cat_name, QNAMES{q}, ...
                    below.image_id(j), rk, below.P(j)};
            end
            for j = 1:height(equal)
                rank_rows(end+1,:) = {pid, grp, cat_name, QNAMES{q}, ...
                    equal.image_id(j), 0, equal.P(j)};
            end
            for j = 1:height(above)
                rank_rows(end+1,:) = {pid, grp, cat_name, QNAMES{q}, ...
                    above.image_id(j), j, above.P(j)};
            end
        end
    end
end

R = cell2table(rank_rows, 'VariableNames', ...
    {'pid','group','category','question','image_id','rank','P'});
writetable(R, fullfile(OUT_DIR, 'fixed_ref_signed_ranks.csv'));

%% 4. Compute group mean signed rank per image per category per question
fig = figure('Color','w','Position',[50 50 1400 900]);
n_cats = 4; n_qs = 3;
sp = 0;

for b = 1:n_cats
    cat_name = CATS{b};
    for q = 1:n_qs
        sp = sp + 1;
        ax = subplot(n_cats, n_qs, sp);
        hold(ax,'on');

        sub = R(strcmp(R.category,cat_name) & strcmp(R.question,QNAMES{q}),:);
        all_img_ids = unique(sub.image_id);

        for g = 1:2
            grp = GROUPS{g};
            col = ART_COL; if g==2, col = CTRL_COL; end
            gsub = sub(strcmp(sub.group,grp),:);

            img_ids_g  = unique(gsub.image_id);
            mean_ranks = NaN(size(img_ids_g));
            sem_ranks  = NaN(size(img_ids_g));

            for ii = 1:length(img_ids_g)
                img_sub = gsub(gsub.image_id == img_ids_g(ii),:);
                mean_ranks(ii) = mean(img_sub.rank);
                sem_ranks(ii)  = std(img_sub.rank) / sqrt(height(img_sub));
            end

            errorbar(ax, img_ids_g, mean_ranks, sem_ranks, ...
                '-o','Color',col,'MarkerFaceColor',col,...
                'MarkerSize',5,'LineWidth',1.2,'CapSize',3,...
                'DisplayName',grp);
        end

        yline(ax, 0, '--', 'Color',[0.5 0.5 0.5],'LineWidth',0.8,...
            'HandleVisibility','off');
        set(ax,'Box','off','TickDir','out','FontSize',9);
        title(ax, sprintf('%s — %s', cat_name, QNAMES{q}),'FontSize',10);
        xlabel(ax,'Image ID');
        ylabel(ax,'Mean signed rank');

        if sp == 1
            legend(ax,'Location','northwest','Box','off','FontSize',8);
        end
        hold(ax,'off');
    end
end

sgtitle('Mean signed rank per image (fixed object reference, all categories)', ...
    'FontSize',12,'FontWeight','bold');

saveas(fig, fullfile(OUT_DIR,'fixed_ref_image_profiles.png'));
saveas(fig, fullfile(OUT_DIR,'fixed_ref_image_profiles.pdf'));
fprintf('Saved figure to %s\n', OUT_DIR);
