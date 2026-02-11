# Quick Start: Full Pipeline

I have created a single script to run the entire pipeline:

**Script:** `src/analysis/python/run_full_pipeline.py`

**Usage:**
1.  Place raw `.EDF` files in `data/raw/`.
2.  Run:
    ```bash
    python Thesis_EyeTracking_Refactored/src/analysis/python/run_full_pipeline.py
    ```

**What it does:**
- Converts `.EDF` to `.mat` (if needed, using MATLAB).
- Runs fixation analysis (MATLAB).
- Aggregates results into `data/final_results_summary.csv`.
