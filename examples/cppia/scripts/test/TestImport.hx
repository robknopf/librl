package scripts.test;

import rl.helpers.Log;

// test file to see if our cppia file can import packages

var toplevelVar: Float = 123.456; // test to see if this shows up in the debugger Globals panel


@:keep
class TestImport {
	public static var logsLeft: Int = 10; // this should be initialized every reload
	public static function test() {
		if (logsLeft >= 0) {
			Log.info('TestImport: testing2 $logsLeft left');
			logsLeft--;
		}
	}
}	