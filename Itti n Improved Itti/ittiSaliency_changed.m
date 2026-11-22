%% Functions
function [varargout] = ittiSaliency_changed(input)
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

origSize = size(input);
origSize = origSize(1:2);   % [H W]

%% Channel division

[I,R,G,B,Y] = channels(input);

%% Center-Surround operation on the intensity channel

CSI = gaussianCenterSurround(I,I);

%% RG and BY opponency

RG = gaussianCenterSurround(R-G,G-R); 
BY = gaussianCenterSurround(B-Y,Y-B);

%% orientation maps

orientationMaps = gaborCenterSurround_paper(I,4);

% %% texture maps (Improved Itti model - ROI-BRISQUE paper)
% % The improved model adds texture saliency computed via Gabor-wavelet
% % center-surround differences across scale and direction.
textureMaps = gaborTextureCenterSurround(I,4);
% 
% %% edge structure maps (Improved Itti model - ROI-BRISQUE paper)
% % The improved model adds edge-structure saliency computed via Canny edges
% % and Gaussian pyramid center-surround differences.
edgeMap = double(edge(I,'canny'));
edgeCS  = gaussianCenterSurround(edgeMap,edgeMap);

%% Conspicuity maps
conspI = conspicuityInt_paper(CSI,1,I);
conspC = conspicuityCol_paper(RG,BY,1,I);
conspOr = conspicuityOr_paper(orientationMaps,1,I);
conspT = conspicuityTex_paper(textureMaps, 1, I);
conspE = conspicuityInt_paper(edgeCS,1,I);

%% Overall saliency map
saliencyMap1 = mixedConsp(conspI,conspC,conspOr,1);
saliencyMap2 = mixedConspImproved(conspI,conspC,conspOr,conspT,conspE,1);

%% A Winner-Take-All implementation

% saliencyCoord = winnerTakeAll(saliencyMap,true);

%% Resize the Saliency Map
saliencyMap1 = imresize(saliencyMap1, origSize, "bilinear");
saliencyMap2 = imresize(saliencyMap2, origSize, "bilinear");
% % Optional: normalize to [0,1] (nice for thresholding/ROI masks)
% mx = max(saliencyMap(:));
% if mx > 0
%     saliencyMap = saliencyMap / mx;
% end

%% Outputs
varargout{1} = saliencyMap1;
varargout{2} = saliencyMap2;
% varargout{3} = conspI;
% varargout{4} = conspC;
% varargout{5} = conspOr;
% varargout{6} = CSI;
% varargout{7} = RG;
% varargout{8} = BY;
% varargout{9} = orientationMaps;
% varargout{10} = I;
% varargout{11} = R;
% varargout{12} = G;
% varargout{13} = B;
% varargout{14} = Y;
% varargout{15} = conspT;
% varargout{16} = conspE;
% varargout{17} = textureMaps;
% varargout{18} = edgeCS;
% varargout{19} = edgeMap;

end

function [I,R,G,B,Y] = channels(input)
% [I,R,G,B,Y] = channels(input)
% Safe RGB-to-(I,R,G,B,Y) conversion (avoids NaNs from 0 denominators).
% Paper intent: normalize r,g,b by I only where I > 0.1*max(I).

    % Work in double to avoid uint overflow and for safe division
    input = double(input);

    % Intensity
    I = (input(:,:,1) + input(:,:,2) + input(:,:,3)) / 3;
    maxI = max(I(:));

    % If the image (or masked region) is completely black, return zeros
    if maxI <= 0
        z = zeros(size(I));
        R = z; G = z; B = z; Y = z;
        return;
    end

    % Only normalize where intensity is significant (paper uses 0.1*max(I))
    mask = (I > maxI/10);

    % Safe denominator: never allow 0
    denom = I;
    denom(denom == 0) = eps;

    % Normalize RGB by intensity everywhere safely, then zero-out outside mask
    r = input(:,:,1) ./ denom;
    g = input(:,:,2) ./ denom;
    b = input(:,:,3) ./ denom;

    r(~mask) = 0;
    g(~mask) = 0;
    b(~mask) = 0;

    % Broadly tuned channels (rectified)
    R = r - (g + b)/2;  R(R < 0) = 0;
    G = g - (r + b)/2;  G(G < 0) = 0;
    B = b - (r + g)/2;  B(B < 0) = 0;

    Y = (r + g)/2 - abs(r - g)/2 - b;
    Y(Y < 0) = 0;

    % Extra safety: clamp any accidental NaN/Inf (shouldn't happen now)
    R(~isfinite(R)) = 0;
    G(~isfinite(G)) = 0;
    B(~isfinite(B)) = 0;
    Y(~isfinite(Y)) = 0;
end

function output = gaussianCenterSurround(input1,input2)
    % Paper: scales s in [0..8], center c in {2,3,4}, surround s=c+{3,4}
    P1 = gaussianPyramid(input1,9);   % indices 1..9 correspond to scales 0..8
    P2 = gaussianPyramid(input2,9);

    k = 1;
    for c = 2:4
        for delta = 3:4
            s = c + delta;

            centerMap   = P1{c+1}; % +1 because MATLAB is 1-indexed
            surroundMap = P2{s+1};
            surroundMap = imresize(surroundMap, size(centerMap), "bilinear");

            output{1,k} = abs(centerMap - surroundMap);
            k = k + 1;
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

function output = gaborCenterSurround_paper(I, nOfDir)
    % Paper-like oriented Gabor pyramids on Gaussian pyramid scales 0..8
    Ipyr = gaussianPyramid(I, 9); % 0..8

    thetas = round((0:nOfDir-1) * (180/nOfDir));  % e.g., 0,45,90,135 when nOfDir=4

    % Compute O(s,theta) at each Gaussian scale
    O = cell(nOfDir, 9);
    for j = 1:nOfDir
        theta = thetas(j);
        for s = 0:8
            Is = Ipyr{s+1};
            % Choose a wavelength or filter size; many implementations keep wavelength fixed per scale.
            % A simple practical choice: wavelength proportional to scale.
            wavelength = 4;  % you can tune this
            O{j, s+1} = imgaborfilt(Is, wavelength, theta);
        end
    end

    % Center-surround differences: c in {2,3,4}, s=c+{3,4}
    output = cell(nOfDir, 6);
    for j = 1:nOfDir
        k = 1;
        for c = 2:4
            for delta = 3:4
                s = c + delta;
                centerMap   = O{j, c+1};
                surroundMap = imresize(O{j, s+1}, size(centerMap), "bilinear");
                output{j, k} = abs(centerMap - surroundMap);
                k = k + 1;
            end
        end
    end
end
function output = gaborTextureCenterSurround(input,nOfDir)
% output = gaborTextureCenterSurround(input,nOfDir)
% Texture feature extraction for the improved Itti model (ROI-BRISQUE paper).
% Implements a Gabor-wavelet bank and center-surround differences:
%   T(c,s) = |T(c) Θ T(s)|  with c∈{2,3,4}, s=c+δ, δ∈{3,4}
% The implementation follows the style of the existing orientation pipeline
% but uses magnitude-only differences (no complex subtraction).

% Build a "gabor pyramid" of magnitudes (no phase needed for texture).
texMag = gaborMagPyramid(input,8,nOfDir);

for j=1:nOfDir
    for c=2:4
        for delta=3:4
            centerMap = texMag{j,c};
            surroundMap = texMag{j,c+delta};
            surroundResize = imresize(surroundMap,size(centerMap));
            output{j,2*c+delta-6} = abs(centerMap - surroundResize);
        end
    end
end
end

function outputMag = gaborMagPyramid(input,l,nOfDir)
% outputMag = gaborMagPyramid(input,l,nOfDir)
% Returns a bank of Gabor magnitudes across scale and direction.
% Note: this matches the code's existing convention where indices start at 1.

for j=1:nOfDir
    outputMag{j,1} = input;
    for i=1:l-1
        theta = round(180/nOfDir*(j-1));
        mag = imgaborfilt(input,2^i,theta);
        outputMag{j,i+1} = mag;
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

function output = conspicuityInt_paper(CSI, M, I)
    % target = scale 4 size from Gaussian pyramid of I
    Ipyr = gaussianPyramid(I, 9);
    targetSize = size(Ipyr{5});   % scale 4 -> index 5

    CSI_norm = mapNormalization(CSI, M);

    output = zeros(targetSize);
    for i = 1:numel(CSI_norm)
        output = output + imresize(CSI_norm{i}, targetSize);
    end
end
function C = conspicuityCol_paper(RG, BY, M, I)
%CONSPICUITYCOL_PAPER Paper-aligned color conspicuity map.
%   RG, BY: 1x6 cell arrays of color opponency feature maps.
%   M: parameter used by your mapNormalization() (same M you already use).
%   I: intensity image used only to derive target size at pyramid scale 4.

    % Target = Gaussian pyramid scale 4 size (scale 0..8 => index 5 in MATLAB)
    Ipyr = gaussianPyramid(I, 9);
    targetSize = size(Ipyr{5});

    % Normalize individual feature maps (paper uses normalization operator N(.))
    RGn = mapNormalization(RG, M);
    BYn = mapNormalization(BY, M);

    % Sum RG and BY separately at target scale
    sumRG = zeros(targetSize);
    for k = 1:numel(RGn)
        sumRG = sumRG + imresize(RGn{k}, targetSize, "bilinear");
    end

    sumBY = zeros(targetSize);
    for k = 1:numel(BYn)
        sumBY = sumBY + imresize(BYn{k}, targetSize, "bilinear");
    end

    % Combine and normalize once more (common in Itti implementations)
    C = sumRG + sumBY;
    C = mapNormalization({C}, M);
    C = C{1};
end
function C = conspicuityOr_paper(O, M, I)
%CONSPICUITYOR_PAPER Paper-aligned orientation conspicuity map.
%   O: nDir x 6 cell array of orientation feature maps (center-surround).
%   M: parameter used by your mapNormalization().
%   I: intensity image used only to derive target size at pyramid scale 4.

    Ipyr = gaussianPyramid(I, 9);
    targetSize = size(Ipyr{5});

    nDir = size(O, 1);
    perTheta = cell(1, nDir);

    for j = 1:nDir
        % Normalize the 6 maps for this orientation
        Oj = O(j, :);
        Ojn = mapNormalization(Oj, M);

        % Sum them at target scale
        tmp = zeros(targetSize);
        for k = 1:numel(Ojn)
            tmp = tmp + imresize(Ojn{k}, targetSize, "bilinear");
        end

        % Normalize per-orientation conspicuity
        tmp = mapNormalization({tmp}, M);
        perTheta{j} = tmp{1};
    end

    % Sum across orientations and normalize final
    C = zeros(targetSize);
    for j = 1:nDir
        C = C + perTheta{j};
    end

    C = mapNormalization({C}, M);
    C = C{1};
end
function output = conspicuityTex_paper(input, M, I)
% Texture conspicuity (ROI-BRISQUE style): sum normalized texture CS maps at scale-4 size.

    inputNorm = mapNormalization(input, M);
    [nOfDir, nOfMaps] = size(inputNorm);

    % Target size = Gaussian pyramid scale 4 (scales 0..8 => index 5)
    Ipyr = gaussianPyramid(I, 9);
    targetSize = size(Ipyr{5});

    output = zeros(targetSize);

    for j = 1:nOfDir
        for k = 1:nOfMaps
            output = output + imresize(inputNorm{j,k}, targetSize, "bilinear");
        end
    end

    % Optional but usually beneficial: normalize final conspicuity
    tmp = mapNormalization({output}, M);
    output = tmp{1};
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
function output = mixedConspImproved(conspI,conspC,conspOr,conspT,conspE,M)
% output = mixedConspImproved(conspI,conspC,conspOr,conspT,conspE,M)
% Overall saliency map for the improved Itti model (ROI-BRISQUE paper).
% Eq. (10): S = 1/5 ( N(I) + N(C) + N(O) + N(T) + N(E) )

conspINorm  = singleMapNormalization(conspI,M);
conspCNorm  = singleMapNormalization(conspC,M);
conspOrNorm = singleMapNormalization(conspOr,M);
conspTNorm  = singleMapNormalization(conspT,M);
conspENorm  = singleMapNormalization(conspE,M);

output = 1/5*(conspINorm + conspCNorm + conspOrNorm + conspTNorm + conspENorm);
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

function saliencyCoord = winnerTakeAll(saliencyMap, varargin)
% saliencyCoord = winnerTakeAll(saliencyMap, isItti)

    % Always return a defined output
    saliencyCoord = {};

    % Guard: empty / invalid / all-zero maps -> no winners
    if isempty(saliencyMap) || ~any(isfinite(saliencyMap(:)))
        return;
    end

    maxSaliency = max(saliencyMap(:));
    if ~isfinite(maxSaliency) || maxSaliency <= 0
        return;
    end

    i = 1;
    while max(saliencyMap(:)) > 0.5 * maxSaliency
        bwMap = (saliencyMap == max(saliencyMap(:)));
        [row, col] = find(bwMap, 1);

        if isempty(row) || isempty(col)
            break;
        end

        saliencyMap = inibitionOfReturn(saliencyMap, [row, col]);
        saliencyCoord{1, i} = [row, col];
        i = i + 1;
    end

    % Optional coordinate scaling (if you still use it)
    if nargin >= 2 && islogical(varargin{1}) && varargin{1} == true
        % NOTE: Only do this if your WTA operates on a reduced map and
        % you truly need to scale back to full resolution.
        for k = 1:numel(saliencyCoord)
            saliencyCoord{1,k} = saliencyCoord{1,k} * 2^4;
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