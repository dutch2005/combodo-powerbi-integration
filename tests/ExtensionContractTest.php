<?php

function registerExtensionContractTests(TestHarness $harness, $root)
{
	require_once $root.'/module.combodo-powerbi-integration.php';
	require_once $root.'/model.combodo-powerbi-integration.php';
	require_once $root.'/en.dict.combodo-powerbi-integration.php';

	$harness->run('module registers the 1.1.2 identity', function () use ($harness) {
		$harness->assertSame(1, count(SetupWebPage::$modules), 'Exactly one module must be registered');
		$harness->assertSame('combodo-powerbi-integration/1.1.2', SetupWebPage::$modules[0][1], 'Registered version must be 1.1.2');
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
		PowerBiIntegrationInstaller::AfterDatabaseCreation(new Config('EN US'), '1.1.2', '1.1.2');
		$harness->assertSame(0, count(XMLDataLoader::$loads), 'Same-version setup must not reload QueryOQL data');
		$harness->assertSame(0, count(XMLDataLoader::$sessions), 'Same-version setup must not open a loader session');
	});

	$harness->run('upgrade loads the English fallback data once', function () use ($harness) {
		XMLDataLoader::reset();
		PowerBiIntegrationInstaller::AfterDatabaseCreation(new Config('DE DE'), '1.0.1', '1.1.2');
		$harness->assertSame(1, count(XMLDataLoader::$loads), 'Upgrade must load one data file');
		$harness->assertSame('en_us.data.combodo-powerbi-integration.xml', basename(XMLDataLoader::$loads[0][0]), 'Missing locale must use English data');
		$harness->assertSame(array(false, true), array(XMLDataLoader::$loads[0][1], XMLDataLoader::$loads[0][2]), 'Loader validation flags changed');
		$harness->assertSame(array(array('start', 'test-change'), array('end')), XMLDataLoader::$sessions, 'Loader session lifecycle changed');
	});

	$harness->run('upgrade loads an existing configured locale file', function () use ($harness) {
		XMLDataLoader::reset();
		PowerBiIntegrationInstaller::AfterDatabaseCreation(new Config('EN US'), '1.0.1', '1.1.2');
		$harness->assertSame(1, count(XMLDataLoader::$loads), 'Configured locale must load once');
		$harness->assertSame('en_us.data.combodo-powerbi-integration.xml', basename(XMLDataLoader::$loads[0][0]), 'Configured locale file was not selected');
	});

	$harness->run('extension manifest declares version 1.1.2', function () use ($harness, $root) {
		$manifest = simplexml_load_file($root.'/extension.xml');
		$harness->assertTrue(false !== $manifest, 'extension.xml is not valid XML');
		$harness->assertSame('combodo-powerbi-integration', (string) $manifest->extension_code, 'Extension code changed');
		$harness->assertSame('1.1.2', (string) $manifest->version, 'Manifest version must be 1.1.2');
	});

	$harness->run('QueryOQL data preserves all three contracts', function () use ($harness, $root) {
		$data = simplexml_load_file($root.'/data/en_us.data.combodo-powerbi-integration.xml');
		$harness->assertTrue(false !== $data, 'QueryOQL data is not valid XML');
		$queries = array();
		foreach ($data->QueryOQL as $query) {
			$id = (string) $query['id'];
			$fields = preg_split('/\s*,\s*/', trim((string) $query->fields));
			$oql = preg_replace('/\s+/', ' ', trim((string) $query->oql));
			$queries[$id] = array('fields' => $fields, 'oql' => $oql);
		}
		$harness->assertSame(array(1, 2, 3), array_keys($queries), 'Query ids changed');
		$expectedFields = array(
			1 => preg_split('/,/', 'id,operational_status,status,ref,org_id,org_name,caller_id,caller_name,team_id,team_id_friendlyname,agent_id,agent_name,impact,urgency,priority,origin,request_type,start_date,end_date,last_update,assignment_date,resolution_date,last_pending_date,sla_tto_passed,sla_ttr_passed,time_spent,resolution_code,tto_escalation_deadline,ttr_escalation_deadline,service_name'),
			2 => array('id', 'name'),
			3 => array('newvalue', 'objkey'),
		);
		$expectedOql = array(
			1 => "SELECT UserRequest WHERE last_update>= DATE_SUB(DATE_FORMAT(NOW(),'%Y-%m-01'), INTERVAL 12 MONTH) AND last_update<= DATE_FORMAT(NOW(),'%Y-%m-31')",
			2 => 'SELECT Team',
			3 => "SELECT CMDBChangeOpSetAttributeScalar AS sa JOIN UserRequest AS u ON sa.objkey=u.id JOIN CMDBChange AS c ON sa.change = c.id WHERE sa.objclass ='UserRequest' AND sa.attcode = 'team_id' AND sa.oldvalue!=sa.newvalue AND sa.oldvalue='0' AND sa.objclass='UserRequest' AND u.last_update>= DATE_SUB(DATE_FORMAT(NOW(),'%Y-%m-01'), INTERVAL 12 MONTH) AND u.last_update<= DATE_FORMAT(NOW(),'%Y-%m-31')",
		);
		foreach (array(1, 2, 3) as $id) {
			$harness->assertSame($expectedFields[$id], $queries[$id]['fields'], 'Query '.$id.' fields changed');
			$harness->assertSame($expectedOql[$id], $queries[$id]['oql'], 'Query '.$id.' OQL changed');
		}
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
