---
name: using-uv-run
description: Use when running Python-related commands such as python, pytest, ruff, mypy, or python-based CLIs to ensure they run in uv-managed project environments.
---

# Using `uv run` for Python Commands

## Core Rule

Always run Python-related commands with `uv run`.

If a command would normally be:

- `python ...`
- `pytest ...`
- `ruff ...`
- `mypy ...`
- any other Python-based CLI

run it as:

- `uv run python ...`
- `uv run pytest ...`
- `uv run ruff ...`
- `uv run mypy ...`
- `uv run <python-cli> ...`

## Why

Using `uv run` ensures commands execute in the project's managed Python environment with the correct interpreter and dependencies.

## Quick Conversions

- `python script.py` → `uv run python script.py`
- `python -m pytest tests/` → `uv run python -m pytest tests/`
- `pytest -q` → `uv run pytest -q`
- `ruff check .` → `uv run ruff check .`
- `mypy src/` → `uv run mypy src/`

## Exceptions

Do not prepend `uv run` when using `uv` environment/package management commands that are already `uv`-native, such as:

- `uv sync`
- `uv lock`
- `uv pip ...`
- `uv venv`

## Red Flags

Stop and rewrite the command if you are about to run:

- `python ...` directly
- `pytest ...` directly
- `ruff ...` directly
- `mypy ...` directly

In all such cases, use `uv run` unless an explicit user instruction says otherwise.
