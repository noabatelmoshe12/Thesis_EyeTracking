from pathlib import Path
from datetime import datetime

import pandas as pd
from matplotlib import pyplot as plt
from scipy.stats import pearsonr


def format_p_value(p_value: float) -> str:
    """
    Format p-values in a human-readable way for reports/CSV output.
    """
    if p_value < 0.0001:
        return "<0.0001"
    return f"{p_value:.4f}"


def get_paths() -> dict:
    """
    Resolve paths relative to the project root.

    Assumes this file is located at:
    src/analysis/python/merged_blocks/
    so the project root is 4 levels up.
    """
    project_root = Path(__file__).resolve().parents[4]
    results_dir = project_root / "data" / "results"
    merged_dir = results_dir / "merged_3_4"

    merged_dir.mkdir(parents=True, exist_ok=True)

    # Prefer an explicitly provided results file (user-specified)
    explicit_behavior_path = Path(r"C:\\Projects\\Thesis_EyeTracking\\data\\results\\behavior_wa_score_relative_pooled_3_4_exp2.csv")
    if explicit_behavior_path.is_file():
        behavior_path = explicit_behavior_path
    else:
        default_behavior_path = merged_dir / "behavior_wa_score_relative_pooled_3_4.csv"
        if default_behavior_path.is_file():
            behavior_path = default_behavior_path
        else:
            behavior_candidates = sorted(merged_dir.glob("behavior_wa_score_relative_pooled_3_4*.csv"))
            behavior_path = behavior_candidates[0] if behavior_candidates else default_behavior_path

    return {
        "project_root": project_root,
        "results_dir": results_dir,
        "merged_dir": merged_dir,
        "behavior_path": behavior_path,
        "eye_path": merged_dir / "subject_vertical_index_total_transitions_merged_blocks.csv",
        "merged_output_path": merged_dir / "behavior_eye_merged_subject_level_3_4.csv",
        "corr_output_path": merged_dir / "behavior_eye_correlations_subject_level_3_4.csv",
        "plot_vertical_output_path": merged_dir / "behavior_vs_verticalindex_subject_3_4.png",
    }


def load_data(behavior_path: Path, eye_path: Path) -> tuple[pd.DataFrame, pd.DataFrame]:
    """
    Load behavioral subject-level summary and eye subject-level summary.
    """
    if not behavior_path.is_file():
        raise FileNotFoundError(f"Behavior file not found: {behavior_path}")

    if not eye_path.is_file():
        raise FileNotFoundError(f"Eye file not found: {eye_path}")

    behavior_df = pd.read_csv(behavior_path)
    eye_df = pd.read_csv(eye_path)

    return behavior_df, eye_df


def normalize_subject_columns(behavior_df: pd.DataFrame, eye_df: pd.DataFrame) -> tuple[pd.DataFrame, pd.DataFrame]:
    """
    Normalize subject identifier columns so merge will work safely.
    """
    behavior_df = behavior_df.copy()
    eye_df = eye_df.copy()

    # Adjust here if your behavior file uses a different subject column name
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


def merge_behavior_eye(
    behavior_df: pd.DataFrame,
    eye_df: pd.DataFrame,
    merged_output_path: Path,
) -> pd.DataFrame:
    """
    Merge behavior and eye data on subject_id and save merged CSV.
    """
    merged = behavior_df.merge(eye_df, on="subject_id", how="inner")

    print("Merged data (first rows):")
    print(merged.head())
    print(f"\nTotal matched subjects used in correlations: {len(merged)}\n")

    try:
        merged.to_csv(merged_output_path, index=False, encoding="utf-8")
        print(f"Merged dataset saved to: {merged_output_path}")
    except PermissionError:
        fallback_path = merged_output_path.with_name(
            f"{merged_output_path.stem}_{datetime.now().strftime('%Y%m%d_%H%M%S')}{merged_output_path.suffix}"
        )
        merged.to_csv(fallback_path, index=False, encoding="utf-8")
        print(f"[WARN] Could not write to locked file: {merged_output_path}")
        print(f"Merged dataset saved to fallback path: {fallback_path}")

    return merged


def compute_and_report_pearson(
    df: pd.DataFrame,
    x_col: str,
    y_col: str,
    description: str,
) -> dict | None:
    """
    Compute and print one-sided Pearson correlation (positive direction) for two columns.

    Hypothesis:
    H0: rho <= 0
    H1: rho > 0
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
        r, p = pearsonr(subset[x_col], subset[y_col], alternative="greater")
    except TypeError:
        # Fallback for older SciPy versions that only support two-sided p-values.
        r, p_two_sided = pearsonr(subset[x_col], subset[y_col])
        p = p_two_sided / 2 if r >= 0 else 1 - (p_two_sided / 2)

    p_display = format_p_value(p)

    print(
        f"{description}: n = {n}, "
        f"effect size (r) = {r:.4f}, "
        f"p-value (significance) = {p_display}"
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
        "test_side": "one-sided (greater)",
    }
def scatter_behavior_vs_vertical(
    df: pd.DataFrame,
    behavior_col: str,
    eye_col: str,
    output_path: Path,
    effect_size_r: float | None = None,
) -> None:
    """
    Create and save a scatter plot:
    behavioral tendency vs merged vertical eye-scan index.
    """
    required_columns = {"subject_id", behavior_col, eye_col}
    missing = required_columns - set(df.columns)
    if missing:
        print(f"[WARN] Columns not found for plotting: {missing}")
        return

    plot_df = df[["subject_id", behavior_col, eye_col]].dropna()

    if plot_df.empty:
        print("[WARN] No data available for plotting.")
        return

    subjects = plot_df["subject_id"].astype(str).tolist()
    n_subjects = len(subjects)
    cmap = plt.get_cmap("tab10")
    colors = [cmap(i % cmap.N) for i in range(n_subjects)]

    plt.figure(figsize=(6, 5))

    for (subject, (_, row), color) in zip(subjects, plot_df.iterrows(), colors):
        plt.scatter(row[behavior_col], row[eye_col], s=40, alpha=0.8, color=color)
        plt.annotate(
            subject,
            (row[behavior_col], row[eye_col]),
            textcoords="offset points",
            xytext=(3, 3),
            fontsize=8,
        )

    plt.xlabel("Behavioral compensatory tendency")
    plt.ylabel("VerticalIndex_subject (higher = more vertical scanning)")
    plt.title("Behavioral tendency vs merged vertical eye-scan index")

    y_max = float(plot_df[eye_col].max())
    if y_max <= 0:
        y_max = 0.01
    y_upper = min(1.0, y_max * 1.08)
    plt.ylim(0, y_upper)

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


def main() -> None:
    paths = get_paths()

    print("Using paths:")
    print(f"  Behavior file : {paths['behavior_path']}")
    print(f"  Eye file      : {paths['eye_path']}")
    print(f"  Merged output : {paths['merged_output_path']}")
    print()

    behavior_df, eye_df = load_data(paths["behavior_path"], paths["eye_path"])
    behavior_df, eye_df = normalize_subject_columns(behavior_df, eye_df)

    common_ids = report_subject_overlap(behavior_df, eye_df)
    if not common_ids:
        print("No overlapping subjects between behavior and eye data. Exiting.")
        return

    behavior_df = behavior_df[behavior_df["subject_id"].isin(common_ids)].copy()
    eye_df = eye_df[eye_df["subject_id"].isin(common_ids)].copy()

    merged_df = merge_behavior_eye(
        behavior_df=behavior_df,
        eye_df=eye_df,
        merged_output_path=paths["merged_output_path"],
    )

    print("\n===== PEARSON CORRELATION =====")
    corr_rows = []

    vertical_corr = compute_and_report_pearson(
        merged_df,
        x_col="wa_score_pooled_3_4",
        y_col="VerticalIndex_subject",
        description="WA pooled (3/4) vs merged vertical eye-scan index",
    )
    if vertical_corr is not None:
        corr_rows.append(vertical_corr)

    if corr_rows:
        corr_df = pd.DataFrame(corr_rows)
        try:
            corr_df.to_csv(paths["corr_output_path"], index=False, encoding="utf-8")
            print(f"Correlation summary saved to: {paths['corr_output_path']}")
        except PermissionError:
            fallback_corr_path = paths["corr_output_path"].with_name(
                f"{paths['corr_output_path'].stem}_{datetime.now().strftime('%Y%m%d_%H%M%S')}{paths['corr_output_path'].suffix}"
            )
            corr_df.to_csv(fallback_corr_path, index=False, encoding="utf-8")
            print(f"[WARN] Could not write to locked file: {paths['corr_output_path']}")
            print(f"Correlation summary saved to fallback path: {fallback_corr_path}")

    print("===== END CORRELATION =====\n")

    scatter_behavior_vs_vertical(
        merged_df,
        behavior_col="wa_score_pooled_3_4",
        eye_col="VerticalIndex_subject",
        output_path=paths["plot_vertical_output_path"],
        effect_size_r=(vertical_corr["pearson_r"] if vertical_corr is not None else None),
    )


if __name__ == "__main__":
    main()