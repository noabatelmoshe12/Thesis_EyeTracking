# Eye Tracking Analysis - Python Automation

This project automates the processing of MATLAB Eye Tracking data and performs scanpath analysis.

## Setup

1.  **Python Environment**:
    This project uses `uv` for dependency management.
    ```bash
    cd python_processing
    # Sync dependencies (creates .venv if needed)
    uv sync
    ```
    *(Note: `pandas`, `jupyter` and `matlabengine` are required.)*

2.  **MATLAB Engine for Python**:
    The project requires `matlabengine` version 25.1. This is managed via `uv`, but ensure your local MATLAB installation is compatible if building from source.
    
    If you need to install it manually or check the version:
    ```bash
    uv add "matlabengine==25.1.*"
    ```
    
    To verify the connection:
    ```bash
    uv run python -c "import matlab.engine; print('MATLAB Engine verified')"
    ```

## Usage

### 1. Automation (`process_eye_data.py`)
Iterates over subject `.mat` files in `../Eyedata`, calls `Analyze_eye_func.m`, and generates CSV files in `../function`.
```bash
python process_eye_data.py
```

### 2. Analysis & Validation (`validation.ipynb`)
Run the Jupyter notebook to:
- Verify the CSV generation.
- Perform the "Horizontal vs Vertical" scanpath analysis.
- Visualize the results.

## Analysis Logic
The `analyze_movements.py` script implements the following logic (matching `classifyScanHV.m`):
- **Vertical (V)**: Movement between same column letters but different row numbers (e.g., A1 -> A2).
- **Horizontal (H)**: Movement between different column letters but same row numbers (e.g., A1 -> B1).
- **Other**: Diagonal moves or moves involving non-matrix elements.
