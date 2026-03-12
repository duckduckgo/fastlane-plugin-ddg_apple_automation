# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Fastlane plugin providing custom actions and helpers for DuckDuckGo's iOS/macOS release automation. Integrates with Asana, GitHub, Mattermost, and Sentry. Used by workflows in the `duckduckgo/apple-browsers` monorepo (typically at `../apple-browsers`).

## Commands

```bash
# Load Ruby environment (required before running any commands)
source ~/.rvm/scripts/rvm

# Run all tests + linting (default rake task)
rake

# Run only tests
rspec

# Run a single test file
rspec spec/git_helper_spec.rb

# Run linting
rubocop

# Auto-fix lint issues
rubocop -a
```

## Architecture

**Two-tier design**: Actions are thin wrappers delegating to helpers.

- **Actions** (`lib/fastlane/plugin/ddg_apple_automation/actions/`): Each inherits `Fastlane::Action`, implements `self.run(params)` and metadata methods (`description`, `available_options`, etc.). ~20 actions covering Asana integration, release management, and external services.
- **Helpers** (`lib/fastlane/plugin/ddg_apple_automation/helper/`): Class methods containing the real logic. Key helpers:
  - `asana_helper.rb` — Asana API: task extraction, URL parsing, release task management
  - `ddg_apple_automation_helper.rb` — Core release logic: version/build number management, branch creation, xcconfig file operations
  - `git_helper.rb` — Git/GitHub operations: tagging, release lookup, branch freezing/unfreezing
  - `github_actions_helper.rb` — Sets GitHub Actions workflow outputs
- **Assets** (`lib/fastlane/plugin/ddg_apple_automation/assets/`): ERB templates for Asana comments/tasks
- **Tests** (`spec/`): RSpec, flat directory. Tests mock external dependencies with doubles.

## Conventions

- Use `UI.message` for info, `UI.important` for warnings, `UI.user_error!` for fatal errors (raises)
- `ConfigItem` extensions for shared params (`asana_access_token`, `github_token`, `platform`) are in `ddg_apple_automation_helper.rb`
- Release tags: internal = `x.y.z-N+platform` (prerelease), public = `x.y.z+platform`
- Release branches: `release/<platform>/<version>`, hotfix branches: `hotfix/<platform>/<version>`
