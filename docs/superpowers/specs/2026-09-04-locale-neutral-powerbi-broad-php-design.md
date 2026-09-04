# Locale-Neutral Power BI and Broad PHP Compatibility Design

## Summary

Release version 1.1.0 of the iTop extension and Power BI template with a stable, locale-neutral data contract. The report interface remains English, while refresh works for every iTop-supported left-to-right language. English, German, Dutch, and French are explicit test fixtures. The same release makes the extension code compatible with the broad PHP 7.0.8 through 8.4 range used across supported iTop generations and adds early-warning checks for future PHP versions.

## Problem

The current template reads iTop's `spreadsheet` HTML export with `Web.Page`, promotes the translated display labels to column names, and then addresses English names such as `Ref`, `id (Primary Key)`, and `New value`. A user whose iTop language is not English receives different headings, so Power Query stops at its first missing English column. Translated enumeration values can also alter filtering without producing an obvious schema error.

The extension documentation currently advertises PHP 8.1 as its maximum even though different supported iTop releases cover a wider PHP range. The extension has no automated compatibility validation, so its simple code can become artificially constrained by stale documentation or unnoticed deprecations.

## Scope

### Included

- Keep all existing reports, visuals, measures, relationships, filters, and query coverage.
- Make ingestion independent of iTop display-language labels.
- Explicitly validate English, German, Dutch, and French response fixtures.
- Support all other iTop left-to-right languages through the same internal-code contract.
- Detect login pages, invalid query identifiers, malformed CSV, and schema drift with actionable errors.
- Verify the extension code on every PHP minor line from 7.0 through 8.4, with PHP 7.0.8 as the precise minimum.
- Run a non-blocking PHP nightly check to identify future incompatibilities before a new PHP version is supported by iTop.
- Release the extension and template with synchronized version 1.1.0 metadata.
- Store editable Power BI project sources alongside the generated `.pbit` artifact.

### Excluded

- Translating report titles, visual captions, or filters.
- Certifying right-to-left report presentation.
- Adding a new iTop webservice or changing iTop core.
- Claiming that an iTop/PHP combination is supported when that iTop release does not support the PHP version.
- Treating a successful PHP nightly syntax check as a supported production runtime.
- Persisting iTop credentials in source control or generated release assets.

## Repositories and Ownership

The extension repository owns the Query Phrasebook definitions, version metadata, compatibility tests, and operator documentation. A fork of `Combodo/combodo-powerbi-template` owns the source-controlled report project and generated template. Both repositories use version 1.1.0 and link their issues and pull requests to each other.

Every created issue and pull request is assigned to `dutch2005`, labeled, attached to a 1.1.0 milestone, and linked with a closing reference. Issues are enabled on the forks if necessary.

## Data Contract

The Power BI connector requests each Query Phrasebook URL with these effective export options:

- `format=csv`
- `no_localize=1`
- a deterministic date/time format

The connector uses the existing Basic Authorization header supplied from required Power BI parameters. Power BI's data-source credential mode remains Anonymous so it does not replace that header.

iTop returns stable internal attribute codes such as `id`, `ref`, `newvalue`, and `objkey`. The connector validates those codes before any type conversion, then renames them to the current semantic model names. Date/time values are split in Power Query so the existing model's date and time columns remain available.

No per-language heading map is used. Language support therefore does not require ongoing translation maintenance and is unaffected by customized display labels.

## Power Query Components

Small reusable M functions separate responsibilities:

1. URL construction merges the required export parameters without duplicating existing query parameters.
2. HTTP retrieval supplies authorization and captures response metadata.
3. CSV parsing applies explicit encoding, delimiter, quoting, and header promotion.
4. Schema validation compares the actual internal codes with the required codes for each query.
5. Model shaping renames fields, applies types, splits date/time values, and preserves current output table schemas.

UserRequest and UserRequest_Period share one shaping function. TeamList and FirstTeam_Affected use smaller schemas. Optional FirstTeam_Affected behavior remains unchanged when its URL parameter is blank.

No M source file may exceed 200 lines. Shared behavior is extracted rather than duplicated.

## Error Handling

The connector fails before model shaping with a concise diagnostic when:

- the HTTP response is a login or HTML error page;
- the Query Phrasebook identifier is invalid;
- required internal fields are absent;
- CSV parsing fails or produces an unexpected shape;
- authentication parameters are empty;
- a required URL is empty.

Errors name the affected query, list missing field codes, and direct the operator to verify credentials and the current Query Phrasebook URL. Credentials are never included in diagnostics.

## Broad PHP Compatibility

The extension uses syntax and APIs compatible with PHP 7.0.8 through PHP 8.4 and does not declare an artificial maximum PHP version. Blocking CI covers PHP 7.0, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, and 8.4. Tests treat warnings, deprecations, and notices from extension loading as failures.

Extension-code compatibility and installed-runtime compatibility are separate claims. Operators must use a PHP version supported by their chosen iTop release. For example, extension code passing PHP 8.4 tests does not make iTop 3.2.2 compatible with PHP 8.4.

The code follows the oldest supported syntax level and avoids version-specific branches unless an unavoidable platform difference is proven. A non-blocking PHP nightly job detects future parser, runtime, and deprecation problems. Nightly success is informational until the relevant PHP release and iTop combination are officially supported.

Validation covers:

- PHP syntax for every extension PHP file;
- XML parsing for manifests and Query Phrasebook data;
- synchronized version identifiers;
- module registration with minimal iTop API test doubles;
- installer method loading and same-version no-op behavior;
- presence and shape of all three Query Phrasebook records.

Containerized runs are attempted locally for representative legacy and current PHP versions, including PHP 8.2 and 8.4. Hosted CI is the authoritative complete matrix when local Docker access is unavailable. Full production compatibility is claimed only for tested iTop/PHP intersections; installed iTop smoke tests are recorded separately when environments are available.

## Testing

### Automated extension tests

- Run blocking jobs on PHP 7.0 through 7.4 and PHP 8.0 through 8.4.
- Enforce PHP 7.0.8 as the minimum supported patch level.
- Run PHP nightly as a non-blocking early-warning job.
- Fail if any code file exceeds 200 lines.
- Fail on syntax, XML, version, installer, or Query Phrasebook contract errors.

### Automated Power Query contract tests

- Use sanitized CSV fixtures for English, German, Dutch, and French accounts.
- Confirm all fixtures resolve to the identical canonical table schemas and representative values.
- Cover empty result sets, translated enum values, optional first-team URL, missing fields, invalid-query HTML, and login HTML.
- Confirm no credential values appear in source or fixtures.

### Artifact verification

- Compile the source-controlled project to `.pbit` with a pinned supported toolchain.
- Re-extract the artifact and compare its M expressions and model schema with source.
- Open and refresh against a reachable test iTop instance when one is available.
- Record any unperformed live verification explicitly in the release notes.

## Compatibility and Migration

Existing iTop Query Phrasebook records and field lists remain valid. Operators replace the old template with 1.1.0 and re-enter connection parameters. Existing report consumers do not need an English iTop account after migration.

The original 1.0.x template remains available as a release artifact for rollback. No existing generated assets are deleted.

## Release

After both pull requests are independently reviewed, green, and merged at their verified heads:

1. Confirm extension and template versions are both 1.1.0.
2. Confirm README instructions match the released artifacts.
3. Create GitHub releases from the exact merge commits.
4. Attach the verified extension package and `.pbit` template.
5. Document the broad PHP matrix, PHP nightly result, locale fixture results, supported iTop/PHP intersections, and the live-refresh verification boundary.

## Acceptance Criteria

- The same template source produces the same canonical schema from English, German, Dutch, and French fixtures.
- No Power Query transformation depends on translated iTop field labels or enum captions.
- Other LTR locales use the same locale-neutral contract without additional mappings.
- Existing report model names and functionality remain unchanged.
- Authentication and schema errors are actionable and do not expose credentials.
- PHP 7.0 through 8.4 extension validation passes with deprecations treated as failures.
- PHP nightly runs as a visible non-blocking compatibility signal.
- Documentation distinguishes extension-code compatibility from supported iTop/PHP runtime combinations.
- Extension and template release metadata are synchronized at 1.1.0.
- All code files remain at or below 200 lines.
- Pull requests are issue-linked, assigned to `dutch2005`, labeled, milestone-grouped, and independently reviewed.
