# Quick Setup: Code Coverage Badge

## What Was Added

✅ **Real code coverage** measurement with bashcov
✅ **Dynamic badge** that auto-updates after each push
✅ **Codecov integration** for detailed reports (optional)
✅ **macOS-only coverage** to keep CI fast on all platforms

## Next Steps (After First Push)

### 1. Enable GitHub Pages (Required)

This allows the badge to read coverage data from `gh-pages` branch.

1. Push these changes to `main` branch
2. Wait for macOS workflow to complete (~3-5 minutes)
3. Go to: **Settings → Pages**
4. Set:
   - Source: **Deploy from a branch**
   - Branch: **gh-pages** / **root**
5. Click **Save**

**The badge will start working within 5-10 minutes after enabling Pages.**

### 2. Add Codecov Token (Optional)

For detailed coverage reports at https://codecov.io/

1. Go to https://codecov.io/ and sign in with GitHub
2. Click **Add Repository** → Find `claude-notifications`
3. Copy the **Repository Upload Token**
4. In GitHub: **Settings → Secrets and variables → Actions**
5. Click **New repository secret**:
   - Name: `CODECOV_TOKEN`
   - Value: (paste token)

**Note:** The dynamic badge works without this step. This is only for detailed web reports.

## What to Expect

### First Run

After pushing to main:

1. ✅ macOS Tests workflow runs (~5-7 minutes)
2. ⚙️ Attempts to measure coverage with bashcov
3. ✅ `coverage-badge.json` is created (with coverage % OR test count)
4. ✅ JSON is deployed to `gh-pages` branch
5. ⏳ Wait 5-10 minutes for GitHub Pages to update
6. ✅ Badge in README shows result

### Badge Format

**If coverage measurement succeeds:**
```
tests: 73.5% | 148 tests
```

**If coverage measurement fails (common for bash):**
```
tests: 148 tests
```

**Colors:**
- 🟢 Green (80%+ coverage) - Excellent
- 🟢 Light Green (60-79% coverage) - Good
- 🟡 Yellow (40-59% coverage) - Needs work
- 🔴 Red (<40% coverage) - Poor
- 🔵 Blue (test count only) - Coverage measurement unavailable

### Why Coverage Might Not Work

Bash code coverage is technically challenging:
- **Sourced files** - bashcov may not track sourced lib/ files correctly
- **Subshells** - Code in `$()` may not be measured
- **Helper functions** - Utility code may not be instrumented

**This is normal!** The badge will still show the test count (148 tests), which is a valid quality metric.

### Typical Coverage for Bash

**Don't expect 90%+!** For bash projects:
- 60-70% is **good**
- 70-80% is **excellent**
- 80%+ is **exceptional**

Bash coverage is tricky due to sourcing, subshells, and helper functions.

## Verifying Setup

### Check Workflow

1. Go to **Actions** tab
2. Click latest **macOS Tests** run
3. Look for these steps:
   - ✅ Install bashcov for coverage
   - ✅ Run tests with coverage
   - ✅ Generate coverage badge JSON
   - ✅ Deploy badge to gh-pages

### Check gh-pages Branch

1. Switch to `gh-pages` branch
2. You should see `coverage-badge.json`:

```json
{
  "schemaVersion": 1,
  "label": "coverage",
  "message": "73.5% | 148 tests",
  "color": "brightgreen"
}
```

### Check Badge

Wait 5-10 minutes after first deploy, then refresh README. Badge should show:

```
[coverage: XX.X% | 148 tests]
```

Click it to visit Codecov (if configured).

## Troubleshooting

### Badge shows "invalid"

- Wait 10 minutes for GitHub Pages to activate
- Check that `gh-pages` branch exists
- Verify Pages is enabled in Settings

### Badge not updating after push

- Ensure you pushed to `main` branch
- Check Actions tab for workflow errors
- PRs don't update the badge (only pushes to main)

### Coverage is 0%

- Check macOS workflow logs for bashcov errors
- Verify tests are actually running
- Look for "Coverage report not found" error

## Local Testing

Test coverage locally on macOS:

```bash
# Install bashcov
gem install bashcov simplecov

# Run tests with coverage
bashcov --root . ./test/run-tests.sh

# View HTML report
open coverage/index.html
```

## Documentation

- [Full Coverage Guide](docs/coverage-setup.md) - Detailed explanation
- [Testing Documentation](docs/testing.md) - Test architecture

## Summary

After your first push to main:

1. ⏱️ Wait for macOS workflow (~5-7 min)
2. ⚙️ Enable GitHub Pages in Settings
3. ⏱️ Wait 5-10 min for Pages to deploy
4. ✅ Badge shows coverage!

**Optional:** Add `CODECOV_TOKEN` secret for detailed web reports.

That's it! 🎉
