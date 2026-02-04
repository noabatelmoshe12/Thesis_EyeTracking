import os
import glob
try:
    import matlab.engine
except ImportError:
    print("Warning: 'matlab.engine' could not be imported. Ensure MATLAB Engine API for Python is installed.")
    matlab = None
import time

def process_subjects(source_dir, output_dir, project_root):
    """
    Iterates over subject files and calls the MATLAB analysis function.
    """
    # Ensure output directory exists
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    print("Starting MATLAB Engine...")
    eng = matlab.engine.start_matlab()
    eng.addpath(project_root)
    print("MATLAB Engine started.")

    # Find subject files
    # Pattern assumption: Subject_XXX_Results_Decision_Strategy_Experiment.mat
    pattern = os.path.join(source_dir, "Subject_*_Results_Decision_Strategy_Experiment.mat")
    files = glob.glob(pattern)
    
    print(f"Found {len(files)} files to process in {source_dir}")

    for file_path in files:
        filename = os.path.basename(file_path)
        # Extract Subject ID
        # Example: Subject_991_Results...
        try:
            parts = filename.split('_')
            # Look for the part after "Subject"
            subject_idx = parts.index("Subject") + 1
            subject_code = parts[subject_idx]
            
            # Check if it's a number
            if not subject_code.isdigit():
                 print(f"Skipping {filename}: Could not parse subject code (found {subject_code}).")
                 continue
                 
            print(f"Processing Subject {subject_code} from {filename}...")
            
            # Call MATLAB function
            # Analyze_eye_func(mat, subject_code, output_directory)
            # matlab.engine requires explicit type conversion often, but strings/ints usually work.
            eng.Analyze_eye_func(file_path, subject_code, output_dir, nargout=0)
            print(f"Finished Subject {subject_code}.")
            
        except ValueError:
            print(f"Skipping {filename}: 'Subject' keyword not found or format mismatch.")
        except Exception as e:
            print(f"Error processing {filename}: {e}")

    eng.quit()
    print("MATLAB Engine closed.")

if __name__ == "__main__":
    # Configuration
    # Adjust these paths as needed
    PROJECT_ROOT = r"c:\Projects\Thesis_EyeTracking"
    SOURCE_DIR = os.path.join(PROJECT_ROOT, "Eyedata")
    OUTPUT_DIR = PROJECT_ROOT # Generate 'function' folder inside here
    
    process_subjects(SOURCE_DIR, OUTPUT_DIR, PROJECT_ROOT)
