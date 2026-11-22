clear variables ; close all ; clc

testidx = [1 779];
DB      = 'LIVE';

filename = 'CIQMznFeatures_LIVE.xlsx';
[data , OrigImgNames] = xlsread(filename,1,'E5:AA783'); 
% For CIQMz Original Model's 14 Features : use E5:T783 
% For CIQMzn Improved Model's 21 features: use E5:AA783 

load('traintest8020-LIVE.mat') % or use "splitTrainTest" function
[MOS , Features1 , imgnames, nameidx, noimg] = getdatasetdata(DB , testidx , data, OrigImgNames);
[Features, ~] = featNormalize(Features1, Features1);
itr = 1000;
parfor i=1:itr
    % [Train(:,i), Test(:,i)]  = splitTrainTest(imgnames, noimg, nameidx, 0.8);

    TrainFeatures = Features(Train(:,i),:);
    TestFeatures  = Features(Test(:,i),:);

    YTrain = MOS(Train(:,i));
    YTest  = MOS(Test(:,i));

    % Support Vector Machine Regressor SVM
    MdlSVM = fitrsvm(TrainFeatures,YTrain,'KernelFunction','rbf');

    % Predictions
    % scoretrain = performancescoressvm(MdlSVM, TrainFeatures, YTrain);
    testresults  = performancescoressvm(MdlSVM, TestFeatures, YTest);

    scoretest(i,:) = [testresults.PLCC  testresults.SRCC  testresults.rmserr ];

end

resultstest = [ median(scoretest(:,1))    std(scoretest(:,1)) % PLCC
                median(scoretest(:,2))    std(scoretest(:,2)) % SRCC
                median(scoretest(:,3))    std(scoretest(:,3)) % RMSE
                ];
PLCCt = resultstest(1,1);
Stdt  = resultstest(1,2);


%% ------------------------------------------------------------------------
function [MOS, Features, imgnames, nameidx, noimg] = getdatasetdata(DB, testidx, data, ImgNames)
switch DB
    case 'LIVE'
        idx = testidx(1,1):testidx(1,2);
        MOS = data(idx,1); Features = data(idx,2:end);
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
function score = performancescoressvm(Mdl, features, refdata)

score.pred = predict(Mdl,features);  % Matlab function
[score.PLCC, score.SRCC, score.rmserr] = performance_measures(score.pred, refdata);
end
function [PLCC, SRCC, rmserr] = performance_measures(pred, refdata)

PLCC   = round(corr(pred, refdata),4);
SRCC   = round(corr(pred, refdata, 'Type', 'Spearman'),4);
rmserr = rmse(pred, refdata);
end

