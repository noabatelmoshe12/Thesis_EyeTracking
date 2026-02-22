import os
import glob
import pandas as pd
from analyze_movements import analyze_scanpath, calculate_indices

def main():
    # Configuration
    project_root = r"c:\Projects\Thesis_EyeTracking"
    csv_dir = os.path.join(project_root, "function")
    output_file = os.path.join(project_root, "final_results.csv")
    
    # Find all CSV files produced by Convert_eye_data
    csv_files = glob.glob(os.path.join(csv_dir, "*.csv"))
    
    if not csv_files:
        print(f"No CSV files found in {csv_dir}. Run process_eye_data.py first.")
        return

    all_movements = []
    
    for csv_path in csv_files:
        filename = os.path.basename(csv_path)
        subject_id = os.path.splitext(filename)[0]
        
        print(f"Analyzing {subject_id}...")
        
        # Parse fixations and classify movements
        # Assuming 2 blocks of 8 trials or similar default; script handles defaults.
        movements_df = analyze_scanpath(subject_id, csv_path)
        
        if not movements_df.empty:
            all_movements.append(movements_df)
            
    if all_movements:
        # Combine all subjects
        total_movements = pd.concat(all_movements, ignore_index=True)
        
        # Calculate indices (H / (H+V))
        results = calculate_indices(total_movements)
        
        # Save to CSV
        results.to_csv(output_file, index=False)
        print(f"Analysis complete. Results saved to {output_file}")
        print(results.head())
    else:
        print("No valid movement data found.")

if __name__ == "__main__":
    main()
