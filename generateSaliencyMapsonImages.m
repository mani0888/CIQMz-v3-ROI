%% Main CIQMz
clc;  close all ;  clear variables

%% Itti and Improved Itti
addpath('Itti n Improved Itti/')
%% CovSal
% options for CovSal saliency estiomation
addpath('path to CovSal Model')
options.size = 512;          % size of rescaled image
options.quantile = 1/10;     % parameter specifying the most similar regions in the neighborhood
options.centerBias = 0;      % 1 for center bias and 0 for no center bias
options.modeltype = 'SigmaPoints';
%% LDS
addpath(genpath('path to LDS Model'));
load('model.mat'); % Chose a fast model.       |
lab_pca_book = load('LAB_pca.mat');

RGB = imread('ZJU_30.jpg');
sz = size(RGB);
if sz(1)>1920 || sz(2)>1920
    if sz(1)>=sz(2)
        rszf =  1920/sz(1);
    elseif sz(1)<sz(2)
        rszf =  1920/sz(2);
    end
    RGB = imresize(RGB,rszf);
    sz = size(RGB);
end

%% ---------------------------------------------------
% Visual Saliency Models
%-----------------------------------------------------
% Itti & Improved Itti
image = (RGB-min(RGB(:)))/(max(RGB(:))-min(RGB(:)));
[saliencyMap_Itti, saliencyMap_IttiImpr] = ittiSaliency_changed(double(image));
saliencyMap = saliencyMap_Itti;
% saliencyMap = saliencyMap_IttiImpr;
%-----------------------------------------------------
% CovSal
% saliencyMap = saliencymap(RGB, options);
%-----------------------------------------------------
% LDS
% saliencyMap = GetSaliencyMap(RGB,x,lab_pca_book);
%-----------------------------------------------------

mx = max(saliencyMap(:));
% Normalize the saliency map for ROI/Non-ROI division
saliencyMap = saliencyMap / mx; % Normalize to 0-1

% ROI / nROI masks
ROI_mask = (saliencyMap > mean(saliencyMap(:))); % for Itti, Improved Itti and CovSal
% ROI_mask = (saliencyMap > 0.5*mean(saliencyMap(:))); % for LDS and EML-NET

ROI_mask = logical(ROI_mask);
nROI_mask = ~ROI_mask;

RGB_ROI = RGB.*uint8(ROI_mask);
figure(), imshow((RGB_ROI))
RGB_nROI = RGB.*uint8(nROI_mask);
figure(), imshow((RGB_nROI))