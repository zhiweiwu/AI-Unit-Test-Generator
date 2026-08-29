# AI Unit Test Generator

AI-driven unit test generation and coverage analysis workflows built as GitHub Copilot skill packs for .NET projects.

This repository is organized around a set of reusable skills that help with repository scanning, coverage analysis, test planning, and generation/validation of unit tests.

## What this repository contains

- `skills/` — the main skill library for Copilot-based workflows
- `copilot-instructions.md` — repo-level guidance for AI execution
- `README.md` — human-facing project overview and entry point

## Skill overview

The project is structured around the following skills:

- `scan-repository` — discover project files, classify types, and assess testability
- `analyze-coverage` — inspect Coverlet output, lock baselines, and compare coverage
- `plan-tests` — prioritize files and prepare a risk-based test plan
- `generate-and-validate-tests` — generate tests, validate them, and report results

For detailed skill documentation, see the README in the skills folder:

- [skills/README.md](skills/README.md)

## Typical workflow

1. Scan the repository and build a type registry
2. Analyze current coverage and lock the baseline
3. Plan which files need test generation first
4. Generate tests file by file and validate results
5. Review the final coverage report and recommendations

## Project goals

- Improve unit test coverage with structured, repeatable workflows
- Reduce guesswork by using repository analysis and measured coverage data
- Keep AI workflows aligned with explicit quality gates and escalation policies
- Support multi-step execution with Copilot skills rather than ad-hoc generation

## Repository conventions

- Scripts are organized under each skill folder
- Templates and outputs are kept local to the relevant skill
- Execution guidance is intentionally separated from human-facing documentation

## Related docs

- [copilot-instructions.md](copilot-instructions.md)
- [skills/README.md](skills/README.md)

## Notes

This repository is primarily designed for AI-assisted engineering workflows. For execution details, follow the skill definitions under the `skills/` directory rather than treating the top-level README as the execution source of truth.
