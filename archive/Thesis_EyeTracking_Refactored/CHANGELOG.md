# Changelog

This project adheres to Semantic Versioning.

## [Unreleased]

## [2026-02-17] - Enhanced Fixation Analysis (v2)

### Changed
- **Core Algorithm Update (`Analyze_eye_func_v2.m`):**
    - Transitioned from a legacy script (`Analyze_eye_old.m`) to a robust, reusable function.
    - Added logic to capture **precise temporal and spatial metrics** for every valid fixation before they are aggregated into sequences.
    - **No changes** were made to the core detection thresholds (`min_sacc=10`, `min_sample=20`) to maintain backward compatibility with previous pilot data.

### Added
- **Detailed Data Export (Long Format):**
    - The function now generates a secondary CSV file: `Subject_XXX_detailed.csv`.
    - Columns include:
        - `StartTime_ms`, `EndTime_ms`: Exact timing relative to stimulus onset.
        - `Duration_ms`: Crucial for weighting strategy analysis (Cognitive Load).
        - `SampleCount`: Raw number of gaze samples in the fixation.
        - `Mean_X`, `Mean_Y`: Geometric center of the fixation.
        - `SD_X`, `SD_Y`: Dispersion metrics (fixation stability).
- **Automation Pipeline Update:**
    - `src/analysis/python/process_eye_data.py` was updated to call the new `v2` function.
    - Added automatic path handling for the new `src/analysis/matlab` directory structure.

### Validation
- Validated on `Subject_991` data.
- Confirmed that the "Detailed" output accurately reflects raw sample counts and valid time ranges (e.g., `Duration` matches `EndTime - StartTime`).

### Purpose
- **Research Goal:** To enable advanced decision strategy analysis (e.g., weighted transitions, dwell time analysis) which requires exact duration and timing data, not just sequence order.
