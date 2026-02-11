# Thesis EyeTracking (Refactored)

This is the organized version of the Thesis EyeTracking project.

## Quick Start

1.  **Place Data**: Put raw `.EDF` files in `data/raw/`.
2.  **Run Pipeline**:
    ```bash
    python src/analysis/python/run_full_pipeline.py
    ```

## Directory Structure

- **`data/`**: All data (raw, processed, results).
- **`src/`**: Source code (experiment, analysis).
- **`docs/`**: Documentation.

## Requirements

- **MATLAB**: Required for Experiment runs and initial data conversion/analysis.
- **Python**: Required for automation and final result aggregation.
- **MATLAB Engine for Python**: MUST be installed for the pipeline to run fully automatically.
    - If not installed, you will need to run the MATLAB analysis steps manually (see `docs/usage.md`).

For detailed instructions, see [docs/usage.md](docs/usage.md).
