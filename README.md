# Thesis EyeTracking Project

This project implements a **Variable Attribute Decision-Making Task** using Psychtoolbox and EyeLink, followed by a comprehensive data analysis pipeline that combines MATLAB and Python.

## 📁 Directory Structure

```text
Thesis_EyeTracking/
+-- src/
|   +-- experiment/               # MATLAB code for the decision-making task (DM_main_noa.m)
|   +-- analysis/
|       +-- matlab/               # Core MATLAB analysis functions (Convert_eye_data.m)
|       +-- python/               # Automation scripts (run_full_pipeline.py, analyze_movements.py)
+-- data/                         # Data storage (ignored by Git)
|   +-- raw/                      # Raw eye-tracking and behavioral Results .mat files
|   +-- processed/
|       +-- fixations/            # Detailed fixation sequences (.csv)
|       +-- movements/            # Trial-by-trial movement logs (H/V/Ignored transitions) (.csv)
|   +-- final_results_summary.csv # Final aggregated Scanpath Index metrics
+-- .venv/                        # Python virtual environment
+-- uv.lock, pyproject.toml       # Python package configuration
```

## 🛠️ Installation & Setup

1. **Python Setup**: This project uses `uv` for fast and reproducible dependency management. From the project root, simply run:
   ```powershell
   uv sync
   ```
   This will create a `.venv` virtual environment and automatically install all required libraries, including the Python MATLAB Engine. This means that in this project there is no need for manual dependencies installation (It is already automatic within the uv).

   ```


2. **MATLAB Installation**: The Python pipeline relies on MATLAB Engine to process raw eye-tracking data. Support for the MATLAB Engine is installed automatically via `uv sync`, but you must ensure you have the actual MATLAB software installed (e.g., R2024b) on your computer.

## 🏗️ Architecture & Data Flow (Pipeline)

This project tracks the complete lifecycle from the live experiment to final classification logic:

### 1. Data Collection (Experiment)
* **Script**: `src/experiment/DM_main_noa.m`
* **Action**: Runs the decision-making task in Psychtoolbox. Records eye position and user selections, and saves the data directly into `.mat` format.
* **Outputs**: `data/raw/` contains the raw eye-tracking and behavioral `.mat` files (`Subject_[ID]_eyeData.mat` and `Subject_[ID]_Results_Decision_Strategy_Experiment.mat`).

### 2. Feature Extraction (MATLAB)
* **Script**: `src/analysis/matlab/Convert_eye_data.m`
* **Action**: Maps raw gaze coordinates to experiment Areas of Interest (AOIs) like the Header, Attributes, and Alternatives.
* **Output**: `data/processed/fixations/[ID]_detailed.csv` (contains a chronological sequence of AOI labels and exact fixation timings per trial).

### 3. Transition Analysis & Strategy Classification (Python)
* **Script**: `src/analysis/python/analyze_movements.py`
* **Action**: Reads the fixation sequences and bridges missing data (`NaN`s / blinks). It classifies direct ocular transitions as:
  - **Horizontal**: Comparing different alternatives on the same attribute (e.g., from `A1` to `B1`).
  - **Vertical**: Comparing different attributes within the same alternative (e.g., from `A1` to `A2`).
  - **Ignored**: Invalid or diagonal moves.
* **Outputs**:
  - Detailed trial transitions: `data/processed/movements/[ID]_movements.csv` (includes classification, `movement_time_ms`, and skipped NaN counts).
  - **Final Strategy Metrics**: Calculates the Scanpath Index (**H / (H + V)**) aggregated per trial and per block in `data/final_results_summary.csv`.

## 🚀 Usage Guide (How to Run)

To run the complete analysis, from Feature Extraction to final Scanpath Strategy Classification, execute:

```powershell
uv run src/analysis/python/run_full_pipeline.py
```

**What this does under the hood:**
1. Starts the MATLAB Engine to run `Convert_eye_data`.
2. Processes all new unprocessed `.mat` files into fixation `.csv`s.
3. Automatically triggers `analyze_movements.py` to classify all scanpath transitions for each subject.
4. Aggregates and updates `data/final_results_summary.csv` with the newly calculated `Scanpath_Index` scores for statistical analysis.

## ❓ Troubleshooting

- **Path Issues / File Not Found**: Always execute `uv run` commands from the **root** folder (`Thesis_EyeTracking`).