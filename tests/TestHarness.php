<?php

final class TestHarness
{
	private $failures = array();
	private $passes = 0;

	public function __construct()
	{
		set_error_handler(array($this, 'handleError'));
	}

	public function handleError($severity, $message, $file, $line)
	{
		if (0 === (error_reporting() & $severity)) {
			return false;
		}
		throw new ErrorException($message, 0, $severity, $file, $line);
	}

	public function assertSame($expected, $actual, $message)
	{
		if ($expected !== $actual) {
			throw new RuntimeException($message."\nExpected: ".var_export($expected, true)."\nActual: ".var_export($actual, true));
		}
	}

	public function assertTrue($condition, $message)
	{
		if (!$condition) {
			throw new RuntimeException($message);
		}
	}

	public function run($name, $callback)
	{
		try {
			call_user_func($callback);
			$this->passes++;
			echo "PASS: {$name}\n";
		} catch (Throwable $error) {
			$this->failures[] = $name.': '.$error->getMessage();
			echo "FAIL: {$name}\n";
		}
	}

	public function finish()
	{
		foreach ($this->failures as $failure) {
			fwrite(STDERR, $failure."\n");
		}
		echo sprintf("%d passed, %d failed\n", $this->passes, count($this->failures));
		return empty($this->failures) ? 0 : 1;
	}
}
