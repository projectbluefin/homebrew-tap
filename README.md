# Project Bluefin Homebrew Tap

Official [Homebrew](https://brew.sh) tap for Project Bluefin packages and applications on Linux.

## Installation

Add the tap:

```bash
brew tap projectbluefin/tap
```

Install packages:

```bash
brew install <package>
```

Or install directly via full tap syntax:

```bash
brew install projectbluefin/tap/<package>
```

Using in a `Brewfile`:

```ruby
tap "projectbluefin/tap"
cask "chairlift"
cask "bluefin-wallpapers-extra"
cask "bluefin-report"
```

## Packages in this tap

- **`chairlift`**: System management tool for bootc-based installations
- **`bluefin-wallpapers-extra`**: Extra wallpaper collection for Bluefin desktop
- **`bluefin-report`**: "Report a problem" app to review and share a privacy-scrubbed system report as a GitHub issue

## Automation and Releasing

- **Autobump**: Daily automated workflow (`.github/workflows/autobump.yml`) runs `brew bump --tap=projectbluefin/tap` against upstream releases via livecheck blocks. When new versions are detected, pull requests are automatically opened.
- **Dependency updates**: Cask versions and checksums are bumped by Autobump (above). GitHub Actions pins in `.github/workflows/` are updated by Renovate (`renovate.json`, extending `projectbluefin/renovate-config`), with the same rules as the other Project Bluefin repos: third-party actions wait three days after release, `projectbluefin/**` actions update at any time, and majors are never merged automatically. Updates to `autobump.yml` and `auto-merge-bumps.yml` get their own pull requests, because those two workflows hold the MergeRaptor App key and only a person or the hive's pin-only rule may merge changes to them. The `ghcr.io/homebrew/brew:main` CI container image is left floating on its `main` tag on purpose.
- **Testing**: PRs run five jobs in `.github/workflows/tests.yml`: `test-bot` checks tap syntax with `brew test-bot --only-tap-syntax` in a Homebrew container; `bump-only-gate` runs `.github/scripts/bump-only_test.sh` to test the automatic version-update merge rules; `cask-steps` runs `.github/scripts/cask-steps_test.sh` to test the casks' embedded install and uninstall shell scripts, and the launcher rewrites that let the menu entries start the apps, against temporary fixtures; `cask-payload` runs `.github/scripts/cask-payload_test.sh`, which downloads each Linux cask's release archive and checks it still holds every file the install steps expect, that every settings schema it ships is installed by a step, and that every wallpaper the archive's XML lists exists once the install steps have run; and `test-scripts-wired` fails if any `.github/scripts/*_test.sh` is not run by a workflow.
- **Prow & Tide**: Managed through Prow (`.github/workflows/prow.yml`) using Project Bluefin's org Prow configuration (`projectbluefin/.project/prow.yaml`).
  - PRs require approval from an approver or reviewer listed in `OWNERS` (`/lgtm` and `/approve`).
  - Merging is handled automatically by Tide when required conditions are satisfied.
  - Both project maintainers and triage team members have merge and review authorization via `OWNERS`.
