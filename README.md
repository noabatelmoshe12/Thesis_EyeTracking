# Thesis EyeTracking Project

This project implements a **Variable Attribute Decision-Making Task** using Psychtoolbox and EyeLink, followed by a comprehensive data analysis pipeline that combines MATLAB and Python.

##  Quick Start

### Prerequisites
1.  **Python**: Managed via `uv`.
2.  **MATLAB**: Required for experiment execution and raw data processing.
    - **Psychtoolbox**: Must be installed for the experiment.
    - **MATLAB Engine API for Python**: Required for the analysis pipeline (`matlab.engine`).

### Installation

To set up the Python environment with all dependencies:

```powershell
uv sync
```

### Running the Analysis

To run the complete analysis pipeline (Data Conversion -> Feature Extraction -> Strategy Classification):

```powershell
uv run src/analysis/python/run_full_pipeline.py
```

This single command will:
1.  **Convert** raw `.EDF` files to `.mat` format.
2.  **Process** gaze data to identify fixations on specific Areas of Interest (AOIs).
3.  **Analyze** scanpaths to classify decision-making strategies (Attribute-based vs. Alternative-based).
4.  **Output** final results to `data/final_results_summary.csv`.

---

## 📂 Project Structure

The project is organized as follows:

-   **`src/`**: Source code for the project.
    -   `experiment/`: MATLAB code for the decision-making task (`DM_main_noa.m`).
    -   `analysis/`:
        -   `matlab/`: Core analysis functions (`Convert_eye_data.m`).
        -   `python/`: Automation scripts and higher-level analysis (`run_full_pipeline.py`, `analyze_movements.py`).
-   **`data/`**: Data storage (ignored by git).
    -   `raw/`: Raw `.EDF` files from the EyeLink.
    -   `processed/`: Converted `.mat` files and intermediate CSVs.
    -   `results/`: Final output files.
-   **`docs/`**: Detailed documentation.
-   **`archive/`**: Old project files and previous versions (kept for reference).

---

## 📚 Documentation

For more detailed information, please refer to the documentation in the `docs/` folder:

-   **[📖 Usage Guide](docs/usage_guide.md)**: Detailed instructions on running experiments, manual data processing, and troubleshooting.
-   **[🏗️ Architecture Overview](docs/architecture.md)**: In-depth explanation of the system design, data flow, and key algorithms.



Pipeline Update – Feb 2026

The MATLAB function previously named `Analyze_eye_func_v2` has been renamed to `Convert_eye_data`.

The function's role remains the same: converting processed eye-tracking data into analysis-ready fixation tables.
However, the simple AOI-sequence CSV output has been disabled, and the function now produces only a detailed fixation-level CSV file.

All scripts that previously called `Analyze_eye_func_v2` should now call `Convert_eye_data`.