"""Correlate behavioral WA scores with eye-tracking scanpath indices.

Overview
========
This script connects **behavioral strategy scores** (WA scores) with
**eye-tracking scanpath indices** that summarize how horizontal vs.
vertical a participant's scanning pattern is in each block.

Inputs (under data/results/)
----------------------------
- behavior_wa_scores.csv
    Columns (expected):
        - subject_id
        - wa_score_3   (WA score for the 3-attribute block)
        - wa_score_4   (WA score for the 4-attribute block)

- block_results_summary.csv
    Columns (expected subset):
        - Subject           (numeric or string subject identifier)
        - Block             (1 = 3-attribute block, 2 = 4-attribute block)
        - Horizontal        (count of horizontal transitions H)
        - Vertical          (count of vertical transitions V)
        - Total             (H + V, ignoring other movement types)
        - ScanIndex_block   = H / (H + V)

Indices used here
-----------------
- ScanIndex_block:  fraction of **horizontal** transitions
    ScanIndex_block = H / (H + V)

- VerticalIndex_block: fraction of **vertical** transitions
    VerticalIndex_block = 1 - ScanIndex_block = V / (H + V)

In the thesis logic, *more compensatory / WA strategy* is associated with
more **vertical** scanning. Therefore, **VerticalIndex_block** is often
the more intuitive index to correlate with WA scores: higher WA should
correspond to higher VerticalIndex_block if the theory holds.

High-level workflow
-------------------
1. Load behavioral scores and block-level eye-tracking indices
   from data/results.
2. Normalize subject IDs and report which participants appear only
   in behavior, only in eye data, and in both.
3. Compute VerticalIndex_block = 1 - ScanIndex_block in the long
   eye DataFrame.
4. Pivot the eye data to a subject-level wide format with columns:
      - scanindex_block1, scanindex_block2
      - verticalindex_block1, verticalindex_block2
5. Merge the behavioral and eye tables on subject_id and save the
   merged dataset to data/results/behavior_eye_merged.csv.
6. Compute Pearson correlations for:
      - wa_score_3 vs scanindex_block1
      - wa_score_3 vs verticalindex_block1
      - wa_score_4 vs scanindex_block2
      - wa_score_4 vs verticalindex_block2
7. Create and save scatter plots for:
      - Block 1: wa_score_3 (x) vs verticalindex_block1 (y)
      - Block 2: wa_score_4 (x) vs verticalindex_block2 (y)

Run from the project root with:
    uv run src/analysis/python/correlate_behavior_eye.py
"""

from pathlib import Path

import pandas as pd
from matplotlib import pyplot as plt
from scipy.stats import pearsonr


def get_paths() -> dict:
    """Resolve all relevant paths relative to the project root.

    Assumes this file is located at src/analysis/python/ within
    the project. The project root is therefore three levels up.
    """

    project_root = Path(__file__).resolve().parents[3]
    data_dir = project_root / "data"
    results_dir = data_dir / "results"

    # Ensure results directory exists (it should already, but this is safe)
    results_dir.mkdir(parents=True, exist_ok=True)

    return {
        "project_root": project_root,
        "data_dir": data_dir,
        "results_dir": results_dir,
        "behavior_path": results_dir / "behavior_wa_scores.csv",
        "eye_path": results_dir / "block_results_summary.csv",
        "merged_output_path": results_dir / "behavior_eye_merged.csv",
        "plot_block1_path": results_dir / "block1_wa_vs_vertical.png",
        "plot_block2_path": results_dir / "block2_wa_vs_vertical.png",
        "plot_behavior_3_vs_4_path": results_dir / "behavior_wa_3_vs_4.png",
        "plot_verticalindex_3_vs_4_path": results_dir / "verticalindex_block1_vs_block2.png",
    }


def load_data(behavior_path: Path, eye_path: Path) -> tuple[pd.DataFrame, pd.DataFrame]:
    """Load behavioral WA scores and block-level eye-tracking results.

    Parameters
    ----------
    behavior_path : Path
        Path to behavior_wa_scores.csv.
    eye_path : Path
        Path to block_results_summary.csv.
    """

    if not behavior_path.is_file():
        raise FileNotFoundError(f"Behavior file not found: {behavior_path}")
    if not eye_path.is_file():
        raise FileNotFoundError(f"Eye-tracking file not found: {eye_path}")

    behavior_df = pd.read_csv(behavior_path)
    eye_df = pd.read_csv(eye_path)

    # Normalize subject identifiers to string on both sides to avoid
    # merge issues due to one being int and the other string.
    behavior_df["subject_id"] = behavior_df["subject_id"].astype(str)

    if "Subject" not in eye_df.columns:
        raise KeyError("Expected column 'Subject' not found in eye data.")

    eye_df = eye_df.rename(columns={"Subject": "subject_id"})
    eye_df["subject_id"] = eye_df["subject_id"].astype(str)

    return behavior_df, eye_df


def report_subject_overlap(behavior_df: pd.DataFrame, eye_df: pd.DataFrame) -> list[str]:
    """Print and return information about subject ID overlap.

    Returns a sorted list of subject IDs that appear in both datasets.
    """

    behavior_ids = set(behavior_df["subject_id"].unique())
    eye_ids = set(eye_df["subject_id"].unique())

    common_ids = sorted(behavior_ids & eye_ids)
    behavior_only_ids = sorted(behavior_ids - eye_ids)
    eye_only_ids = sorted(eye_ids - behavior_ids)

    print("\n===== SUBJECT OVERLAP DIAGNOSTICS =====")
    print(f"Total subjects in behavior file : {len(behavior_ids)}")
    print(f"Total subjects in eye file      : {len(eye_ids)}")
    print(f"Subjects in BOTH                : {len(common_ids)}")

    if behavior_only_ids:
        print(f"\nSubjects ONLY in behavior (no eye data): {behavior_only_ids}")
    else:
        print("\nNo subjects appear only in behavior.")

    if eye_only_ids:
        print(f"\nSubjects ONLY in eye (no behavior data): {eye_only_ids}")
    else:
        print("No subjects appear only in eye data.")

    print("=======================================\n")
    return common_ids


def add_vertical_index(eye_df: pd.DataFrame) -> pd.DataFrame:
    """Compute VerticalIndex_block = 1 - ScanIndex_block.

    Assumes ScanIndex_block is already present and is defined as
    H / (H + V), where H is the count of horizontal transitions and
    V is the count of vertical transitions.

    The new vertical index is therefore V / (H + V). Where
    ScanIndex_block is NaN, the vertical index will also be NaN.
    """

    if "ScanIndex_block" not in eye_df.columns:
        raise KeyError("Expected column 'ScanIndex_block' not found in eye data.")

    eye_df = eye_df.copy()
    eye_df["VerticalIndex_block"] = 1.0 - eye_df["ScanIndex_block"]
    return eye_df


def pivot_eye_data(eye_df: pd.DataFrame) -> pd.DataFrame:
    """Pivot long eye data to wide format by subject and block.

    Produces columns:
        - scanindex_block1, scanindex_block2
        - verticalindex_block1, verticalindex_block2
    One row per subject_id.
    """

    required_columns = {"subject_id", "Block", "ScanIndex_block", "VerticalIndex_block"}
    missing = required_columns - set(eye_df.columns)
    if missing:
        raise KeyError(f"Eye data missing required columns: {missing}")

    # Pivot both ScanIndex_block and VerticalIndex_block simultaneously
    wide = eye_df.pivot_table(
        index="subject_id",
        columns="Block",
        values=["ScanIndex_block", "VerticalIndex_block"],
    )

    # Flatten MultiIndex columns to simple names, e.g. scanindex_block1, verticalindex_block2
    renamed_columns = []
    for metric, block in wide.columns.to_flat_index():
        # metric is e.g. "ScanIndex_block" or "VerticalIndex_block"
        base = metric.replace("_block", "").lower()  # -> "scanindex" / "verticalindex"
        renamed_columns.append(f"{base}_block{int(block)}")

    wide.columns = renamed_columns

    wide = wide.reset_index()
    return wide


def merge_behavior_eye(
    behavior_df: pd.DataFrame,
    eye_wide_df: pd.DataFrame,
    merged_output_path: Path,
) -> pd.DataFrame:
    """Merge behavior and eye data on subject_id and save merged CSV."""

    merged = behavior_df.merge(eye_wide_df, on="subject_id", how="inner")

    print("Merged data (first rows):")
    print(merged.head())
    print(f"\nTotal matched subjects used in correlations: {len(merged)}\n")

    merged.to_csv(merged_output_path, index=False, encoding="utf-8")
    print(f"Merged dataset saved to: {merged_output_path}")

    return merged


def compute_and_report_pearson(
    df: pd.DataFrame,
    x_col: str,
    y_col: str,
    description: str,
) -> None:
    """Compute and print Pearson correlation for two columns.

    Drops rows where either x_col or y_col is NaN.
    """

    if x_col not in df.columns or y_col not in df.columns:
        print(f"[WARN] Columns not found for correlation: {x_col}, {y_col}")
        return

    subset = df[[x_col, y_col]].dropna()
    n = len(subset)

    if n < 2:
        print(f"[WARN] Not enough valid data points for {description} (n={n}).")
        return

    r, p = pearsonr(subset[x_col], subset[y_col])
    print(
        f"{description}: n = {n}, "
        f"effect size (r) = {r:.4f}, "
        f"p-value (significance) = {p:.4f}"
    )


def scatter_wa_vs_vertical(
    df: pd.DataFrame,
    wa_col: str,
    vertical_col: str,
    block_label: str,
    output_path: Path,
) -> None:
    """Create and save a scatter plot: WA score vs VerticalIndex_block.

    Each point is a subject; points are annotated with subject_id.
    """

    if wa_col not in df.columns or vertical_col not in df.columns:
        print(f"[WARN] Columns not found for plotting: {wa_col}, {vertical_col}")
        return

    # Use only rows with complete data for this plot
    plot_df = df[["subject_id", wa_col, vertical_col]].dropna()

    if plot_df.empty:
        print(f"[WARN] No data available to plot for {block_label}.")
        return

    # Give each participant a unique color to make it easy
    # to visually distinguish individuals, especially in a
    # small pilot sample.
    subjects = plot_df["subject_id"].astype(str).tolist()
    n_subjects = len(subjects)
    cmap = plt.get_cmap("tab10")  # מפה קטגורית מתאימה לנבדקים בודדים
    colors = [cmap(i % cmap.N) for i in range(n_subjects)]

    plt.figure(figsize=(6, 5))

    # Draw each participant as a single point with a unique color
    for (subject, (_, row), color) in zip(subjects, plot_df.iterrows(), colors):
        plt.scatter(row[wa_col], row[vertical_col], s=40, alpha=0.8, color=color)
        # Add a text label with subject_id next to each point so the
        # supervisor can quickly see which participant is which.
        plt.annotate(
            subject,
            (row[wa_col], row[vertical_col]),
            textcoords="offset points",
            xytext=(3, 3),
            fontsize=8,
        )

    # Intuitive presentation: X-axis = degree of compensatory strategy use,
    # Y-axis = complementary vertical index (more vertical scanning
    #   corresponds to more compensatory behavior in the thesis logic).
    plt.xlabel("Behavioral WA score (higher = more compensatory strategy use)")
    plt.ylabel("VerticalIndex_block (higher = more vertical scanning)")
    plt.title(
        f"{block_label}: Relationship between compensatory strategy use\n"
        "and tendency for vertical scanning"
    )

    # For small samples, a legend helps the supervisor see which
    # color corresponds to which participant.
    if n_subjects <= 10:
        plt.legend(title="Subject ID", fontsize=8)

    plt.grid(True, alpha=0.3)
    plt.tight_layout()

    plt.savefig(output_path, dpi=300)
    plt.close()

    print(f"Scatter plot saved to: {output_path}")


def scatter_by_subject(
    df: pd.DataFrame,
    x_col: str,
    y_col: str,
    x_label: str,
    y_label: str,
    title: str,
    output_path: Path,
) -> None:
    """Generic scatter plot of two columns, colored/annotated by subject_id."""

    required_columns = {"subject_id", x_col, y_col}
    missing = required_columns - set(df.columns)
    if missing:
        print(f"[WARN] Columns not found for plotting: {missing}")
        return

    plot_df = df[["subject_id", x_col, y_col]].dropna()

    if plot_df.empty:
        print(f"[WARN] No data available to plot for {title}.")
        return

    subjects = plot_df["subject_id"].astype(str).tolist()
    n_subjects = len(subjects)
    cmap = plt.get_cmap("tab10")
    colors = [cmap(i % cmap.N) for i in range(n_subjects)]

    plt.figure(figsize=(6, 5))

    for (subject, (_, row), color) in zip(subjects, plot_df.iterrows(), colors):
        plt.scatter(row[x_col], row[y_col], s=40, alpha=0.8, color=color)
        plt.annotate(
            subject,
            (row[x_col], row[y_col]),
            textcoords="offset points",
            xytext=(3, 3),
            fontsize=8,
        )

    plt.xlabel(x_label)
    plt.ylabel(y_label)
    plt.title(title)

    if n_subjects <= 10:
        plt.legend(title="Subject ID", fontsize=8)

    plt.grid(True, alpha=0.3)
    plt.tight_layout()

    plt.savefig(output_path, dpi=300)
    plt.close()

    print(f"Scatter plot saved to: {output_path}")


def main() -> None:
    paths = get_paths()

    print("Using paths:")
    print(f"  Behavior file : {paths['behavior_path']}")
    print(f"  Eye file      : {paths['eye_path']}")
    print(f"  Merged output : {paths['merged_output_path']}")
    print()

    behavior_df, eye_df = load_data(paths["behavior_path"], paths["eye_path"])

    # Report which subjects are available where
    common_ids = report_subject_overlap(behavior_df, eye_df)
    if not common_ids:
        print("No overlapping subjects between behavior and eye data. Exiting.")
        return

    # Restrict both DataFrames to overlapping subjects only
    behavior_df = behavior_df[behavior_df["subject_id"].isin(common_ids)].copy()
    eye_df = eye_df[eye_df["subject_id"].isin(common_ids)].copy()

    # Add vertical index and pivot to wide subject-level format
    eye_df = add_vertical_index(eye_df)
    eye_wide_df = pivot_eye_data(eye_df)

    # Merge behavior and eye data, save merged dataset
    merged_df = merge_behavior_eye(
        behavior_df=behavior_df,
        eye_wide_df=eye_wide_df,
        merged_output_path=paths["merged_output_path"],
    )

    print("\n===== PEARSON CORRELATIONS =====")
    # Block mapping:
    #   Block 1 -> wa_score_3 (3-attribute block)
    #   Block 2 -> wa_score_4 (4-attribute block)

    # Horizontal fraction (ScanIndex_block)
    compute_and_report_pearson(
        merged_df,
        x_col="wa_score_3",
        y_col="scanindex_block1",
        description="Block 1 (3-attr): WA score (wa_score_3) vs ScanIndex_block1 (horizontal fraction)",
    )
    compute_and_report_pearson(
        merged_df,
        x_col="wa_score_4",
        y_col="scanindex_block2",
        description="Block 2 (4-attr): WA score (wa_score_4) vs ScanIndex_block2 (horizontal fraction)",
    )

    # Vertical fraction (VerticalIndex_block)
    compute_and_report_pearson(
        merged_df,
        x_col="wa_score_3",
        y_col="verticalindex_block1",
        description="Block 1 (3-attr): WA score (wa_score_3) vs VerticalIndex_block1 (vertical fraction)",
    )
    compute_and_report_pearson(
        merged_df,
        x_col="wa_score_4",
        y_col="verticalindex_block2",
        description="Block 2 (4-attr): WA score (wa_score_4) vs VerticalIndex_block2 (vertical fraction)",
    )

    # Correlation between 3- vs 4-attribute behavioral compensatory strategy
    compute_and_report_pearson(
        merged_df,
        x_col="wa_score_3",
        y_col="wa_score_4",
        description=(
            "Behavior: WA score 3-attribute (wa_score_3) "
            "vs WA score 4-attribute (wa_score_4)"
        ),
    )

    # Correlation between 3- vs 4-attribute vertical eye-scan indices
    compute_and_report_pearson(
        merged_df,
        x_col="verticalindex_block1",
        y_col="verticalindex_block2",
        description=(
            "Eye scan vertical index: Block 1 (verticalindex_block1) "
            "vs Block 2 (verticalindex_block2)"
        ),
    )

    print("===== END CORRELATIONS =====\n")

    # Scatter plots for the vertical index (more intuitive interpretation)
    scatter_wa_vs_vertical(
        merged_df,
        wa_col="wa_score_3",
        vertical_col="verticalindex_block1",
        block_label="Block 1 (3-attribute)",
        output_path=paths["plot_block1_path"],
    )

    scatter_wa_vs_vertical(
        merged_df,
        wa_col="wa_score_4",
        vertical_col="verticalindex_block2",
        block_label="Block 2 (4-attribute)",
        output_path=paths["plot_block2_path"],
    )

    # Scatter plot: WA 3-attribute vs WA 4-attribute
    scatter_by_subject(
        merged_df,
        x_col="wa_score_3",
        y_col="wa_score_4",
        x_label="WA score 3-attribute block (wa_score_3)",
        y_label="WA score 4-attribute block (wa_score_4)",
        title=(
            "Behavioral tendency for compensatory strategy:\n"
            "3-attribute vs 4-attribute blocks"
        ),
        output_path=paths["plot_behavior_3_vs_4_path"],
    )

    # Scatter plot: vertical index 3-attribute vs 4-attribute
    scatter_by_subject(
        merged_df,
        x_col="verticalindex_block1",
        y_col="verticalindex_block2",
        x_label="VerticalIndex_block1 (3-attribute block)",
        y_label="VerticalIndex_block2 (4-attribute block)",
        title=(
            "Eye-scan vertical index:\n"
            "3-attribute block vs 4-attribute block"
        ),
        output_path=paths["plot_verticalindex_3_vs_4_path"],
    )


if __name__ == "__main__":
    main()