import pandas as pd
import re
import os

def default_is_horizontal(col_prev, row_prev, col_curr, row_curr):
    return col_prev != col_curr and row_prev == row_curr

def default_is_vertical(col_prev, row_prev, col_curr, row_curr):
    return col_prev == col_curr and row_prev != row_curr

def process_fixations_to_movements(
    participant_id, 
    csv_path, 
    is_horizontal=default_is_horizontal, 
    is_vertical=default_is_vertical
):
    """
    Parses a long-format fixation CSV and returns a DataFrame of movements.
    Saves the result to data/processed/movements/{participant_id}_movements.csv.
    """
    if not os.path.exists(csv_path):
        print(f"File not found: {csv_path}")
        return pd.DataFrame()

    try:
        # Load the new detailed CSV format
        df = pd.read_csv(csv_path)
    except pd.errors.EmptyDataError:
         print(f"Empty CSV: {csv_path}")
         return pd.DataFrame()
         
    # Check if necessary columns exist
    required_cols = {'Block', 'Trial', 'AOI', 'StartTime_ms', 'FixationSeq'}
    if not required_cols.issubset(df.columns):
        print(f"CSV {csv_path} is missing required columns. It needs: {required_cols}")
        return pd.DataFrame()

    movements = []

    # Group by Block and Trial
    grouped = df.groupby(['Block', 'Trial'])

    for (block_num, trial_num), group in grouped:
        # Sort by fixation sequence just to be safe
        group = group.sort_values('FixationSeq')
        
        # Iterate over the fixations in this trial
        # We need to look at consecutive pairs
        for i in range(len(group) - 1):
            prev_row = group.iloc[i]
            curr_row = group.iloc[i+1]
            
            prev_aoi = str(prev_row['AOI'])
            curr_aoi = str(curr_row['AOI'])
            
            if prev_aoi == 'nan' or curr_aoi == 'nan':
                continue
                
            # Time of movement is the start time of the destination fixation
            time_of_movement = curr_row['StartTime_ms']

            # Analyze transitions
            pattern = r"^([a-zA-Z]+)(\d*)$"
            match_prev = re.match(pattern, prev_aoi)
            match_curr = re.match(pattern, curr_aoi)

            mov_type = "other"

            if match_prev and match_curr:
                col_prev = match_prev.group(1)
                row_prev = int(match_prev.group(2)) if match_prev.group(2) else 0
                
                col_curr = match_curr.group(1)
                row_curr = int(match_curr.group(2)) if match_curr.group(2) else 0

                if col_prev == col_curr and row_prev == row_curr:
                    continue  # Ignore repetition/same cell
                
                if is_vertical(col_prev, row_prev, col_curr, row_curr):
                    mov_type = "v"
                elif is_horizontal(col_prev, row_prev, col_curr, row_curr):
                    mov_type = "h"
                else:
                    mov_type = "other"

            movements.append({
                "participant_id": participant_id,
                "movement_type": mov_type,
                "trial": trial_num,
                "block": block_num,
                "time": time_of_movement
            })

    result_df = pd.DataFrame(movements)
    
    # Automatically save to the movements directory
    proj_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    movements_dir = os.path.join(proj_root, "data", "processed", "movements")
    os.makedirs(movements_dir, exist_ok=True)
    
    out_path = os.path.join(movements_dir, f"{participant_id}_movements.csv")
    result_df.to_csv(out_path, index=False)
    print(f"Saved movement data to: {out_path}")

    return result_df

def calculate_indices(movements_df):
    """
    Calculates H / (H + V) index per trial and block.
    """
    if movements_df.empty:
        return pd.DataFrame()
        
    hv_df = movements_df[movements_df['movement_type'].isin(['h', 'v'])]
    if hv_df.empty:
        # Prevent errors if there are no H or V movements
        return pd.DataFrame()
    
    grouped = hv_df.groupby(['participant_id', 'block', 'trial', 'movement_type']).size().unstack(fill_value=0)
    
    if 'h' not in grouped.columns: grouped['h'] = 0
    if 'v' not in grouped.columns: grouped['v'] = 0
    
    grouped['total'] = grouped['h'] + grouped['v']
    # Avoid division by zero
    grouped['index'] = grouped.apply(lambda row: row['h'] / row['total'] if row['total'] > 0 else 0, axis=1)
    
    return grouped.reset_index()
