#!/usr/bin/env python3
"""
Test runner for AudioControl integration tests.

Usage:
    python run_tests.py                          # Run all integration tests
    python run_tests.py test_name                # Run a specific test by name
    python run_tests.py test1 test2 test3        # Run multiple tests by name
"""

import os
import subprocess
import sys
from pathlib import Path


# All integration test files in this directory.
TEST_FILES = [
    "test_generic_integration.py",
    "test_librespot_integration.py",
    "test_activemonitor_integration.py",
    "test_raat_integration.py",
    "test_volume_integration.py",
    "test_settings_integration.py",
    "test_cache_integration.py",
    "test_backgroundjobs_integration.py",
    "test_mpd_backgroundjobs_integration.py",
    "test_m3u_integration.py",
    "test_coverart_integration.py",
    "test_favourites_integration.py",
    "test_theaudiodb.py",
    "test_fanarttv.py",
    "test_websocket.py",
]


def ensure_dependencies():
    """Ensure Python dependencies are installed."""
    requirements_file = Path(__file__).parent / "requirements.txt"

    print("Installing Python dependencies...")
    result = subprocess.run(
        [sys.executable, "-m", "pip", "install", "-r", str(requirements_file)],
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print(f"Failed to install dependencies: {result.stderr}")
        return False

    print("Dependencies installed successfully")
    return True


def build_audiocontrol():
    """Build the AudioControl binary."""
    print("Building AudioControl binary...")

    project_root = Path(__file__).parent.parent
    result = subprocess.run(
        ["cargo", "build"],
        cwd=str(project_root),
        capture_output=True,
        text=True,
    )

    if result.returncode != 0:
        print(f"Failed to build AudioControl: {result.stderr}")
        return False

    print("AudioControl built successfully")
    return True


def run_tests(test_names=None):
    """Run the integration tests."""
    test_dir = Path(__file__).parent
    print("Running integration tests...")

    all_passed = True

    for test_file in TEST_FILES:
        test_path = test_dir / test_file
        if not test_path.exists():
            print(f"Warning: Test file {test_file} not found")
            continue

        print(f"\n{'=' * 50}")
        print(f"Running {test_file}")
        print(f"{'=' * 50}")

        cmd = [sys.executable, "-m", "pytest", str(test_path), "-v", "--tb=short"]
        if test_names:
            for name in test_names:
                cmd.extend(["-k", name])

        result = subprocess.run(cmd)

        if result.returncode != 0:
            all_passed = False
            print(f"FAILED: {test_file}")
        else:
            print(f"PASSED: {test_file}")

    return all_passed


def main():
    """Main entry point."""
    print("AudioControl Integration Test Runner")
    print("=" * 40)

    os.chdir(Path(__file__).parent)

    if not ensure_dependencies():
        return 1

    if not build_audiocontrol():
        return 1

    test_names = sys.argv[1:] or None

    if run_tests(test_names):
        print("\n" + "=" * 40)
        print("All tests passed!")
        return 0
    else:
        print("\n" + "=" * 40)
        print("Some tests failed!")
        return 1


if __name__ == "__main__":
    sys.exit(main())
