# Broad PHP Extension Compatibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Release `combodo-powerbi-integration` 1.1.0 with automated proof that the extension itself loads cleanly on PHP 7.0.8 through 8.4, plus a non-blocking PHP nightly signal.

**Architecture:** Keep the production extension dependency-free and compatible with PHP 7.0 syntax. Add a small native-PHP test harness that replaces the iTop APIs with test doubles, loads the real module, exercises installer paths, and validates XML/query/version contracts. GitHub Actions runs the same harness on every supported PHP minor.

**Tech Stack:** PHP 7.0-compatible scripts, SimpleXML, GitHub Actions, PowerShell release packaging, iTop module XML/PHP.

**Spec:** `docs/superpowers/specs/2026-09-04-locale-neutral-powerbi-broad-php-design.md`

## Global Constraints

- Preserve all three existing `QueryOQL` records and their OQL/field behavior.
- Do not add a runtime dependency or an artificial maximum PHP version.
- Treat PHP warnings, notices, and deprecations from extension loading as test failures.
- Distinguish extension-code compatibility from the PHP versions supported by each iTop release.
- Keep every code file at or below 200 physical lines.
- Never include credentials or instance configuration in tests, fixtures, packages, or logs.
- Assign the issue and PR to `dutch2005`; apply labels and the `1.1.0` milestone; use a closing reference to the issue number captured in Task 1.
- Do not merge or release until independent agentic review is substantive and the exact PR head remains green.

---

### Task 1: Create the tracked 1.1.0 extension issue

**Files:**
- Reference: `docs/superpowers/specs/2026-09-04-locale-neutral-powerbi-broad-php-design.md`

- [ ] **Step 1: Confirm repository state and the absence of a conflicting open issue**

Run:

```powershell
git status --short
gh issue list --state open --limit 100 --json number,title,labels,milestone,assignees
```

Expected: the working tree contains only intentional planning changes, and no existing issue owns the broad PHP compatibility scope.

- [ ] **Step 2: Enable issues on the fork if they remain disabled**

Run:

```powershell
gh repo edit dutch2005/combodo-powerbi-integration --enable-issues
```

Expected: repository settings report issues enabled.

- [ ] **Step 3: Create or reuse the `1.1.0` milestone and compatibility labels**

Use `gh api` to create the milestone only when no open milestone with title `1.1.0` exists. Ensure `enhancement`, `testing`, and `php-compatibility` labels exist; create only missing labels.

- [ ] **Step 4: Create the issue from the approved spec**

The issue title is `Add broad PHP compatibility validation for extension 1.1.0`. Its body must include the PHP 7.0.8–8.4 blocking matrix, non-blocking nightly check, iTop/PHP claim boundary, no-regression requirements, and acceptance checklist. Assign `dutch2005`, add the three labels, and attach the `1.1.0` milestone.

- [ ] **Step 5: Record the issue number in the plan execution notes**

Do not edit production files until the issue URL and number are known.

### Task 2: Add a failing, dependency-free compatibility harness

**Files:**
- Create: `tests/TestHarness.php`
- Create: `tests/ItopStubs.php`
- Create: `tests/ExtensionContractTest.php`
- Create: `tests/run.php`

- [ ] **Step 1: Create the minimal assertion and error-capture harness**

In `tests/TestHarness.php`, implement only:

```php
final class TestHarness
{
    private $failures = array();

    public function assertSame($expected, $actual, $message) { /* record mismatch */ }
    public function assertTrue($condition, $message) { /* record false */ }
    public function run($name, $callback) { /* print PASS/FAIL and catch Throwable/Exception */ }
    public function finish() { /* exit 1 on failures, 0 otherwise */ }
}
```

Install an error handler that throws `ErrorException` for every level present in `error_reporting()`. Use PHP 7.0-compatible syntax only; do not use union types, arrow functions, typed properties, or trailing commas after the final argument.

- [ ] **Step 2: Add narrow iTop test doubles**

In `tests/ItopStubs.php`, define the exact APIs touched by the module:

- `SetupWebPage::AddModule()` captures its arguments.
- Empty `ModuleInstallerAPI` parent class.
- `Config` returns a supplied default language.
- `XMLDataLoader` records sessions and loaded filenames without touching a database.
- `CMDBObject` records track information and returns a fake change id.
- `SetupLog::Info()` records messages.
- Temporary `APPCONF` and `ITOP_CONFIG_FILE` constants point to a nonexistent config file.

- [ ] **Step 3: Write contract tests before changing version metadata**

In `tests/ExtensionContractTest.php`, add tests that require the real module and assert:

1. Module code is `combodo-powerbi-integration`.
2. Registered version is `1.1.0`.
3. Dependency remains `itop-request-mgmt-itil/2.7.0||itop-request-mgmt/2.7.0`.
4. Installer class and all three hooks load.
5. Same-version `AfterDatabaseCreation()` performs zero loader sessions.
6. Upgrade `1.0.1` to `1.1.0` loads the English data file once when the configured locale file is absent.
7. `extension.xml` parses and reports version `1.1.0`.
8. `data/en_us.data.combodo-powerbi-integration.xml` parses and contains exactly query ids `1`, `2`, and `3`.
9. Query 1 contains `ref`, query 2 contains `id,name`, and query 3 contains `newvalue,objkey` as normalized field codes.
10. Every `.php`, `.ps1`, and `.m` code file in the repository is at most 200 physical lines.

- [ ] **Step 4: Add the test runner**

`tests/run.php` loads the harness, stubs, and tests, then returns the harness exit code. It must not depend on Composer or PHPUnit.

- [ ] **Step 5: Run the suite and confirm the intended failures**

Run:

```powershell
php -d error_reporting=-1 -d display_errors=1 tests/run.php
```

Expected: failures report the still-current `1.0.1` metadata; unrelated XML, installer, and QueryOQL assertions pass.

- [ ] **Step 6: Commit the failing tests**

```powershell
git add tests
git commit -m "test: define broad PHP extension contract"
```

### Task 3: Update production metadata to 1.1.0

**Files:**
- Modify: `extension.xml`
- Modify: `module.combodo-powerbi-integration.php`

- [ ] **Step 1: Update both authoritative versions**

Change `<version>1.0.1</version>` to `1.1.0` and change the module registration identifier from `combodo-powerbi-integration/1.0.1` to `combodo-powerbi-integration/1.1.0`.

- [ ] **Step 2: Make only proven PHP compatibility changes**

Run syntax and harness tests first. If PHP 7.0–8.4 exposes a warning or incompatibility in production code, apply the smallest PHP 7.0-compatible correction. Do not add version checks merely to silence a hypothetical future issue.

- [ ] **Step 3: Run the local current-PHP suite**

```powershell
php -l module.combodo-powerbi-integration.php
php -l model.combodo-powerbi-integration.php
php -l en.dict.combodo-powerbi-integration.php
php -d error_reporting=-1 -d display_errors=1 tests/run.php
git diff --check
```

Expected: all commands exit zero and no warning/deprecation text appears.

- [ ] **Step 4: Commit the production version update**

```powershell
git add extension.xml module.combodo-powerbi-integration.php
git commit -m "feat: declare extension 1.1.0 compatibility"
```

### Task 4: Add the full hosted PHP matrix

**Files:**
- Create: `.github/workflows/php-compatibility.yml`

- [ ] **Step 1: Add the blocking matrix**

Create one job on `ubuntu-latest` using `shivammathur/setup-php@v2` with `coverage: none` and this exact matrix:

```yaml
php: ['7.0.8', '7.1', '7.2', '7.3', '7.4', '8.0', '8.1', '8.2', '8.3', '8.4']
```

Run `php -d error_reporting=-1 -d display_errors=1 tests/run.php`. Do not set `continue-on-error` on any matrix entry.

- [ ] **Step 2: Add the non-blocking nightly job**

Create a distinct job with PHP `nightly`, `continue-on-error: true`, the same test command, and a clear job name containing `informational`. Trigger it on pushes, pull requests, manual dispatch, and a weekly schedule. The nightly job must never be included in the blocking matrix.

- [ ] **Step 3: Validate workflow structure locally**

Run a YAML parser if available, then inspect with:

```powershell
Select-String -Path .github/workflows/php-compatibility.yml -Pattern "7.0.8|8.4|nightly|continue-on-error"
git diff --check
```

Expected: all ten blocking versions appear and only the nightly job is allowed to fail.

- [ ] **Step 4: Commit CI**

```powershell
git add .github/workflows/php-compatibility.yml
git commit -m "ci: test PHP 7.0 through 8.4"
```

### Task 5: Add reproducible extension packaging and operator documentation

**Files:**
- Create: `scripts/build-release.ps1`
- Modify: `README.md`
- Modify: `exclude.txt`

- [ ] **Step 1: Write a deterministic package builder**

`scripts/build-release.ps1` must:

1. Read both production version declarations and fail unless both equal `1.1.0`.
2. Recreate only `dist/combodo-powerbi-integration-1.1.0/` after validating that exact path is inside the repository.
3. Copy the runtime files and `data/` tree, excluding `.git`, `.github`, `docs`, `tests`, `scripts`, and `dist`.
4. Produce `dist/combodo-powerbi-integration-1.1.0.zip` with the module directory as the archive root.
5. Print the SHA-256 hash of the resulting zip.

Keep the script below 200 physical lines and use literal validated paths for deletion.

- [ ] **Step 2: Update package exclusions**

Expand `exclude.txt` so source-only CI, test, plan, and build files are not treated as runtime extension contents. Preserve `README.md` in source control.

- [ ] **Step 3: Rewrite README compatibility and migration sections**

Document:

- extension 1.1.0 purpose and three Query Phrasebook records;
- PHP 7.0.8–8.4 extension-code validation and non-blocking nightly meaning;
- the rule that the selected iTop release still determines usable PHP versions;
- iTop 3.2.2's tested/operator target of PHP 8.1–8.3, without claiming PHP 8.4 for that iTop release;
- the matching locale-neutral template 1.1.0 and `format=csv&no_localize=1` contract;
- upgrade, rollback, package-build, and test commands;
- the boundary that no live iTop smoke test is implied by the PHP harness.

- [ ] **Step 4: Test packaging**

```powershell
pwsh -NoProfile -File scripts/build-release.ps1
php -d error_reporting=-1 -d display_errors=1 tests/run.php
git diff --check
```

Inspect the zip and assert it contains `extension.xml`, the module PHP file, and the QueryOQL data file, but not `.github`, `tests`, `docs`, or credentials.

- [ ] **Step 5: Commit packaging and docs**

```powershell
git add README.md exclude.txt scripts/build-release.ps1
git commit -m "docs: publish extension 1.1.0 support policy"
```

### Task 6: Validate representative PHP containers

**Files:**
- Evidence only; do not commit transient container output.

- [ ] **Step 1: Run the oldest boundary container**

From the repository root, mount the checkout read-only and run the harness with `php:7.0.8-cli`.

Expected: exit zero with no warning, notice, or deprecation output.

- [ ] **Step 2: Run modern representative containers**

Repeat with `php:8.2-cli` and `php:8.4-cli`.

Expected: both exit zero with identical test counts.

- [ ] **Step 3: Record environment limitations honestly**

If local Docker cannot run, do not weaken or remove the checks. Record local container validation as unavailable and rely on the hosted matrix after push.

### Task 7: Review, PR, and exact-head verification

**Files:**
- Review: all changed files

- [ ] **Step 1: Run the complete local gate**

```powershell
php -d error_reporting=-1 -d display_errors=1 tests/run.php
pwsh -NoProfile -File scripts/build-release.ps1
git diff --check
git status --short
```

- [ ] **Step 2: Invoke independent agentic code review**

Use `superpowers:requesting-code-review`. Resolve every actionable finding, rerun the gate, and obtain a second review if the head changes materially.

- [ ] **Step 3: Push and create the linked PR**

Push `codex/locale-neutral-powerbi-php82`. Create a PR titled `Add broad PHP compatibility validation for 1.1.0`, include `Fixes #` followed by the extension issue number captured in Task 1, link the template issue/PR, assign `dutch2005`, and apply the milestone and labels.

- [ ] **Step 4: Verify the live exact head**

Fetch PR JSON including `headRefOid`, `mergeable`, `mergeStateStatus`, reviews, and checks. Confirm the ten blocking PHP jobs pass, nightly is informational, no review threads remain unresolved, and substantive approval exists for the exact head.

- [ ] **Step 5: Stop before merge unless both repositories are ready**

The extension PR may not merge independently if doing so would produce mismatched public 1.1.0 artifacts. Coordinate with the template plan's release gate.

### Task 8: Coordinated merge and extension release

**Files:**
- Release artifact: `dist/combodo-powerbi-integration-1.1.0.zip`

- [ ] **Step 1: Recheck both exact PR heads immediately before merge**

Confirm version `1.1.0`, mergeability, required checks, unresolved threads, assignment, labels, milestone, and independent approval in both repositories.

- [ ] **Step 2: Merge using exact-head protection**

Use squash merge with each verified `headRefOid`. Abort if either head changed.

- [ ] **Step 3: Rebuild from the extension merge commit**

Check out the exact extension merge commit, rerun tests and `scripts/build-release.ps1`, and record the zip SHA-256.

- [ ] **Step 4: Publish GitHub release `v1.1.0`**

Create the release from the exact extension merge commit and attach the verified zip. Release notes must link the issue and template release, list the PHP matrix, and state the iTop/PHP compatibility boundary.

- [ ] **Step 5: Verify the published asset**

Download the release asset, compare its SHA-256 to the locally verified hash, and confirm the release tag resolves to the intended merge commit.
