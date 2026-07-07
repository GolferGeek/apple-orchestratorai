# Effort: Build The Effort System

## Goal
Create the first concrete app effort structure for Apple Orchestrator AI.

## Context
This app uses profile-guided work intake. Inbox files are proposed intentions. Clear intentions become current efforts. Unclear intentions produce blocking questions before any current effort is created.

## Constraints
- Use the agreed directories: `inbox`, `current`, `future`, and `archive`.
- Every accepted effort should have shared note files.
- Use explicit turn ownership in `effort.json`.
- Keep this app's effort files in this repository.

## Acceptance Criteria
- The app registry includes `apple-orchestratorai`.
- The app has an `efforts/` folder with the required subdirectories.
- The repo has an effort folder template.
- There is a validation script for effort folders.
- The effort contract documents turn ownership.
