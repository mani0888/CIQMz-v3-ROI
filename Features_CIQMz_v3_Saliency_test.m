%% Main CIQMz
clc;    close all;      clear variables

% matrices for the features
ROI_features     = zeros(1, 21);
Non_ROI_features = zeros(1, 21);

for ii = 1
    RGB = imread('ljp2k_img2_1.bmp');
    sz = size(RGB);
    maxdim = 1920;
    if sz(1)>maxdim || sz(2)>maxdim
        if sz(1)>=sz(2)
            rszf =  maxdim/sz(1);
        elseif sz(1)<sz(2)
            rszf =  maxdim/sz(2);
        end
        RGB = imresize(RGB,rszf);
        sz = size(RGB);
    end
    % Load saliency map
    Map = load('Itti_ljp2k_img2_1.mat');
    saliencyMap = double(Map.saliencyMap);
    saliencyMap = imresize(saliencyMap, [sz(1) sz(2)]);
    mx = max(saliencyMap(:));
    % Normalize the saliency map for ROI/Non-ROI division
    saliencyMap = saliencyMap / mx;

    % ROI / nROI masks (same size as RGB)
    ROI_mask = (saliencyMap > mean(saliencyMap(:))); % for Itti, Improved Itti and CovSal
    % ROI_mask = (saliencyMap > 0.5*mean(saliencyMap(:))); % for LDS, EML-NET

    ROI_mask = logical(ROI_mask);
    nROI_mask = ~ROI_mask;
    ROI_features(ii,:)     = CIQMZN(RGB, ROI_mask);
    Non_ROI_features(ii,:) = CIQMZN(RGB, nROI_mask);

end
FeaturesAll = [ROI_features Non_ROI_features];


%% CIQMZN++
function FeaturesCIQMZN = CIQMZN(RGB, mask)
if nargin < 2 || isempty(mask)
    mask = true(size(RGB,1), size(RGB,2));
end
mask = logical(mask);
% CIQMA
FeaturesA  = IQM_CIQMA( RGB , [] , mask );
% CIQMR
[cr,dr,tr] = calculate_allratio_gbd(RGB,'sRGB', mask);
[gc,lc,s]  = calculate_contrasts(RGB,'sRGB', mask);
FeaturesB  = [dr tr cr gc lc s];

% Naturalness (CIQMZN++: current + new cross-channel/cast/multi-scale features)
EnLh     = visionalignment_Naturalness(RGB, mask);
C_glcm   = texture_Naturalness(RGB, mask);
EnLBPRGB = lbpRGB_entropy(RGB, 3, 16, mask); % Radius=3, Neighbors=16 for LBP
% EnLBP    = lbp_entropy(RGB, 3, 16, mask);
EnLBP_MS = multiscalelbp_entropy(RGB, 3, 16, mask);

% Legacy naturalness feature pack (keep for backward comparability)
FeaturesC  = [EnLh EnLBP_MS EnLBPRGB C_glcm];

FeaturesCIQMZN = [FeaturesA FeaturesB FeaturesC];
end

%% CIQMA feature calculation with ROI masks
function [IQAtr] = IQM_CIQMA( RGB , XYZ , mask )

dims = size(RGB);
if isempty(XYZ)
    XYZt = 100*rgb2xyz(RGB);
    XYZt = (reshape(permute(XYZt, [3 1 2]), [3, dims(1) * dims(2)]))'; % nx3 dimension
else
    XYZt = XYZ;
    if size(XYZ,3)==3
        XYZt = (reshape(permute(XYZt, [3 1 2]), [3, dims(1) * dims(2)]))'; % nx3 dimension
    end
end
%--------------------------------------------------------------------------
[lab] = xyz2lab(XYZt,'d65_31');
lch=lab2lch(lab);
L = lab(:,1);
C = lch(:,2);

L_test  = reshape(L , [dims(1) dims(2)]);
Ch_test = reshape(C , [dims(1) dims(2)]);
%--------------------------------------------------------------------------
% Brightness
IL = BrightnessWoR( L_test, mask );

% --------------------------------------------------------------------------
% Chroma
IC = ColorfulnessWoR( Ch_test, mask );

%--------------------------------------------------------------------------
% Contrast (Using M D Fairchild Model)
ws = [5 9 13];
for i = 1:3
    % Lightness Contrast
    val = Contrast_SIPL(L_test , ws(i), mask);%%#ok<AGROW>
    LCj(i) = val(3); %#ok<AGROW>

    %--------------------------------------------------------------------------
    % Sharpness Contrast
    SCj(i) = Contrast_SIPS(L_test , ws(i), mask);%#ok<AGROW>

    %--------------------------------------------------------------------------
    % Chroma Contrast
    val = Contrast_SIPC(Ch_test , ws(i), mask);% %#ok<AGROW>
    CC(i) = val(3); %#ok<AGROW>

end
Contrast = [LCj CC SCj];

%--------------------------------------------------------------------------
% Color Sciene Model Attributes (Features)
IQAtr = [IL(3) IC(3) Contrast(1) Contrast(4) Contrast(6) Contrast(7) Contrast(8) Contrast(9) ];

end
function lch = lab2lch(lab)
% LAB2LCH Converts Lab color values to LCh (Lightness, Chroma, Hue)
% Input:
%   lab - Nx3 matrix with columns [L, a, b]
% Output:
%   lch - Nx3 matrix with columns [L, c, h] where h is in degrees

% Compute chroma
c = sqrt(lab(:,2).^2 + lab(:,3).^2);

% Initialize hue
h = zeros(size(lab(:,1)));

% Identify achromatic pixels (a = 0, b = 0)
achromatic = (lab(:,2) == 0) & (lab(:,3) == 0);

% Compute hue for chromatic pixels using atan2 (more robust than atan)
h(~achromatic) = atan2(lab(~achromatic,3), lab(~achromatic,2)) * 180 / pi;

% Ensure hue is in [0, 360]
h = mod(h, 360);

% Assign default hue (0 degrees) for achromatic pixels
h(achromatic) = 0;

% Combine results
lch = [lab(:,1), c, h];
end
function [lab] = xyz2lab(xyz,obs,xyzw)

if (size(xyz,2)~=3)
    disp('xyz must be n by 3'); return;
end
lab = zeros(size(xyz,1),size(xyz,2));

if strcmp('a_64',obs)
    white=[111.144 100.00 35.200];
elseif strcmp('a_31', obs)
    white=[109.850 100.00 35.585];
elseif strcmp('c_64', obs)
    white=[97.285 100.00 116.145];
elseif strcmp('c_31', obs)
    white=[98.074 100.00 118.232];
elseif strcmp('d50_64', obs)
    white=[96.720 100.00 81.427];
elseif strcmp('d50_31', obs)
    white=[96.422 100.00 82.521];
elseif strcmp('d55_64', obs)
    white=[95.799 100.00 90.926];
elseif strcmp('d55_31', obs)
    white=[95.682 100.00 92.149];
elseif strcmp('d65_64', obs)
    white=[94.811 100.00 107.304];
elseif strcmp('d65_31', obs)
    white=[95.047 100.00 108.883];
elseif strcmp('d75_64', obs)
    white=[94.416 100.00 120.641];
elseif strcmp('d75_31', obs)
    white=[94.072 100.00 122.638];
elseif strcmp('f2_64', obs)
    white=[103.279 100.00 69.027];
elseif strcmp('f2_31', obs)
    white=[99.186 100.00 67.393];
elseif strcmp('f7_64', obs)
    white=[95.792 100.00 107.686];
elseif strcmp('f7_31', obs)
    white=[95.041 100.00 108.747];
elseif strcmp('f11_64', obs)
    white=[103.863 100.00 65.607];
elseif strcmp('f11_31', obs)
    white=[100.962 100.00 64.350];
elseif strcmp('user', obs)
    white=xyzw;
else
    disp('unknown option obs');
    disp('use d65_64 for D65 and 1964 observer'); return;
end

lab = zeros(size(xyz,1),3);

fx = zeros(size(xyz,1),3);
for i=1:3
    index = (xyz(:,i)/white(i) > (6/29)^3);
    fx(:,i) = fx(:,i) + index.*(xyz(:,i)/white(i)).^(1/3);
    fx(:,i) = fx(:,i) + (1-index).*((841/108)*(xyz(:,i)/white(i)) + 4/29);
end

lab(:,1)=116*fx(:,2)-16;
lab(:,2) = 500*(fx(:,1)-fx(:,2));
lab(:,3) = 200*(fx(:,2)-fx(:,3));

end
function IB = BrightnessWoR( Q_test, mask )

Q_test = Q_test(mask);
Q_test = sort(Q_test);
count = numel(Q_test);
minc = round(.05*count);
maxc = round(.95*count);

Qt(1) = mean(Q_test(1:minc));
Qt(2) = mean(Q_test(maxc:end));
Qt(3) = mean(Q_test(:));
IB = Qt;

end
function M = ColorfulnessWoR( M_test, mask )

M_test = M_test(mask);
M_test = sort(M_test);
count = numel(M_test);
minc = round(.05*count);
maxc = round(.95*count);

M(1) = mean(M_test(1:minc));
M(2) = mean(M_test(maxc:end));
M(3) = mean(M_test(:));

end
function LC = Contrast_SIPL(L_ldr , ws, mask)
% Lightness Contrast
fun = @(x) std(x(:))*ones(size(x));
I8 = blkproc(L_ldr,[ws ws],fun);

I8 = I8(mask);
I8 = sort(I8);
count = numel(I8);
minc = round(.05*count);
maxc = round(.95*count);

LC(1) = mean(I8(1:minc));
LC(2) = mean(I8(maxc:end));
LC(3) = mean(I8);

end
function SC = Contrast_SIPS(L_ldr , ws, mask)
% Sharpness Contrast
[m,n]=size(L_ldr);
EdgeImg = edge(L_ldr,'sobel');
EdgeImg = EdgeImg.*mask;
loc = find(EdgeImg > 0);
loc = loc(find(loc >6*m & loc<(m*n - 6*m))); %#ok<FNDSB>
I = mod(loc,m);
J = 1 + floor(loc./m);

s = ((ws)/2)-0.5;
j=0;
Del_J = zeros(m,n);
for i=1:length(I)
    % i
    if I(i)<=m-6 && I(i)>6
        wJ = L_ldr(I(i)+(-s:s),J(i)+(-s:s),1);
        Del_J(I(i),J(i)) = std(wJ(:));
        j=j+1;
    end
end
SC = sum(Del_J(:))./j;

end
function CC = Contrast_SIPC(C , ws, mask)
% Chroma Contrast
fun = @(x) std(x(:))*ones(size(x));
I8 = blkproc(C,[ws ws],fun);

I8 = I8(mask);
I8 = sort(I8(:));
count = numel(I8);
minc = round(.05*count);
maxc = round(.95*count);

CC(1) = mean(I8(1:minc));
CC(2) = mean(I8(maxc:end));
CC(3) = mean(I8);

end

%% CIQMR
function [cr,dr,clr] = calculate_allratio_gbd(img00,gamutname, mask)
%%
load GBD.mat;
switch gamutname
    case 'sRGB'
        gbdL = srgbL;
        gbdC = srgbC;
    case 'p3'
        gbdL = p3L;
        gbdC = p3C;
end

sz = size(img00);
if sz(1)>2160 || sz(2)>2160
    if sz(1)>=sz(2)
        rszf =  2160/sz(1);
    elseif sz(1)<sz(2)
        rszf =  2160/sz(2);
    end
    img00 = imresize(img00,rszf);
    mask  = imresize(mask,rszf);
end
sz = size(img00);
img0 = double(reshape(img00,sz(1)*sz(2),3))/255;
clear img00
mask = mask(:);
img0 = img0(mask,:);
% -----------------------------------------------------
switch gamutname
    case 'sRGB'
        xyzw = 100*rgb2xyz([1 1 1]);
        xyz0 = 100*rgb2xyz(img0);
        lab0 = xyz2lab(xyz0,'user',xyzw);
end
% -----------------------------------------------------
chroma = sqrt(lab0(:,2).^2+lab0(:,3).^2);
hue = hue_angle_degree(lab0(:,2),lab0(:,3));
lightness = lab0(:,1);
len = length(lightness);
chromaCL1 = [zeros(len,1),lightness];
depthCL1 = [zeros(len,1),100*ones(len,1)];
clarityCL1 = [zeros(len,1),50*ones(len,1)];
CL2 = [chroma,lightness];

crossnodesC1 = zeros(len,20);
crossnodesC4 = zeros(len,20);
crossnodesC5 = zeros(len,20);
flag1 = zeros(len,20);
flag4 = zeros(len,20);
flag5 = zeros(len,20);
%%
for ii = 1:20
    CLgb1 = [gbdC(floor(hue)+1,ii),gbdL(floor(hue)+1,ii)];
    CLgb2 = [gbdC(floor(hue)+1,ii+1),gbdL(floor(hue)+1,ii+1)];

    crossnodes = crossnode(chromaCL1,CL2,CLgb1,CLgb2);
    flag1(:,ii) = (((crossnodes(:,1)>=CLgb1(:,1)) & (crossnodes(:,1)<=CLgb2(:,1)))|((crossnodes(:,1)<=CLgb1(:,1)) & (crossnodes(:,1)>=CLgb2(:,1)))) & (crossnodes(:,2)>=CLgb1(:,2)) & (crossnodes(:,2)<=CLgb2(:,2));
    crossnodesC1(:,ii) = crossnodes(:,1);

    crossnodes = crossnode(depthCL1,CL2,CLgb1,CLgb2);
    flag4(:,ii) = (((crossnodes(:,1)>=CLgb1(:,1)) & (crossnodes(:,1)<=CLgb2(:,1)))|((crossnodes(:,1)<=CLgb1(:,1)) & (crossnodes(:,1)>=CLgb2(:,1)))) & (crossnodes(:,2)>=CLgb1(:,2)) & (crossnodes(:,2)<=CLgb2(:,2));
    crossnodesC4(:,ii) = crossnodes(:,1);

    crossnodes = crossnode(clarityCL1,CL2,CLgb1,CLgb2);
    flag5(:,ii) = (((crossnodes(:,1)>=CLgb1(:,1)) & (crossnodes(:,1)<=CLgb2(:,1)))|((crossnodes(:,1)<=CLgb1(:,1)) & (crossnodes(:,1)>=CLgb2(:,1)))) & (crossnodes(:,2)>=CLgb1(:,2)) & (crossnodes(:,2)<=CLgb2(:,2));
    crossnodesC5(:,ii) = crossnodes(:,1);

end
gamutC1 = sum(crossnodesC1.*flag1,2);
chromaratio = chroma./gamutC1;
chromaratio(gamutC1==0) = 1;                    % verify: pointsoutside gamut ,should be--1
chromaratio(chromaratio>1) = 1;
chromaratio(sum(flag1,2)==0) = 1;
chromaratio(chroma==0) = 0;                     % verify: zero poitns--0
cr = mean(chromaratio);

gamutC4 = max(crossnodesC4.*flag4,[],2);            % max function assure calculating the outer crosspoint
depthratio = chroma./gamutC4;
depthratio(gamutC4==0) = 1;
depthratio(depthratio>1) = 1;
depthratio(sum(flag4,2)==0) = 1;
depthratio(chroma==0)=(100-lightness(chroma==0))/100;          % verify: for axile points-- 1-lightness ratio value
dr = mean(depthratio);

gamutC5 = sum(crossnodesC5.*flag5,2);
clarityratio = chroma./gamutC5;
clarityratio(gamutC5==0) = 1;
clarityratio(clarityratio>1) = 1;
clarityratio(sum(flag5,2)==0) = 1;
clarityratio(chroma==0)=abs(lightness(chroma==0)-50)/50;        % verify: for axile points--1
clr = mean(clarityratio);
end
function [gc,lc,s] = calculate_contrasts(img00,gamutname, mask)

% -----------------------------------------------------
img1 = imresize(img00,[128,96]);   % for clearss/Sharpness, run faster
mask1 = imresize(mask,[128,96]);
img2 = imresize(img00,[512,512]);  % for global contrast and local contrast
mask2 = imresize(mask,[512,512]);
% -----------------------------------------------------
sz1 = size(img1); sz2 = size(img2);
img1 = double(reshape(img1,sz1(1)*sz1(2),3))/255;
img2 = double(reshape(img2,sz2(1)*sz2(2),3))/255;
% -----------------------------------------------------
switch gamutname
    case 'sRGB'
        xyzw = 100*rgb2xyz([1 1 1]);
        xyz1 = 100*rgb2xyz(img1);
        lab1 = xyz2lab(xyz1,'user',xyzw);
        xyz2 = 100*rgb2xyz(img2);
        lab2 = xyz2lab(xyz2,'user',xyzw);
end
clear img1 img2 xyz1 xyz2
% -----------------------------------------------------
% clearness / Sharpness
lab1 = reshape(lab1,sz1(1),sz1(2),3);
dete = zeros(sz1(1),sz1(2));
for i = 3:(sz1(1)-2)
    for j = 3:(sz1(2)-2)
        temp2 = lab1(i-2:i+2,j-2:j+2,:);
        labbar = repmat(lab1(i,j,:),5,5);
        deltaeij = sqrt( sum( abs(temp2-labbar).^2,3 ) );
        dete(i,j) = sum(deltaeij(:))/24;
    end
end
dete2 = dete(3:end-2,3:end-2);
mask11 = mask1(3:end-2,3:end-2);
dete2 = dete2(mask11);
s = mean(dete2,'all');

% global contrast and local contrast
lab2 = reshape(lab2,sz2(1),sz2(2),3);
detl = zeros(sz2(1),sz2(2));
for i = 3:(sz2(1)-2)
    for j = 3:(sz2(2)-2)
        temp1= lab2(i-2:i+2,j-2:j+2,1);
        lbar = lab2(i,j,1)*ones(5);
        detl(i,j) = sum(abs(temp1-lbar),'all')/24;
    end
end
detl2 = detl(3:end-2,3:end-2);
mask22 = mask2(3:end-2,3:end-2);
detl2 = detl2(mask22);
lc = mean(detl2,'all');

l2 = lab2(:,:,1);
l2 = l2(mask2);
len = length(l2);

l_seq = sort(l2,'descend');
gc = ( mean( l_seq(1:round(1/100*len))) - mean( l_seq(round(99/100*len):end) ) )/100;

end
function h=hue_angle_degree(a,b)
% HUE_ANGLE: Computes four-quadrant polar angle in degrees from Cartesian coordinates
%
%   Colour Engineering Toolbox
%   author:    ?Phil Green
%   version:   1.1
%   date:  	   17-01-2001
%   book:      http://www.wileyeurope.com/WileyCDA/WileyTitle/productCd-0471486884.html
%   web:       http://www.digitalcolour.org

h=(180/pi)*atan2(b,a);
j=(b<0);
h(j)=h(j)+360;
end
function cn = crossnode(p1,q1,p2,q2)

cn = zeros(size(p1));

idx1 = (p1(:,1) == q1(:,1));
if(sum(idx1))
    cn(idx1,1) = p1(idx1,1);
    k2 = (q2(idx1,2)-p2(idx1,2))./(q2(idx1,1)-p2(idx1,1));
    b2 = p2(idx1,2)-k2.*p2(idx1,1);
    cn(idx1,2) = k2.*cn(idx1,1)+b2;
end

idx2 = (p2(:,1) == q2(:,1));
if(sum(idx2))
    cn(idx2,1) = p2(idx2,1);
    k1 = (q1(idx2,2)-p1(idx2,2))./(q1(idx2,1)-p1(idx2,1));
    b1 = p1(idx2,2)-k1.*p1(idx2,1);
    cn(idx2,2) = k1.*cn(idx2,1)+b1;
end

idx3 = ~(idx1|idx2);
if(sum(idx3))
    k1 = (q1(idx3,2)-p1(idx3,2))./(q1(idx3,1)-p1(idx3,1));
    k2 = (q2(idx3,2)-p2(idx3,2))./(q2(idx3,1)-p2(idx3,1));

    temp = zeros(sum(idx3),2);
    tempq1 = q1(idx3,:);

    idx4 = (k1 == k2);
    if(sum(idx4))
        temp(idx4,1) = tempq1(idx4,1);
        temp(idx4,2) = tempq1(idx4,2);
    end

    idx5 = ~idx4;
    if(sum(idx5))
        b1 = p1(idx3,2)-k1.*p1(idx3,1);
        b2 = p2(idx3,2)-k2.*p2(idx3,1);
        temp(idx5,1) = (b2(idx5,1)-b1(idx5,1))./(k1(idx5,1)-k2(idx5,1));
        temp(idx5,2) = k1(idx5,1).*temp(idx5,1)+b1(idx5,1);

    end
    cn(idx3,:) = temp;
end


end

%% Statistical Naturalness Functions

function [VN] = visionalignment_Naturalness(image_rgb, mask)
dims = size(image_rgb);
% Convert to XYZ
image_xyz = 100*rgb2xyz(image_rgb);
image_xyz = reshape(permute(image_xyz, [3 1 2]), [3, dims(1)*dims(2)])';

% Convert to CIELAB and LCh
image_lab = xyz2lab(image_xyz, 'd65_31');
image_lch=lab2lch(image_lab);
image_lab = permute(reshape(image_lab', [3, dims(1), dims(2)]), [2 3 1]);
image_lch = permute(reshape(image_lch', [3, dims(1), dims(2)]), [2 3 1]);

L = image_lab(:,:,1);
chroma = image_lch(:,:,2);
hue = image_lch(:,:,3);

% Compute entropy of lightness
% Histogram with 100 bins in [0, 100]
L = L(mask);
iqr_L = iqr(L(:));
n_bins = ceil((max(L(:)) - min(L(:))) / (2 * iqr_L * numel(L)^(-1/3)));
n_bins = max(10, min(n_bins, 200));
edges = linspace(0, 100, n_bins+1);
hist = histcounts(L(:), edges);
hist = hist / sum(hist);
hist = hist(hist > 0);
entropyL = -sum(hist .* log2(hist));
clear hist

% Compute entropy of hue
h = hue * pi / 180;
h = h(mask);
[counts, ~] = histcounts(h, 36);
probs = counts / sum(counts);
probs(probs == 0) = [];
entropyh = -sum(probs .* log2(probs));

VN = [entropyL entropyh];
end
function [TNS ]= texture_Naturalness(image_rgb, mask)
% Represent excluded pixels as NaN so downstream stats can omit them
RGBm = image_rgb;
for ch = 1:3
    tmp = RGBm(:,:,ch);
    tmp(~mask) = NaN;
    RGBm(:,:,ch) = tmp;
end
% % Convert to grayscale using XYZ Y-channel
image_xyz = rgb2xyz(RGBm);
image_gray = image_xyz(:,:,2);

% Compute GLCM features
offsets = [0 1];%; -1 0; -1 1; -1 -1];
glcm = graycomatrix(image_gray, 'NumLevels', 32, 'Offset', offsets, 'Symmetric', true);
stats = graycoprops(glcm, {'Contrast', 'Energy', 'Correlation'});
contrast = mean(stats.Contrast);
% correlation = mean(stats.Correlation);
TNS = contrast;
end
function entropylbp = lbp_entropy(image_rgb, radius, neighbors, mask)
% Convert to grayscale using XYZ Y-channel
image_xyz = 255*rgb2xyz(image_rgb);
image_gray = image_xyz(:,:,2);

% LBP
[lbp] = compute_lbp(image_gray, radius, neighbors, mask);
entropylbp = compute_histogram_entropy(lbp.hist);
end
function entropy_rgb = lbpRGB_entropy(image_rgb, radius, neighbors, mask)
if size(image_rgb, 3) ~= 3
    error('Input must be an RGB image');
end
image_rgb = double(image_rgb);

% Initialize feature struct
features = struct();

% Extract R, G, B channels
R = image_rgb(:,:,1);
G = image_rgb(:,:,2);
B = image_rgb(:,:,3);

% Compute LBP for each color channel
features.lbp_R = compute_lbp(R, radius, neighbors, mask);
features.lbp_G = compute_lbp(G, radius, neighbors, mask);
features.lbp_B = compute_lbp(B, radius, neighbors, mask);

% Concatenate all histograms for final feature vector
features.feature_vector_rgb  = [features.lbp_R.hist, features.lbp_G.hist, features.lbp_B.hist];
entropy_rgb = compute_histogram_entropy(features.feature_vector_rgb);
end
function entropy_MS = multiscalelbp_entropy(image_rgb, radius, neighbors, mask)
RGBd = im2double(image_rgb);
scales = [1.0, 0.5, 0.25];
HLBP = zeros(1,3);
for k = 1:3
    s = scales(k);
    if s < 1
        I = imresize(RGBd, s, 'bilinear');
        maskI = imresize(mask, s, 'bilinear');
    else
        I = RGBd;
        maskI = mask;
    end
    % LBP entropy on grayscale
    % gray = rgb2gray(I);
    % Convert to grayscale using XYZ Y-channel
    I_xyz = 255*rgb2xyz(I);
    gray = I_xyz(:,:,2);

    lbp = compute_lbp(gray, radius, neighbors, maskI);
    HLBP(k) = compute_histogram_entropy(lbp.hist);
end

entropy_MS = HLBP;
end

function lbp_result = compute_lbp(channel, radius, neighbors, mask)
% COMPUTE_LBP Computes LBP for a single color channel
[height, width] = size(channel);
lbp_map = zeros(height, width);

% Sampling points
angles = linspace(0, 2*pi, neighbors+1);
angles = angles(1:end-1);
x = radius * cos(angles);
y = radius * sin(angles);

for i = radius+1:height-radius
    for j = radius+1:width-radius
        center = channel(i, j);
        binary = zeros(1, neighbors);
        for k = 1:neighbors
            xi = i + x(k);
            yj = j + y(k);
            val = interpolate(channel, xi, yj);
            binary(k) = val >= center;
        end
        lbp_map(i, j) = sum(binary .* (2.^(0:neighbors-1)));
    end
end

% Compute histogram
lbp_result.map = lbp_map;
lbp_result.hist = histcounts(lbp_map(mask), 0:2^neighbors);
end
function val = interpolate(channel, x, y)
% INTERPOLATE Bilinear interpolation for non-integer coordinates
x1 = floor(x); x2 = ceil(x);
y1 = floor(y); y2 = ceil(y);
if x1 == x2, x2 = x1 + 1; end
if y1 == y2, y2 = y1 + 1; end

% Ensure coordinates are within bounds
x1 = max(1, min(x1, size(channel, 1)));
x2 = max(1, min(x2, size(channel, 1)));
y1 = max(1, min(y1, size(channel, 2)));
y2 = max(1, min(y2, size(channel, 2)));

% Get pixel values
Q11 = channel(x1, y1);
Q12 = channel(x1, y2);
Q21 = channel(x2, y1);
Q22 = channel(x2, y2);

% Bilinear interpolation
val = (Q11 * (x2-x) * (y2-y) + Q21 * (x-x1) * (y2-y) + ...
    Q12 * (x2-x) * (y-y1) + Q22 * (x-x1) * (y-y1)) / ((x2-x1) * (y2-y1));
end
function entropy = compute_histogram_entropy(hist)
% Computes entropy of a histogram
hist = hist / (sum(hist) + eps); % Normalize to probabilities, add eps to avoid division by zero
hist(hist == 0) = eps; % Avoid log(0)
entropy = -sum(hist .* log2(hist));
end
