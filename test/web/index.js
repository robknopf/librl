import { rl } from "/out/librl.js";

(async function () {
  try {
    await rl.init({ idealWidth: 1024, idealHeight: 1280 });
    rl.initWindow(800, 600, "Hello, World! (Web)");
    rl.setTargetFPS(60);

    const fontSize = 24;
    const smallFontSize = 16;
    const modelPath = "models/gumshoe/gumshoe.glb";
    const spritePath = "sprites/logo/wg-logo-bw-alpha.png";
    const greyAlphaColor = rl.createColor(0, 0, 0, 128);
    const komika = await rl.createFont("fonts/Komika/KOMIKAH_.ttf", fontSize);
    const komikaSmall = await rl.createFont("fonts/Komika/KOMIKAH_.ttf", smallFontSize);

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

    rl.enableLighting();
    rl.setLightDirection(-0.6, -1.0, -0.5);
    rl.setLightAmbient(0.25);

    let countdownTimer = 5.0;
    let totalTime = 0.0;
    let lastTime = rl.getTime();
    let animationFrameId = 0;
    let cleanedUp = false;
    const cleanup = () => {
      if (cleanedUp) return;
      cleanedUp = true;
      if (animationFrameId) {
        window.cancelAnimationFrame(animationFrameId);
      }
      rl.disableLighting();
      rl.destroyModel(gumshoe);
      rl.destroySprite3D(sprite);
      rl.destroyFont(komika);
      rl.destroyFont(komikaSmall);
      rl.destroyColor(greyAlphaColor);
      rl.deinit();
      rl.closeWindow();
    };

    window.addEventListener("beforeunload", cleanup);

    const mainLoop = () => {
      const currentTime = rl.getTime();
      const deltaTime = currentTime - lastTime;
      lastTime = currentTime;
      totalTime += deltaTime;
      countdownTimer -= deltaTime;
      if (countdownTimer <= 0) {
        cleanup();
        return;
      }

      rl.update();
      const message = "Hello World!";
      const mouse = rl.getMouseState();
      rl.beginDrawing();
      rl.clearBackground(rl.RAYWHITE);
      rl.beginMode3D();
      rl.modelAnimate(gumshoe, deltaTime);
      rl.drawModel(gumshoe, 0.0, 0.0, 0.0, 1.0, rl.RAYWHITE);

      rl.drawSprite3D(sprite, 0, 0, 0, 1, rl.RAYWHITE)
      rl.endMode3D();

      const w = rl.getScreenWidth();
      const h = rl.getScreenHeight();
      const textSize = rl.measureTextEx(komika, message, fontSize, 0);
      rl.drawTextEx(komika, message, (w - textSize.x) / 2, (h - textSize.y) / 2, fontSize, 1, rl.BLUE);
      rl.drawTextEx(komikaSmall, `Remaining: ${countdownTimer.toFixed(2)}`, 10, 36, smallFontSize, 1, rl.BLACK);
      rl.drawTextEx(komikaSmall, `Elapsed: ${totalTime.toFixed(2)}`, 10, 56, smallFontSize, 1, rl.BLACK);
      rl.drawTextEx(komikaSmall, `Mouse: (${mouse.x.toFixed(0)}, ${mouse.y.toFixed(0)})`, 10, 76, smallFontSize, 1, rl.BLACK);

      rl.drawFPSEx(komikaSmall, 10, 10, smallFontSize, greyAlphaColor);
      rl.endDrawing();
      animationFrameId = window.requestAnimationFrame(mainLoop);
    };
    mainLoop();
  } catch (e) {
    console.error(e);
  }
})();
