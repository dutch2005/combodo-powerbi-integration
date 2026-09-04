# Reporting for Power BI - Helpdesk view

This iTop extension installs three Query Phrasebook entries used by the matching Power BI helpdesk template:

1. User requests updated during the last 12 months.
2. The list of teams.
3. The first team assigned to each included request.

The extension does not add a public webservice or store Power BI credentials. Power BI reads the standard iTop Query Phrasebook export URLs using the account supplied in the template parameters.

## Version compatibility

Version 1.1.0 keeps production code compatible with PHP 7.0 syntax and validates the extension in blocking CI jobs on PHP 7.0.8, 7.1, 7.2, 7.3, 7.4, 8.0, 8.1, 8.2, 8.3, and 8.4. A separate non-blocking PHP 8.6 nightly job is an early warning for future changes.

This is an **extension-code** compatibility range. Your installed iTop version still determines which PHP versions are safe to run. For example:

- iTop 3.2.2 supports PHP 8.1 through 8.3, so do not move that installation to PHP 8.4 merely because this extension passes PHP 8.4 tests.
- iTop 3.2.3-1 adds PHP 8.4 support.
- iTop 3.3 supports PHP 8.2 through 8.4.

Always check the current [official iTop requirements](https://www.itophub.io/wiki/page?id=latest%3Ainstall%3Arequirements) before changing the server runtime.

The automated harness validates extension loading with minimal iTop API test doubles. It does not replace an installation test against the exact iTop, PHP, database, and extension set used in production.

## Locale-neutral Power BI template

Use extension 1.1.0 with Power BI template 1.1.0. That template requests CSV exports with `no_localize=1` and addresses stable internal field codes such as `ref`, `id`, `newvalue`, and `objkey`.

The data refresh therefore works independently of the iTop account's display language for supported left-to-right languages. English, German, Dutch, and French are explicit fixtures. Report page captions remain English, and right-to-left presentation is not certified.

The locale-neutral template fixes refresh failures such as:

- `The column 'Ref' of the table wasn't found.`
- `The column 'id (Primary Key)' of the table wasn't found.`
- `The column 'New value' of the table wasn't found.`
- `The column 'object id' of the table wasn't found.`

Those messages refer to translated column headings, not empty record values.

## Installation and upgrade

1. Back up iTop and test the upgrade on a copy of the production environment.
2. Place the `combodo-powerbi-integration` directory in iTop's `extensions` directory.
3. Run iTop setup and keep **Reporting for PowerBI - Helpdesk view** selected.
4. Open **Query Phrasebook** and verify all three Power BI queries are present.
5. Open Power BI template 1.1.0 and enter the current three Query Phrasebook URLs plus the dedicated iTop account credentials.
6. Keep Power BI's data-source credential mode set to Anonymous because the M queries supply the Basic Authorization header themselves.
7. Refresh all tables before publishing the report.

When upgrading from 1.0.x, the installer reloads its Query Phrasebook data once because the module version changed. Existing query behavior and field lists are preserved.

If a refresh reports login HTML, an invalid query id, or missing internal fields, verify the account credentials and copy fresh Query Phrasebook URLs from the upgraded iTop instance.

## Rollback

Keep the prior extension directory and Power BI 1.0.x template artifact in your normal backup location. To roll back, restore both matching 1.0.x components and rerun iTop setup. Do not mix the locale-neutral 1.1.0 template with modified or missing Query Phrasebook definitions.

## Development

Run the contract suite in Docker so the host does not need PHP:

```powershell
docker run --rm -v "${PWD}:/app:ro" -w /app php:8.4-cli php -d error_reporting=-1 -d display_errors=1 tests/run.php
```

Build and verify the deterministic release archive:

```powershell
pwsh -NoProfile -File tests/BuildReleaseTest.ps1
```

The resulting archive is `dist/combodo-powerbi-integration-1.1.0.zip`. The build prints its SHA-256 hash.

## More information

- [iTop extension documentation](https://www.itophub.io/wiki/page?id=extensions%3Acombodo-powerbi-integration)
- [Official Power BI template repository](https://github.com/Combodo/combodo-powerbi-template)
- [iTop Hub Store](https://store.itophub.io/en_US/taxons/all-extensions)

This module is sponsored, led, and supported by [Combodo](https://www.combodo.com).
