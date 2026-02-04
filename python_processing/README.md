# Eye Tracking Analysis - Python Automation

This project automates the processing of MATLAB Eye Tracking data and performs scanpath analysis.

## Setup

1.  **Python Environment**:
    This project uses a virtual environment.
    ```bash
    cd python_processing
    python -m venv .venv
    .venv\Scripts\activate
    pip install -r requirements.txt
    ```
    *(Note: `pandas` and `jupyter` are required.)*

2.  **MATLAB Engine for Python**:
    For the automation script (`process_eye_data.py`) to work, you must install the MATLAB Engine API for Python.
    
    -   **Option A**: PyPI (for newer MATLAB versions)
        ```bash
        pip install matlabengine
        ```
    -   **Option B**: From MATLAB root
        Navigate to your MATLAB installation folder, e.g., `C:\Program Files\MATLAB\R2023b\extern\engines\python` and run:
        ```bash
        python setup.py install
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
