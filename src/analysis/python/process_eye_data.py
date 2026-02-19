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
    # Add the path to the MATLAB source code
    matlab_src_path = os.path.join(project_root, "src", "analysis", "matlab")
    eng.addpath(matlab_src_path)
    eng.addpath(project_root) # Fallback / Original root
    print(f"MATLAB Engine started. Added path: {matlab_src_path}")

    # Find subject files
    # Pattern assumption: Subject_XXX_Results_Decision_Strategy_Experiment.mat
    pattern = os.path.join(source_dir, "Subject_*_eyeData.mat")
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
            
            # Call MATLAB function (v2)
            # Analyze_eye_func_v2(mat, subject_code, output_directory)
            # matlab.engine requires explicit type conversion often, but strings/ints usually work.
            eng.Analyze_eye_func(file_path, subject_code, output_directory, nargout=0)
            print(f"Finished Subject {subject_code}.")
            
        except ValueError:
            print(f"Skipping {filename}: 'Subject' keyword not found or format mismatch.")
        except Exception as e:
            print(f"Error processing {filename}: {e}")

    eng.quit()
    print("MATLAB Engine closed.")

if __name__ == "__main__":
    # Configuration
    # Determine project root relative to this script
    # Script is in src/analysis/python
    # Root is ../../../
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(script_dir, "..", "..", ".."))
    
    # Input: Processed MAT files
    source_dir = os.path.join(project_root, "data", "processed")
    
    # Output: Project Root (Analyze_eye_func handles subdirs 'data/results' and 'data/results_longformat')
    output_dir = project_root
    
    print(f"Project Root: {project_root}")
    print(f"Source Dir: {source_dir}")
    print(f"Output Dir: {output_dir}")
    
    process_subjects(source_dir, output_dir, project_root)
