import { rl } from "../../bindings/js/rl.js";

(async function () {
  try {
    const assetHost = new URL(".", window.location.href).href.replace(/\/$/, "");
    const bootRc = await rl.boot({
      idealWidth: 1024,
      idealHeight: 1280,
    });
    if (bootRc !== 0) {
      throw new Error(`rl.boot failed: ${bootRc}`);
    }
    const initRc = await rl.init({
      windowWidth: 800,
      windowHeight: 600,
      windowTitle: "Hello, World! (Web)",
      windowFlags: rl.FLAG_MSAA_4X_HINT,
      assetHost: assetHost,
    });
    if (initRc !== 0) {
      throw new Error(`rl.init failed: ${initRc}`);
    }
    rl.setTargetFPS(60);

    const fontSize = 24;
    const smallFontSize = 16;
    const modelPath = "assets/models/gumshoe/gumshoe.glb";
    const spritePath = "assets/sprites/logo/wg-logo-bw-alpha.png";
    const fontPath = "assets/fonts/Komika/KOMIKAH_.ttf";
    const bgmPath = "assets/music/ethernight_club.mp3";
    const greyAlphaColor = rl.createColor(0, 0, 0, 128);
    let komika = 0;
    let komikaSmall = 0;
    let bgm = 0;
    let gumshoe = 0;
    let sprite = 0;
    const camera = rl.createCamera3d(
      12.0, 12.0, 12.0,
      0.0, 1.0, 0.0,
      0.0, 1.0, 0.0,
      45.0, rl.CAMERA_PERSPECTIVE
    );

    rl.setActiveCamera3d(camera);

    rl.enableLighting();
    rl.setLightDirection(-0.6, -1.0, -0.5);
    rl.setLightAmbient(0.25);

    // using a task group to load assets asynchronously
    /*
    let loadingGroup = rl.createTaskGroup(
      () => {
        loadingGroup = null;
      },
      (group, loadedCtx) => {
        console.error(`asset import failed: ${group.failedPaths().join(", ")}`);
        loadingGroup = null;
        cleanup();
      },
      {}
    );
    loadingGroup.addImportTask(modelPath, (path) => {
      gumshoe = rl.createModel(path);
      rl.modelSetAnimation(gumshoe, 1);
      rl.modelSetAnimationSpeed(gumshoe, 1.0);
      rl.modelSetAnimationLoop(gumshoe, true);
    });
    loadingGroup.addImportTask(spritePath, (path) => {
      sprite = rl.createSprite3d(path);
    });
    loadingGroup.addImportTask(fontPath, (path) => {
      komika = rl.createFont(path, fontSize);
      komikaSmall = rl.createFont(path, smallFontSize);
    });
    loadingGroup.addImportTask(bgmPath, (path) => {
      bgm = rl.createMusic(path);
      rl.setMusicLoop(bgm, true);
      rl.playMusic(bgm);
    });
    */

    // helper to import assets tasks
    const importAssetTask = (path, onSuccess, onError) => {
      const task = rl.fileioEnsureAsync(path, null);
      if (task !== 0) {
        rl.fileioAddTask(task, onSuccess, onError);
      } else {
        onError?.call(null, `invalid task: ${path}`);
      }
    };

    importAssetTask(modelPath, (path) => {
      gumshoe = rl.createModel(path);
      rl.modelSetAnimation(gumshoe, 1);
      rl.modelSetAnimationSpeed(gumshoe, 1.0);
      rl.modelSetAnimationLoop(gumshoe, true);
    }, (path, error) => {
      console.error(`asset import failed: ${path}: ${error}`);
    });
    importAssetTask(spritePath, (path) => {
      sprite = rl.createSprite3d(path);
    }, (path, error) => {
      console.error(`asset import failed: ${path}: ${error}`);
    });
    importAssetTask(fontPath, (path) => {
      komika = rl.createFont(path, fontSize);
      komikaSmall = rl.createFont(path, smallFontSize);
    }, (path, error) => {
      console.error(`asset import failed: ${path}: ${error}`);
    });
    importAssetTask(bgmPath, (path) => {
      bgm = rl.createMusic(path);
      rl.setMusicLoop(bgm, true);
      rl.playMusic(bgm);
    }, (path, error) => {
      console.error(`asset import failed: ${path}: ${error}`);
    });

    let countdownTimer = 10.0;
    let totalTime = 0.0;
    let lastTime = rl.getTime();
    let animationFrameId = 0;

    let shutdownFn = async () => {
      if (animationFrameId) {
        window.cancelAnimationFrame(animationFrameId);
        animationFrameId = 0;
      }
      //rl.disableLighting();
      // Resources are automatically destroyed with rl.deinit()
      //  rl.destroyModel(gumshoe);
      //  rl.destroySprite3d(sprite);
      //  rl.destroyFont(komika);
      //    rl.destroyFont(komikaSmall);
      //  rl.destroyColor(greyAlphaColor);
      //  rl.destroyMusic(bgm);
      if (shutdownFn) {
        await rl.deinit();
        shutdownFn = null;
      }
    };

    window.addEventListener("beforeunload", shutdownFn);

    const mainLoop = () => {
      const currentTime = rl.getTime();
      const deltaTime = currentTime - lastTime;
      lastTime = currentTime;
      totalTime += deltaTime;
      countdownTimer -= deltaTime;
      if (countdownTimer <= 0) {
        shutdownFn?.call().then(() => {
          animationFrameId = 0;
        });
        return;
      }

      rl.tick();
      // tell RL to write the current state to the scratch area
      rl.refreshScratch();

      rl.updateAllMusic();
      const message = "Hello World!";
      const mouse = rl.getMouseState();
      rl.beginDrawing();
      rl.clearBackground(rl.COLOR_RAYWHITE);
      rl.beginMode3d();
     // if (loadingGroup && loadingGroup.process() > 0) {
     //   rl.endMode3d();
     //   rl.endDrawing();
     //   animationFrameId = window.requestAnimationFrame(mainLoop);
     //   return;
     // }
      if (gumshoe) {
        rl.modelAnimate(gumshoe, deltaTime);
        rl.drawModel(gumshoe, rl.COLOR_WHITE);
      }
      if (sprite) {
        rl.drawSprite3d(sprite, rl.COLOR_WHITE);
      }
      rl.endMode3d();

      const w = rl.getScreenWidth();
      const h = rl.getScreenHeight();
      if (komika) {
        const textSize = rl.measureTextEx(komika, message, fontSize, 0);
        rl.drawTextEx(komika, message, (w - textSize.x) / 2, (h - textSize.y) / 2, fontSize, 1, rl.COLOR_BLUE);
      }
      if (komikaSmall) {
        rl.drawTextEx(komikaSmall, `Remaining: ${countdownTimer.toFixed(2)}`, 10, 36, smallFontSize, 1, rl.COLOR_BLACK);
        rl.drawTextEx(komikaSmall, `Elapsed: ${totalTime.toFixed(2)}`, 10, 56, smallFontSize, 1, rl.COLOR_BLACK);
        rl.drawTextEx(komikaSmall, `Mouse: (${mouse.x.toFixed(0)}, ${mouse.y.toFixed(0)})`, 10, 76, smallFontSize, 1, rl.COLOR_BLACK);
        rl.drawFPSEx(komikaSmall, 10, 10, smallFontSize, rl.COLOR_BLUE);
      }
      rl.endDrawing();
      animationFrameId = window.requestAnimationFrame(mainLoop);
    };
    mainLoop();
  } catch (e) {
    console.error(e);
  }
})();
