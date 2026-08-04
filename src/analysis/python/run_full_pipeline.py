"""Primary orchestration for the eye-tracking analysis pipeline."""

import glob
import os
import re
import sys
from dataclasses import dataclass, field

import pandas as pd

# Configure the participants for one pipeline execution here. Supported forms:
#   101                  -> one participant
#   [101, 105, 201]      -> specific participants
#   range(101, 111)      -> numeric range (Python's stop value is exclusive)
#   "all"                -> every participant discovered in data/raw
PARTICIPANT_SELECTION = "all"

EXPERIMENT_RANGES = {
    "Exp1": (101, 140),
    "Exp2": (201, 245),
}

TRIAL_RESULT_COLUMNS = [
    "Subject",
    "Block",
    "Trial",
    "Horizontal",
    "Vertical",
    "Total",
    "ScanIndex_trial",
]

try:
    import matlab.engine
except ImportError:
    print("Warning: 'matlab.engine' could not be imported.")
    matlab = None


sys.path.append(os.path.dirname(os.path.abspath(__file__)))
try:
    from analyze_movements import (
        calculate_scanpath_index,
        process_fixations_to_movements,
    )
except ImportError:
    print(
        "Warning: Could not import 'analyze_movements'. Final aggregation might fail."
    )


@dataclass
class ParticipantRun:
    """In-memory status for one participant selected for this execution."""

    requested_value: str
    raw_file: str
    participant_id: str | None = None
    experiment: str | None = None
    fixation_file: str | None = None
    processed: bool = False
    skip_reason: str | None = None
    output_files: list[str] = field(default_factory=list)


@dataclass
class PipelineRun:
    """All information used to render the console summary for this execution."""

    participants: list[ParticipantRun] = field(default_factory=list)
    output_files: list[str] = field(default_factory=list)
    requested_selection: str = "all"


def setup_paths():
    """Resolve pipeline input, working, and output paths."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.abspath(os.path.join(script_dir, "..", "..", ".."))

    raw_dir = os.path.join(project_root, "data", "raw")
    processed_dir = os.path.join(project_root, "data", "processed")
    results_dir = os.path.join(project_root, "data", "results")

    print("--- Thesis EyeTracking Pipeline ---")
    print(f"Project Root: {project_root}")

    return {
        "project_root": project_root,
        "raw_dir": raw_dir,
        "processed_dir": processed_dir,
        "results_dir": results_dir,
        "trial_results_files": {
            "Exp1": os.path.join(results_dir, "trial_results_summary_exp1.csv"),
            "Exp2": os.path.join(results_dir, "trial_results_summary_exp2.csv"),
        },
        "matlab_script_dir": os.path.join(project_root, "src", "analysis", "matlab"),
    }


def validate_directories(paths):
    """Create required runtime directories when they do not exist."""
    for directory in (paths["raw_dir"], paths["processed_dir"], paths["results_dir"]):
        if not os.path.exists(directory):
            os.makedirs(directory)
            print(f"Created directory: {directory}")


def experiment_for(participant_id):
    """Return the experiment encoded by the study participant-number range."""
    number = int(participant_id)
    for experiment, (first_participant, last_participant) in EXPERIMENT_RANGES.items():
        if first_participant <= number <= last_participant:
            return experiment
    return None


def _requested_participant_ids(selection):
    """Normalize the configured selection to participant IDs, or None for all."""
    if selection == "all":
        return None
    if isinstance(selection, bool):
        raise TypeError("PARTICIPANT_SELECTION cannot be a boolean")
    if isinstance(selection, (int, str)):
        values = [selection]
    elif isinstance(selection, (list, tuple, set, range)):
        values = list(selection)
    else:
        raise TypeError(
            "PARTICIPANT_SELECTION must be an integer, a collection of participant "
            'numbers, a range, or "all"'
        )

    participant_ids = []
    for value in values:
        text = str(value).strip()
        if not text.isdigit():
            raise ValueError(
                f"Invalid participant number in PARTICIPANT_SELECTION: {value!r}"
            )
        participant_id = str(int(text))
        if participant_id not in participant_ids:
            participant_ids.append(participant_id)
    return participant_ids


def _selection_label(selection, requested_ids):
    """Return a stable console representation of the configured selection."""
    if requested_ids is None:
        return "all available participants"
    if isinstance(selection, range) and requested_ids:
        return f"{requested_ids[0]}-{requested_ids[-1]}"
    return ", ".join(requested_ids) if requested_ids else "None"


def select_participants(paths, selection):
    """Discover raw participants, then apply the orchestration-level selection."""
    pattern = os.path.join(paths["raw_dir"], "Subject_*_eyeData.mat")
    raw_files = sorted(glob.glob(pattern))
    available_participants = []

    for raw_file in raw_files:
        filename = os.path.basename(raw_file)
        match = re.fullmatch(r"Subject_(\d+)_eyeData\.mat", filename)
        participant = ParticipantRun(requested_value=filename, raw_file=raw_file)

        if not match:
            participant.skip_reason = "could not parse participant number from filename"
        else:
            participant.participant_id = match.group(1)
            participant.requested_value = participant.participant_id
            participant.experiment = experiment_for(participant.participant_id)
            if participant.experiment is None:
                participant.skip_reason = (
                    "participant number is outside the Exp1/Exp2 ranges"
                )

        available_participants.append(participant)

    requested_ids = _requested_participant_ids(selection)
    if requested_ids is None:
        selected_participants = available_participants
    else:
        available_by_id = {
            participant.participant_id: participant
            for participant in available_participants
            if participant.participant_id is not None
        }
        selected_participants = []
        for participant_id in requested_ids:
            participant = available_by_id.get(participant_id)
            if participant is None:
                participant = ParticipantRun(
                    requested_value=participant_id,
                    raw_file=os.path.join(
                        paths["raw_dir"], f"Subject_{participant_id}_eyeData.mat"
                    ),
                    participant_id=participant_id,
                    experiment=experiment_for(participant_id),
                    skip_reason="raw participant file was not found",
                )
            selected_participants.append(participant)

    print(f"Found {len(raw_files)} available subject .mat files.")
    print(f"Selected {len(selected_participants)} participants for this run.")
    return selected_participants, _selection_label(selection, requested_ids)


def _file_signature(path):
    """Capture enough state to tell whether a known output path changed in this run."""
    try:
        stat = os.stat(path)
    except FileNotFoundError:
        return None
    return stat.st_mtime_ns, stat.st_size


def _record_if_generated(participant, path, before_signature):
    """Record a known output only when the current operation created or changed it."""
    after_signature = _file_signature(path)
    if after_signature is not None and after_signature != before_signature:
        participant.output_files.append(path)
        return True
    return False


def run_matlab_processing(paths, participants):
    """Generate fixation data for only the participants selected for this run."""
    eligible = [
        participant for participant in participants if participant.skip_reason is None
    ]
    if not eligible:
        return

    if matlab is None:
        raise RuntimeError(
            "MATLAB Engine is required for fixation processing but could not be imported."
        )

    try:
        print("Starting MATLAB Engine...")
        engine = matlab.engine.start_matlab()
        engine.cd(paths["matlab_script_dir"], nargout=0)
        engine.addpath(paths["matlab_script_dir"], nargout=0)
        print("MATLAB Engine started.")
    except Exception as exc:
        raise RuntimeError(
            "MATLAB Engine is required for fixation processing but could not be started."
        ) from exc

    try:
        for participant in eligible:
            participant_id = participant.participant_id
            fixation_file = os.path.join(
                paths["processed_dir"], "fixations", f"{participant_id}_detailed.csv"
            )
            before_signature = _file_signature(fixation_file)
            print(f"Processing Subject {participant_id}...")

            try:
                engine.Convert_eye_data(
                    participant.raw_file,
                    participant_id,
                    paths["project_root"],
                    nargout=0,
                )

                if _record_if_generated(participant, fixation_file, before_signature):
                    participant.fixation_file = fixation_file
                    print("  Done.")
                else:
                    participant.skip_reason = "fixation conversion produced no output"
                    print(
                        f"  Skipping Subject {participant_id}: {participant.skip_reason}."
                    )
            except Exception as exc:  # noqa: BLE001 - continue with other participants
                participant.skip_reason = f"fixation conversion failed: {exc}"
                print(f"  Analysis failed for {participant_id}: {exc}")
    finally:
        try:
            engine.quit()
        except Exception as exc:  # noqa: BLE001 - shutdown must not change results
            print(f"Warning: MATLAB Engine did not close cleanly: {exc}")


def aggregate_fixations(paths, participants):
    """Build and group current-run movements using orchestration metadata."""
    print("\n[Step 3/3] Aggregating Results (CSV -> Summary)...")
    movements_by_experiment = {"Exp1": [], "Exp2": []}

    for participant in participants:
        if participant.skip_reason is not None or participant.fixation_file is None:
            continue

        movement_file = os.path.join(
            paths["processed_dir"],
            "movements",
            f"{participant.participant_id}_movements.csv",
        )
        before_signature = _file_signature(movement_file)

        try:
            movements = process_fixations_to_movements(
                participant.participant_id, participant.fixation_file
            )
            _record_if_generated(participant, movement_file, before_signature)
            if movements.empty:
                participant.skip_reason = "no valid movement data"
            else:
                participant.processed = True
                movements_by_experiment[participant.experiment].append(movements)
        except Exception as exc:  # noqa: BLE001 - continue with other participants
            participant.skip_reason = f"movement aggregation failed: {exc}"
            print(f"  Error aggregating {participant.participant_id}: {exc}")

    if not any(movements_by_experiment.values()):
        print("No valid movement data found to aggregate.")
    return movements_by_experiment


def _normalize_trial_result_schema(trial_results):
    """Apply the historical trial-summary schema without changing calculations."""
    normalized = trial_results.copy()

    for column in ("Horizontal", "Vertical"):
        if column not in normalized.columns:
            normalized[column] = 0
        else:
            normalized[column] = normalized[column].fillna(0)

    if "Total" not in normalized.columns:
        normalized["Total"] = normalized["Horizontal"] + normalized["Vertical"]

    for column in ("Subject", "Block", "Trial", "ScanIndex_trial"):
        if column not in normalized.columns:
            normalized[column] = pd.Series(dtype="object")

    return normalized.loc[:, TRIAL_RESULT_COLUMNS]


def export_results(movements_by_experiment, paths):
    """Export fresh trial summaries routed by the current-run experiment groups."""
    output_files = []

    for experiment in ("Exp1", "Exp2"):
        experiment_movements = movements_by_experiment[experiment]
        if experiment_movements:
            total_movements = pd.concat(experiment_movements, ignore_index=True)
            trial_results = calculate_scanpath_index(total_movements)
        else:
            trial_results = pd.DataFrame()

        trial_results = _normalize_trial_result_schema(trial_results)

        output_file = paths["trial_results_files"][experiment]
        trial_results.to_csv(output_file, index=False, na_rep="NaN")
        output_files.append(output_file)
        print(f"{experiment} trial summary saved to: {output_file}")

    print("\nPipeline Complete!")
    return output_files


def _display_path(path, project_root):
    """Format a recorded path without discovering or inspecting any files."""
    try:
        return os.path.relpath(path, project_root)
    except ValueError:
        return path


def print_run_summary(run, paths):
    """Print a console-only summary from this execution's in-memory state."""
    print("\n--- Current Pipeline Run Summary ---")

    print(f"Requested participant selection: {run.requested_selection}")

    processed = [
        participant for participant in run.participants if participant.processed
    ]
    print(
        "Successfully processed participants: "
        + (
            ", ".join(participant.participant_id for participant in processed)
            if processed
            else "None"
        )
    )

    skipped = [
        participant for participant in run.participants if not participant.processed
    ]
    print("Skipped participants:")
    if skipped:
        for participant in skipped:
            reason = participant.skip_reason or "reason unavailable"
            print(f"  - {participant.requested_value}: {reason}")
    else:
        print("  None")

    print("Experiment assignments:")
    if processed:
        for participant in processed:
            print(f"  - {participant.participant_id}: {participant.experiment}")
    else:
        print("  None")

    generated = [
        output
        for participant in run.participants
        for output in participant.output_files
    ] + run.output_files
    print("Output files generated during this run:")
    if generated:
        for output in generated:
            print(f"  - {_display_path(output, paths['project_root'])}")
    else:
        print("  None")
    print("--- End Current Pipeline Run Summary ---")


def _print_run_summary_safely(run, paths):
    """Keep summary rendering observational and non-fatal to the pipeline."""
    try:
        print_run_summary(run, paths)
    except Exception as exc:  # noqa: BLE001 - summary must never stop the pipeline
        try:
            print(f"Warning: Could not print current-run summary: {exc}")
        except Exception:  # noqa: BLE001,S110 - even a closed stdout is non-fatal
            pass


def run_full_pipeline():
    """Run every pipeline stage and print the summary immediately before returning."""
    run = PipelineRun()
    paths = setup_paths()
    validate_directories(paths)

    run.participants, run.requested_selection = select_participants(
        paths, PARTICIPANT_SELECTION
    )
    run_matlab_processing(paths, run.participants)
    movements_by_experiment = aggregate_fixations(paths, run.participants)
    run.output_files.extend(export_results(movements_by_experiment, paths))

    _print_run_summary_safely(run, paths)
    return run


if __name__ == "__main__":
    run_full_pipeline()
