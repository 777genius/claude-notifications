# Code Coverage Setup

This project uses real code coverage measurement with **bashcov** on macOS.

## How It Works

### Coverage Collection (macOS only)

1. **macOS workflow** runs tests with bashcov instrumentation
2. **bashcov** generates HTML coverage report in `coverage/`
3. Coverage percentage is extracted and formatted as shields.io JSON
4. JSON is deployed to `gh-pages` branch
5. **Dynamic badge** in README reads from gh-pages and updates automatically

### Why macOS Only?

- **Ruby is pre-installed** on macOS GitHub runners
- **bashcov is reliable** on macOS with BSD tools
- Other platforms (Linux, Windows) still run tests, just without coverage

This keeps CI fast on all platforms while providing accurate coverage metrics.

## Setup Instructions

### 1. Enable GitHub Pages

1. Go to repository Settings → Pages
2. Source: Deploy from a branch
3. Branch: `gh-pages` / `root`
4. Click Save

*The first push will create `gh-pages` branch automatically.*

### 2. Add Codecov Token (Optional)

For full coverage reports on [codecov.io](https://codecov.io/):

1. Sign up at https://codecov.io/ with GitHub
2. Activate your repository
3. Copy the Repository Upload Token
4. Add to GitHub: Settings → Secrets → Actions
   - Name: `CODECOV_TOKEN`
   - Value: (paste token)

**Note:** The dynamic badge works without Codecov. Codecov is optional for detailed reports.

### 3. Verify Setup

After pushing to main:

1. Check GitHub Actions → macOS Tests workflow
2. Look for "Generate coverage badge JSON" step
3. Check that `gh-pages` branch was created
4. Badge in README should show coverage percentage

## Badge URL

The dynamic badge uses this endpoint:

```
https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/777genius/claude-notifications/gh-pages/coverage-badge.json
```

### Badge Format

The badge shows: **"coverage: XX.X% | 148 tests"**

Colors:
- 🟢 **Green** (80%+) - Excellent coverage
- 🟢 **Light Green** (60-79%) - Good coverage
- 🟡 **Yellow** (40-59%) - Needs improvement
- 🔴 **Red** (<40%) - Poor coverage

## Local Coverage Testing

Run coverage locally on macOS:

```bash
# Install bashcov
gem install bashcov simplecov

# Run tests with coverage
bashcov --root . ./test/run-tests.sh

# View report
open coverage/index.html
```

**Note:** bashcov may not work correctly on Linux/Windows. Use macOS for accurate results.

## Coverage Configuration

Coverage settings are in `codecov.yml`:

```yaml
coverage:
  range: "60...100"  # 60%+ is good for bash

flags:
  bash:
    paths:
      - lib/      # Main logic
      - hooks/    # Hook handlers

ignore:
  - test/       # Don't count test code
  - docs/
  - sounds/
  - config/
```

## Troubleshooting

### Badge shows "invalid"

- Wait 5-10 minutes for GitHub Pages to deploy
- Check that `gh-pages` branch exists
- Verify `coverage-badge.json` is in `gh-pages` root

### Coverage seems low

Bash coverage can be tricky:
- Sourced files may not be tracked correctly
- Some helper functions are hard to instrument
- Focus on `lib/` and `hooks/` coverage, not overall %

### Badge not updating

- Ensure push is to `main` branch (PRs don't update badge)
- Check GitHub Actions logs for errors
- Verify gh-pages deployment succeeded

## Understanding Bash Coverage

**Why bash coverage differs from other languages:**

1. **Sourcing complexity** - `source file.sh` doesn't always track correctly
2. **Subshells** - Commands in `$()` may not be counted
3. **Conditional blocks** - Some branches hard to reach in tests
4. **Helper functions** - Utility code may inflate uncovered %

**Good bash coverage targets:**
- 60-70% is good
- 70-80% is excellent
- 80%+ is exceptional (rare for bash)

Don't aim for 100% - focus on testing critical logic in `lib/` and `hooks/`.

## Resources

- [bashcov GitHub](https://github.com/infertux/bashcov) - Coverage tool
- [Codecov Docs](https://docs.codecov.com/) - Coverage reporting
- [Shields.io Endpoint](https://shields.io/endpoint) - Dynamic badges
- [Testing Documentation](testing.md) - Full test guide
