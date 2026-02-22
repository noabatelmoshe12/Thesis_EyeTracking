# Usage Guide

This guide provides detailed instructions for running the **Thesis EyeTracking** project, from data collection to final analysis.

## 1. Environment Setup

### Install Dependencies
Ensure you are in the project root directory and run:

```powershell
uv sync
```

This installs all Python dependencies, including `pandas`, `jupyter`, and the `matlabengine`.

### MATLAB Configuration
Ensure you have the **MATLAB Engine API for Python** installed. This allows Python scripts to control MATLAB sessions directly.
*   The project currently expects MATLAB R2024b (Engine version `25.1.*`).

---

## 2. Running the Experiment

The experiment is written in MATLAB using the Psychtoolbox framework.

1.  Open **MATLAB**.
2.  Navigate to `src/experiment/`.
3.  Run the main experimental script:
    ```matlab
    DM_main_noa
    ```
4.  Follow the on-screen instructions to calibrate the EyeLink and run the blocks.
5.  **Output**:
    -   Raw EyeLink data: `data/raw/sub_[ID].EDF`
    -   Behavioral data: `data/raw/Subject_[ID]_Results...mat`

---

## 3. Data Analysis Pipeline

The analysis pipeline is automated using Python (`src/analysis/python/run_full_pipeline.py`).

### Automatic Execution
Run the full pipeline with a single command:

```powershell
uv run src/analysis/python/run_full_pipeline.py
```

### Pipeline Steps (What happens under the hood?)

#### Step A: Data Conversion
*   **Input**: `data/raw/*.EDF`
*   **Action**: Converts proprietary EyeLink files to MATLAB `.mat` files.
*   **Tool**: `edfmex` (via MATLAB Engine).
*   **Output**: `data/processed/Subject_[ID]_eyeData.mat`

#### Step B: Feature Extraction (MATLAB)
*   **Input**: `data/processed/Subject_[ID]_eyeData.mat`
*   **Action**: Maps raw gaze coordinates to experiment Areas of Interest (AOIs).
*   **Script**: `src/analysis/matlab/Convert_eye_data.m`
*   **Output**:
    -   Fixation sequence CSV: `data/results/[ID]_fixations.csv`
    -   Long-format data CSV: `data/results_longformat/[ID]_detailed.csv`

#### Step C: Strategy Classification (Python)
*   **Input**: Fixation sequence CSVs.
*   **Action**: Calculates the **Payne Index** (Horizontal vs. Vertical transitions).
*   **Script**: `src/analysis/python/analyze_movements.py`
*   **Output**: `data/final_results_summary.csv`

---

## 4. Troubleshooting

### MATLAB Engine Errors
*   **Error**: `No module named 'matlab'` or `matlab.engine`.
*   **Fix**: Ensure you installed the engine for your specific MATLAB version.
    ```powershell
    cd "C:\Program Files\MATLAB\R2024b\extern\engines\python"
    uv pip install .
    ```

### Path Issues
*   Always run `uv` commands from the **root** folder (`Thesis_EyeTracking`).
*   If scripts fail to find files, check that your `data/` directory structure matches the expected layout (`raw`, `processed`, `results`).

### "edfmex" Not Found
*   If the automatic conversion fails, it might be because `edfmex` is not in the system path or recognized by the engine.
*   **Workaround**: Manually convert `.EDF` files to `.mat` using the EyeLink GUI tool or `edfmex` in MATLAB, then place the `.mat` files in `data/processed/`.

Note:
As of Feb 2026, the MATLAB conversion step uses Convert_eye_data.m instead of Analyze_eye_func_v2.m.