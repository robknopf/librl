package tests.bindings.haxe;

import utest.Runner;
import utest.ui.Report;
import tests.bindings.haxe.BuildLibrl; // triggers buildXml for librl link

class Main {
  static function main() {
    var runner = new Runner();
    runner.addCase(new TestRL());
    Report.create(runner);
    runner.run();
  }
}
