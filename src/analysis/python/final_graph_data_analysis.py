"""Final Graph Data Analysis Pipeline

This script serves as the unified entry point for final statistical and graphical 
analysis. It correlates behavioral WA scores with eye-tracking scanpath indices at 
both block-level (Experiment 1 / individual blocks) and subject-level (Experiment 2 
/ pooled blocks).

Workflow Steps:
    1. Resolve paths relative to project root.
    2. Run transitions pre-requisite step to regenerate subject transitions.
    3. Load, normalize, and verify existence of required data files.
    4. Perform Block-Level Correlation Analysis (equivalent to correlate_behavior_eye.py).
    5. Perform Merged-Blocks Correlation Analysis (equivalent to correlate_behavior_eye_merged_blocks.py).

Run with:
    uv run src/analysis/python/final_graph_data_analysis.py
"""

import sys
from pathlib import Path
from datetime import datetime

import pandas as pd
from matplotlib import pyplot as plt
from scipy.stats import pearsonr

# Try to import transitions module. Add src/analysis/python to system path if needed.
try:
    from merged_blocks.run_subject_total_transitions_vertical_index import main as run_transitions
except ImportError:
    script_dir = Path(__file__).resolve().parent
    if str(script_dir) not in sys.path:
        sys.path.append(str(script_dir))
    from merged_blocks.run_subject_total_transitions_vertical_index import main as run_transitions

# Try to import block-level summary module.
try:
    from run_final_analysis import main as run_block_preprocessing
except ImportError:
    script_dir = Path(__file__).resolve().parent
    if str(script_dir) not in sys.path:
        sys.path.append(str(script_dir))
    from run_final_analysis import main as run_block_preprocessing


def format_p_value(p_value: float) -> str:
    """
    Format p-values in a human-readable way for reports/CSV output.
    """
    if p_value < 0.0001:
        return "<0.0001"
    return f"{p_value:.4f}"


def save_csv_safe(df: pd.DataFrame, target_path: Path) -> None:
    """
    Save a DataFrame to CSV, with fallback in case the target file is locked/open.
    """
    try:
        df.to_csv(target_path, index=False, encoding="utf-8")
        print(f"Saved dataset to: {target_path}")
    except PermissionError:
        fallback_path = target_path.with_name(
            f"{target_path.stem}_{datetime.now().strftime('%Y%m%d_%H%M%S')}{target_path.suffix}"
        )
        df.to_csv(fallback_path, index=False, encoding="utf-8")
        print(f"[WARN] Could not write to locked file: {target_path}")
        print(f"Saved dataset to fallback path: {fallback_path}")


def get_paths() -> dict:
    """
    Resolve paths relative to the project root.
    Assumes this file is located at: src/analysis/python/final_graph_data_analysis.py
    So the project root is 3 levels up.
    """
    project_root = Path(__file__).resolve().parents[3]
    results_dir = project_root / "data" / "results"
    merged_dir = results_dir / "merged_3_4"

    merged_dir.mkdir(parents=True, exist_ok=True)

    # Resolve pooled behavior path (prefer Exp 2 pooled file)
    explicit_behavior_path = results_dir / "behavior_wa_score_relative_pooled_3_4_exp2.csv"
    if explicit_behavior_path.is_file():
        behavior_pooled_path = explicit_behavior_path
    else:
        default_behavior_path = merged_dir / "behavior_wa_score_relative_pooled_3_4.csv"
        if default_behavior_path.is_file():
            behavior_pooled_path = default_behavior_path
        else:
            behavior_candidates = sorted(merged_dir.glob("behavior_wa_score_relative_pooled_3_4*.csv"))
            behavior_pooled_path = behavior_candidates[0] if behavior_candidates else default_behavior_path

    return {
        "project_root": project_root,
        "results_dir": results_dir,
        "merged_dir": merged_dir,
        # Block-level inputs/outputs
        "behavior_block_path": results_dir / "behavior_wa_scores.csv",
        "eye_block_path": results_dir / "block_results_summary.csv",
        "merged_block_output_path": results_dir / "behavior_eye_merged.csv",
        "plot_block1_path": results_dir / "block1_wa_vs_vertical.png",
        "plot_block2_path": results_dir / "block2_wa_vs_vertical.png",
        "plot_behavior_3_vs_4_path": results_dir / "behavior_wa_3_vs_4.png",
        "plot_verticalindex_3_vs_4_path": results_dir / "verticalindex_block1_vs_block2.png",
        # Pooled-level inputs/outputs
        "behavior_pooled_path": behavior_pooled_path,
        "eye_pooled_path": merged_dir / "subject_vertical_index_total_transitions_merged_blocks.csv",
        "merged_pooled_output_path": merged_dir / "behavior_eye_merged_subject_level_3_4.csv",
        "corr_pooled_output_path": merged_dir / "behavior_eye_correlations_subject_level_3_4.csv",
        "plot_pooled_output_path": merged_dir / "behavior_vs_verticalindex_subject_3_4.png",
    }


def normalize_subject_columns(behavior_df: pd.DataFrame, eye_df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    """
    Normalize subject identifier columns so merge will work safely.
    """
    behavior_df = behavior_df.copy()
    eye_df = eye_df.copy()

    if "Subject" in behavior_df.columns:
        behavior_df = behavior_df.rename(columns={"Subject": "subject_id"})
    elif "subject_id" not in behavior_df.columns:
        raise KeyError("Behavior file must contain 'Subject' or 'subject_id'.")

    if "Subject" in eye_df.columns:
        eye_df = eye_df.rename(columns={"Subject": "subject_id"})
    elif "subject_id" not in eye_df.columns:
        raise KeyError("Eye file must contain 'Subject' or 'subject_id'.")

    behavior_df["subject_id"] = behavior_df["subject_id"].astype(str)
    eye_df["subject_id"] = eye_df["subject_id"].astype(str)

    return behavior_df, eye_df


def report_subject_overlap(behavior_df: pd.DataFrame, eye_df: pd.DataFrame) -> list[str]:
    """
    Print and return information about subject ID overlap.
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


def compute_and_report_pearson(
    df: pd.DataFrame,
    x_col: str,
    y_col: str,
    description: str,
    one_tailed: bool = False,
) -> dict | None:
    """
    Compute and print Pearson correlation (supports one-tailed greater or two-tailed).
    """
    if x_col not in df.columns or y_col not in df.columns:
        print(f"[WARN] Columns not found for correlation: {x_col}, {y_col}")
        return None

    subset = df[[x_col, y_col]].dropna()
    n = len(subset)

    if n < 2:
        print(f"[WARN] Not enough valid data points for {description} (n={n}).")
        return None

    try:
        if one_tailed:
            r, p = pearsonr(subset[x_col], subset[y_col], alternative="greater")
        else:
            r, p = pearsonr(subset[x_col], subset[y_col])
    except TypeError:
        # Fallback for older SciPy versions that only support two-sided p-values.
        r, p_two_sided = pearsonr(subset[x_col], subset[y_col])
        if one_tailed:
            p = p_two_sided / 2 if r >= 0 else 1 - (p_two_sided / 2)
        else:
            p = p_two_sided

    p_display = format_p_value(p)
    test_side = "one-sided (greater)" if one_tailed else "two-sided"

    print(
        f"{description}: n = {n}, "
        f"effect size (r) = {r:.4f}, "
        f"p-value (significance) = {p_display} [{test_side}]"
    )

    return {
        "analysis": description,
        "x_col": x_col,
        "y_col": y_col,
        "n": n,
        "pearson_r": r,
        "p_value": p,
        "pearson_r_display": f"{r:.4f}",
        "p_value_display": p_display,
        "test_side": test_side,
    }


def generate_scatter_plot(
    df: pd.DataFrame,
    x_col: str,
    y_col: str,
    x_label: str,
    y_label: str,
    title: str,
    output_path: Path,
    effect_size_r: float | None = None,
    show_legend_if_small: bool = True,
) -> None:
    """
    Unified scatter plot helper: plots x vs y, colors each subject uniquely,
    annotates each point with subject_id, and overlays Pearson r.
    """
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

    plt.xlim(0, 1)
    plt.ylim(0, 1)

    if show_legend_if_small and n_subjects <= 10:
        plt.legend(title="Subject ID", fontsize=8)

    if effect_size_r is not None:
        plt.text(
            0.02,
            0.98,
            f"Effect size\nr = {effect_size_r:.3f}",
            transform=plt.gca().transAxes,
            va="top",
            ha="left",
            fontsize=10,
            bbox={"boxstyle": "round,pad=0.3", "facecolor": "white", "alpha": 0.85},
        )

    plt.grid(True, alpha=0.3)
    plt.tight_layout()
    plt.savefig(output_path, dpi=300)
    plt.close()

    print(f"Scatter plot saved to: {output_path}")


def pivot_eye_data(eye_df: pd.DataFrame) -> pd.DataFrame:
    """
    Pivot long block-level eye data to wide format by subject and block.
    """
    required_columns = {"subject_id", "Block", "VerticalIndex_block"}
    missing = required_columns - set(eye_df.columns)
    if missing:
        raise KeyError(f"Eye data missing required columns: {missing}")

    wide = eye_df.pivot_table(
        index="subject_id",
        columns="Block",
        values=["VerticalIndex_block"],
    )

    renamed_columns = []
    for metric, block in wide.columns.to_flat_index():
        base = metric.replace("_block", "").lower()
        renamed_columns.append(f"{base}_block{int(block)}")

    wide.columns = renamed_columns
    return wide.reset_index()


def run_block_level_analysis(paths: dict) -> None:
    """
    Load data, execute correlations, and plot results at the Block Level (correlate_behavior_eye.py).
    """
    print("\n=========================================")
    print("RUNNING BLOCK-LEVEL CORRELATION ANALYSIS")
    print("=========================================")

    if not paths["behavior_block_path"].is_file():
        print(f"[WARN] Block-level behavior file missing: {paths['behavior_block_path']}")
        return
    if not paths["eye_block_path"].is_file():
        print(f"[WARN] Block-level eye file missing: {paths['eye_block_path']}")
        print("Please run 'run_final_analysis.py' or 'run_full_pipeline.py' first.")
        return

    behavior_df = pd.read_csv(paths["behavior_block_path"])
    eye_df = pd.read_csv(paths["eye_block_path"])

    # Pre-process block-level eye indexes
    if "ScanIndex_block" not in eye_df.columns:
        print("[WARN] Column 'ScanIndex_block' not found in block eye data.")
        return

    eye_df = eye_df.copy()
    eye_df["VerticalIndex_block"] = 1.0 - eye_df["ScanIndex_block"]

    behavior_df, eye_df = normalize_subject_columns(behavior_df, eye_df)
    common_ids = report_subject_overlap(behavior_df, eye_df)

    if not common_ids:
        print("No overlapping subjects for block-level analysis.")
        return

    behavior_df = behavior_df[behavior_df["subject_id"].isin(common_ids)].copy()
    eye_df = eye_df[eye_df["subject_id"].isin(common_ids)].copy()

    # Pivot eye data to wide format
    eye_wide_df = pivot_eye_data(eye_df)

    # Merge behavior and eye data
    merged_df = behavior_df.merge(eye_wide_df, on="subject_id", how="inner")
    print(f"Total matched subjects used in block correlations: {len(merged_df)}")

    save_csv_safe(merged_df, paths["merged_block_output_path"])

    print("\n===== PEARSON CORRELATIONS =====")
    r_block1_dict = compute_and_report_pearson(
        merged_df,
        x_col="wa_score_3",
        y_col="verticalindex_block1",
        description="Block 1 (3-attr): WA score (wa_score_3) vs VerticalIndex_block1",
        one_tailed=True,
    )
    r_block2_dict = compute_and_report_pearson(
        merged_df,
        x_col="wa_score_4",
        y_col="verticalindex_block2",
        description="Block 2 (4-attr): WA score (wa_score_4) vs VerticalIndex_block2",
        one_tailed=True,
    )
    r_behavior_3_vs_4_dict = compute_and_report_pearson(
        merged_df,
        x_col="wa_score_3",
        y_col="wa_score_4",
        description="Behavior Consistency: WA score 3-attribute vs WA score 4-attribute",
        one_tailed=True,
    )
    r_vertical_1_vs_2_dict = compute_and_report_pearson(
        merged_df,
        x_col="verticalindex_block1",
        y_col="verticalindex_block2",
        description="Eye Scan Consistency: Block 1 Vertical index vs Block 2 Vertical index",
        one_tailed=True,
    )
    print("================================\n")

    r_block1 = r_block1_dict["pearson_r"] if r_block1_dict else None
    r_block2 = r_block2_dict["pearson_r"] if r_block2_dict else None
    r_behavior_3_vs_4 = r_behavior_3_vs_4_dict["pearson_r"] if r_behavior_3_vs_4_dict else None
    r_vertical_1_vs_2 = r_vertical_1_vs_2_dict["pearson_r"] if r_vertical_1_vs_2_dict else None

    # Scatter Plots
    generate_scatter_plot(
        merged_df,
        x_col="wa_score_3",
        y_col="verticalindex_block1",
        x_label="Behavioral WA score (higher = more compensatory strategy use)",
        y_label="VerticalIndex_block (higher = more vertical scanning)",
        title="Block 1 (3-attribute): Relationship between compensatory strategy use\nand tendency for vertical scanning",
        output_path=paths["plot_block1_path"],
        effect_size_r=r_block1,
        show_legend_if_small=True,
    )

    generate_scatter_plot(
        merged_df,
        x_col="wa_score_4",
        y_col="verticalindex_block2",
        x_label="Behavioral WA score (higher = more compensatory strategy use)",
        y_label="VerticalIndex_block (higher = more vertical scanning)",
        title="Block 2 (4-attribute): Relationship between compensatory strategy use\nand tendency for vertical scanning",
        output_path=paths["plot_block2_path"],
        effect_size_r=r_block2,
        show_legend_if_small=True,
    )

    generate_scatter_plot(
        merged_df,
        x_col="wa_score_3",
        y_col="wa_score_4",
        x_label="WA score 3-attribute block (wa_score_3)",
        y_label="WA score 4-attribute block (wa_score_4)",
        title="Behavioral tendency for compensatory strategy:\n3-attribute vs 4-attribute blocks",
        output_path=paths["plot_behavior_3_vs_4_path"],
        effect_size_r=r_behavior_3_vs_4,
        show_legend_if_small=True,
    )

    generate_scatter_plot(
        merged_df,
        x_col="verticalindex_block1",
        y_col="verticalindex_block2",
        x_label="VerticalIndex_block1 (3-attribute block)",
        y_label="VerticalIndex_block2 (4-attribute block)",
        title="Eye-scan vertical index:\n3-attribute block vs 4-attribute block",
        output_path=paths["plot_verticalindex_3_vs_4_path"],
        effect_size_r=r_vertical_1_vs_2,
        show_legend_if_small=True,
    )


def run_merged_blocks_analysis(paths: dict) -> None:
    """
    Load data, execute correlations, and plot results at the Subject Level (correlate_behavior_eye_merged_blocks.py).
    """
    print("\n=========================================")
    print("RUNNING POOLED MERGED-BLOCKS ANALYSIS")
    print("=========================================")

    if not paths["behavior_pooled_path"].is_file():
        print(f"[WARN] Pooled behavior file missing: {paths['behavior_pooled_path']}")
        return
    if not paths["eye_pooled_path"].is_file():
        print(f"[WARN] Pooled eye file missing: {paths['eye_pooled_path']}")
        return

    behavior_df = pd.read_csv(paths["behavior_pooled_path"])
    eye_df = pd.read_csv(paths["eye_pooled_path"])

    behavior_df, eye_df = normalize_subject_columns(behavior_df, eye_df)
    common_ids = report_subject_overlap(behavior_df, eye_df)

    if not common_ids:
        print("No overlapping subjects for merged-blocks analysis.")
        return

    behavior_df = behavior_df[behavior_df["subject_id"].isin(common_ids)].copy()
    eye_df = eye_df[eye_df["subject_id"].isin(common_ids)].copy()

    # Merge behavior and eye data
    merged_df = behavior_df.merge(eye_df, on="subject_id", how="inner")
    print(f"Total matched subjects used in pooled correlations: {len(merged_df)}")

    save_csv_safe(merged_df, paths["merged_pooled_output_path"])

    print("\n===== PEARSON CORRELATION =====")
    corr_rows = []
    vertical_corr = compute_and_report_pearson(
        merged_df,
        x_col="wa_score_pooled_3_4",
        y_col="VerticalIndex_subject",
        description="WA pooled (3/4) vs merged vertical eye-scan index",
        one_tailed=True,
    )
    if vertical_corr is not None:
        corr_rows.append(vertical_corr)

    if corr_rows:
        corr_df = pd.DataFrame(corr_rows)
        save_csv_safe(corr_df, paths["corr_pooled_output_path"])
    print("===============================\n")

    # Plot
    generate_scatter_plot(
        merged_df,
        x_col="wa_score_pooled_3_4",
        y_col="VerticalIndex_subject",
        x_label="Behavioral compensatory tendency",
        y_label="VerticalIndex_subject (higher = more vertical scanning)",
        title="Behavioral tendency vs merged vertical eye-scan index",
        output_path=paths["plot_pooled_output_path"],
        effect_size_r=(vertical_corr["pearson_r"] if vertical_corr is not None else None),
        show_legend_if_small=False,
    )


def main() -> None:
    paths = get_paths()

    print("=========================================")
    print("STEP 0: REGENERATING BLOCK-LEVEL SUMMARY")
    print("=========================================")
    try:
        run_block_preprocessing()
    except Exception as e:
        print(f"[ERROR] Failed to run run_final_analysis: {e}")
        sys.exit(1)

    print("=========================================")
    print("STEP 1: REGENERATING MERGED TRANSITIONS")
    print("=========================================")
    # Re-run run_subject_total_transitions_vertical_index to get fresh transitions
    try:
        run_transitions()
    except Exception as e:
        print(f"[ERROR] Failed to run run_subject_total_transitions_vertical_index: {e}")
        sys.exit(1)

    # Verify transition file was generated
    if not paths["eye_pooled_path"].is_file():
        print(f"[ERROR] Transition index file was not generated at: {paths['eye_pooled_path']}")
        sys.exit(1)

    print("\nUsing verified input paths:")
    print(f"  Block behavior : {paths['behavior_block_path']}")
    print(f"  Block eye      : {paths['eye_block_path']}")
    print(f"  Pooled behavior: {paths['behavior_pooled_path']}")
    print(f"  Pooled eye     : {paths['eye_pooled_path']}")

    # Step 2: Block-level Analysis
    run_block_level_analysis(paths)

    # Step 3: Pooled/Merged-blocks Analysis
    run_merged_blocks_analysis(paths)

    print("\n=========================================")
    print("ALL GRAPHS AND CORRELATIONS SUCCESSFULLY GENERATED!")
    print("=========================================")


if __name__ == "__main__":
    main()
