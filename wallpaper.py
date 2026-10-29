#!/usr/bin/env python3
"""Command-line entry point for the Omarchy wallpaper picker."""

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent / "python_files"))

from picker_core import main


if __name__ == "__main__":
    main()
