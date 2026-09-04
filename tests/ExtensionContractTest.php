<?php

function registerExtensionContractTests(TestHarness $harness, $root)
{
	require_once $root.'/module.combodo-powerbi-integration.php';

	$harness->run('module registers the 1.1.0 identity', function () use ($harness) {
		$harness->assertSame(1, count(SetupWebPage::$modules), 'Exactly one module must be registered');
		$harness->assertSame('combodo-powerbi-integration/1.1.0', SetupWebPage::$modules[0][1], 'Registered version must be 1.1.0');
	});

	$harness->run('module preserves the iTop request management dependency', function () use ($harness) {
		$definition = SetupWebPage::$modules[0][2];
		$expected = array('itop-request-mgmt-itil/2.7.0||itop-request-mgmt/2.7.0');
		$harness->assertSame($expected, $definition['dependencies'], 'Request management dependency changed');
	});

	$harness->run('installer exposes all lifecycle hooks', function () use ($harness) {
		$harness->assertTrue(class_exists('PowerBiIntegrationInstaller'), 'Installer class did not load');
		foreach (array('BeforeWritingConfig', 'BeforeDatabaseCreation', 'AfterDatabaseCreation') as $method) {
			$harness->assertTrue(method_exists('PowerBiIntegrationInstaller', $method), 'Missing installer method '.$method);
		}
	});

	$harness->run('same-version setup performs no data load', function () use ($harness) {
		XMLDataLoader::reset();
		PowerBiIntegrationInstaller::AfterDatabaseCreation(new Config('EN US'), '1.1.0', '1.1.0');
		$harness->assertSame(0, count(XMLDataLoader::$loads), 'Same-version setup must not reload QueryOQL data');
	});

	$harness->run('upgrade loads the English fallback data once', function () use ($harness) {
		XMLDataLoader::reset();
		PowerBiIntegrationInstaller::AfterDatabaseCreation(new Config('DE DE'), '1.0.1', '1.1.0');
		$harness->assertSame(1, count(XMLDataLoader::$loads), 'Upgrade must load one data file');
		$harness->assertSame('en_us.data.combodo-powerbi-integration.xml', basename(XMLDataLoader::$loads[0][0]), 'Missing locale must use English data');
		$harness->assertSame(array(array('start', 'test-change'), array('end')), XMLDataLoader::$sessions, 'Loader session lifecycle changed');
	});

	$harness->run('extension manifest declares version 1.1.0', function () use ($harness, $root) {
		$manifest = simplexml_load_file($root.'/extension.xml');
		$harness->assertTrue(false !== $manifest, 'extension.xml is not valid XML');
		$harness->assertSame('combodo-powerbi-integration', (string) $manifest->extension_code, 'Extension code changed');
		$harness->assertSame('1.1.0', (string) $manifest->version, 'Manifest version must be 1.1.0');
	});

	$harness->run('QueryOQL data preserves all three contracts', function () use ($harness, $root) {
		$data = simplexml_load_file($root.'/data/en_us.data.combodo-powerbi-integration.xml');
		$harness->assertTrue(false !== $data, 'QueryOQL data is not valid XML');
		$queries = array();
		foreach ($data->QueryOQL as $query) {
			$id = (string) $query['id'];
			$fields = preg_split('/\s*,\s*/', trim((string) $query->fields));
			$queries[$id] = $fields;
		}
		$harness->assertSame(array(1, 2, 3), array_keys($queries), 'Query ids changed');
		$harness->assertTrue(in_array('ref', $queries['1'], true), 'Query 1 must expose ref');
		$harness->assertSame(array('id', 'name'), $queries['2'], 'Query 2 fields changed');
		$harness->assertSame(array('newvalue', 'objkey'), $queries['3'], 'Query 3 fields changed');
	});

	$harness->run('all code files stay within 200 lines', function () use ($harness, $root) {
		$iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS));
		foreach ($iterator as $file) {
			if (!$file->isFile() || !in_array(strtolower($file->getExtension()), array('php', 'ps1', 'm'), true)) {
				continue;
			}
			$relative = str_replace('\\', '/', substr($file->getPathname(), strlen($root) + 1));
			if (0 === strpos($relative, 'dist/')) {
				continue;
			}
			$lines = file($file->getPathname());
			$harness->assertTrue(false !== $lines && count($lines) <= 200, $relative.' exceeds 200 lines');
		}
	});
}
