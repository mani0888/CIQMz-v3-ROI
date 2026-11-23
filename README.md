**CIQMz-v3-ROI**
Saliency-Guided No-Reference Image Quality Assessment using a Naturalness-Enhanced Color-domain Image Quality Metric

This repository contains the MATLAB implementation of two no-reference image quality metrics (NR-IQMs) proposed in the CIC34 paper:

**CIQM<sub>ZN</sub>**  – a naturalness-enhanced extension of the color-domain CIQM<sub>Z</sub> metric (21 features).

**CIQM<sub>ZN_Saliency</sub>** – a saliency-guided variant that extracts features separately from perceptually salient (ROI) and non-salient (nROI) regions, trains two SVR models, and fuses their predictions.

For full methodological details, please refer to the paper:

Muhammad Usman Khan, Ming Ronnier Luo, Imran Mehmood, "Saliency-Guided No-Reference Image Quality Assessment using a Naturalness-Enhanced Color-domain Image Quality Metric", CIC34.

**Repository Structure**
CIQMz-v3-ROI/
│
├── Feature calculation files          # CIQM<sub>ZN</sub> and CIQM<sub>ZN_Saliency</sub> feature extraction
├── Itti and Improved Itti/            # MATLAB implementations of Itti and Improved Itti saliency models
├── generateSaliencyMapsonImages.m     # Generates saliency maps for a test image as shown in the Paper
├── Evaluation_SDB_CIQMzn.m            # Same-database (SDB) evaluation for CIQM<sub>ZN</sub>
├── Evaluation_SDB_CIQMzn_ROI.m        # Same-database (SDB) evaluation for CIQM<sub>ZN_Saliency</sub>
├── images                             # Sample / benchmark images used for evaluation
└── ... (supporting .mat files, labels, etc.)

**Requirements**

MATLAB (tested with recent versions; R2019b or later recommended)

Statistics and Machine Learning Toolbox (for fitrsvm / SVR training)

Image Processing Toolbox (for LBP, GLCM, color-space conversions, etc.)

**File Descriptions & Usage**

**1. Feature Calculation Files**

These scripts compute the 21-dimensional CIQM<sub>ZN</sub> feature vector from an input image.

**The feature set comprises:**

Category	Features
Appearance-based (14) — from CIQM<sub>Z</sub>	Lightness, Chroma, Lightness contrast, Chroma contrasts, Sharpness contrasts, Depth/Chroma/Clarity ratios, Global contrast, Local contrasts, Sharpness
Statistical naturalness (7) — new in CIQM<sub>ZN</sub>	Lightness entropy (En<sub>L</sub>), Hue entropy (En<sub>hue</sub>), Grayscale LBP entropies at 3 scales (En<sub>LBP₁</sub>, En<sub>LBP₀.₅</sub>, En<sub>LBP₀.₂₅</sub>), RGB-LBP entropy (En<sub>LBP_RGB</sub>), GLCM contrast (C<sub>GLCM</sub>)
Use these files to:

Extract features for a single image (CIQM<sub>ZN</sub>).

Extract ROI and nROI feature vectors (CIQM<sub>ZN_Saliency</sub>) once the saliency masks are available.

Note: For CIQM<sub>ZN_Saliency</sub>, the same 21 features are computed twice — once on the ROI region and once on the nROI region — producing f_ROI and f_nROI.

**2. generateSaliencyMapsonImages.m**

Generates normalized saliency maps for every image in a specified folder, using one of the supported saliency models. From each saliency map, ROI and nROI masks are obtained using mean thresholding (as described in the paper).

Supported saliency models:

Saliency model	Where to obtain the code
Itti	Provided in the Itti and Improved Itti/ folder
Improved Itti	Provided in the Itti and Improved Itti/ folder
CovSal, LDS, & EML-Net (Python-based code)	Download from https://saliency.tuebingen.ai/results.html

**How to use:**
Place the saliency model's code in the MATLAB path (or in the appropriate subfolder).

Edit the image-folder path and output-folder path inside generateSaliencyMapsonImages.m.

Run the script — the normalized saliency maps can be saved for later use with minor changes.


**3. Evaluation Scripts**

**Evaluation_SDB_CIQMzn.m**
Performs same-database (SDB) evaluation for the CIQM<sub>ZN</sub> metric.

Uses an 80:20 train–test split (by content, so no image content overlaps between train and test).

Repeats the random split 1,000 times and reports the median PLCC (Pearson Linear Correlation Coefficient).

SRCC (Spearman Rank-Order Correlation Coefficient) can also be enabled with a minor modification.

Use this file when you want to:

Reproduce the CIQM<sub>ZN</sub> baseline results (Table 2 in the paper).

Benchmark CIQM<sub>ZN</sub> on your own dataset using subjective MOS labels.

**Evaluation_SDB_CIQMzn_ROI.m**
Performs same-database (SDB) evaluation for the CIQM<sub>ZN_Saliency</sub> metric.

Trains two independent SVR models (RBF kernel) on the ROI and nROI feature vectors.

Estimates the fusion weight η via 5-fold inner cross-validation on the training set.

Final score: IQ = η · IQ_ROI + (1 − η) · IQ_nROI.

Same 80:20 / 1,000-iteration protocol as above; reports median PLCC.

Use this file when you want to:

Reproduce the saliency-guided results (Table 3 in the paper).

Compare the five saliency models (Itti, Improved Itti, CovSal, LDS, EML-Net) on your own data.

Evaluate the CIQM<sub>ZN_CovSal</sub> variant against literature IQMs (Table 4).


**4. Itti and Improved Itti/ Folder**

Contains the MATLAB source for the two baseline saliency models used in this work:

Itti — biologically inspired bottom-up model (intensity, color, orientation contrasts).

Improved Itti — extends Itti with additional texture and edge cues.

These are called by generateSaliencyMapsonImages.m. No external download is required for these two models.

**5. Images / Datasets**

Benchmark images (or subsets) and any associated MOS/DMOS label files for LIVE dataset are included so the evaluation scripts can be run out of the box. The MOS used in this study are rescaled to the median score of the CIDIQ dataset to align MOS from different datasets. For further details on rescaling the MOS, please refer to the following article
Khan M U, Mehmood I, & Luo M R.  No-Reference Generic Image Quality Assessment via Adaptive Fusion of Naturalness-Enhanced Color and Appearance Driven Spatial Metrics. IEEE Access, 2026, 14: 79811-79832.

If you use the full datasets, download them from their original sources:

LIVE – https://live.ece.utexas.edu/research/quality/

CSIQ – https://s2.smu.edu/~eclarson/csiq/

TID2013 – http://www.ponomarenko.info/tid2013.htm

CIDIQ – see the corresponding publications ([19] in the paper)

KADID – http://database.mmsp-kn.de/kadid-10k-database.html

ZJU, ZJUI, ZJU_Xu - Links will be made available once datasets made available online

TID2013 and KADID "Color Saturation" categories contain color-inverted images; the paper excludes these (2,839 / 9,949 images retained). Use the same exclusion when reproducing results.

**Quick-Start Workflow**

**Step 1**  →  Prepare images + MOS labels (place in a folder, update paths).
**Step 2**  →  [For CIQMzn]        Run feature-calculation script on all images.
               [For CIQMzn_Saliency] Run generateSaliencyMapsonImages.m to get masks,
                                     then run feature extraction on ROI and nROI.
**Step 3**  →  Run Evaluation_SDB_CIQMzn.m        (baseline CIQMzn)
               or  Evaluation_SDB_CIQMzn_ROI.m    (saliency-guided CIQMzn_Saliency).
**Step 4**  →  Read median PLCC (and SRCC) from the output.

**Notes & Tips**

**Content-exclusive splits:** The evaluation scripts split by original image content to prevent leakage. Keep this behavior if you adapt the code.

**Fusion weight η:** Estimated per-dataset via 5-fold inner-CV. If you have very few images, consider fixing η manually.

**Color space:** All appearance and naturalness features are computed in CIELAB / LCh (and sRGB for the RGB-LBP descriptor). Ensure input images are properly color-managed.

**LODO protocol:** Datasets sharing source images with the test set must be excluded from training (see Section Evaluation Protocol in the paper). The scripts include these exclusions for ZJU<sub>Xu</sub> ↔ {CIDIQ, KADID, ZJU} and ZJUI ↔ {CSIQ, TID2013, CIDIQ}.

**Reproducibility:** Random splits are seeded; results should be stable across runs.

**Citation**
If you use this code or the CIQM<sub>ZN</sub> / CIQM<sub>ZN_Saliency</sub> metrics in your research, please cite:

bibtex
@inproceedings{khan2025ciqmzn,
  title     = {Saliency-Guided No-Reference Image Quality Assessment using a
               Naturalness-Enhanced Color-domain Image Quality Metric},
  author    = {Khan, Muhammad Usman and Luo, Ming Ronnier and Mehmood, Imran},
  booktitle = {Color and Imaging Conference (CIC34)},
  year      = {2026}
}

**Contact**

For questions, bug reports, or collaboration inquiries, please open an Issue on this repository or contact the corresponding author.

**License**

Please refer to the repository's LICENSE file (if present). The saliency models downloaded from https://saliency.tuebingen.ai/results.html are subject to their respective licenses; please cite their original papers when using them.
