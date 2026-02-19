# Quick Start: Full Pipeline (Updated)

This pipeline has been enhanced to produce **detailed, timestamped metrics** for deeper analysis.

**Script:** `src/analysis/python/run_full_pipeline.py`

## 🚀 How to Run

1.  **Prepare Data:**
    *   Place your raw `.EDF` files in `data/raw/`.

2.  **Execute:**
    *   Open your terminal in the project root.
    *   Run:
        ```bash
        python src/analysis/python/run_full_pipeline.py
        ```

## 📊 Expected Output

The script will automatically:
1.  Convert `.EDF` -> `.mat` (if you haven't already).
2.  Run `Analyze_eye_func_v2.m` on each subject.
3.  Generate inside `data/results/`:
    *   **`Subject_XXX.csv`**: Basic fixation sequence (AOIs only).
    *   **`Subject_XXX_detailed.csv`**: Full temporal data (Start, End, Duration, Coordinates).

## 💡 Analysis Tips

*   **For Strategy Analysis:** Use the `Subject_XXX_detailed.csv`.
    *   **Duration:** Use this to weight the importance of each fixation.
    *   **Gaps:** Calculate `StartTime(n+1) - EndTime(n)` to find movement times (Saccades).
    *   **Dispersion:** High `SD_X/SD_Y` might indicate uncertaintyor complex processing.
