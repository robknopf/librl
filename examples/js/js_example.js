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
      windowTitle: "Hello, World! (Web)",
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
    const fontPath = "assets/fonts/Komika/KOMIKAH_.ttf";
    const bgmPath = "assets/music/ethernight_club.mp3";
    const greyAlphaColor = rl.color.create(0, 0, 0, 128);
    let komika = 0;
    let komikaSmall = 0;
    let labelText2d = 0;
    let bgm = 0;
    let gumshoe = 0;
    let sprite = 0;
    const camera = rl.camera3d.create(
      12.0, 12.0, 12.0,
      0.0, 1.0, 0.0,
      0.0, 1.0, 0.0,
      45.0, rl.CAMERA_PERSPECTIVE
    );

    rl.camera3d.setActive(camera);

    rl.render.enableLighting();
    rl.render.setLightDirection(-0.6, -1.0, -0.5);
    rl.render.setLightAmbient(0.25);

    labelText2d = rl.text2d.create(rl.font.getDefault(), fontSize);
    rl.text2d.setContent(labelText2d, "rl_text2d: retained label");
    rl.text2d.setPosition(labelText2d, 10, 136);
    rl.text2d.setColor(labelText2d, rl.COLOR_GREEN);

    const importAssetTask = (path, onSuccess, onError) => {
      const task = rl.asset.ensureAsync(path, null);
      if (task !== 0) {
        rl.asset.addTask(task, onSuccess, onError);
      } else {
        onError?.call(null, `invalid task: ${path}`);
      }
    };

    importAssetTask(modelPath, (path) => {
      gumshoe = rl.model.createFromFile(path);
      rl.model.setAnimation(gumshoe, 1);
      rl.model.setAnimationSpeed(gumshoe, 1.0);
      rl.model.setAnimationLoop(gumshoe, true);
    }, (path, error) => {
      console.error(`asset import failed: ${path}: ${error}`);
    });
    importAssetTask(spritePath, (path) => {
      sprite = rl.sprite3d.createFromFile(path);
    }, (path, error) => {
      console.error(`asset import failed: ${path}: ${error}`);
    });
    importAssetTask(fontPath, (path) => {
      komika = rl.font.create(path, fontSize);
      komikaSmall = rl.font.create(path, smallFontSize);
      if (labelText2d) rl.text2d.setFont(labelText2d, komika);
    }, (path, error) => {
      console.error(`asset import failed: ${path}: ${error}`);
    });
    importAssetTask(bgmPath, (path) => {
      bgm = rl.music.create(path);
      rl.music.setLoop(bgm, true);
      rl.music.play(bgm);
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
      rl.refreshScratch();

      rl.music.updateAll();
      const message = "Hello World!";
      const mouse = rl.input.getMouseState();
      rl.render.begin();
      rl.render.clearBackground(rl.COLOR_RAYWHITE);
      rl.render.beginMode3D();
      if (gumshoe) {
        rl.model.animate(gumshoe, deltaTime);
        rl.model.draw(gumshoe, rl.COLOR_WHITE);
      }
      if (sprite) {
        rl.sprite3d.draw(sprite, rl.COLOR_WHITE);
      }
      rl.render.endMode3D();

      const w = rl.helpers.getScreenWidth();
      const h = rl.helpers.getScreenHeight();
      if (komika) {
        const textSize = rl.text.measureEx(komika, message, fontSize, 0);
        rl.text.drawEx(komika, message, (w - textSize.x) / 2, (h - textSize.y) / 2, fontSize, 1, rl.COLOR_BLUE);
      }
      if (komikaSmall) {
        rl.text.drawEx(komikaSmall, `Remaining: ${countdownTimer.toFixed(2)}`, 10, 36, smallFontSize, 1, rl.COLOR_BLACK);
        rl.text.drawEx(komikaSmall, `Elapsed: ${totalTime.toFixed(2)}`, 10, 56, smallFontSize, 1, rl.COLOR_BLACK);
        rl.text.drawEx(komikaSmall, `Mouse: (${mouse.x.toFixed(0)}, ${mouse.y.toFixed(0)})`, 10, 76, smallFontSize, 1, rl.COLOR_BLACK);
        rl.text.drawFpsEx(komikaSmall, 10, 10, smallFontSize, rl.COLOR_BLUE);
      }
      if (labelText2d) {
        rl.text2d.draw(labelText2d);
      }
      rl.render.end();
      animationFrameId = window.requestAnimationFrame(mainLoop);
    };
    mainLoop();
  } catch (e) {
    console.error(e);
  }
})();
