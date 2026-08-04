import importlib
import sys
import tempfile
import unittest
from pathlib import Path

import pandas as pd

PYTHON_ANALYSIS_DIR = (
    Path(__file__).resolve().parents[1] / "src" / "analysis" / "python"
)
sys.path.insert(0, str(PYTHON_ANALYSIS_DIR))
pipeline = importlib.import_module("run_full_pipeline")


EXPECTED_COLUMNS = [
    "Subject",
    "Block",
    "Trial",
    "Horizontal",
    "Vertical",
    "Total",
    "ScanIndex_trial",
]


def movement_rows(subject, classifications):
    return pd.DataFrame(
        [
            {
                "Subject": str(subject),
                "Block": 1,
                "Trial": 1,
                "Classification": classification,
            }
            for classification in classifications
        ]
    )


class ExperimentTrialSummarySchemaTests(unittest.TestCase):
    def setUp(self):
        self.temporary_directory = tempfile.TemporaryDirectory()
        results_dir = Path(self.temporary_directory.name)
        self.paths = {
            "trial_results_files": {
                "Exp1": str(results_dir / "trial_results_summary_exp1.csv"),
                "Exp2": str(results_dir / "trial_results_summary_exp2.csv"),
            }
        }

    def tearDown(self):
        self.temporary_directory.cleanup()

    def export(self, exp1=None, exp2=None):
        pipeline.export_results(
            {
                "Exp1": [] if exp1 is None else exp1,
                "Exp2": [] if exp2 is None else exp2,
            },
            self.paths,
        )

    def read_output(self, experiment):
        return pd.read_csv(self.paths["trial_results_files"][experiment])

    def test_exp1_output_uses_exact_historical_column_order(self):
        self.export(
            exp1=[movement_rows(101, ["Horizontal", "Vertical"])],
        )

        self.assertEqual(list(self.read_output("Exp1").columns), EXPECTED_COLUMNS)

    def test_exp2_output_uses_exact_historical_column_order(self):
        self.export(
            exp2=[movement_rows(201, ["Horizontal", "Vertical"])],
        )

        self.assertEqual(list(self.read_output("Exp2").columns), EXPECTED_COLUMNS)

    def test_missing_transition_category_is_added_as_zero(self):
        self.export(exp1=[movement_rows(101, ["Horizontal"])])

        result = self.read_output("Exp1")
        self.assertEqual(list(result.columns), EXPECTED_COLUMNS)
        self.assertEqual(result["Horizontal"].tolist(), [1])
        self.assertEqual(result["Vertical"].tolist(), [0])
        self.assertEqual(result["Total"].tolist(), [1])

    def test_header_only_output_uses_complete_schema(self):
        self.export()

        for experiment in ("Exp1", "Exp2"):
            result = self.read_output(experiment)
            self.assertTrue(result.empty)
            self.assertEqual(list(result.columns), EXPECTED_COLUMNS)


class ExperimentAssignmentTests(unittest.TestCase):
    def test_actual_study_range_boundaries(self):
        assignments = {
            101: "Exp1",
            140: "Exp1",
            201: "Exp2",
            245: "Exp2",
        }

        for participant_id, expected_experiment in assignments.items():
            with self.subTest(participant_id=participant_id):
                self.assertEqual(
                    pipeline.experiment_for(participant_id), expected_experiment
                )

    def test_participants_outside_study_ranges_are_unassigned(self):
        for participant_id in (100, 141, 200, 246):
            with self.subTest(participant_id=participant_id):
                self.assertIsNone(pipeline.experiment_for(participant_id))

    def test_unassigned_discovered_participant_is_skipped(self):
        with tempfile.TemporaryDirectory() as temporary_directory:
            raw_dir = Path(temporary_directory)
            (raw_dir / "Subject_141_eyeData.mat").touch()

            participants, _ = pipeline.select_participants(
                {"raw_dir": str(raw_dir)}, "all"
            )

        self.assertEqual(len(participants), 1)
        self.assertIsNone(participants[0].experiment)
        self.assertEqual(
            participants[0].skip_reason,
            "participant number is outside the Exp1/Exp2 ranges",
        )


if __name__ == "__main__":
    unittest.main()
