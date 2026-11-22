clear; 
close all; clc;

% Reference: Itti, L., C. Koch, e E. Niebur. «A model of saliency-based
% visual attention for rapid scene analysis». IEEE Transactions on Pattern
% Analysis and Machine Intelligence 20, n. 11 (novembre 1998): 1254–59.
% https://doi.org/10.1109/34.730558.

% Code Author: Osvaldo Pulpito
% Email: osvaldopulpito@gmail.com
% Date: 19/10/2021

%% Image loading

% image = double(imread('bunny.png')); % boat.jpg  bunny.png  road.jpg
image = double(imread('bunny.png')); % boat.jpg  bunny.png  road.jpg

imsize = [480 640]; % size(image,[1 2]); %[480 640];
image = imresize(image,imsize);
image = (image-min(image(:)))/(max(image(:))-min(image(:)));

tic

[saliencyCoord,saliencyMap,conspI,conspC,conspOr,CSI,RG,BY,orientationMaps,I,R,G,B,Y] = ittiSaliency(image);

time = toc

%% Figures
% 
% figure
% imagesc(image)
% set(gcf, 'Units', 'Normalized', 'OuterPosition', [0 0 1 1]);
% set(gcf, 'Toolbar', 'none', 'Menu', 'none');
% set(gcf, 'Name', 'original image', 'NumberTitle', 'Off') 

nOfSaliencies = size(saliencyCoord,2);
map = zeros(imsize);
for i=1:nOfSaliencies
    col = saliencyCoord{1,i}(1);
    row = saliencyCoord{1,i}(2);
    map(col,row) = 1/nOfSaliencies*(nOfSaliencies-i+1);
end
filtWindow = circFilter(min(imsize)/3);
map = conv2(map,filtWindow,'same');
map = map/max(map(:));

figure
imagesc(image)
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0 0 1 1]);
set(gcf, 'Toolbar', 'none', 'Menu', 'none');
set(gcf, 'Name', 'Focus of Attention points on image', 'NumberTitle', 'Off') 
hold on
imagesc(map,'alphaData',.5)
colormap turbo
colorbar

%% Functions
function [varargout] = ittiSaliency(input)
% [saliencyCoord,saliencyMap,conspI,conspC,conspOr,CSI,RG,BY,orientationMaps,I,R,G,B,Y] = ittiSaliency(image);
% Computes the all process described in the rerence article:
% 1. Devides the input image in I,R,G,B and Y channels as described in
%    par. 2.1
% 2. Computes the center-surround operation on the Intensity channel and
%    the RG and BY double opponencies as described in par 2.1
% 3. Computes the 4 orientation center-surround operation as described
%    in par 2.1
% 4. Produces the conspicuity maps of intensity, color and orientation
%    as described in par 2.2
% 5. Produces the saliency map as described in par 2.2
% 6. Extracts the saliency points with the Winner-Take-All and Inibition of
%    Return strategy proposed in par 2.2 - Note: This is just my 
%    interpretation of the WTA section. It is not based on the leaky
%    integrate-and-fire neuron model. I could not find any implementation
%    of this kind of model. Please, let me know if it looks correct to you
%    or if you got any suggestion or if you have the correct version of the
%    model proposed by Itti et al.

%% Channel division

[I,R,G,B,Y] = channels(input);

%% Center-Surround operation on the intensity channel

CSI = gaussianCenterSurround(I,I);

%% RG and BY opponency

RG = gaussianCenterSurround(R-G,G-R); 
BY = gaussianCenterSurround(B-Y,Y-B);

%% orientation maps

orientationMaps = gaborCenterSurround(I,4);

%% Conspicuity maps

conspI = conspicuityInt(CSI,1);
conspC = conspicuityCol(RG,BY,1);
conspOr = conspicuityOr(orientationMaps,1);

%% Overall saliency map

saliencyMap = mixedConsp(conspI,conspC,conspOr,1);

%% A Winner-Take-All implementation

saliencyCoord = winnerTakeAll(saliencyMap,true);

%% Outputs
varargout{1} = saliencyCoord;
varargout{2} = saliencyMap;
varargout{3} = conspI;
varargout{4} = conspC;
varargout{5} = conspOr;
varargout{6} = CSI;
varargout{7} = RG;
varargout{8} = BY;
varargout{9} = orientationMaps;
varargout{10} = I;
varargout{11} = R;
varargout{12} = G;
varargout{13} = B;
varargout{14} = Y;

end

function [I,R,G,B,Y] = channels(input)
%[I,R,G,B,Y] = channels(input)
% produces the intensity I map and the R,G,B and Y channels of the input
% image
I = (input(:,:,1)+input(:,:,2)+input(:,:,3))/3;
maxI = max(I(:));
r = (I>maxI/10).*input(:,:,1)./I;
g = (I>maxI/10).*input(:,:,2)./I;
b = (I>maxI/10).*input(:,:,3)./I;
R = r-(g+b)/2;
R = R.*(R>0);
G = g-(r+b)/2;
G = G.*(G>0);
B = b-(r+g)/2;
B = B.*(B>0);
Y = (r+g)/2-abs(r-g)/2-b;
Y = Y.*(Y>0);
end

function output = gaussianCenterSurround(input1,input2)
% compute the gaussian pyramid based center-surround operation between the
% input1 and the input 2;
% the inputs must be of the same size
center = gaussianPyramid(input1,4);
surround = gaussianPyramid(input2,8);
for c=2:4
    for delta=3:4
        centerSize = size(center{c},1,2);
        surroundResize = imresize(surround{c+delta},centerSize);
        output{2*c+delta-6} = abs(center{c}-surroundResize);
    end
end
end
function output = gaussianPyramid(input,l)
% output = gaussianPyramid(input,l)
% compute the l-th level gassian pyramid of the input, where l=0 is the
% base image, l=1 is the first reduction, etc...
output{1} = input;
for i=1:l-1
    output{i+1} = impyramid(output{i},'reduce');
end
end

function output = gaborCenterSurround(input,nOfDir)
% output = gaborCenterSurround(input,nOfDir)
% compute the gabor pyramid based center-surround operation of the input in
% nOfDir numbers of directions equally dinstributed between 0 and 180°
[surroundMag, surroundPhase] = gaborPyramid(input,8,nOfDir);
centerMag = surroundMag;
centerPhase =  surroundPhase;
for j=1:nOfDir
    for c=2:4
        for delta=3:4
            reCenter = centerMag{j,c}.*cos(centerPhase{j,c});
            imCenter = centerMag{j,c}.*sin(centerPhase{j,c});
            reSurround = surroundMag{j,c+delta}.*cos(surroundPhase{j,...
                c+delta});
            imSurround = surroundMag{j,c+delta}.*sin(surroundPhase{j,...
                c+delta});
            reOutput = reCenter-reSurround;
            imOutput = imCenter-imSurround;
            output{j,2*c+delta-6} = sqrt(reOutput.^2+imOutput.^2);
        end
    end
end
end
function [outputMag, outputPhase] = gaborPyramid(input,l,nOfDir)
% [outputMag, outputPhase] = gaborPyramid(input,l,nOfDir)
% compute the l-th level gabor pyramid of the input, where l=0 is the
% base image, l=1 is the first reduction, etc... while nOfDir is the number
% of directions if interest equally dinstributed between 0 and 180°
for j=1:nOfDir
    outputMag{j,1} = input;
    for i=1:l-1
        theta = round(180/nOfDir*(j-1));
        [mag, phase] = imgaborfilt(input,2^i,theta);
        outputMag{j,i+1} = mag;
        outputPhase{j,i+1} = phase;
    end
end
end

function output = conspicuityInt(input,M)
% output = conspicuityInt(input,M)
% produces the intensity conspicuity map of the intensity center-surround
% maps in input
% M is the normalization value according to the normalization function
% proposed by Itti et al.
inputNorm = mapNormalization(input,M);
[nOfMaps] = size(inputNorm,2);
[hScale4,wScale4] = size(inputNorm{end,end});
output = zeros(hScale4,wScale4);
for i=1:nOfMaps
    mapResize = imresize(inputNorm{1,i},[hScale4 wScale4]);
    output = output+mapResize;
end
end
function output = conspicuityCol(RG,BY,M)
% output = conspicuityCol(RG,BY,M)
% produces the color conspicuity map of the RG and BY center-surround maps 
% in input 
% M is the normalization value according to the normalization function
% proposed by Itti et al.

% Reference: Itti, L., C. Koch, e E. Niebur. «A model of saliency-based
% visual attention for rapid scene analysis». IEEE Transactions on Pattern
% Analysis and Machine Intelligence 20, n. 11 (novembre 1998): 1254–59.
% https://doi.org/10.1109/34.730558.

% Code Author: Osvaldo Pulpito
% Email: osvaldopulpito@gmail.com
% Date: 19/10/2021

input1Norm = mapNormalization(RG,M);
input2Norm = mapNormalization(BY,M);
[nOfMaps] = size(input1Norm,2);
[hScale4,wScale4] = size(input1Norm{end,end});
output = zeros(hScale4,wScale4);
for i=1:nOfMaps
    mapResize1 = imresize(input1Norm{1,i},[hScale4 wScale4]);
    mapResize2 = imresize(input2Norm{1,i},[hScale4 wScale4]);
    output = output+mapResize1+mapResize2;
end
end
function output = conspicuityOr(input,M)
% output = conspicuityOr(input,M)
% produces the orientation conspicuity map of the orientation 
% center-surround maps in input
% M is the normalization value according to the normalization function
inputNorm = mapNormalization(input,M);
[nOfDir,nOfMaps] = size(inputNorm);
[hScale,wScale] = size(inputNorm{end,end});
output = zeros(hScale,wScale);
for j=1:nOfDir
    temp = zeros(hScale,wScale);
    for i=1:nOfMaps
        temp = temp+inputNorm{j,i};
    end
    output = output+singleMapNormalization(temp,M);
end
output = imresize(output,1/2^(4-1));
end
function output = mixedConsp(conspI,conspC,conspOr,M)
% output = ittiSaliency(conspI,conspC,conspOr,M)
% produces the overall saliency map by averaging the intensity, color and
% orientation conspicuity maps
% M is the normalization value according to the normalization function
conspINorm = singleMapNormalization(conspI,M);
conspCNorm = singleMapNormalization(conspC,M);
conspOrNorm = singleMapNormalization(conspOr,M);
output = 1/3*(conspINorm+conspCNorm+conspOrNorm);
end
function output = mapNormalization(input,M)
% output = mapNormalization(input,M)
% normalizes the input set of maps by:
% - normalizing them from 0 to M;
% - assigning to a variable m the average local maxima (excluded M);
% - normalizing again in a range from 0 to (M-m)^2
[nOfMapsI,nOfMapsJ] = size(input);
for i=1:nOfMapsI
    for j=1:nOfMapsJ
        map = input{i,j};
        output{i,j} = singleMapNormalization(map,M);
    end
end
end
function output = singleMapNormalization(input,M)
% normalizes the input map by:
% - normalizing it from 0 to M;
% - assigning to a variable m the average local maxima (excluded M);
% - normalizing again in a range from 0 to (M-m)^2
dynamicLimited = (input-min(input(:)))./(max(input(:))-min(input(:))).*M;
noGlobalMax = dynamicLimited.*(dynamicLimited<M);
localMaxima = nonzeros(noGlobalMax.*islocalmax(noGlobalMax));
m = mean(localMaxima);
output = dynamicLimited*(M-m)^2;
end

function [saliencyCoord] = winnerTakeAll(saliencyMap,varargin)
% saliencyCoord = winnerTakeAll(saliencyMap,nOfSaliencies,isItti)

% Gives as output the most salient points coordinates according to the 
% saliencyMap in input. At each iteration, the region surrounding the 
% selected point is inibited by setting to zero a number of pixel of the
% saliency map (see inibitionOfReturn function). Further, if the 
% saliencyMap comes from the Itti et al. strategy, (isItti flag set to 
% true) we know that its dimensions have to be reset to (2^3)x as the maps
% are based on the 3rd level of the gaussian/gabor pyramid.

% Note: This is just my interpretation of the WTA section. It is not based
% on the leaky integrate-and-fire neuron model. I could not find any
% implementation of this kind of model. Please, let me know if it looks
% correct to you or if you got any suggestion or if you have the correct
maxSaliency = max(saliencyMap(:));
i = 1;
while max(saliencyMap(:))>.75*maxSaliency
    bwMap = saliencyMap==max(saliencyMap(:));
    [row,col] = find(bwMap,1);
    saliencyMap = inibitionOfReturn(saliencyMap,[row,col]); % it sets a
    % region surrounding the selected saliency to zero in order to avoid
    % returns
    saliencyCoord{1,i} = [row,col];
    % filtWindow = circFilter(1+1*level);
    % saliencyMap = conv2(saliencyMap,filtWindow,'same'); % it filters the
    % saliency map with a circular filter with growing dimensions. This 
    % step helps moving the attention towards other regions of the image
    i = i+1;
end
if (nargin==2) && (varargin{1}==true)
    for j=1:i-1
        saliencyCoord{j} = saliencyCoord{j}*2^3; % reset the coordinate to
        % the original dimensions of the image
    end
end
end
function output = inibitionOfReturn(input,previousWinner)
% output = inibitionOfReturn(input,previousWinner)
% Sets the pixel near the previousWinner coordinates to zero in order to
% avoid returns in the next iteration.
[w,h] = size(input);
r = min(w,h)/10;
x = 1:w;
y = 1:h;
X = repmat(x',1,h);
Y = repmat(y,w,1);
rho = sqrt((X-previousWinner(1)).^2+(Y-previousWinner(2)).^2);
output = input.*(rho>r);
end

function filter = circFilter(d)
% filter = circFilter(d)
% Produces a circular filtering window of diameter d and weight that
% decreases from the center to the borders
Y = repmat(1:d,d,1);
rho = sqrt((Y'-(d+1)/2).^2+(Y-(d+1)/2).^2)/((d+1)/2);
filter = (sin(pi/2*(1-rho).*(rho<=1))).^2;
filter = filter/sum(filter(:));
end


