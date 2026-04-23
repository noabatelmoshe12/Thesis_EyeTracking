from pathlib import Path
import glob
import os
import re
import pandas as pd
import numpy as np


def parse_aoi(label):
    """
    Parse AOI labels of the form ATi, Ai, or Bi.

    Returns:
        (row_index, kind)
    If invalid, returns (np.nan, None).
    """
    if pd.isna(label):
        return np.nan, None

    label_str = str(label).strip()
    match = re.match(r"^(AT|A|B)(\d+)$", label_str)
    if match:
        kind = match.group(1)
        row = int(match.group(2))
        return row, kind

    return np.nan, None


def classify_transition(from_label, to_label):
    """
    Classify a transition between two consecutive AOIs.

    Rules:
    - Horizontal: same row index, different labels
    - Vertical: same kind ('A' or 'B'), different row
    - Ignored: any other valid pair
    - None: invalid or identical AOIs
    """
    if from_label is None or to_label is None:
        return None

    row_from, kind_from = parse_aoi(from_label)
    row_to, kind_to = parse_aoi(to_label)

    if pd.isna(row_from) or kind_from is None:
        return None
    if pd.isna(row_to) or kind_to is None:
        return None

    if from_label == to_label:
        return None

    if row_from == row_to:
        return "Horizontal"

    if kind_from == kind_to and kind_from in {"A", "B"} and row_from != row_to:
        return "Vertical"

    return "Ignored"


def summarize_subject_transition_counts(subject_id, csv_path):
    """
    Create one merged transition summary per subject across all blocks/trials.

    Output columns:
    - Subject
    - Horizontal_Count
    - Vertical_Count
    - Ignored_Count
    - Valid_Transition_Count (= Horizontal_Count + Vertical_Count)
    - VerticalIndex_subject (= Vertical_Count / Valid_Transition_Count)
    """
    if not os.path.exists(csv_path):
        print(f"File not found: {csv_path}")
        return pd.DataFrame()

    try:
        df = pd.read_csv(csv_path)
    except pd.errors.EmptyDataError:
        print(f"Empty CSV: {csv_path}")
        return pd.DataFrame()

    required_cols = {"Block", "Trial", "AOI", "FixationSeq"}
    if not required_cols.issubset(df.columns):
        print(f"Missing required columns in {csv_path}")
        return pd.DataFrame()

    horizontal_count = 0
    vertical_count = 0
    ignored_count = 0

    for (_, _), group in df.groupby(["Block", "Trial"]):
        group = group.sort_values("FixationSeq").reset_index(drop=True)

        for i in range(len(group) - 1):
            from_raw = group.iloc[i]["AOI"]
            to_raw = group.iloc[i + 1]["AOI"]

            from_label = None if pd.isna(from_raw) else str(from_raw).strip()
            to_label = None if pd.isna(to_raw) else str(to_raw).strip()

            classification = classify_transition(from_label, to_label)

            if classification == "Horizontal":
                horizontal_count += 1
            elif classification == "Vertical":
                vertical_count += 1
            elif classification == "Ignored":
                ignored_count += 1

    valid_transition_count = horizontal_count + vertical_count

    if valid_transition_count > 0:
        vertical_index_subject = vertical_count / valid_transition_count
    else:
        vertical_index_subject = np.nan

    return pd.DataFrame([
        {
            "Subject": subject_id,
            "Horizontal_Count": horizontal_count,
            "Vertical_Count": vertical_count,
            "Ignored_Count": ignored_count,
            "Valid_Transition_Count": valid_transition_count,
            "VerticalIndex_subject": vertical_index_subject,
        }
    ])


def main():
    project_root = Path(__file__).resolve().parents[4]
    csv_dir = project_root / "data" / "processed" / "fixations"
    output_dir = project_root / "data" / "results" / "merged_3_4"
    output_file = output_dir / "subject_vertical_index_total_transitions_merged_blocks.csv"

    output_dir.mkdir(parents=True, exist_ok=True)

    csv_files = glob.glob(str(csv_dir / "*.csv"))

    if not csv_files:
        print(f"No CSV files found in {csv_dir}")
        return

    subject_summaries = []

    for csv_path in csv_files:
        filename = os.path.basename(csv_path)
        subject_id = os.path.splitext(filename)[0]
        subject_id = subject_id.replace("_detailed", "")

        print(f"Processing {subject_id}...")

        summary_df = summarize_subject_transition_counts(subject_id, csv_path)

        if not summary_df.empty:
            subject_summaries.append(summary_df)

    if not subject_summaries:
        print("No valid subject summaries were created.")
        return

    subject_results = pd.concat(subject_summaries, ignore_index=True)

    try:
        subject_results["Subject_num"] = pd.to_numeric(subject_results["Subject"], errors="coerce")
        subject_results = subject_results.sort_values(["Subject_num", "Subject"]).drop(columns=["Subject_num"])
    except Exception:
        subject_results = subject_results.sort_values("Subject")

    subject_results.to_csv(output_file, index=False)

    print(f"\nSaved merged subject-level transition summary to:\n{output_file}")
    print("\nPreview:")
    print(subject_results.head())


if __name__ == "__main__":
    main()
