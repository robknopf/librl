import { rl } from "/lib/librl.js";

(async function () {
  try {
    await rl.init({ idealWidth: 1024, idealHeight: 1280 });
    rl.initWindow(800, 600, "Pick Example (Web)", rl.FLAG_MSAA_4X_HINT);
    rl.setTargetFPS(60);

    const fontSize = 24;
    const smallFontSize = 16;
    const modelPath = "assets/models/gumshoe/gumshoe.glb";
    const spritePath = "assets/sprites/logo/wg-logo-bw-alpha.png";
    const spritePos = { x: 5.0, y: 0.0, z: 0.0 };
    const spriteSize = 1.0;

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
    rl.resetPickStats();

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
        const modelPick = rl.pickModel(camera, gumshoe, mouse.x, mouse.y, 0, 0, 0, 1);
        const spritePick = rl.pickSprite3D(
          camera,
          sprite,
          mouse.x,
          mouse.y,
          spritePos.x,
          spritePos.y,
          spritePos.z,
          spriteSize
        );
        if (modelPick.hit && spritePick.hit) {
          lastPick = modelPick.distance <= spritePick.distance
            ? { ...modelPick, target: "model" }
            : { ...spritePick, target: "sprite3d" };
        } else if (modelPick.hit) {
          lastPick = { ...modelPick, target: "model" };
        } else if (spritePick.hit) {
          lastPick = { ...spritePick, target: "sprite3d" };
        } else {
          lastPick = { hit: false, target: "none" };
        }
      }

      rl.beginDrawing();
      rl.clearBackground(rl.RAYWHITE);

      rl.beginMode3D();
      rl.modelAnimate(gumshoe, dt);
      rl.drawModel(gumshoe, 0.0, 0.0, 0.0, 1.0, rl.RAYWHITE);
      rl.drawSprite3D(sprite, spritePos.x, spritePos.y, spritePos.z, spriteSize, rl.RAYWHITE);
      rl.endMode3D();

      const title = "Click model to test pick";
      const size = rl.measureTextEx(komika, title, fontSize, 1);
      rl.drawTextEx(komika, title, (rl.getScreenWidth() - size.x) * 0.5, 14, fontSize, 1, rl.BLUE);

      rl.drawTextEx(
        komikaSmall,
        `Mouse: (${mouse.x}, ${mouse.y})`,
        10, 46, smallFontSize, 1, rl.BLACK
      );
      const pickStats = rl.getPickStats();
      const skippedNarrowphase = pickStats.broadphaseRejects;
      rl.drawTextEx(
        komikaSmall,
        `Pick broad: ${pickStats.broadphaseTests} tests, ${pickStats.broadphaseRejects} rejects`,
        10, 86, smallFontSize, 1, rl.DARKGRAY
      );
      rl.drawTextEx(
        komikaSmall,
        `Pick narrow: ${pickStats.narrowphaseTests} tests, ${pickStats.narrowphaseHits} hits`,
        10, 106, smallFontSize, 1, rl.DARKGRAY
      );
      rl.drawTextEx(
        komikaSmall,
        `Narrow-phase skipped: ${skippedNarrowphase}`,
        10, 126, smallFontSize, 1, rl.DARKGREEN
      );

      if (lastPick) {
        if (lastPick.hit) {
          rl.drawTextEx(
            komikaSmall,
            `Pick ${lastPick.target} hit d=${lastPick.distance.toFixed(2)} @ (${lastPick.point.x.toFixed(2)}, ${lastPick.point.y.toFixed(2)}, ${lastPick.point.z.toFixed(2)})`,
            10, 66, smallFontSize, 1, rl.DARKGREEN
          );
        } else {
          rl.drawTextEx(komikaSmall, "Pick miss", 10, 66, smallFontSize, 1, rl.MAROON);
        }
      } else {
        rl.drawTextEx(komikaSmall, "No pick yet", 10, 66, smallFontSize, 1, rl.GRAY);
      }

      rl.drawFPSEx(komikaSmall, 10, 148, smallFontSize, rl.BLACK);
      rl.endDrawing();
      animationFrameId = window.requestAnimationFrame(mainLoop);
    };

    mainLoop();
  } catch (e) {
    console.error(e);
  }
})();
