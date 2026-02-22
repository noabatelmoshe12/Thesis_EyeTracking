# NOTE (Feb 2026):
# MATLAB function Analyze_eye_func_v2 was renamed to Convert_eye_data.
# The pipeline now expects Convert_eye_data.m to be available on the MATLAB path.

import os
import glob
import sys
import shutil
import pandas as pd
import time
import subprocess

try:
    import matlab.engine
except ImportError:
    print("Warning: 'matlab.engine' could not be imported. MATLAB steps will be skipped.")
    matlab = None

# Add current directory to path to import local modules
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
try:
    from analyze_movements import process_fixations_to_movements, calculate_indices
except ImportError:
    # If running from root, might need adjustment, but script location + sys.path append should work
    print("Warning: Could not import 'analyze_movements'. Final aggregation might fail.")

def run_full_pipeline():
    # --- 1. Setup Paths ---
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(script_dir, "..", "..", ".."))
    
    raw_dir = os.path.join(project_root, "data", "raw")
    processed_dir = os.path.join(project_root, "data", "processed")
    results_dir = os.path.join(project_root, "data", "results")
    final_results_file = os.path.join(project_root, "data", "final_results_summary.csv")
    
    matlab_script_dir = os.path.join(project_root, "src", "analysis", "matlab")
    
    print(f"--- Thesis EyeTracking Pipeline ---")
    print(f"Project Root: {project_root}")
    
    # Ensure directories exist
    for d in [raw_dir, processed_dir, results_dir]:
        if not os.path.exists(d):
            os.makedirs(d)
            print(f"Created directory: {d}")

    # Start MATLAB Engine
    eng = None
    if matlab:
        print("Starting MATLAB Engine...")
        eng = matlab.engine.start_matlab()
        # Change directory to script folder to avoid shadowing by files in root
        eng.cd(matlab_script_dir, nargout=0)
        eng.addpath(matlab_script_dir, nargout=0)
        print("MATLAB Engine started.")

    # ... (conversion step - unchanged) ...

        if eng:
            try:
                # Call Convert_eye_data
                # Convert_eye_data(mat_path, subject_code, project_root)
                eng.Convert_eye_data(mat_path, subject_code, project_root, nargout=0)
                print(f"  Done.")
            except Exception as e:
                print(f"  Analysis failed for {subject_code}: {e}")
        else:
             print("  Skipping analysis (No MATLAB Engine).")

    if eng:
        eng.quit()
    elif shutil.which("matlab"):
        # Fallback to subprocess if MATLAB command is available but Engine isn't
        print("\n[Step 2/3 Alternative] Running Fixation Analysis via MATLAB CLI...")
        print("  Can't open MATLAB Engine, calling 'matlab -batch run_batch_analysis'...")
        
        # Change to script directory so it uses the correct Convert_eye_data
        # We use -sd (Startup Directory)
        
        matlab_script_folder = os.path.join(project_root, "src", "analysis", "matlab")
        
        cmd = [
            "matlab", 
            "-sd", matlab_script_folder,
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

    # --- 4. Final Aggregation (CSV -> Summary) ---
    print("\n[Step 3/3] Aggregating Results (CSV -> Summary)...")
    
    fixations_dir = os.path.join(processed_dir, "fixations")
    csv_files = glob.glob(os.path.join(fixations_dir, "*.csv"))
    # Filter out empty files or non-subject files
    csv_files = [f for f in csv_files if os.path.getsize(f) > 0]
    
    if not csv_files:
        print(f"No result CSVs found in {results_dir}.")
        return

    all_movements = []
    for csv_path in csv_files:
        filename = os.path.basename(csv_path)
        subject_id = os.path.splitext(filename)[0]
        
        # Skip if not a subject file (heuristic)
        if not subject_id[0].isdigit():
             continue

        try:
            # Use process_fixations_to_movements from local module
            df = process_fixations_to_movements(subject_id, csv_path)
            if not df.empty:
                all_movements.append(df)
        except Exception as e:
            print(f"  Error aggregating {subject_id}: {e}")

    if all_movements:
        total_movements = pd.concat(all_movements, ignore_index=True)
        results = calculate_indices(total_movements)
        
        results.to_csv(final_results_file, index=False)
        print(f"\nPipeline Complete!")
        print(f"Final summary saved to: {final_results_file}")
        print("\nPreview:")
        print(results.head())
    else:
        print("No valid movement data found to aggregate.")

if __name__ == "__main__":
    run_full_pipeline()
