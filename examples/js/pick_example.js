import { rl } from "/lib/librl.js";

(async function () {
  try {
    await rl.init({ idealWidth: 1024, idealHeight: 1280 });
    rl.initWindow(800, 600, "Pick Example (Web)");
    rl.setTargetFPS(60);

    const fontSize = 24;
    const smallFontSize = 16;
    const modelPath = "assets/models/gumshoe/gumshoe.glb";
    const spritePath = "assets/sprites/logo/wg-logo-bw-alpha.png";

    const komika = await rl.createFont("assets/fonts/Komika/KOMIKAH_.ttf", fontSize);
    const komikaSmall = await rl.createFont("assets/fonts/Komika/KOMIKAH_.ttf", smallFontSize);
    const gumshoe = await rl.createModel(modelPath);
    const sprite = await rl.createSprite3D(spritePath);
    const camera = rl.createCamera3D(
      12.0, 12.0, 12.0,
      0.0, 1.0, 0.0,
      0.0, 1.0, 0.0,
      45.0, rl.CAMERA_PERSPECTIVE
    );

    rl.setActiveCamera3D(camera);
    rl.modelSetAnimation(gumshoe, 1);
    rl.modelSetAnimationSpeed(gumshoe, 1.0);
    rl.modelSetAnimationLoop(gumshoe, true);

    let lastTime = rl.getTime();
    let lastPick = null;
    let animationFrameId = 0;
    let cleanedUp = false;

    const cleanup = () => {
      if (cleanedUp) return;
      cleanedUp = true;
      if (animationFrameId) window.cancelAnimationFrame(animationFrameId);
      rl.destroyModel(gumshoe);
      rl.destroySprite3D(sprite);
      rl.destroyFont(komika);
      rl.destroyFont(komikaSmall);
      rl.destroyCamera3D(camera);
      rl.deinit();
      rl.closeWindow();
    };

    window.addEventListener("beforeunload", cleanup);

    const mainLoop = () => {
      const now = rl.getTime();
      const dt = now - lastTime;
      lastTime = now;

      rl.update();
      const mouse = rl.getMouseState();
      if (mouse.left === rl.BUTTON_PRESSED) {
        lastPick = rl.pickModel(camera, gumshoe, mouse.x, mouse.y, 0, 0, 0, 1);
      }

      rl.beginDrawing();
      rl.clearBackground(rl.RAYWHITE);

      rl.beginMode3D();
      rl.modelAnimate(gumshoe, dt);
      rl.drawModel(gumshoe, 0.0, 0.0, 0.0, 1.0, rl.RAYWHITE);
      rl.drawSprite3D(sprite, 0.0, 0.0, 0.0, 1.0, rl.RAYWHITE);
      rl.endMode3D();

      const title = "Click model to test pick";
      const size = rl.measureTextEx(komika, title, fontSize, 1);
      rl.drawTextEx(komika, title, (rl.getScreenWidth() - size.x) * 0.5, 14, fontSize, 1, rl.BLUE);

      rl.drawTextEx(
        komikaSmall,
        `Mouse: (${mouse.x}, ${mouse.y})`,
        10, 46, smallFontSize, 1, rl.BLACK
      );

      if (lastPick) {
        if (lastPick.hit) {
          rl.drawTextEx(
            komikaSmall,
            `Pick hit d=${lastPick.distance.toFixed(2)} @ (${lastPick.point.x.toFixed(2)}, ${lastPick.point.y.toFixed(2)}, ${lastPick.point.z.toFixed(2)})`,
            10, 66, smallFontSize, 1, rl.DARKGREEN
          );
        } else {
          rl.drawTextEx(komikaSmall, "Pick miss", 10, 66, smallFontSize, 1, rl.MAROON);
        }
      } else {
        rl.drawTextEx(komikaSmall, "No pick yet", 10, 66, smallFontSize, 1, rl.GRAY);
      }

      rl.drawFPSEx(komikaSmall, 10, 88, smallFontSize, rl.BLACK);
      rl.endDrawing();
      animationFrameId = window.requestAnimationFrame(mainLoop);
    };

    mainLoop();
  } catch (e) {
    console.error(e);
  }
})();
