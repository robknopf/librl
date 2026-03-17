import { rl } from "../../lib/librl.js";

(async function () {
  try {
    await rl.init({ idealWidth: 1024, idealHeight: 1280 });
    rl.openWindow(800, 600, "Hello, World! (Web)", rl.FLAG_MSAA_4X_HINT);
    rl.setTargetFPS(60);

    const fontSize = 24;
    const smallFontSize = 16;
    const modelPath = "assets/models/gumshoe/gumshoe.glb";
    const spritePath = "assets/sprites/logo/wg-logo-bw-alpha.png";
    const greyAlphaColor = rl.createColor(0, 0, 0, 128);
    const komika = await rl.createFont("assets/fonts/Komika/KOMIKAH_.ttf", fontSize);
    const komikaSmall = await rl.createFont("assets/fonts/Komika/KOMIKAH_.ttf", smallFontSize);
    const bgm = await rl.createMusic("assets/music/ethernight_club.mp3");

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

    rl.playMusic(bgm);

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
      // Resources are automatically destroyed with rl.deinit()
      //  rl.destroyModel(gumshoe);
      //  rl.destroySprite3D(sprite);
      //  rl.destroyFont(komika);
      //    rl.destroyFont(komikaSmall);
      //  rl.destroyColor(greyAlphaColor);
      //  rl.destroyMusic(bgm);
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
      rl.updateAllMusic();
      const message = "Hello World!";
      const mouse = rl.getMouseState();
      rl.beginDrawing();
      rl.clearBackground(rl.COLOR_RAYWHITE);
      rl.beginMode3D();
      rl.modelAnimate(gumshoe, deltaTime);
      //rl.modelSetTransform(gumshoe, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0);
      rl.drawModel(gumshoe, rl.COLOR_WHITE);

      //rl.sprite3DSetTransform(sprite, 0, 0, 0, 1);
      rl.drawSprite3D(sprite, rl.COLOR_WHITE)
      rl.endMode3D();

      const w = rl.getScreenWidth();
      const h = rl.getScreenHeight();
      const textSize = rl.measureTextEx(komika, message, fontSize, 0);
      rl.drawTextEx(komika, message, (w - textSize.x) / 2, (h - textSize.y) / 2, fontSize, 1, rl.COLOR_BLUE);
      rl.drawTextEx(komikaSmall, `Remaining: ${countdownTimer.toFixed(2)}`, 10, 36, smallFontSize, 1, rl.COLOR_BLACK);
      rl.drawTextEx(komikaSmall, `Elapsed: ${totalTime.toFixed(2)}`, 10, 56, smallFontSize, 1, rl.COLOR_BLACK);
      rl.drawTextEx(komikaSmall, `Mouse: (${mouse.x.toFixed(0)}, ${mouse.y.toFixed(0)})`, 10, 76, smallFontSize, 1, rl.COLOR_BLACK);

      rl.drawFPSEx(komikaSmall, 10, 10, smallFontSize, rl.COLOR_BLUE);
      rl.endDrawing();
      animationFrameId = window.requestAnimationFrame(mainLoop);
    };
    mainLoop();
  } catch (e) {
    console.error(e);
  }
})();
