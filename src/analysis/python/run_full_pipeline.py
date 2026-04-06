"""
Thesis Eye Tracking Data Pipeline

This module serves as the *primary entry point* and orchestrator for the entire eye-tracking
analysis workflow. It manages the transition of raw data through various processing steps 
to produce the final aggregated scanpath metrics.

Workflow Steps:
     1. Environment & Paths:
         Resolves the project root from the script location and builds absolute paths for
         data folders and output files.
     2. Directory Validation:
         Ensures required directories exist: data/raw, data/processed, and data/results.
     3. MATLAB Processing:
         a) Preferred path: Starts MATLAB Engine, scans Subject_*_eyeData.mat files, and
             runs Convert_eye_data for each detected subject.
         b) Fallback path: If engine is unavailable but MATLAB CLI exists, runs
             matlab -batch run_batch_analysis from the MATLAB scripts directory.
     4. Python Aggregation:
         Loads non-empty fixation CSV files from data/processed/fixations, converts each
         subject's fixations into movement sequences with process_fixations_to_movements,
         and accumulates valid movement tables.
     5. Final Metrics & Export:
         Concatenates all movement data, computes final indices with
         calculate_scanpath_index, and saves block-level summary output to
         data/block_results_summary.csv.

Requirements:
        - MATLAB Engine API (matlab.engine) or a system-accessible matlab CLI command.
        - Local module analyze_movements that provides:
            process_fixations_to_movements and calculate_scanpath_index.

Historical Notes:
    - Modified in Feb 2026: The core MATLAB processing script `Analyze_eye_func_v2` 
      was refactored and renamed to `Convert_eye_data`.
"""

import os  # Path handling, directory checks, and file discovery support.
import glob  # Finds raw and processed data files using wildcard patterns.
import sys  # Extends the import path so local analysis modules can be loaded.
import shutil  # Checks whether the MATLAB CLI is available on the system.
import pandas as pd  # Combines and exports the aggregated analysis results.
import time  # Reserved for timing or future pipeline performance measurements.
import subprocess  # Runs the MATLAB CLI fallback when the engine is unavailable.

try: # Attempt to load MATLAB Engine
    import matlab.engine
except ImportError:
    print("Warning: 'matlab.engine' could not be imported. MATLAB steps will be skipped.")
    matlab = None

# Add current directory to path to import local modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
try:
    from analyze_movements import process_fixations_to_movements, calculate_scanpath_index
except ImportError:
    # If running from root, might need adjustment, but script location + sys.path append should work
    print("Warning: Could not import 'analyze_movements'. Final aggregation might fail.")

def setup_paths():
    """
    Step 1 — Environment & Paths.

    Resolves the project root from the script location and builds absolute paths
    for data folders and output files.

    Returns a dict with keys: project_root, raw_dir, processed_dir, results_dir,
    trial_results_file, block_results_file, matlab_script_dir.
    """
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(script_dir, "..", "..", ".."))

    raw_dir = os.path.join(project_root, "data", "raw")
    processed_dir = os.path.join(project_root, "data", "processed")
    results_dir = os.path.join(project_root, "data", "results")
    trial_results_file = os.path.join(results_dir, "trial_results_summary.csv")
    block_results_file = os.path.join(results_dir, "block_results_summary.csv")
    matlab_script_dir = os.path.join(project_root, "src", "analysis", "matlab")

    print(f"--- Thesis EyeTracking Pipeline ---")
    print(f"Project Root: {project_root}")

    return {
        "project_root": project_root,
        "raw_dir": raw_dir,
        "processed_dir": processed_dir,
        "results_dir": results_dir,
        "trial_results_file": trial_results_file,
        "block_results_file": block_results_file,
        "matlab_script_dir": matlab_script_dir,
    }


def validate_directories(paths):
    """
    Step 2 — Directory Validation.

    Ensures required directories exist: data/raw, data/processed, and data/results.
    Creates any that are missing.
    """
    for d in [paths["raw_dir"], paths["processed_dir"], paths["results_dir"]]:
        if not os.path.exists(d):
            os.makedirs(d)
            print(f"Created directory: {d}")


def run_matlab_processing(paths):
    """
    Step 3 — MATLAB Processing.

    a) Preferred path: Starts MATLAB Engine, scans Subject_*_eyeData.mat files,
       and runs Convert_eye_data for each detected subject.
    b) Fallback path: If engine is unavailable but MATLAB CLI exists, runs
       matlab -batch run_batch_analysis from the MATLAB scripts directory.
    """
    raw_dir = paths["raw_dir"]
    project_root = paths["project_root"]
    matlab_script_dir = paths["matlab_script_dir"]

    eng = None
    if matlab:
        print("Starting MATLAB Engine...")
        eng = matlab.engine.start_matlab()
        eng.cd(matlab_script_dir, nargout=0)
        eng.addpath(matlab_script_dir, nargout=0)
        print("MATLAB Engine started.")

    pattern = os.path.join(raw_dir, "Subject_*_eyeData.mat")
    mat_files = glob.glob(pattern)
    print(f"Found {len(mat_files)} subject .mat files to process.")

    for mat_path in mat_files:
        filename = os.path.basename(mat_path)
        try:
            parts = filename.split('_')
            subject_idx = parts.index("Subject") + 1
            subject_code = parts[subject_idx]

            if not subject_code.isdigit():
                 print(f"  Skipping {filename}: Could not parse subject code.")
                 continue

            print(f"Processing Subject {subject_code}...")

            if eng:
                try:
                    eng.Convert_eye_data(mat_path, subject_code, project_root, nargout=0)
                    print(f"  Done.")
                except Exception as e:
                    print(f"  Analysis failed for {subject_code}: {e}")
            else:
                 print("  Skipping analysis (No MATLAB Engine).")

        except ValueError:
            print(f"  Skipping {filename}: format mismatch.")

    if eng:
        eng.quit()
    elif shutil.which("matlab"):
        print("\n[Step 2/3 Alternative] Running Fixation Analysis via MATLAB CLI...")
        print("  Can't open MATLAB Engine, calling 'matlab -batch run_batch_analysis'...")

        cmd = [
            "matlab",
            "-sd", matlab_script_dir,
            "-batch",
            "run_batch_analysis"
        ]

        try:
            subprocess.run(cmd, check=True)
            print("  Batch Analysis completed via CLI.")
        except subprocess.CalledProcessError as e:
            print(f"  Error running MATLAB via CLI: {e}")
    else:
        print("  Matlab Engine not found AND 'matlab' command not found. Skipping analysis.")


def aggregate_fixations(paths):
    """
    Step 4 — Python Aggregation.

    Loads non-empty fixation CSV files from data/processed/fixations, converts each
    subject's fixations into movement sequences with process_fixations_to_movements,
    and accumulates valid movement tables.

    Returns a list of movement DataFrames (may be empty).
    """
    print("\n[Step 3/3] Aggregating Results (CSV -> Summary)...")

    fixations_dir = os.path.join(paths["processed_dir"], "fixations")
    csv_files = glob.glob(os.path.join(fixations_dir, "*.csv"))
    csv_files = [f for f in csv_files if os.path.getsize(f) > 0]

    if not csv_files:
        print(f"No result CSVs found in {fixations_dir}.")
        return []

    all_movements = []
    for csv_path in csv_files:
        filename = os.path.basename(csv_path)
        subject_id = os.path.splitext(filename)[0]

        subject_id = subject_id.replace("_detailed", "")
        if not subject_id[0].isdigit():
             continue

        try:
            trial_idx, block_idx, df = process_fixations_to_movements(subject_id, csv_path)
            if not df.empty:
                all_movements.append(df)
        except Exception as e:
            print(f"  Error aggregating {subject_id}: {e}")

    return all_movements


def export_results(all_movements, paths):
    """
    Step 5 — Final Metrics & Export.

    Concatenates all movement data, computes final indices with
    calculate_scanpath_index, and saves trial-level and block-level summaries.
    """
    if not all_movements:
        print("No valid movement data found to aggregate.")
        return

    total_movements = pd.concat(all_movements, ignore_index=True)
    trial_results, block_results = calculate_scanpath_index(total_movements)

    trial_results.to_csv(paths["trial_results_file"], index=False, na_rep='NaN')
    block_results.to_csv(paths["block_results_file"], index=False, na_rep='NaN')

    print(f"\nPipeline Complete!")
    print(f"Trial summary saved to: {paths['trial_results_file']}")
    print(f"Block summary saved to: {paths['block_results_file']}")
    print("\nBlock-level preview:")
    print(block_results.to_string())


def run_full_pipeline():
    """
    Main execution function for the eye-tracking pipeline.

    Orchestrates the sequential execution of environment validation,
    raw data parsing via MATLAB, and feature extraction via Python.
    """
    paths = setup_paths()               # Step 1: Environment & Paths
    validate_directories(paths)          # Step 2: Directory Validation
    run_matlab_processing(paths)         # Step 3: MATLAB Processing
    all_movements = aggregate_fixations(paths)  # Step 4: Python Aggregation
    export_results(all_movements, paths) # Step 5: Final Metrics & Export

if __name__ == "__main__":
    run_full_pipeline()
