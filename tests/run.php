<?php

error_reporting(E_ALL);
ini_set('display_errors', '1');

require_once __DIR__.'/TestHarness.php';
require_once __DIR__.'/ItopStubs.php';
require_once __DIR__.'/ExtensionContractTest.php';

$harness = new TestHarness();
registerExtensionContractTests($harness, dirname(__DIR__));
exit($harness->finish());
