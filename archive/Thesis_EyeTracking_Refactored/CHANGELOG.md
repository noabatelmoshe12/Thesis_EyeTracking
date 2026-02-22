# Changelog

## [2026-02-17] - Enhanced Fixation Analysis (v2)

### Changed
- **Core Function Update (`Convert_eye_data.m`):**
    - *Note: Renamed from Analyze_eye_func_v2.m and Analyze_eye_func.m in Feb 2026*
    - This version is based directly on the original `Analyze_eye_func.m` (now `Convert_eye_data.m`).
    - The analytical logic remains unchanged; fixation detection and thresholds are identical.
    - The only functional change is the addition of an extra fixation-level CSV export.
    - **No changes** were made to the core detection thresholds (`min_sacc=10`, `min_sample=20`) to maintain backward compatibility with previous pilot data.

### Added
- **New Additional CSV Output (Fixation-Level Data):**
    - The function now produces an extra CSV file (`Subject_XXX_detailed.csv`)
      containing fixation-level temporal and spatial metrics.
    - This file supplements the original sequence output rather than replacing it.
    - Columns include:
        - `StartTime_ms`, `EndTime_ms`: Exact timing relative to stimulus onset.
        - `Duration_ms`: Crucial for weighting strategy analysis (Cognitive Load).
        - `SampleCount`: Raw number of gaze samples in the fixation.
        - `Mean_X`, `Mean_Y`: Geometric center of the fixation.
        - `SD_X`, `SD_Y`: Dispersion metrics (fixation stability).
- **Automation Pipeline Update:**
    - `src/analysis/python/process_eye_data.py` was updated to call the new `v2` function.
    - Added automatic path handling for the new `src/analysis/matlab` directory structure.



