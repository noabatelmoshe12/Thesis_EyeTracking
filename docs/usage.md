# Thesis EyeTracking Project - Usage Guide

This project is organized to separate experiments, analysis code, and data.

## Directory Structure
... (same as before)

## FAST START: Full Pipeline

I have created a single script to run the entire analysis pipeline (Conversion -> Analysis -> Aggregation).

1.  **Place Data**: Put your raw `.EDF` files in `data/raw/`.
2.  **Run Pipeline**:
    ```bash
    python src/analysis/python/run_full_pipeline.py
    ```

**What this script does:**
1.  **Converts Data**: Checks `data/raw` for `.EDF` files. If they haven't been processed, it attempts to convert them to `.mat` using MATLAB (`edfmex`).
    - *Note: This requires `edfmex` to be installed and accessible in your MATLAB environment.*
2.  **Analyzes Fixations**: Runs `Analyze_eye_func.m` on all `.mat` files in `data/processed/`.
    - Generates sequences in `data/results/`.
    - Generates detailed data in `data/results_longformat/`.
3.  **Aggregates Results**: Reads all sequences and calculates the Horizontal/Vertical search strategies.
    - Saves the final summary to **`data/final_results_summary.csv`**.

---

## Detailed / Manual Workflow

### 1. Run Experiment
To run the experiment, open MATLAB and navigate to `src/experiment/`.
Run the main script:
```matlab
DM_main_noa
```
This will generate `.EDF` files in `data/raw/` (check the script configuration if it saves elsewhere by default).

### 2. Convert Data (If Pipeline Fails)
If the automated pipeline fails to convert data (e.g., `edfmex` not found), convert manually:
1.  Use `edfmex` or EyeLink Converter to create `.mat` files from `.EDF` files.
2.  Name them `Subject_[ID]_eyeData.mat`.
3.  Place them in `data/processed/`.

### 3. Run Analysis Pipeline (Step-by-Step)
You can also run the analysis without conversion/aggregation:
```bash
python src/analysis/python/process_eye_data.py
```

## Troubleshooting
- **MATLAB Engine**: Ensure you have the MATLAB Engine for Python installed.
- **Paths**: The scripts use relative paths. Ensure you run them from their respective directories or adjust the working directory.
- **edfmex**: If conversion fails, ensure `edfmex` is in your MATLAB path or convert files manually.
