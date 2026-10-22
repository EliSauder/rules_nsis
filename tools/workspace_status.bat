@echo off
REM Windows wrapper for workspace_status.py so it can be used as Bazel's
REM --workspace_status_command on platforms without shebang support.
setlocal
python "%~dp0workspace_status.py"
