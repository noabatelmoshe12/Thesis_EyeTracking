# How to Run the Project Environment

This guide explains how to use the modern Python environment (`uv`) to run the eye-tracking analysis pipeline.

## 1. Initial Setup (One-Time)

Before running any scripts, ensure you are in the project root directory (`Thesis_EyeTracking`) and initialize the environment.

```powershell
# Installs all dependencies (pandas, matlabengine, etc.)
uv sync
```

This creates a virtual environment in `.venv`.

## 2. Running the Analysis Pipeline

The main script automates the MATLAB analysis. It finds new subject files in `Eyedata/` and processes them.

**Command:**
```powershell
# Run from the project root
uv run python_processing/process_eye_data.py
```

**What this does:**
1.  Starts the MATLAB Engine in the background.
2.  Connects to your `Analyze_eye_func.m` script.
3.  Converts `.mat` files to CSVs in the `function/` folder.

## 3. Running  Analysis (Classification)

To generate the  scanpath classification metrics (Horizontal vs Vertical scan index), run the analysis script. This script implements the logic from `classifyScanHV.m` purely in Python.

**Command:**
```powershell
uv run python_processing/run_final_analysis.py
```

**What this does:**
1.  Reads the processed CSV files from the `function/` folder.
2.  Classifies movements as Horizontal, Vertical, or Other.
3.  Calculates the H/(H+V) index for each trial/block.
4.  Saves the consolidated results to `final_results.csv` in the project root.

## 4. Running Interactive Analysis (Jupyter)

To explore the data, validate results, or tweak the analysis logic interactively, use the Jupyter Notebook.

**Command:**
```powershell
# Starts the Jupyter interface
uv run jupyter notebook python_processing/validation.ipynb
```

## 5. Troubleshooting

*   **MATLAB Engine Error**: If you see an error about `matlab.engine`, ensure your MATLAB version matches the library version (currently configured for R2024b / 25.1).
*   **Path Issues**: Always run `uv run` commands from the **root** folder (`Thesis_EyeTracking`) to ensure all paths are resolved correctly.

## 6. Quick Reference

| Task | Command |
| :--- | :--- |
| **Sync/Install** | `uv sync` |
| **Process Data** | `uv run python_processing/process_eye_data.py` |
| **Final Analysis** | `uv run python_processing/run_final_analysis.py` |
| **Open Notebook**| `uv run jupyter notebook` |
| **Check Python** | `uv run python --version` |
