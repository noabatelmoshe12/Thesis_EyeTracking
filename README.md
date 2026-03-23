# Thesis EyeTracking Project

This project implements a **Variable Attribute Decision-Making Task** using Psychtoolbox and EyeLink, followed by a comprehensive data analysis pipeline that combines MATLAB and Python.

##  Directory Structure

```text
Thesis_EyeTracking/
+-- src/
|   +-- experiment/               # MATLAB code for the decision-making task (DM_main_noa.m)
|   +-- analysis/
|       +-- matlab/               # Core MATLAB analysis functions (Convert_eye_data.m)
|       +-- python/               # Automation scripts (run_full_pipeline.py, analyze_movements.py)
+-- data/                         # Data storage (ignored by Git)
|   +-- raw/                      # Subject-level MATLAB input files (eyeData, behavioral results, demographics)
|   +-- processed/
|       +-- fixations/            # Detailed fixation sequences (.csv)
|       +-- movements/            # Trial-by-trial movement logs (H/V/Ignored transitions) (.csv)
|   +-- final_results_summary.csv # Final aggregated Scanpath Index metrics
+-- .venv/                        # Python virtual environment
+-- uv.lock, pyproject.toml       # Python package configuration
```

##  Installation & Setup

1. **Python Setup**: This project uses `uv` for fast and reproducible dependency management. From the project root, run:

   ```powershell
   uv sync

   This will create a `.venv` virtual environment and automatically install all required libraries, including the Python MATLAB Engine. This means that in this project there is no need for manual dependencies installation (It is already automatic within the uv).

   ```


2. **MATLAB Installation**: The Python pipeline relies on MATLAB Engine to process raw eye-tracking data. Support for the MATLAB Engine is installed automatically via `uv sync`, but you must ensure you have the actual MATLAB software installed (e.g., R2024b) on your computer.

##  Architecture & Data Flow (Pipeline)

This project tracks the complete lifecycle from the live experiment to final classification logic:

### 1. Data Collection (Experiment)
* **Script**: `src/experiment/DM_main_noa.m`
* **Action**: Runs the decision-making task in Psychtoolbox, records eye position and behavioral responses, and saves subject-level output files for downstream analysis.
* **Outputs**: `data/raw/` contains subject-level files such as `Subject_[ID]_eyeData.mat`, `Subject_[ID]_Results_Decision_Strategy_Experiment.mat`, and demographics files when available.

### 2. Feature Extraction (MATLAB)
* **Script**: `src/analysis/matlab/Convert_eye_data.m`
* **Action**: Detects fixations from gaze samples, maps each fixation to predefined Areas of Interest (AOIs), and exports a detailed fixation-level CSV for downstream analysis.
* **Output**: `data/processed/fixations/[ID]_detailed.csv` (contains a chronological sequence of AOI labels and exact fixation timings per trial).

### 3. Transition Analysis & Strategy Classification (Python)
* **Script**: `src/analysis/python/analyze_movements.py`
* **Action**: Reads the fixation sequences and, for each trial, examines **only consecutive fixation pairs** in the original recorded order (FixationSeq i and i+1). There is **no bridging** over invalid AOIs (e.g., NaNs, blinks, or labels that do not match ATi/Ai/Bi), and invalid pairs are simply ignored and never turned into later inferred movements. A movement is recorded only when both AOIs in the consecutive pair are valid (ATi, Ai, or Bi) and their labels differ. Each valid pair is then classified as:
*  - **Horizontal**: Two **different** valid AOIs with the **same row index**, even if the kinds differ (e.g., `A1 -> B1`, `AT1 -> B1`, `A1 -> AT1`).
*  - **Vertical**: Same AOI kind **within an alternative** (only `A`→`A` or `B`→`B`) with **different row indices** (e.g., `A1 -> A3`, `B2 -> B4`).
*  - **Ignored**: Any other valid transition that is neither Horizontal nor Vertical (e.g., `A1 -> B2`).

  Examples that illustrate this logic:
  - `AT1 -> B1` is classified as **Horizontal**.
  - `A1 -> A3` is classified as **Vertical**.
  - `A1 -> B2` is classified as **Ignored**.
  - `AT1 -> AT1` produces **no movement** (identical AOIs are skipped).
  - `AT1 -> NaN -> B1` produces **0 movements**, because only the consecutive pairs `(AT1, NaN)` and `(NaN, B1)` are checked, and both involve an invalid AOI.

* **Outputs**:
*  - Detailed trial transitions: `data/processed/movements/[ID]_movements.csv` (one row per recorded movement, including classification, raw AOI labels, fixation order indices, and three timing fields: `From_StartTime_ms`, `To_StartTime_ms`, and `InterFixationInterval_ms = To_StartTime_ms - From_StartTime_ms`).
*  - **Final Strategy Metrics**: Calculates the Scanpath Index (**H / (H + V)**) aggregated per trial and per block in `data/final_results_summary.csv`.

##  Usage Guide (How to Run)

To run the complete analysis, from Feature Extraction to final Scanpath Strategy Classification, execute:

```powershell
uv run src/analysis/python/run_full_pipeline.py
```

**What this does under the hood:**
1. Starts the MATLAB Engine to run `Convert_eye_data`.
2. Processes all detected subject `.mat` files into fixation `.csv` files.
1. Automatically triggers `analyze_movements.py` to classify all scanpath transitions for each subject.
2. Aggregates and updates `data/final_results_summary.csv` with the newly calculated `Scanpath_Index` scores for statistical analysis.

##  Troubleshooting

- **Path Issues / File Not Found**: Always execute `uv run` commands from the **root** folder (`Thesis_EyeTracking`).


##  Active Pipeline Scripts

- `src/experiment/DM_main_noa.m` — experiment runtime
- `src/analysis/matlab/Convert_eye_data.m` — fixation extraction and AOI mapping
- `src/analysis/python/analyze_movements.py` — transition classification and scanpath metrics
- `src/analysis/python/run_full_pipeline.py` — full end-to-end pipeline runner