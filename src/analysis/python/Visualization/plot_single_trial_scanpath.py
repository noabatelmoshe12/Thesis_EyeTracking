# ============================================================
# plot_trial_movements_on_table_timecolor.py
#
# Purpose:
# Plot scanpath on a schematic stimulus table.
#
# Each AOI visit is shown as a small dot.
# Time/order is represented by color.
# Multiple visits to the same AOI are shown as nearby dots
# within the same table cell.
#
# Output:
# C:\Projects\Thesis_EyeTracking\data\results\scanpath_plots
# ============================================================

import pandas as pd
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from pathlib import Path
import numpy as np


# ============================================================
# User settings
# ============================================================

BASE_DIR = Path(r"C:\Projects\Thesis_EyeTracking")

SUBJECT = 217
BLOCK = 1
TRIAL = 36

MOVEMENTS_CSV = (
    BASE_DIR
    / "data"
    / "processed"
    / "movements"
    / f"{SUBJECT}_movements.csv"
)

# If your movements file is elsewhere, use exact path:
# MOVEMENTS_CSV = Path(
#     r"C:\Projects\Thesis_EyeTracking\data\processed\fixations\217_movements(1).csv"
# )

OUTPUT_DIR = BASE_DIR / "data" / "results" / "scanpath_plots"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

SHOW_IGNORED_TRANSITIONS = True

# תיקון: לכלול גם אזורי תכונות AT1/AT2/AT3/AT4
INCLUDE_ATTRIBUTE_AOIS = True

SHOW_CELL_LABELS = False
SHOW_ATTRIBUTE_LABELS = True

# Show thin arrows between consecutive gaze visits
SHOW_ARROWS = True

# ============================================================
# Column names in movements file
# ============================================================

SUBJECT_COL = "Subject"
BLOCK_COL = "Block"
TRIAL_COL = "Trial"

MOVE_INDEX_COL = "Move_Index"
FROM_AOI_COL = "From_AOI_Raw"
TO_AOI_COL = "To_AOI_Raw"
CLASSIFICATION_COL = "Classification"


# ============================================================
# Attribute labels
# ============================================================

ATTR_LABELS_3 = [
    "intelligence",
    "work ethic",
    "easy to work with",
]

ATTR_LABELS_4 = [
    "intelligence",
    "work ethic",
    "easy to work with",
    "creativity",
]


# ============================================================
# Helpers
# ============================================================

def clean_aoi(aoi):
    if pd.isna(aoi):
        return "NA"
    return str(aoi).strip()


def load_trial_movements(movements_csv, subject, block, trial):
    print(f"Reading movements file from: {movements_csv}")
    print(f"Does file exist? {movements_csv.exists()}")

    if not movements_csv.exists():
        raise FileNotFoundError(f"Movements file not found:\n{movements_csv}")

    df = pd.read_csv(movements_csv)

    required_cols = [
        SUBJECT_COL,
        BLOCK_COL,
        TRIAL_COL,
        MOVE_INDEX_COL,
        FROM_AOI_COL,
        TO_AOI_COL,
        CLASSIFICATION_COL,
    ]

    missing = [col for col in required_cols if col not in df.columns]
    if missing:
        raise ValueError(
            f"Missing columns in movements file: {missing}\n\n"
            f"Existing columns:\n{list(df.columns)}"
        )

    trial_df = df[
        (df[SUBJECT_COL] == subject)
        & (df[BLOCK_COL] == block)
        & (df[TRIAL_COL] == trial)
    ].copy()

    if trial_df.empty:
        raise ValueError(
            f"No movements found for Subject={subject}, Block={block}, Trial={trial}"
        )

    trial_df[FROM_AOI_COL] = trial_df[FROM_AOI_COL].apply(clean_aoi)
    trial_df[TO_AOI_COL] = trial_df[TO_AOI_COL].apply(clean_aoi)
    trial_df[CLASSIFICATION_COL] = trial_df[CLASSIFICATION_COL].astype(str).str.strip()

    trial_df = trial_df.sort_values(MOVE_INDEX_COL).reset_index(drop=True)

    return trial_df


def infer_attr_count(trial_df):
    all_aois = set(
        trial_df[FROM_AOI_COL].tolist()
        + trial_df[TO_AOI_COL].tolist()
    )

    if "A4" in all_aois or "B4" in all_aois or "AT4" in all_aois:
        return 4

    return 3


def prepare_movements_for_plot(trial_df, attr_count):
    valid_aois = set()

    for i in range(1, attr_count + 1):
        valid_aois.add(f"A{i}")
        valid_aois.add(f"B{i}")

        # תיקון: להוסיף גם אזורי תכונות
        if INCLUDE_ATTRIBUTE_AOIS:
            valid_aois.add(f"AT{i}")

    df = trial_df[
        trial_df[FROM_AOI_COL].isin(valid_aois)
        & trial_df[TO_AOI_COL].isin(valid_aois)
    ].copy()

    if not SHOW_IGNORED_TRANSITIONS:
        df = df[df[CLASSIFICATION_COL].isin(["Horizontal", "Vertical"])].copy()

    df = df.reset_index(drop=True)

    if df.empty:
        raise ValueError(
            "No movements remained after filtering. "
            "Try setting SHOW_IGNORED_TRANSITIONS = True."
        )

    return df


# ============================================================
# Table geometry
# ============================================================

def build_table_geometry(attr_count):
    """
    Creates a clean table layout:
    attribute labels | A | B
    """

    x_left = 0.0
    x_attr_right = 2.8
    x_a_right = 4.5
    x_b_right = 6.2

    row_h = 1.15
    header_h = 1.25

    y_bottom = 0.0
    y_top = header_h + attr_count * row_h

    aoi_centers = {}
    cell_size = {}

    for attr_idx in range(1, attr_count + 1):
        row_top = y_top - header_h - (attr_idx - 1) * row_h
        row_bottom = row_top - row_h
        y_center = (row_top + row_bottom) / 2

        a_center_x = (x_attr_right + x_a_right) / 2
        b_center_x = (x_a_right + x_b_right) / 2

        # תיקון: מרכז תא התכונה עבור AT
        at_center_x = (x_left + x_attr_right) / 2

        # תיקון: להוסיף מיקום וגודל תא עבור AT1/AT2/AT3/AT4
        if INCLUDE_ATTRIBUTE_AOIS:
            aoi_centers[f"AT{attr_idx}"] = (at_center_x, y_center)
            cell_size[f"AT{attr_idx}"] = (x_attr_right - x_left, row_h)

        aoi_centers[f"A{attr_idx}"] = (a_center_x, y_center)
        aoi_centers[f"B{attr_idx}"] = (b_center_x, y_center)

        cell_size[f"A{attr_idx}"] = (x_a_right - x_attr_right, row_h)
        cell_size[f"B{attr_idx}"] = (x_b_right - x_a_right, row_h)

    return {
        "x_left": x_left,
        "x_attr_right": x_attr_right,
        "x_a_right": x_a_right,
        "x_b_right": x_b_right,
        "x_right": x_b_right,
        "y_bottom": y_bottom,
        "y_top": y_top,
        "row_h": row_h,
        "header_h": header_h,
        "aoi_centers": aoi_centers,
        "cell_size": cell_size,
    }


# ============================================================
# Draw table
# ============================================================

def draw_table(ax, attr_count, geometry):
    x_left = geometry["x_left"]
    x_attr_right = geometry["x_attr_right"]
    x_a_right = geometry["x_a_right"]
    x_b_right = geometry["x_b_right"]
    x_right = geometry["x_right"]

    y_bottom = geometry["y_bottom"]
    y_top = geometry["y_top"]
    row_h = geometry["row_h"]
    header_h = geometry["header_h"]

    attr_labels = ATTR_LABELS_4 if attr_count == 4 else ATTR_LABELS_3

    ax.add_patch(
        Rectangle(
            (x_left, y_bottom),
            x_right - x_left,
            y_top - y_bottom,
            facecolor="white",
            edgecolor="black",
            linewidth=2,
            zorder=0,
        )
    )

    # Vertical lines
    for x in [x_left, x_attr_right, x_a_right, x_b_right]:
        ax.plot([x, x], [y_bottom, y_top], color="black", linewidth=2, zorder=1)

    # Horizontal lines
    for i in range(attr_count + 2):
        y = y_bottom + i * row_h
        ax.plot([x_left, x_right], [y, y], color="black", linewidth=2, zorder=1)

    # Headers
    header_y = y_top - header_h / 2

    ax.text(
        (x_attr_right + x_a_right) / 2,
        header_y,
        "A",
        ha="center",
        va="center",
        fontsize=20,
        fontweight="bold",
        color="darkred",
        zorder=3,
    )

    ax.text(
        (x_a_right + x_b_right) / 2,
        header_y,
        "B",
        ha="center",
        va="center",
        fontsize=20,
        fontweight="bold",
        color="darkred",
        zorder=3,
    )

    # Rows
    for attr_idx in range(1, attr_count + 1):
        row_top = y_top - header_h - (attr_idx - 1) * row_h
        row_bottom = row_top - row_h
        y_center = (row_top + row_bottom) / 2

        if SHOW_ATTRIBUTE_LABELS:
            ax.text(
                x_left + 0.28,
                y_center,
                f"{attr_labels[attr_idx - 1]} – {attr_count - attr_idx + 1}",
                ha="left",
                va="center",
                fontsize=14,
                color="darkgreen",
                zorder=3,
            )

        if SHOW_CELL_LABELS:
            ax.text(
                (x_attr_right + x_a_right) / 2,
                y_center,
                f"A{attr_idx}",
                ha="center",
                va="center",
                fontsize=13,
                color="gray",
                alpha=0.22,
                zorder=2,
            )
            ax.text(
                (x_a_right + x_b_right) / 2,
                y_center,
                f"B{attr_idx}",
                ha="center",
                va="center",
                fontsize=13,
                color="gray",
                alpha=0.22,
                zorder=2,
            )

    ax.set_xlim(x_left - 0.15, x_right + 0.15)
    ax.set_ylim(y_bottom - 0.12, y_top + 0.32)
    ax.set_aspect("equal")
    ax.axis("off")


# ============================================================
# Build visit sequence from movement rows
# ============================================================

def build_visit_sequence(plot_df):
    """
    Convert transitions into visit sequence.

    Example:
    A3 -> A1
    A1 -> A2
    A2 -> A1

    becomes:
    A3, A1, A2, A1
    """

    sequence = [plot_df.iloc[0][FROM_AOI_COL]]
    edge_classes = []

    for _, row in plot_df.iterrows():
        sequence.append(row[TO_AOI_COL])
        edge_classes.append(row[CLASSIFICATION_COL])

    return sequence, edge_classes


# ============================================================
# Make multiple visits in the same cell appear nearby
# ============================================================

def get_jitter_offsets():
    """
    Offsets for repeated visits to the same AOI.
    This creates several nearby dots inside the same cell.
    """
    return [
        (0.00, 0.00),
        (-0.16, 0.12),
        (0.16, 0.12),
        (-0.16, -0.12),
        (0.16, -0.12),
        (0.00, 0.22),
        (0.00, -0.22),
        (-0.26, 0.00),
        (0.26, 0.00),
    ]


def compute_visit_positions(sequence, geometry):
    aoi_centers = geometry["aoi_centers"]
    cell_size = geometry["cell_size"]

    visit_counts = {}
    offsets = get_jitter_offsets()

    positions = []

    for aoi in sequence:
        if aoi not in aoi_centers:
            raise ValueError(
                f"AOI {aoi} has no position in aoi_centers. "
                f"Check INCLUDE_ATTRIBUTE_AOIS and attr_count."
            )

        visit_counts[aoi] = visit_counts.get(aoi, 0) + 1
        visit_index_in_same_cell = visit_counts[aoi] - 1

        center_x, center_y = aoi_centers[aoi]
        cell_w, cell_h = cell_size[aoi]

        dx_norm, dy_norm = offsets[visit_index_in_same_cell % len(offsets)]

        # Convert normalized offsets to actual cell-space offsets
        dx = dx_norm * cell_w
        dy = dy_norm * cell_h

        positions.append((center_x + dx, center_y + dy))

    return positions


# ============================================================
# Plot time-colored points and arrows
# ============================================================

def _segment_overlap_key(p1, p2, eps=1e-9):
    x1, y1 = p1
    x2, y2 = p2

    if abs(x1 - x2) < eps:
        # Group all vertical arrows on the same x corridor,
        # not only identical segment ranges.
        return ("vertical", round((x1 + x2) / 2, 6))

    if abs(y1 - y2) < eps:
        # Group all horizontal arrows on the same y corridor,
        # not only identical segment ranges.
        return ("horizontal", round((y1 + y2) / 2, 6))

    a = (round(x1, 6), round(y1, 6))
    b = (round(x2, 6), round(y2, 6))
    return ("diagonal",) + tuple(sorted([a, b]))


def _compute_overlap_shift(p1, p2, lane, base_offset=0.08):
    if lane <= 0:
        return 0.0, 0.0

    x1, y1 = p1
    x2, y2 = p2
    dx = x2 - x1
    dy = y2 - y1
    length = np.hypot(dx, dy)

    if length == 0:
        return 0.0, 0.0

    # Perpendicular unit vector for a parallel shift.
    px = -dy / length
    py = dx / length

    # Prefer left-side shift on screen whenever possible.
    if px > 0:
        px = -px
        py = -py

    magnitude = base_offset * lane

    return px * magnitude, py * magnitude


def plot_time_colored_scanpath(ax, sequence, edge_classes, positions):
    n_visits = len(sequence)

    # Draw arrows first, behind the points
    if SHOW_ARROWS:
        edge_keys = []
        segment_totals = {}

        for i, _ in enumerate(edge_classes):
            key = _segment_overlap_key(positions[i], positions[i + 1])
            edge_keys.append(key)
            segment_totals[key] = segment_totals.get(key, 0) + 1

        segment_seen = {}

        for i, classification in enumerate(edge_classes):
            x1, y1 = positions[i]
            x2, y2 = positions[i + 1]

            key = edge_keys[i]
            overlap_index = segment_seen.get(key, 0)
            segment_seen[key] = overlap_index + 1
            total_for_key = segment_totals[key]

            # Keep first arrow close to center and shift later overlaps
            # to one preferred side for easier visual tracking.
            lane = overlap_index

            shift_x, shift_y = _compute_overlap_shift(
                (x1, y1),
                (x2, y2),
                lane,
            )

            x1s, y1s = x1 + shift_x, y1 + shift_y
            x2s, y2s = x2 + shift_x, y2 + shift_y

            if classification == "Vertical":
                line_style = "-"
                alpha = 0.95
                line_width = 2.6
            elif classification == "Horizontal":
                line_style = "-"
                alpha = 0.95
                line_width = 2.6
            else:
                line_style = "--"
                alpha = 0.70
                line_width = 2.0

            ax.annotate(
                "",
                xy=(x2s, y2s),
                xytext=(x1s, y1s),
                arrowprops=dict(
                    arrowstyle="->",
                    color="royalblue",
                    lw=line_width,
                    linestyle=line_style,
                    alpha=alpha,
                    shrinkA=6,
                    shrinkB=6,
                ),
                zorder=4,
            )

    # Draw dots colored by time
    xs = [p[0] for p in positions]
    ys = [p[1] for p in positions]

    scatter = ax.scatter(
        xs,
        ys,
        color="#555555",
        s=65,
        edgecolors="black",
        linewidths=0.6,
        zorder=6,
    )

    # Tiny order numbers near points, optional but useful
    for i, (x, y) in enumerate(positions, start=1):
        ax.text(
            x + 0.08,
            y + 0.08,
            str(i),
            fontsize=8,
            color="black",
            fontweight="bold",
            zorder=7,
        )

    return scatter


# ============================================================
# Print info
# ============================================================

def print_trial_info(plot_df, sequence, edge_classes):
    print("\n====================================")
    print("Plotted movements")
    print("====================================")
    print(
        plot_df[
            [MOVE_INDEX_COL, FROM_AOI_COL, TO_AOI_COL, CLASSIFICATION_COL]
        ].to_string(index=False)
    )

    print("\nVisit sequence:")
    print(" -> ".join(sequence))

    print("\nCounts:")
    print(f"Horizontal: {sum(c == 'Horizontal' for c in edge_classes)}")
    print(f"Vertical:   {sum(c == 'Vertical' for c in edge_classes)}")
    print(f"Ignored:    {sum(c == 'Ignored' for c in edge_classes)}")


# ============================================================
# Main plotting function
# ============================================================

def plot_trial_table_scanpath(plot_df, attr_count, subject, block, trial):
    geometry = build_table_geometry(attr_count)

    sequence, edge_classes = build_visit_sequence(plot_df)
    positions = compute_visit_positions(sequence, geometry)

    print_trial_info(plot_df, sequence, edge_classes)

    fig, ax = plt.subplots(figsize=(8.4, 5.8))

    draw_table(ax, attr_count, geometry)

    plot_time_colored_scanpath(
        ax=ax,
        sequence=sequence,
        edge_classes=edge_classes,
        positions=positions,
    )

    n_horizontal = sum(c == "Horizontal" for c in edge_classes)
    n_vertical = sum(c == "Vertical" for c in edge_classes)
    n_ignored = sum(c == "Ignored" for c in edge_classes)

    ax.set_title(
        f"Scanpath on stimulus table | Subject {subject}, Block {block}, Trial {trial}\n"
        f"Horizontal={n_horizontal}, Vertical={n_vertical}, Ignored={n_ignored}",
        fontsize=16,
    )

    plt.tight_layout()

    output_path = (
        OUTPUT_DIR
        / f"scanpath_table_timecolor_sub-{subject}_block-{block}_trial-{trial}.png"
    )

    plt.savefig(output_path, dpi=300, bbox_inches="tight")
    plt.close()

    print(f"\nSaved figure to:\n{output_path}")


# ============================================================
# Main
# ============================================================

def main():
    trial_df = load_trial_movements(
        movements_csv=MOVEMENTS_CSV,
        subject=SUBJECT,
        block=BLOCK,
        trial=TRIAL,
    )

    attr_count = infer_attr_count(trial_df)

    plot_df = prepare_movements_for_plot(
        trial_df=trial_df,
        attr_count=attr_count,
    )

    plot_trial_table_scanpath(
        plot_df=plot_df,
        attr_count=attr_count,
        subject=SUBJECT,
        block=BLOCK,
        trial=TRIAL,
    )


if __name__ == "__main__":
    main()