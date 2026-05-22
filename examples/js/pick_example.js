import { rl } from "../../bindings/js/dist/rl.js";

(async function () {
  try {
    const assetHost = new URL(".", window.location.href).href.replace(/\/$/, "");
    const bootRc = await rl.boot({
      idealWidth: 1024,
      idealHeight: 1280,
    });
    if (bootRc !== rl.BOOT_OK) {
      throw new Error(`rl.boot failed: ${bootRc}`);
    }
    const initRc = await rl.init({
      windowWidth: 800,
      windowHeight: 600,
      windowTitle: "Pick Example (Web)",
      windowFlags: rl.FLAG_MSAA_4X_HINT,
      assetHost: assetHost,
    });
    if (initRc !== rl.INIT_OK) {
      throw new Error(`rl.init failed: ${initRc}`);
    }
    rl.setTargetFPS(60);

    const fontSize = 24;
    const smallFontSize = 16;
    const modelPath = "assets/models/gumshoe/gumshoe.glb";
    const spritePath = "assets/sprites/logo/wg-logo-bw-alpha.png";
    const spritePos = { x: 5.0, y: 0.0, z: 0.0 };
    const spriteSize = 1.0;

    const fontPath = "assets/fonts/Komika/KOMIKAH_.ttf";
    let rc = await rl.asset.ensure(fontPath);
    if (rc !== 0) throw new Error(`Failed to import asset: ${fontPath} (rc=${rc})`);
    rc = await rl.asset.ensure(modelPath);
    if (rc !== 0) throw new Error(`Failed to import asset: ${modelPath} (rc=${rc})`);
    rc = await rl.asset.ensure(spritePath);
    if (rc !== 0) throw new Error(`Failed to import asset: ${spritePath} (rc=${rc})`);

    const komika = rl.font.create(fontPath, fontSize);
    const komikaSmall = rl.font.create(fontPath, smallFontSize);
    const gumshoe = rl.model.createFromFile(modelPath);
    const sprite = rl.sprite3d.createFromFile(spritePath);
    rl.sprite3d.setTransform(sprite, spritePos.x, spritePos.y, spritePos.z, spriteSize);
    const camera = rl.camera3d.create(
      12.0, 12.0, 12.0,
      0.0, 1.0, 0.0,
      0.0, 1.0, 0.0,
      45.0, rl.CAMERA_PERSPECTIVE
    );

    rl.camera3d.setActive(camera);
    rl.model.setAnimation(gumshoe, 1);
    rl.model.setAnimationSpeed(gumshoe, 1.0);
    rl.model.setAnimationLoop(gumshoe, true);
    rl.pick.resetStats();

    let lastTime = rl.getTime();
    let lastPick = null;
    let animationFrameId = 0;
    let cleanedUp = false;

    const cleanup = () => {
      if (cleanedUp) return;
      cleanedUp = true;
      if (animationFrameId) window.cancelAnimationFrame(animationFrameId);
      rl.model.destroy(gumshoe);
      rl.sprite3d.destroy(sprite);
      rl.font.destroy(komika);
      rl.font.destroy(komikaSmall);
      rl.camera3d.destroy(camera);
      rl.deinit();
    };

    window.addEventListener("beforeunload", cleanup);

    const mainLoop = () => {
      const now = rl.getTime();
      const dt = now - lastTime;
      lastTime = now;

      rl.refreshScratch();
      const mouse = rl.input.getMouseState();
      if (mouse.left === rl.BUTTON_PRESSED) {
        const modelPick = rl.pick.model(camera, gumshoe, mouse.x, mouse.y);
        const spritePick = rl.pick.sprite3d(camera, sprite, mouse.x, mouse.y);
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

      rl.render.begin();
      rl.render.clearBackground(rl.color.RAYWHITE);

      rl.render.beginMode3D();
      rl.model.animate(gumshoe, dt);
      rl.model.draw(gumshoe, rl.color.RAYWHITE);
      rl.sprite3d.draw(sprite, rl.color.RAYWHITE);
      rl.render.endMode3D();

      const title = "Click model to test pick";
      const size = rl.text.measureEx(komika, title, fontSize, 1);
      rl.text.drawEx(komika, title, (rl.helpers.getScreenWidth() - size.x) * 0.5, 14, fontSize, 1, rl.color.BLUE);

      rl.text.drawEx(
        komikaSmall,
        `Mouse: (${mouse.x}, ${mouse.y})`,
        10, 46, smallFontSize, 1, rl.color.BLACK
      );
      const pickStats = rl.helpers.getPickStats();
      const skippedNarrowphase = pickStats.broadphaseRejects;
      rl.text.drawEx(
        komikaSmall,
        `Pick broad: ${pickStats.broadphaseTests} tests, ${pickStats.broadphaseRejects} rejects`,
        10, 86, smallFontSize, 1, rl.color.DARKGRAY
      );
      rl.text.drawEx(
        komikaSmall,
        `Pick narrow: ${pickStats.narrowphaseTests} tests, ${pickStats.narrowphaseHits} hits`,
        10, 106, smallFontSize, 1, rl.color.DARKGRAY
      );
      rl.text.drawEx(
        komikaSmall,
        `Narrow-phase skipped: ${skippedNarrowphase}`,
        10, 126, smallFontSize, 1, rl.color.DARKGREEN
      );

      if (lastPick) {
        if (lastPick.hit) {
          rl.text.drawEx(
            komikaSmall,
            `Pick ${lastPick.target} hit d=${lastPick.distance.toFixed(2)} @ (${lastPick.point.x.toFixed(2)}, ${lastPick.point.y.toFixed(2)}, ${lastPick.point.z.toFixed(2)})`,
            10, 66, smallFontSize, 1, rl.color.DARKGREEN
          );
        } else {
          rl.text.drawEx(komikaSmall, "Pick miss", 10, 66, smallFontSize, 1, rl.color.MAROON);
        }
      } else {
        rl.text.drawEx(komikaSmall, "No pick yet", 10, 66, smallFontSize, 1, rl.color.GRAY);
      }

      rl.text.drawFpsEx(komikaSmall, 10, 148, smallFontSize, rl.color.BLACK);
      rl.render.end();
      animationFrameId = window.requestAnimationFrame(mainLoop);
    };

    mainLoop();
  } catch (e) {
    console.error(e);
  }
})();
