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
        Reads a long-format fixation CSV and builds a sequence of scanpath movements
        by examining only consecutive fixation pairs in the original recorded order.

        Movement detection (high-level behaviour)
        ----------------------------------------
        1. Consecutive pairs only (no bridging):
             - For each (Block, Trial), fixations are sorted by FixationSeq.
             - Only adjacent rows (i, i+1) are considered as a potential movement.
             - There is no bridging across invalid values. For example, the pattern
                 AT1 -> NaN -> B1 produces 0 movements, because only the pairs
                 (AT1, NaN) and (NaN, B1) are checked, and both are invalid.

        2. Valid vs. invalid AOIs:
             - AOIs are parsed with parse_aoi, which accepts only labels of the form
                 ATi, Ai, or Bi (e.g., 'AT1', 'A2', 'B3'). These are considered valid AOIs.
             - Anything else (e.g., 'F', plain 'A' or 'B' with no index, NaN, or any
                 other string) is treated as invalid and cannot start or end a movement.

        3. When is a movement recorded?
             - A movement is recorded only when ALL of the following hold for the
                 consecutive pair (row i, row i+1):
                     * Both AOIs are valid (parse to a row index and kind).
                     * The raw AOI labels are different (e.g., 'AT1' -> 'B1').
             - If either AOI is invalid, or the two labels are identical (e.g.,
                 'AT1' -> 'AT1'), the pair is ignored and NO movement is created.
             - Ignored pairs do not lead to any later inferred movement; they are
                 simply skipped.

        4. Classification rules (exactly as implemented):
             Let row_from_idx, kind_from be the parsed row index and kind for the
             first AOI in the pair, and row_to_idx, kind_to for the second.

             - Horizontal:
                     * row_from_idx == row_to_idx (same row index) AND the labels are
                         different. The AOI kinds may differ.
                     * Examples: A1 -> B1, AT1 -> B1, A1 -> AT1.

             - Vertical:
                     * kind_from == kind_to and kind_from is either 'A' or 'B'; AND
                         row_from_idx != row_to_idx (different rows within the same kind).
                     * Examples: A1 -> A3, B2 -> B4.

             - Ignored:
                     * Any other valid pair that is not Horizontal or Vertical.
                     * Example: A1 -> B2.

             Note: Because identical labels are skipped before classification, a
             pair like AT1 -> AT1 does not appear in the output at all (it is
             treated as "no movement").

        Short examples that summarise the logic
        ---------------------------------------
        - AT1 -> B1         => Horizontal
        - A1  -> A3         => Vertical
        - A1  -> B2         => Ignored
        - AT1 -> AT1        => no movement recorded
        - AT1 -> NaN -> B1  => 0 movements, because only consecutive pairs are
                                                     checked and both contain an invalid AOI.

        Inputs
        ------
        participant_id : str
                The identifier for the subject (e.g., '889'). Used for output tagging.
        csv_path : str
                Absolute path to the long-format CSV containing the fixation data.
                The CSV must contain the following columns:
                - Block: The block number.
                - Trial: The trial number.
                - AOI: The Area of Interest label (e.g., 'A1', 'AT1', 'F', 'NaN').
                - FixationSeq: A sequential integer indicating temporal order.

        Returns
        -------
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

    # Step 2: Build Transitions (consecutive pairs only, no bridging)
    for (block_num, trial_num), group in df.groupby(['Block', 'Trial']):
        # Ensure fixations are evaluated in their chronological order
        group = group.sort_values('FixationSeq').reset_index(drop=True)

        move_index = 1

        # Slide over consecutive pairs: row i and row i+1
        for i in range(len(group) - 1):
            row_from_data = group.iloc[i]
            row_to_data = group.iloc[i + 1]

            aoi_from_raw = row_from_data['AOI']
            aoi_to_raw = row_to_data['AOI']

            # Convert raw AOI values to stripped strings, handle NaN
            from_label = None if pd.isna(aoi_from_raw) else str(aoi_from_raw).strip()
            to_label = None if pd.isna(aoi_to_raw) else str(aoi_to_raw).strip()

            # Skip if either is missing/NaN-like
            if from_label is None or to_label is None:
                continue

            # Parse into (row_index, kind); invalid labels give (nan, None)
            row_from_idx, kind_from = parse_aoi(from_label)
            row_to_idx, kind_to = parse_aoi(to_label)

            # Skip if either AOI is invalid
            if pd.isna(row_from_idx) or kind_from is None:
                continue
            if pd.isna(row_to_idx) or kind_to is None:
                continue

            # Skip if the AOI labels are identical (no movement)
            if from_label == to_label:
                continue

            # Classification logic
            classification = "Ignored"
            if (not pd.isna(row_from_idx)) and (row_from_idx == row_to_idx):
                # Same row index => Horizontal
                classification = "Horizontal"
            elif (kind_from == kind_to) and (kind_from in {"A", "B"}) and (row_from_idx != row_to_idx):
                # Same kind ('A' with 'A' or 'B' with 'B'), different row => Vertical
                classification = "Vertical"

            from_pos_raw = row_from_data['FixationSeq']
            to_pos_raw = row_to_data['FixationSeq']
            from_start_time = row_from_data['StartTime_ms']
            to_start_time = row_to_data['StartTime_ms']
            inter_fixation_interval = to_start_time - from_start_time

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
                "From_AOI_Raw": from_label,
                # 'To_AOI_Raw': The AOI label where the movement ended.
                "To_AOI_Raw": to_label,
                # 'Classification': Indicates if the movement was Horizontal, Vertical, or Ignored (diagonal/cross-attribute).
                "Classification": classification,
                # 'From_Pos_Raw': The FixationSeq integer showing when the 'From' fixation occurred in the trial.
                "From_Pos_Raw": from_pos_raw,
                # 'To_Pos_Raw': The FixationSeq integer showing when the 'To' fixation occurred in the trial.
                "To_Pos_Raw": to_pos_raw,
                # 'From_StartTime_ms': The onset time (StartTime_ms) of the first fixation in the pair.
                "From_StartTime_ms": from_start_time,
                # 'To_StartTime_ms': The onset time (StartTime_ms) of the second fixation in the pair.
                "To_StartTime_ms": to_start_time,
                # 'InterFixationInterval_ms': Time between fixation onsets (To_StartTime_ms - From_StartTime_ms).
                "InterFixationInterval_ms": inter_fixation_interval
            })

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
                "From_StartTime_ms": None,
                "To_StartTime_ms": None,
                "InterFixationInterval_ms": None
            })

    result_df = pd.DataFrame(movements)
    if result_df.empty:
        result_df = pd.DataFrame(columns=[
            "Subject", "Block", "Trial", "Move_Index",
            "From_AOI_Raw", "To_AOI_Raw", "Classification",
            "From_Pos_Raw", "To_Pos_Raw",
            "From_StartTime_ms", "To_StartTime_ms", "InterFixationInterval_ms"
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
