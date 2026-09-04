<?php

class SetupWebPage
{
	public static $modules = array();

	public static function AddModule($file, $version, $definition)
	{
		self::$modules[] = array($file, $version, $definition);
	}
}

class ModuleInstallerAPI
{
}

class Config
{
	private $language;

	public function __construct($language)
	{
		$this->language = $language;
	}

	public function GetDefaultLanguage()
	{
		return $this->language;
	}
}

class XMLDataLoader
{
	public static $sessions = array();
	public static $loads = array();

	public static function reset()
	{
		self::$sessions = array();
		self::$loads = array();
	}

	public function StartSession($change)
	{
		self::$sessions[] = array('start', $change);
	}

	public function LoadFile($file, $reconcile, $validate)
	{
		self::$loads[] = array($file, $reconcile, $validate);
	}

	public function EndSession()
	{
		self::$sessions[] = array('end');
	}
}

class CMDBObject
{
	public static $trackInfo;

	public static function SetTrackInfo($trackInfo)
	{
		self::$trackInfo = $trackInfo;
	}

	public static function GetCurrentChange()
	{
		return 'test-change';
	}
}

class SetupLog
{
	public static $messages = array();

	public static function Info($message)
	{
		self::$messages[] = $message;
	}
}

class Dict
{
	public static $entries = array();

	public static function Add($locale, $language, $description, $entries)
	{
		self::$entries[] = array($locale, $language, $description, $entries);
	}
}

if (!defined('APPCONF')) {
	define('APPCONF', sys_get_temp_dir().DIRECTORY_SEPARATOR.'combodo-powerbi-tests'.DIRECTORY_SEPARATOR);
}
if (!defined('ITOP_CONFIG_FILE')) {
	define('ITOP_CONFIG_FILE', 'config-itop.php');
}
