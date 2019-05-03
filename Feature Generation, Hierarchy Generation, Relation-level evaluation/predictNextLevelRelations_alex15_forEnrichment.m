function [ nextLevelRelations,nextLevelRelations_score,candidate_tag_list ] = predictNextLevelRelations_alex15_forEnrichment(model,currentLevelRelations,candidate_tag_list,taglist,ptz,pzt,pz,hm_taglist,co_occ_mat,co_occ_res_mat,freq_count_per_tag,res_count_per_tag,hm_nodelist,d_graph,minF,maxF,sim_threshold,threshold,prob_estimate)
% predict next level relations, with revised features.

% remove the predicted tags from the tag list
%candidate_tag_list = setdiff(candidate_tag_list,currentLevelRelations(:,1));

% % generate representation for candidate_tag_list
% m = size(candidate_tag_list,1);
% rep = [];
% for i=1:m
%     [vtag,~] = getvector(candidate_tag_list(i),taglist,pzt);
%     rep = [rep;vtag];
% end

random_tag_list_for_prediction = [];
m = size(currentLevelRelations,1);

for i=1:m
    i
 %num_level2=20;
 seed_tag = currentLevelRelations(i,1);
 root_tag = currentLevelRelations(i,2);
 
 [~,seed_index] = getvector(seed_tag,taglist,pzt);
 [~,root_index] = getvector(root_tag,taglist,pzt);
 %threshold = 1/size(taglist,1); % threshold as average.
 %[sim_tag_list,sim_scores] = getMostAssociatedTagsFromTwoTags(root_tag,seed_tag,taglist,ptz,pzt,pz,threshold);
 
 %[candidates,~] = getMostSimTagsFromCandidates(seed_tag,candidate_tag_list,taglist,pzt,num_level2);
 %[candidates,~] = getMostSimTagsThresholdFromCandidates(seed_tag,candidate_tag_list,taglist,pzt,sim_threshold);
 %[sim_tag_list,sim_scores] = getMostAssociatedTags(seed_tag,taglist,ptz,pzt,num_level2);
 %[sim_tag_list_root_tag,~] = getMostSimTags(root_tag,taglist,pzt,num_level1); % get the most similar tags to the root tag.
 %[sim_tag_list_root_tag,~] = getMostAssociatedTags(root_tag,taglist,ptz,pzt,num_level1);
 
 %candidates = intersect(getMostAssociatedTagsFromTwoTagsFromCandidates(seed_tag,root_tag,candidate_tag_list,taglist,ptz,pzt,pz,threshold),getMostAssociatedTagsThresholdFromCandidates(seed_tag,candidate_tag_list,taglist,ptz,pzt,threshold));
 candidates = getMostAssociatedTagsFromTwoTagsFromCandidates(seed_tag,root_tag,candidate_tag_list,taglist,ptz,pzt,pz,threshold);
 candidates = getMostAssociatedTagsThresholdFromCandidates(seed_tag,candidates,taglist,ptz,pzt,threshold); % use an intersection.
% the above two lines mean p(tag1|tag2) > threshold AND p(tag1|tag2,R) > threshold.

 %candidate_tag_list = intersect(sim_tag_list,sim_tag_list_root_tag)
 %candidate_tag_list = sim_tag_list;
 num_cand = size(candidates,1);
 num_cand_col = size(candidates,2); 
 if ((num_cand == 0) || (num_cand_col == 0))
 %if (num_cand == 0)
     continue
 end      
 seed_list=cell(num_cand,1);
 root_list=cell(num_cand,1);
 for j=1:num_cand
    seed_list(j)=taglist(seed_index);
    root_list(j)=taglist(root_index);
 end

 random_tag_list_for_prediction = [random_tag_list_for_prediction;candidates,seed_list,root_list];
end

fprintf('Candidates generated.\n');

% revised features
%feature_matrix_prediction=generateFeaturesWithRoots(random_tag_list_for_prediction,pzt,ptz,pz,taglist,p_sig_topics,overlapping_threshold);
%feature_matrix_prediction=generateRevisedFeaturesWithRoots(random_tag_list_for_prediction,pzt,ptz,pz,taglist,p_sig_topics);
feature_matrix_prediction=generateFeaturesAlex15(random_tag_list_for_prediction,hm_taglist,co_occ_mat,co_occ_res_mat,freq_count_per_tag,res_count_per_tag,hm_nodelist,d_graph);
feature_matrix_prediction=minMaxNormForTestingAndPrediction(feature_matrix_prediction,minF,maxF);

fprintf('Candidate feature generated.\n');

%% predict second-level relations
% generate training data and train the model [with feature selection]

% set_simiar_1 = zeros(1,14);
% set_simiar_1(1:4) = 1;
% set_topic_dist_2 = zeros(1,14);
% set_topic_dist_2(5:8) = 1;
% set_prob_asso_3_withonlyroot = zeros(1,14); % the probabilistic association with only root
% set_prob_asso_3_withonlyroot(12:14) = 1;
% set_all_withonlyroot = set_simiar_1 + set_topic_dist_2 + set_prob_asso_3_withonlyroot;
% set_2_3_withonlyroot = set_topic_dist_2 + set_prob_asso_3_withonlyroot;
% 
% set_to_test = set_2_3_withonlyroot; % the set to test 

m = size(feature_matrix_prediction,1)
fakeY = ones(m,1);
%prediction_data = [fakeY,feature_matrix_prediction(:,logical(set_to_test))];
prediction_data = [fakeY,feature_matrix_prediction];
outputFileName = 'prediction_data';
funOutputAsLibSVMFormat(outputFileName,prediction_data);

% read prediction_data and make prediction
[predictY, predictX] = libsvmread(['prediction_data.txt']);
[prediction,~,score] = svmpredict(predictY, predictX, model, ['-b ', num2str(prob_estimate)]);
% get next level relations and SVM predicted scores 
random_tag_list_for_prediction
prediction
nextLevelRelations = random_tag_list_for_prediction(prediction == 1,:);
nextLevelRelations_score = score(prediction == 1,:);
% rank the relations by scores in descendent order
[nextLevelRelations_score,I] = sort(nextLevelRelations_score,'descend');
nextLevelRelations = nextLevelRelations(I,:);
% prune the ranked relations
[nextLevelRelations,index_pruned] = hierarchyPruning( nextLevelRelations,currentLevelRelations );
nextLevelRelations_score = nextLevelRelations_score(index_pruned);
fprintf('Relation generated.\n');

% remove the predicted tags from the tag list
if (size(nextLevelRelations,1) > 0)
    candidate_tag_list = setdiff(candidate_tag_list,nextLevelRelations(:,1));
end

fprintf('Remaining domain tags in the list:\n');
size(candidate_tag_list,1)

end
