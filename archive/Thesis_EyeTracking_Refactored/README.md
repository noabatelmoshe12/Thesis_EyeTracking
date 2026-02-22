# Thesis EyeTracking 

This is the organized version of the Thesis EyeTracking project, designed to analyze decision-making strategies through eye movement patterns.

##  Key Features (Updated Feb 2026)

*   **Automated Pipeline:** Full automation from raw `.EDF` to final analysis using Python & MATLAB integration.
*   **Dual Output Formats:**
    *   **Sequence (Wide):** Traditional sequence of AOIs (e.g., A1 -> B1 -> A2).
    *   **Detailed (Long Format):** A comprehensive, tidy-data table containing precise temporal and spatial metrics for every single fixation.
*   **Advanced Metrics:** Now captures Fixation Duration, Exact Start/End Times, Geometric Mean (X,Y), and Dispersion (SD).

##  Directory Structure

*   **`data/`**:
    *   `raw/`: Place raw `.EDF` files here.
    *   `processed/`: Converted `.mat` files.
    *   `results/`: Final CSV outputs (both simple and detailed).
*   **`src/`**:
    *   `analysis/matlab/`: Core algorithms (including `Convert_eye_data.m` - *Note: Renamed from Analyze_eye_func_v2.m in Feb 2026*).
    *   `analysis/python/`: Automation scripts (`process_eye_data.py`).

##  Output Explaination

The pipeline generates two files per subject:
1.  **`Subject_XXX.csv`**: Simple sequence of AOIs.
2.  **`Subject_XXX_detailed.csv`** 
    *   `Block` / `Trial`: Experiment phases.
    *   `AOI`: Area of Interest label.
    *   `StartTime_ms` / `EndTime_ms`: Precise timestamps relative to stimulus onset.
    *   `Duration_ms`: Integration of gaze time (Cognitive Load proxy).
    *   `Mean_X` / `Mean_Y`: Exact landing position of the gaze.
    *   `SD_X` / `SD_Y`: Fixation stability (Dispersion).

##  Requirements

*   **MATLAB**: Required for core fixation algorithms.
*   **Python**: Drives the automation.
*   **MATLAB Engine for Python**: Must be installed for the scripts to communicate.

## Quick Start

1.  **Place Data**: Put `.EDF` files in `data/raw/`.
2.  **Run**:
    ```bash
    python src/analysis/python/run_full_pipeline.py
    ```
## Expected Output

The script will automatically:
1.  Convert `.EDF` -> `.mat` (if you haven't already).
2.  Run `Convert_eye_data.m` on each subject.
3.  Generate inside `data/results/`:
    *   **`Subject_XXX.csv`**: Basic fixation sequence (AOIs only).
    *   **`Subject_XXX_detailed.csv`**: Full temporal data (Start, End, Duration, Coordinates).

##  Analysis Tips

*   **For Strategy Analysis:** Use the `Subject_XXX_detailed.csv`.
    *   **Duration:** Use this to weight the importance of each fixation.
    *   **Gaps:** Calculate `StartTime(n+1) - EndTime(n)` to find movement times (Saccades).
    *   **Dispersion:** High `SD_X/SD_Y` might indicate uncertaintyor complex processing.