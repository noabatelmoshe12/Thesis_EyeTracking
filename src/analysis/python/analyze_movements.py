import pandas as pd
import numpy as np
import os
import re

def parse_aoi(label):
    """
    Parses an AOI string into (row_index, kind).
    kind is 'AT', 'A', or 'B'.
    row is an integer.
    If invalid (e.g. F, A, B without number), returns (np.nan, None).
    """
    if pd.isna(label):
        return np.nan, None
        
    label_str = str(label).strip()
    # Match ATi, Ai, Bi where i is the row index
    match = re.match(r"^(AT|A|B)(\d+)$", label_str)
    if match:
        kind = match.group(1)
        row = int(match.group(2))
        return row, kind
    return np.nan, None

def process_fixations_to_movements(participant_id, csv_path):
    """
    Reads a long-format fixation CSV and builds a sequence of scanpath movements,
    handling bridging across missing data (NaNs) and classifying transitions.

    Inputs:
    -------
    participant_id : str
        The identifier for the subject (e.g., '889'). Used for output tagging.
    csv_path : str
        Absolute path to the long-format CSV containing the fixation data.
        The CSV must contain the following columns:
        - Block: The block number.
        - Trial: The trial number.
        - AOI: The Area of Interest label (e.g., 'A1', 'AT1', 'F', 'NaN').
        - FixationSeq: A sequential integer indicating temporal order.

    Algorithm & Logic:
    ------------------
    1. Parse AOIs: Extracts rows and kinds ('A', 'B', 'AT') from raw strings.
       Invalid labels ('F', 'A' without a number) are grouped as NaN rows.
    2. Bridge NaNs: Iterates through fixations sequentially. If a NaN or invalid
       AOI is encountered, it is counted as `Skipped_NaN_Count` but skipped over so 
       the next valid AOI bridges directly to the last valid AOI in the sequence.
    3. Classification:
       - Horizontal: The row indices of the From and To AOIs exactly match.
       - Vertical: The 'kinds' match between 'A' and 'B', but the rows differ.
       - Ignored: Diagonal jumps, undefined rows, or moves between attributes (e.g., 'AT1' to 'AT3').

    Returns (Tuple):
    ----------------
    trial_idx : pd.DataFrame
        Trial-level scanpath index calculations.
    block_idx : pd.DataFrame
        Block-level scanpath index calculations.
    result_df : pd.DataFrame
        The full line-by-line movement history output table.
    """
    if not os.path.exists(csv_path):
        print(f"File not found: {csv_path}")
        return pd.DataFrame(), pd.DataFrame(), pd.DataFrame()

    try:
        df = pd.read_csv(csv_path)
    except pd.errors.EmptyDataError:
        print(f"Empty CSV: {csv_path}")
        return pd.DataFrame(), pd.DataFrame(), pd.DataFrame()

    required_cols = {'Block', 'Trial', 'AOI', 'FixationSeq', 'StartTime_ms'}
    if not required_cols.issubset(set(df.columns)):
        print(f"CSV {csv_path} missing required columns.")
        return pd.DataFrame(), pd.DataFrame(), pd.DataFrame()

    movements = []

    # Step 2: Build Transitions (Bridge across NaNs)
    for (block_num, trial_num), group in df.groupby(['Block', 'Trial']):
        # Ensure fixations are evaluated in their chronological order
        group = group.sort_values('FixationSeq')
        
        last_valid_aoi = None
        last_valid_pos = None
        skipped_nan = 0
        move_index = 1
        
        for _, row_data in group.iterrows():
            aoi_t = row_data['AOI']
            t_raw = row_data['FixationSeq']
            time_t = row_data['StartTime_ms']
            
            # 1. If AOI_t is NaN, increment bridge counter and continue
            if pd.isna(aoi_t) or str(aoi_t).strip().lower() == 'nan':
                skipped_nan += 1
                continue
                
            aoi_str = str(aoi_t).strip()
            row_val, kind_val = parse_aoi(aoi_str)
            
            # 2. If AOI_t is not a valid AOI with a defined row (e.g. 'F')
            if pd.isna(row_val) or kind_val is None:
                continue
                
            # 3. If lastValidAOI is None, this is the first valid fixation of the trial
            if last_valid_aoi is None:
                last_valid_aoi = aoi_str
                last_valid_pos = t_raw
                skipped_nan = 0
                continue
                
            # 4. Create transition (spanning between the bridged fixations)
            from_aoi = last_valid_aoi
            to_aoi = aoi_str
            from_pos_raw = last_valid_pos
            to_pos_raw = t_raw
            movement_time = time_t
            skipped_nan_count = skipped_nan
            
            # Step 3: Transition Classification Logic
            row_from, kind_from = parse_aoi(from_aoi)
            row_to, kind_to = parse_aoi(to_aoi)
            
            classification = "Ignored"
            # Horizontal: Same row (implying scanning across attributes)
            if row_from == row_to and not pd.isna(row_from):
                classification = "Horizontal"
            # Vertical: Same alternative type ('A' or 'B') but jumping to different rows
            elif kind_from == kind_to and kind_from in {"A", "B"} and row_from != row_to:
                classification = "Vertical"
                
            movements.append({
                # 'Subject': The unique identifier for the participant.
                "Subject": participant_id,
                # 'Block': The block number of the current trial.
                "Block": block_num,
                # 'Trial': The trial number within the block.
                "Trial": trial_num,
                # 'Move_Index': A sequential counter for the valid transitions within this specific trial.
                "Move_Index": move_index,
                # 'From_AOI_Raw': The AOI label where the movement started.
                "From_AOI_Raw": from_aoi,
                # 'To_AOI_Raw': The AOI label where the movement ended.
                "To_AOI_Raw": to_aoi,
                # 'Classification': Indicates if the movement was Horizontal, Vertical, or Ignored (diagonal/cross-attribute).
                "Classification": classification,
                # 'From_Pos_Raw': The FixationSeq integer showing when the 'From' fixation occurred in the trial.
                "From_Pos_Raw": from_pos_raw,
                # 'To_Pos_Raw': The FixationSeq integer showing when the 'To' fixation occurred in the trial.
                "To_Pos_Raw": to_pos_raw,
                # 'movement_time_ms': The exact time (StartTime_ms) the participant landed on the destination AOI.
                "movement_time_ms": movement_time,
                # 'Skipped_NaN_Count': How many invalid/NaN fixations occurred sequentially between the 'From' and 'To' fixations.
                "Skipped_NaN_Count": skipped_nan_count
            })
            
            # Update trackers for the next loop iteration
            last_valid_aoi = aoi_str
            last_valid_pos = t_raw
            skipped_nan = 0
            move_index += 1
            
        # Ensure the Trial/Block doesn't disappear from our data if it had 0 matching pairs
        if move_index == 1:
            movements.append({
                "Subject": participant_id,
                "Block": block_num,
                "Trial": trial_num,
                "Move_Index": 0,
                "From_AOI_Raw": None,
                "To_AOI_Raw": None,
                "Classification": "None",
                "From_Pos_Raw": None,
                "To_Pos_Raw": None,
                "movement_time_ms": None,
                "Skipped_NaN_Count": skipped_nan
            })

    result_df = pd.DataFrame(movements)
    if result_df.empty:
        result_df = pd.DataFrame(columns=[
            "Subject", "Block", "Trial", "Move_Index", 
            "From_AOI_Raw", "To_AOI_Raw", "Classification", 
            "From_Pos_Raw", "To_Pos_Raw", "movement_time_ms", "Skipped_NaN_Count"
        ])

    # Save to disk
    proj_root = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
    movements_dir = os.path.join(proj_root, "data", "processed", "movements")
    os.makedirs(movements_dir, exist_ok=True)
    out_path = os.path.join(movements_dir, f"{participant_id}_movements.csv")
    result_df.to_csv(out_path, index=False)
    print(f"Saved movement data to: {out_path}")

    # Step 4 & 5: Calculate statistical indices
    trial_idx, block_idx = calculate_scanpath_index(result_df)
    
    return trial_idx, block_idx, result_df

def calculate_scanpath_index(movements_df):
    """
    Computes trial-level and block-level scan indices for analytical reporting.
    
    The Scan Index is calculated as: H / (H + V)
    Where:
    - H: Total number of 'Horizontal' transitions.
    - V: Total number of 'Vertical' transitions.
    - Any 'Ignored' transitions are excluded from this metric entirely.
    
    Returns (Tuple):
    ----------------
    trial_df : pd.DataFrame
        Detailed index aggregated per trial for time-series / granular analysis.
    block_df : pd.DataFrame
        Macro index aggregated per block.
    """
    if movements_df.empty:
        return pd.DataFrame(), pd.DataFrame()
        
    # Create base dataframes representing all unique Subjects, Blocks, and Trials in the input.
    base_trials = movements_df[['Subject', 'Block', 'Trial']].drop_duplicates()
    base_blocks = movements_df[['Subject', 'Block']].drop_duplicates()

    # Isolate only the relevant classifications
    hv_df = movements_df[movements_df['Classification'].isin(['Horizontal', 'Vertical'])]
    
    # TRIAL-LEVEL (Step 4)
    if hv_df.empty:
        trial_df = base_trials.copy()
        trial_df['ScanIndex_trial'] = np.nan
        block_df = base_blocks.copy()
        block_df['ScanIndex_block'] = np.nan
        return trial_df, block_df

    # Pivot to sum Horizontal and Vertical transitions per trial
    trial_counts = hv_df.groupby(['Subject', 'Block', 'Trial', 'Classification']).size().unstack(fill_value=0)
    trial_counts = trial_counts.reset_index()
    
    # Merge with base_trials to keep trials that had 0 H/V transitions
    trial_counts = pd.merge(base_trials, trial_counts, on=['Subject', 'Block', 'Trial'], how='left')
    
    for col in ['Horizontal', 'Vertical']:
        if col not in trial_counts.columns:
            trial_counts[col] = 0
            
    trial_counts['Horizontal'] = trial_counts['Horizontal'].fillna(0)
    trial_counts['Vertical'] = trial_counts['Vertical'].fillna(0)
            
    trial_counts['Total'] = trial_counts['Horizontal'] + trial_counts['Vertical']
    # Calculate Trial Index: H / (H + V) -- guard against div by 0
    trial_counts['ScanIndex_trial'] = trial_counts.apply(
        lambda r: r['Horizontal'] / r['Total'] if r['Total'] > 0 else np.nan, axis=1)
        
    trial_df = trial_counts

    # BLOCK-LEVEL (Step 5)
    # Pivot to sum Horizontal and Vertical transitions across the entire block
    block_counts = hv_df.groupby(['Subject', 'Block', 'Classification']).size().unstack(fill_value=0)
    block_counts = block_counts.reset_index()
    
    # Merge with base_blocks to keep blocks that had 0 H/V transitions
    block_counts = pd.merge(base_blocks, block_counts, on=['Subject', 'Block'], how='left')
    
    for col in ['Horizontal', 'Vertical']:
        if col not in block_counts.columns:
            block_counts[col] = 0
            
    block_counts['Horizontal'] = block_counts['Horizontal'].fillna(0)
    block_counts['Vertical'] = block_counts['Vertical'].fillna(0)
            
    block_counts['Total'] = block_counts['Horizontal'] + block_counts['Vertical']
    # Calculate Block Index: H / (H + V) -- guard against div by 0
    block_counts['ScanIndex_block'] = block_counts.apply(
        lambda r: r['Horizontal'] / r['Total'] if r['Total'] > 0 else np.nan, axis=1)
        
    block_df = block_counts

    return trial_df, block_df
