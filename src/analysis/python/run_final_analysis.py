import os
import glob
import pandas as pd
from analyze_movements import process_fixations_to_movements, calculate_scanpath_index

def main():
    # Configuration
    project_root = r"c:\Projects\Thesis_EyeTracking"
    csv_dir = os.path.join(project_root, "data", "processed", "fixations")
    output_file = os.path.join(project_root, "data", "final_results_summary.csv")
    
    # Find all CSV files produced by Convert_eye_data
    csv_files = glob.glob(os.path.join(csv_dir, "*.csv"))
    
    if not csv_files:
        print(f"No CSV files found in {csv_dir}.")
        return

    all_movements = []
    
    for csv_path in csv_files:
        filename = os.path.basename(csv_path)
        subject_id = os.path.splitext(filename)[0]
        
        subject_id = subject_id.replace("_detailed", "")
        print(f"Analyzing {subject_id}...")
        
        # Parse fixations and classify movements
        # Assuming 2 blocks of 8 trials or similar default; script handles defaults.
        trial_df, block_df, movements_df = process_fixations_to_movements(subject_id, csv_path)
        
        if not movements_df.empty:
            all_movements.append(movements_df)
            
    if all_movements:
        # Combine all subjects
        total_movements = pd.concat(all_movements, ignore_index=True)
        
        # Calculate indices (H / (H+V))
        trial_results, block_results = calculate_scanpath_index(total_movements)
        
        # Save to CSV
        block_results.to_csv(output_file, index=False)
        print(f"Analysis complete. Results saved to {output_file}")
        print(block_results.head())
    else:
        print("No valid movement data found.")

if __name__ == "__main__":
    main()
