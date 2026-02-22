# Thesis EyeTracking Project

This repository contains the experiment code and analysis pipeline for the "Variable Attribute Decision-Making Task".

## Documentation

*   **[Architecture Overview](architecture.md)**: Explains the project structure, file roles, and data flow.
*   **[Usage Guide](USAGE.md)**: Instructions on how to run the analysis scripts and environment.

## Project Structure

*   `01_Experiment/`: MATLAB Psychtoolbox experiment code.
*   `python_processing/`: Python automation and analysis scripts.
*   `Eyedata/`: Raw data storage.

## Quick Start

1.  Install dependencies: `uv sync`
2.  Run analysis: `uv run python_processing/process_eye_data.py`



Note:
As of Feb 2026, the MATLAB conversion step uses Convert_eye_data.m instead of Analyze_eye_func_v2.m.