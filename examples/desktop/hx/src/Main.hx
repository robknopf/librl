package;

import RL;
import haxe.Timer;

class Main {
	static var startTime:Float;
	static var totalTime:Float;

	static var komika:RLHandle;
	static var komikaSize = 24;

	static var komikaSmall:RLHandle;
	static var komikaSmallSize = 16;

	public static function update():Bool {
		RL.update();
		RL.beginDrawing();
		RL.clearBackground(RL.RAYWHITE);
		// trace('Main.update()');
		RL.drawTextEx(komika, "Hello World!", 10, 10, komikaSize, 1, RL.BLUE);
		var dim = RL.measureTextEx(komika, "Hello World!", komikaSize, 0);
		// trace('measureText: (${dim.x}, ${dim.y})');

		RL.drawFPSEx(komikaSmall, 10, 10, komikaSmallSize, RL.GRAY);
		RL.endDrawing();

		RL.drawText("Seconds: " + totalTime, 10, 30, 0, 0);

		return true;
	}

	public static function main() {
		trace('Main.main()');
		Main.startTime = Timer.stamp();
		totalTime = 0;
		// var rl = new RL();
		RL.init();
		RL.initWindow(800, 600, "Hello, World!");
		RL.setTargetFPS(60);

		komika = RL.createFont("https://localhost:4444/fonts/Komika/KOMIKAH_.ttf", komikaSize);
		komikaSmall = RL.createFont("https://localhost:4444/fonts/Komika/KOMIKAH_.ttf", komikaSmallSize);

		var updateTimer = new Timer(Std.int(1000.0 / 60));
		updateTimer.run = () -> {
			if (totalTime < 5) {
				totalTime = Timer.stamp() - Main.startTime;
				Main.update();
			} else {
				updateTimer.stop();
				RL.deinit();
				RL.closeWindow();
			}
		};
	}
}
