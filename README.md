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
```

## Packages in this tap

- **`chairlift`**: System management tool for bootc-based installations
- **`bluefin-wallpapers-extra`**: Extra wallpaper collection for Bluefin desktop

## Automation and Releasing

- **Autobump**: Daily automated workflow (`.github/workflows/autobump.yml`) runs `brew bump --tap=projectbluefin/tap` against upstream releases via livecheck blocks. When new versions are detected, pull requests are automatically opened.
- **Dependency updates**: Cask versions and checksums are bumped by Autobump (above). GitHub Actions pins in `.github/workflows/` are bumped weekly by Dependabot (`.github/dependabot.yml`). Renovate (`renovate.json`, extending `projectbluefin/renovate-config`) is enabled but currently tracks nothing here: its `github-actions` manager is disabled to avoid duplicate PRs with Dependabot, and that manager is also the only one that reads the `ghcr.io/homebrew/brew:main` CI container image, which floats on its `main` tag.
- **Testing**: PRs run `brew test-bot --only-tap-syntax` on Homebrew container CI (`.github/workflows/tests.yml`).
- **Prow & Tide**: Managed through Prow (`.github/workflows/prow.yml`) using Project Bluefin's org Prow configuration (`projectbluefin/.project/prow.yaml`).
  - PRs require approval from an approver or reviewer listed in `OWNERS` (`/lgtm` and `/approve`).
  - Merging is handled automatically by Tide when required conditions are satisfied.
  - Both project maintainers and triage team members have merge and review authorization via `OWNERS`.
