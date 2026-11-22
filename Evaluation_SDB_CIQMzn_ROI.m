clear variables ; close all ; clc

% addpath('F:\Studies Backup\PhD Work\2. SVM Codes\Matlab SVM')
IQM     = {'CIQMznFeatures_LIVE' };
testidx = [1 779];
DB      = 'LIVE';
% for x = 1
filename = 'CIQMznFeatures_LIVE.xlsx';
[data , OrigImgNames] = xlsread(filename,1,'E5:AV783');
load('traintest8020-LIVE.mat') % or use "splitTrainTest" function

nooffeatures = 21;
[MOS , FeaturesROI1, FeaturesnROI1, imgnames, nameidx, noimg] = getdatasetdataROI(DB , testidx , data, OrigImgNames, nooffeatures);
[FeaturesROI,  ~] = featNormalize(FeaturesROI1, FeaturesROI1);
[FeaturesnROI, ~] = featNormalize(FeaturesnROI1, FeaturesnROI1);
len = length(MOS);
itr = 1000;
parfor i=1:itr
    % i
    % [Train(:,i), Test(:,i)] = splitTrainTest(imgnames, noimg, nameidx , 0.8);
    TrainFeaturesROI  = FeaturesROI(Train(:,i),:);
    TrainFeaturesnROI = FeaturesnROI(Train(:,i),:);
    YTrain = MOS(Train(:,i));

    predTrainROI_CV  = getTrainCVPredictions(TrainFeaturesROI, YTrain, 5);
    predTrainnROI_CV = getTrainCVPredictions(TrainFeaturesnROI, YTrain, 5);

    n_opt(i,1) = estimateFusionWeight(predTrainROI_CV, predTrainnROI_CV, YTrain);

    [~, scoretestROI]  = calculateIQScores(FeaturesROI , MOS, Train, Test, i);
    [~, scoretestnROI] = calculateIQScores(FeaturesnROI, MOS, Train, Test, i);

    pred_IQt = n_opt(i,1) * scoretestROI.pred + (1 - n_opt(i,1)) * scoretestnROI.pred;
    [PLCC, SRCC, rmserr] = performance_measures(pred_IQt, MOS(Test(:,i)));
    rtest(i,:) = [PLCC, SRCC, rmserr];

end
resultstest = [ median(rtest(:,1))    std(rtest(:,1)) % PLCC
                median(rtest(:,2))    std(rtest(:,2)) % SRCC
                median(rtest(:,3))    std(rtest(:,3)) % RMSE
                ];
PLCCt = resultstest(1,1);
Stdt  = resultstest(1,2);


function [MOS, FeaturesROI, FeaturesnROI, imgnames, nameidx, noimg] = getdatasetdataROI(DB , testidx , data, ImgNames, dataidx)
switch DB
    case 'LIVE'
        idx = testidx(1,1):testidx(1,2);
        MOS = data(idx,1);
        FeaturesROI= data(idx,2:dataidx+1); FeaturesnROI = data(idx,dataidx+2:end);
        imgnames = ImgNames( idx ,1);
        nameidx=2:3; noimg = 29;
end
end
function [trainX, testX] = featNormalize(trainX, testX)
minimums = min(trainX, [], 1);
ranges = max(trainX, [], 1) - minimums;

trainX = (trainX - repmat(minimums, size(trainX, 1), 1)) ./ repmat(ranges, size(trainX, 1), 1);

testX = (testX - repmat(minimums, size(testX, 1), 1)) ./ repmat(ranges, size(testX, 1), 1);

trainX(isnan(trainX))=0;
testX(isnan(testX))=0;
end

function [scoretrain, scoretest] = calculateIQScores(Features, MOS, Train, Test, i)

TrainFeatures = Features(Train(:,i),:);
TestFeatures  = Features(Test(:,i),:);

YTrain = MOS(Train(:,i));
YTest  = MOS(Test(:,i));

% Support Vector Machine Regressor SVM
MdlSVM = fitrsvm(TrainFeatures,YTrain,'KernelFunction','rbf');

% Predictions
scoretrain = performancescoressvm(MdlSVM, TrainFeatures, YTrain);
scoretest  = performancescoressvm(MdlSVM, TestFeatures, YTest);

end
function score = performancescoressvm(Mdl, features, refdata)

score.pred = predict(Mdl,features);  % Matlab function
[score.PLCC, score.SRCC, score.rmserr] = performance_measures(score.pred, refdata);
end
function [PLCC, SRCC, rmserr] = performance_measures(pred, refdata)

PLCC   = round(corr(pred, refdata),4);
SRCC   = round(corr(pred, refdata, 'Type', 'Spearman'),4);
rmserr = rmse(pred, refdata);
end

function predCV = getTrainCVPredictions(FeaturesTrain, YTrain, K)
cv = cvpartition(length(YTrain), 'KFold', K);
predCV = zeros(size(YTrain));
for f = 1:K
    idxTr = training(cv, f);
    idxVal = test(cv, f);

    mdl = fitrsvm(FeaturesTrain(idxTr,:), YTrain(idxTr), 'KernelFunction', 'rbf');
    predCV(idxVal) = predict(mdl, FeaturesTrain(idxVal,:));
end
end

function n_opt = estimateFusionWeight(predROI, prednROI, YTrain)
n_candidates = 0:0.01:1;
bestPLCC = -inf;
n_opt = 0.5;
for k = 1:length(n_candidates)
    n = n_candidates(k);
    predFuse = n * predROI + (1 - n) * prednROI;
    [PLCC, ~, ~] = performance_measures(predFuse, YTrain);
    if ~isnan(PLCC) && PLCC > bestPLCC
        bestPLCC = PLCC;
        n_opt = n;
    end
end
end

function [Train,Test] = splitTrainTest(names,noim,idx,splitratio)

numberOfImages = size(names,1);
Train = false(numberOfImages,1);
Test  = false(numberOfImages,1);

p = randperm(noim);
tr = round(splitratio*noim);
train = p(1:tr);

for i=1:numberOfImages
    name = names{i};
    tmp = char(name);
    tmp = str2double(tmp(idx));
    if( ismember(tmp,train) )
        Train(i)=true;
    else
        Test(i)=true;
    end
end

end