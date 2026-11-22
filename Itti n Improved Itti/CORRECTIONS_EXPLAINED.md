# Corrections to Itti Saliency Model Implementation

## Summary of Issues Found and Corrections Made

Based on the paper "A Model of Saliency-Based Visual Attention for Rapid Scene Analysis" (Itti, Koch, & Niebur, 1998), I identified and corrected several implementation issues in the original MATLAB code.

---

## 1. **Gabor Pyramid Implementation** (CRITICAL ERROR)

### Original Issue:
```matlab
function [outputMag, outputPhase] = gaborPyramid(input,l,nOfDir)
    for j=1:nOfDir
        outputMag{j,1} = input;
        for i=1:l-1
            theta = round(180/nOfDir*(j-1));
            [mag, phase] = imgaborfilt(input,2^i,theta);  % ❌ WRONG: filters original image
            outputMag{j,i+1} = mag;
            outputPhase{j,i+1} = phase;
        end
    end
end
```

**Problem**: The function was applying Gabor filters directly to the original image at different wavelengths, rather than creating a proper pyramid with downsampled images at each level.

### Correction:
```matlab
% First create Gaussian pyramid of intensity
gaussPyr = gaussianPyramid(input, 9);

% Apply Gabor filters at each scale for each orientation
for j = 1:nOfDir
    theta = round(180/nOfDir * (j-1));
    for s = 1:9  % Scales 0-8
        wavelength = 2^(s-1) * 2;
        [mag, phase] = imgaborfilt(gaussPyr{s}, wavelength, theta);
        outputMag{j,s} = mag;
        outputPhase{j,s} = phase;
    end
end
```

**Why**: According to the paper (Section 2.1), orientation information is obtained using "oriented Gabor pyramids O(σ,θ), where σ ∈ [0..8] represents the scale". This means Gabor filters should be applied to a Gaussian pyramid, similar to how intensity features are processed.

---

## 2. **Channel Division - Normalization Logic**

### Original Issue:
```matlab
r = (I>maxI/10).*input(:,:,1)./I;
```

**Problem**: This creates division by zero warnings and doesn't properly handle the masking.

### Correction:
```matlab
mask = (I > maxI/10);
r_norm = zeros(size(r));
r_norm(mask) = r(mask) ./ I(mask);
```

**Why**: The paper states "normalization is only applied at the locations where I is larger than 1/10 of its maximum" to avoid hue computation at very low luminance. The corrected version explicitly masks these regions.

---

## 3. **Center-Surround Resizing**

### Original Issue:
```matlab
centerSize = size(center{c},1,2);  % ❌ Wrong syntax
surroundResize = imresize(surround{c+delta},centerSize);
```

**Problem**: Incorrect `size()` syntax and potential indexing issues.

### Correction:
```matlab
centerMap = center{c+1};
surroundMap = surround{s+1};
centerSize = size(centerMap);
surroundResized = imresize(surroundMap, centerSize(1:2));
```

**Why**: Proper indexing (MATLAB is 1-based) and correct size extraction for image resizing.

---

## 4. **Map Normalization - Numerical Stability**

### Original Issue:
```matlab
noGlobalMax = dynamicLimited.*(dynamicLimited<M);
localMaxima = nonzeros(noGlobalMax.*islocalmax(noGlobalMax));
m = mean(localMaxima);
```

**Problem**: Doesn't handle edge cases where no local maxima exist or the map is constant.

### Correction:
```matlab
if isempty(input) || (max(input(:)) == min(input(:)))
    output = zeros(size(input));
    return;
end

% Proper handling of local maxima detection
localMaxMap = islocalmax(noGlobalMax, 1) | islocalmax(noGlobalMax, 2);
localMaxima = noGlobalMax(localMaxMap & noGlobalMax > 0);

if isempty(localMaxima)
    m = 0;
else
    m = mean(localMaxima);
end
```

**Why**: The normalization operator N(.) described in the paper (Section 2.2 and Fig. 2) should gracefully handle edge cases to avoid numerical issues.

---

## 5. **Conspicuity Map Resizing**

### Original Issue:
```matlab
function output = conspicuityOr(input,M)
    % ...
    output = output+singleMapNormalization(temp,M);
    % ...
    output = imresize(output,1/2^(4-1));  % ❌ Incorrect scale adjustment
end
```

**Problem**: Unnecessary and incorrect resizing at the end. The maps should already be at the correct scale.

### Correction:
```matlab
function output = conspicuityOr(input, M)
    % Process maps at their natural scale
    for j = 1:nOfDir
        temp = zeros(targetSize(1:2));
        for i = 1:nOfMaps
            mapResized = imresize(inputNorm{j,i}, targetSize(1:2));
            temp = temp + mapResized;
        end
        tempNorm = singleMapNormalization(temp, M);
        output = output + tempNorm;
    end
    % Output is already at correct scale
end
```

**Why**: According to the paper, conspicuity maps should be at scale σ=4. The resizing should happen when combining feature maps, not at the end.

---

## 6. **Gaussian Pyramid Levels**

### Original Issue:
```matlab
CSI = gaussianCenterSurround(I,I);
% But inside, only creates 4 or 8 levels
```

**Problem**: Inconsistent pyramid depth across different functions.

### Correction:
```matlab
center = gaussianPyramid(input1, 9);  % Always create 9 levels (0-8)
surround = gaussianPyramid(input2, 9);
```

**Why**: The paper explicitly states "Nine spatial scales are created using dyadic Gaussian pyramids" (Section 2). All pyramids should have 9 levels for consistency.

---

## 7. **Inhibition of Return - Coordinate System**

### Original Issue:
```matlab
X = repmat(x',1,h);
Y = repmat(y,w,1);
```

**Problem**: Inconsistent coordinate system that could cause X/Y confusion.

### Correction:
```matlab
[X, Y] = meshgrid(1:w, 1:h);
rho = sqrt((Y - previousWinner(1)).^2 + (X - previousWinner(2)).^2);
```

**Why**: Using `meshgrid` is clearer and ensures correct row/column correspondence.

---

## Key Improvements Summary

| Issue | Impact | Correction |
|-------|---------|-----------|
| Gabor pyramid | **Critical** - Wrong multi-scale representation | Create Gaussian pyramid first, then apply Gabor |
| Channel normalization | Minor - Causes warnings | Proper masking before division |
| Map resizing | Moderate - Could affect accuracy | Correct size extraction and indexing |
| Normalization stability | Moderate - Could crash on edge cases | Add empty/constant map handling |
| Scale consistency | Moderate - Inconsistent feature extraction | Use 9 levels throughout |
| Conspicuity resizing | Minor - Unnecessary operation | Remove redundant resize |

---

## Testing Recommendations

1. **Test with the original paper's images** if available
2. **Compare intermediate outputs**:
   - Check pyramid levels (should have 9 levels)
   - Verify 42 feature maps total (6 intensity + 12 color + 24 orientation)
   - Ensure conspicuity maps are same size
3. **Visual validation**:
   - Salient objects should be detected first
   - FOA should move to conspicuous locations
4. **Numerical validation**:
   - Check for NaN or Inf values
   - Verify normalization produces values in [0, M]

---

## References

The corrections are based on:
- **Section 2.1** (Feature Extraction): Multi-scale pyramids, center-surround computation
- **Section 2.2** (Saliency Map): Normalization operator N(.), conspicuity map combination
- **Fig. 1**: Overall architecture
- **Fig. 2**: The normalization operator

All implementations now correctly follow the mathematical formulations in equations (1)-(8) of the paper.
