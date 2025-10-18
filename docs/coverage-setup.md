# Code Coverage Setup

This project uses [Codecov](https://codecov.io/) to track test coverage for bash scripts.

## Setup Instructions

### 1. Sign up for Codecov

1. Go to [codecov.io](https://codecov.io/)
2. Sign in with your GitHub account
3. Authorize Codecov to access your repositories

### 2. Add Repository

1. In Codecov dashboard, click "Add Repository"
2. Find `claude-notifications` in the list
3. Click "Activate" to enable coverage tracking

### 3. Get Codecov Token

1. In the repository settings on Codecov, go to "Settings" → "General"
2. Copy the "Repository Upload Token"

### 4. Add Token to GitHub Secrets

1. Go to your GitHub repository settings
2. Navigate to "Secrets and variables" → "Actions"
3. Click "New repository secret"
4. Name: `CODECOV_TOKEN`
5. Value: Paste the token from step 3
6. Click "Add secret"

### 5. Verify Setup

1. Push changes to trigger CI workflow
2. Wait for Linux tests to complete
3. Check Codecov dashboard for coverage report
4. Coverage badge in README.md should now display percentage

## Coverage Badge

The coverage badge is automatically updated after each push:

```markdown
[![codecov](https://codecov.io/gh/777genius/claude-notifications/branch/main/graph/badge.svg)](https://codecov.io/gh/777genius/claude-notifications)
```

## Local Coverage Testing

You can generate coverage reports locally on Linux:

```bash
# Install kcov (Ubuntu/Debian)
sudo apt-get install kcov

# Run tests with coverage
mkdir -p coverage
for test_file in test/test-*.sh; do
  test_name=$(basename "$test_file" .sh)
  kcov --exclude-pattern=/usr,/tmp coverage/"$test_name" bash "$test_file"
done

# View coverage report
open coverage/index.html  # or use your browser
```

## How It Works

### kcov

[kcov](https://github.com/SimonKagstrom/kcov) is a code coverage tool that works with bash scripts:

- Uses kernel debug information to track execution
- Generates cobertura XML and HTML reports
- Works without modifying the original scripts

### Coverage Collection

The Linux CI workflow:

1. Installs kcov via apt-get
2. Runs each test file with kcov instrumentation
3. Generates coverage reports in `coverage/` directory
4. Uploads reports to Codecov using `codecov-action@v4`

### Coverage Metrics

Codecov tracks:

- **Line coverage** - Percentage of lines executed by tests
- **Branch coverage** - Percentage of conditional branches tested
- **File coverage** - Coverage per file

### Configuration

Coverage settings are defined in `codecov.yml`:

```yaml
coverage:
  precision: 2
  round: down
  range: "70...100"
```

This means:
- Coverage is rounded down to 2 decimal places
- Acceptable range is 70-100%
- Project status checks require maintaining coverage

## Troubleshooting

### Badge not updating

- Ensure `CODECOV_TOKEN` is set in GitHub secrets
- Check CI logs for upload errors
- Wait 5-10 minutes for Codecov to process the report

### Coverage is 0%

- Verify kcov is installed correctly in CI
- Check that tests are actually running
- Look for kcov errors in CI logs

### Coverage seems too low

- Bash coverage can be tricky due to sourcing and subshells
- Some helper functions may not be tracked correctly
- Focus on main logic files (hooks/, lib/)

## Resources

- [Codecov Documentation](https://docs.codecov.com/)
- [kcov GitHub](https://github.com/SimonKagstrom/kcov)
- [Bash Code Coverage Best Practices](https://github.com/SimonKagstrom/kcov/blob/master/COVERAGE.md)
