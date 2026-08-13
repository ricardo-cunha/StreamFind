---
name: repo-python-venv
description: Use the repository-local .venv for every Python script, test, formatter, or package command in this repository. Use whenever Python is executed or dependencies are installed.
---

# Repository Python Environment

- Never run repository Python code with the system interpreter.
- Use `.venv\Scripts\python.exe` on Windows and `.venv/bin/python` on POSIX.
- Create `.venv` in the repository root if it does not exist.
- Install dependencies only into that environment.
- Prefer `python -m pip` through the selected interpreter.
- Verify the selected interpreter before running a script:
  - Windows: `\.venv\Scripts\python.exe -c "import sys; print(sys.executable)"`
  - POSIX: `\.venv/bin/python -c 'import sys; print(sys.executable)'`
- Do not use `python`, `python3`, or a system `pip` directly for repository work.
