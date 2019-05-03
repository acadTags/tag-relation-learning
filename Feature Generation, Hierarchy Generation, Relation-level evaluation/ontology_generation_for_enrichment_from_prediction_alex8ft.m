% ontology generation for enrichment from prediction
%clearvars
% load seed-tags-to-predict for enrichment
%load('seed_tags_to_predict_acm_2.mat')
%seed_tags_with_root = seed_tags_to_predict_acm_2;
%load('seed_tags_to_predict_dbpedia_CS_IS_5.mat')
%seed_tags_with_root = seed_tags_to_predict_dbpedia_CS_IS_5;

load('taglist_tf.mat')
taglist=taglist_tf(:,1);
load('pzt_new_count_based.mat')
load('pz_new_count_based.mat')
pz = pz';
load('ptz.mat')
T = size(ptz,1);

sim_threshold = 0.1;
threshold = 0.001; % for selecting the most associated tags.
%threshold = 1/size(taglist,1); % for selecting the most associated tags.
%threshold = 10/size(taglist,1); % for selecting the most associated tags.
freq_threshold = 1; % select tags appeared no less than 3 times.

num_stop=10; % number of most similar tags to search for further levels from all "num" tags.

% paremeter for feature generation, should not change.
p_sig_topics = 1/T;
overlapping_threshold=0.8;

%% model training
% parameter for training and prediction
% also specify min-max parameters for feature normalisation
%load("bibsonomy_hier_instances_features_18ft_final.mat")
load("bibsonomy_hier_instances_features_alex8ft_final.mat"); % cosine as criteria
%load('bibsonomy_hier_asso_instances_features_alex8ft_final.mat'); % prob-asso as criteria
clear cell;
%load('bibsonomy_hier_instances_features_14ft_ori_final.mat')
fileNameSuffix = 'data';
outputNameSuffix = 'alex8ft_final';
prob_estimate = false;
cvalue = 2^10;
gammavalue = 2^7;
weight = 1;

% generate training and testing files from the feature matrices.
label_training(label_training == 2) = -1;
training_data = [label_training,feature_matrix]; % this is min-maxed.
outputFileName = 'trainingdata';
funOutputAsLibSVMFormat(outputFileName,training_data);

label_validation(label_validation == 2) = -1;
testing_data = [label_validation,feature_matrix_validation];
outputFileName = 'testingdata';
funOutputAsLibSVMFormat(outputFileName,testing_data);

% generate training data and train the model
% using the whole data: both train and test to retrain the model for prediction.
[trainY, trainX] = libsvmread(['training',fileNameSuffix,'.txt']);
[testY, testX] = libsvmread(['testing',fileNameSuffix,'.txt']);
final_trainY = [trainY;testY];
final_trainX = [trainX;testX]; 

param = ['-c ', num2str(cvalue), ' -g ', num2str(gammavalue), ' -w1 ', num2str(weight), ' -w-1 1 -b ', num2str(prob_estimate), ' -h 0'];
model = svmtrain(final_trainY, final_trainX, param);
[~,ret,~] = do_binary_predict(final_trainY, final_trainX, model);

%% model prediction
num_seeds = size(seed_tags_with_root,1);
for ith_tag = 1:num_seeds
    %% Candidate and feature generation for 1st level data
    % generating candidates
    tag1 = lower(seed_tags_with_root{ith_tag,1});
    tag2 = lower(seed_tags_with_root{ith_tag,2});
    [~,seed_index] = getvector(tag1,taglist,pzt);
    [~,root_index] = getvector(tag2,taglist,pzt);

    %   candidates as most similar or associated tags
    %[sim_tag_list,sim_scores] = getMostSimTagsWithFrequencyThreshold(tag1,taglist_tf,pzt,sim_threshold,freq_threshold);
    %%[sim_tag_list,~] = getTopicalOverlappedTags(seed_tag,taglist_tf,pzt,p_sig_topics,freq_threshold);
    if (not(strcmp(tag1,tag2)))
        [sim_tag_list,sim_scores] = intersect(getMostAssociatedTagsFromTwoTags(tag1,tag2,taglist,ptz,pzt,pz,threshold),getMostAssociatedTagsThreshold(tag1,taglist,ptz,pzt,threshold));
    else
        [sim_tag_list,sim_scores] = getMostAssociatedTagsThreshold(tag1,taglist,ptz,pzt,threshold);
    end    
    candidate_tag_list = sim_tag_list;
    file_name_ending = '_from_all_tags.csv';

    num = size(candidate_tag_list,1);
    
    seed_list=cell(num,1);
    root_list=cell(num,1);
    for j=1:num
        seed_list(j)=taglist(seed_index);
        root_list(j)=taglist(root_index);
    end
    random_tag_list_for_prediction = [candidate_tag_list,seed_list,root_list];

    level=1;
    fprintf('Level %d\n',level);
    fprintf('Candidates generated.\n');

    % generating [revised] features
    %feature_matrix_prediction=generateFeaturesWithRoots(random_tag_list_for_prediction,pzt,ptz,pz,taglist,p_sig_topics,overlapping_threshold);
    %feature_matrix_prediction=generateRevisedFeaturesWithRoots(random_tag_list_for_prediction,pzt,ptz,pz,taglist,p_sig_topics);
    feature_matrix_prediction=generateFeaturesAlex15(random_tag_list_for_prediction,hm_taglist,co_occ_mat,co_occ_res_mat,freq_count_per_tag,res_count_per_tag,hm_nodelist,d_graph);
    feature_matrix_prediction=minMaxNormForTestingAndPrediction(feature_matrix_prediction,minF,maxF);

    fprintf('Candidate feature generated.\n');

    %% prediction and training for 1st level data

    m = size(feature_matrix_prediction,1)
    fakeY = ones(m,1);
    %prediction_data = [fakeY,feature_matrix_prediction(:,logical(set_to_test))];
    prediction_data = [fakeY,feature_matrix_prediction];
    outputFileName = 'prediction_data';
    funOutputAsLibSVMFormat(outputFileName,prediction_data);

    % read prediction_data and make prediction
    [predictY, predictX] = libsvmread(['prediction_data.txt']);
    delete prediction_data.txt % delete the file once used
    [prediction,~,score] = svmpredict(predictY, predictX, model, ['-b ', num2str(prob_estimate)]);

    % generate and output first level relations
    first_level_relations = random_tag_list_for_prediction(prediction == 1,:);
    first_level_relations_score = score(prediction == 1,:);
    %cell2csv([tag1 '_lvl_' num2str(level) '.csv'],[first_level_relations num2cell(first_level_relations_score)]);

    candidate_tag_list = setdiff(candidate_tag_list,tag1);
    candidate_tag_list = setdiff(candidate_tag_list,tag2);
    candidate_tag_list = setdiff(candidate_tag_list,first_level_relations(:,1));

    fprintf('Relations generated.\n');

    % generate 2nd and further level relations 
    all_relations = [first_level_relations num2cell(first_level_relations_score)]; % for storing all relations;

    current_level_relations = first_level_relations;

    while (size(candidate_tag_list,1)>=num_stop)
        level = level+1;
        fprintf(['Level_',num2str(level),'\n']);
        [ next_level_relations,next_level_relations_score,candidate_tag_list ] = predictNextLevelRelations_alex15_forEnrichment(model,current_level_relations,candidate_tag_list,taglist,ptz,pzt,pz,hm_taglist,co_occ_mat,co_occ_res_mat,freq_count_per_tag,res_count_per_tag,hm_nodelist,d_graph,minF,maxF,sim_threshold,threshold,prob_estimate);
        if (size(next_level_relations,1) == 0)
            break;
        end
        %cell2csv([tag1 '_lvl_' num2str(level) '.csv'],[next_level_relations num2cell(next_level_relations_score)]);
        current_level_relations=next_level_relations;
        all_relations = [all_relations; [next_level_relations num2cell(next_level_relations_score)]];
    end
    
    %cd 'LO'
    cell2csv([tag1 ' ' outputNameSuffix '_' num2str(log2(cvalue)) '_' num2str(log2(gammavalue)) file_name_ending],all_relations(:,1:2));
    %cd ..
    disp(['tag-seed-' num2str(ith_tag) '-' tag1 '-done']);
end