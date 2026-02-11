# Project Architecture

This document outlines the structure and functionality of the Thesis EyeTracking project. The project is designed to run a "Variable Attribute Decision-Making Task" using Psychtoolbox and EyeLink, and subsequently process and analyze the eye-tracking data using a hybrid MATLAB/Python pipeline.

## System Overview

1.  **Experiment**: Written in MATLAB (Psychtoolbox). runs the decision-making task, communicates with the EyeLink eye tracker, and saves raw data (`.EDF`) and behavioral data (`.mat`).
2.  **Data Conversion**: `.EDF` files are converted to `.mat` structures (containing `edfStruct`) using `edfmex`.
3.  **Primary Analysis (MATLAB)**: The `Analyze_eye_func.m` function maps raw gaze coordinates to specific Areas of Interest (AOIs) blocks (Header, Attributes, Alternatives) to generate a sequence of fixations.
4.  **Secondary Analysis (Python)**: Python scripts automate the MATLAB analysis (via `matlab.engine`) and perform higher-level movement analysis (Horizontal vs. Vertical transitions) to classify decision strategies.

## Directory Structure

```graphql
Thesis_EyeTracking/
a"|
+-- 01_Experiment/          # Main experiment code (Psychtoolbox)
|   +-- DM_main_noa.m       # ENTRY POINT: Main experiment script
|   +-- instructions/       # Images for instructions
|   +-- Sub_*.mat           # Behavioral results files
|
+-- Eyedata/                # Raw and Intermediate Data storage
|   +-- sub_*.EDF           # Raw EyeLink data
|   +-- Subject_*_eyeData.mat # Converted EyeLink data (edfStruct)
|
+-- python_processing/      # Python analysis pipeline
|   +-- process_eye_data.py # ENTRY POINT: Batch processing script
|   +-- analyze_movements.py# Library for scanpath/transition analysis
|   +-- validation.ipynb    # Jupyter notebook for data validation
|   +-- requirements.txt    # Python dependencies
|
+-- function/               # Output directory for analysis CSVs
+-- Analyze_eye_func.m      # Core MATLAB analysis logic (converts gaze to AOIs)
+-- Analyze_eye_func_v2.m   # Version 2 of analysis logic
+-- classifyScanHV.m        # Helper for classifying search patterns
+-- main.py                 # Placeholder script
+-- README.md               # Project documentation
```

## Key Files & Modules

### 1. Experiment (`01_Experiment/`)

*   **`DM_main_noa.m`**: The heart of the data collection.
    *   **Setup**: Initializes Psychtoolbox window, defines colors, and connects to EyeLink.
    *   **Logic**: Runs 2 blocks of trials (3 attributes vs 4 attributes).
    *   **Stimuli**: Draws a dynamic grid table with Headers, Attributes, and Alternatives (A/B) on off-screen windows for efficiency.
    *   **Recording**: Check fixation, starts EyeLink recording, waits for response, and logs precision timing.
    *   **Output**: Saves `Subject_X_Results...mat` (behavioral) and `sub_X.EDF` (eye).

### 2. MATLAB Analysis (Root)

*   **`Analyze_eye_func.m`**:
    *   **Input**: A `.mat` file containing the `edfStruct` (raw eye data).
    *   **AOI Definition**: Defines the geometric coordinates for the screen layout (Header, Attribute columns, Alternatives A & B).
    *   **Logic**:
        *   Parses "TRIAL X SET Y" messages to sync with experiment blocks.
        *   Detects fixations based on gaze stability (via `mean` and `std` thresholding).
        *   Maps each fixation to a named cell (e.g., 'A1', 'AT2', 'F').
    *   **Output**: Generates a CSV file in the `function/` folder containing the sequence of fixations for each trial.

*   **`classifyScanHV.m`**:
    *   A helper script (likely used by older pipelines or reference) to calculate the Horizontal/Vertical index. *Note: Similar logic is reimplemented in Python's `analyze_movements.py`.*

### 3. Python Pipeline (`python_processing/`)

*   **`process_eye_data.py`**:
    *   **Role**: Automation Wrapper.
    *   **Function**: Finds all `Subject_*` files in `Eyedata/`, starts the MATLAB Engine API for Python, and calls `Analyze_eye_func` for every subject.

*   **`analyze_movements.py`**:
    *   **Role**: Data Analysis Library.
    *   **Function**: Reads the produced CSVs.
    *   **Logic**:
        *   Parses fixation transitions (e.g., A1 -> A2 is Vertical, A1 -> B1 is Horizontal).
        *   Calculates the **Payne Index** (Index = H / (H + V)) to determine if a user uses an "Attribute-based" (Horizontal) or "Alternative-based" (Vertical) strategy.

## Data Flow Summary

1.  **Run Experiment** (`DM_main_noa.m`) $\rightarrow$ Outputs `.EDF` & `.mat` (Behavioral).
2.  **Convert Data** (End of Experiment) $\rightarrow$ `.EDF` converted to `Subject_X_eyeData.mat`.
3.  **Process Data** (Run `python_processing/process_eye_data.py`) $\rightarrow$ Calls `Analyze_eye_func.m` $\rightarrow$ Outputs `Subject_X.csv` (Fixation Sequence).
4.  **Analyze Data** (Use functions in `analyze_movements.py`) $\rightarrow$ Reads `Subject_X.csv` $\rightarrow$ Outputs DataFrames with Strategy Indices (H/V).
