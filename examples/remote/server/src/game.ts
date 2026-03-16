import type { FrameSnapshot } from "./types";
import { CommandType } from "./types";
import {
  type rl_frame_command_buffer_t,
  rl_frame_commands_append,
  rl_frame_commands_reset,
} from "./rl/rl_frame_commands";
import {
  begin_frame_snapshot,
  end_frame_snapshot,
  rl_render_begin,
  rl_render_clear_background,
  rl_render_end,
} from "./rl/rl_render";
import {
  create_frame_command_buffer,
  destroy_frame_command_buffer,
  set_frame_command_buffer,
} from "./frame_command_buffer";
import {
  rl_loader_add_task,
  rl_loader_add_task_result_t,
  rl_loader_import_asset_async,
  rl_loader_tick,
} from "./rl/rl_loader";
import {
  rl_color_create,
  rl_color_destroy,
  set_resource_manager as set_color_resource_manager,
} from "./rl/rl_color";
import {
  rl_font_create,
  rl_font_destroy,
  set_resource_manager as set_font_resource_manager,
} from "./rl/rl_font";
import { rl_text_draw_ex } from "./rl/rl_text";
import {
  SessionResourceManager,
} from "./resource_manager";
import type { WorldResourceDefinition } from "./world_resource_manager";
import { WorldResources } from "./world_resource_manager";
import { Model } from "./model";
import { Camera3D } from "./camera3d";
import { Music } from "./music";
import { Sound } from "./sound";
import { Sprite3D } from "./sprite3d";
import { Texture } from "./texture";
import type {
  ClientInputState,
  ClientMessage,
  PickRequest,
  PickResponse,
  ServerPickRequestsMessage,
  ServerMessage,
} from "./protocol";
import { PickRequestType } from "./protocol";

const IDEAL_W = 1024;
const IDEAL_H = 1280;
const CAMERA_PERSPECTIVE = 0;
const GUMSHOE_ORBIT_RADIUS = 3.5;

export interface LayoutMetrics {
  screenW: number;
  screenH: number;
  sx: number;
  sy: number;
  su: number;
}

export interface RemotePickResult {
  hit: boolean;
  distance: number;
  point: {
    x: number;
    y: number;
    z: number;
  };
}

export interface GameClient {
  id: string;
  send: (message: ServerMessage) => void;
  disconnect: () => void;
}

export interface GameRuntime {
  init: () => void;
  destroy: () => void;
  onConnect: (client: GameClient) => Promise<void>;
  onDisconnect: (clientId: string) => void;
  onMessage: (clientId: string, message: ClientMessage) => void;
  tick: (dt: number) => void;
}

interface WorldState {
  musicPlaying: boolean;
  resourcesReady: boolean;
  resourceLoadFailed: boolean;
  assets: {
    raywhiteColor: number;
    whiteColor: number;
    accentColor: number;
    panelColor: number;
    shadowColor: number;
    logoSprite3d: Sprite3D | null;
    logoTexture: Texture | null;
    blobShadowTexture: Texture | null;
    camera3d: Camera3D | null;
    gumshoeModel: Model | null;
  };
}

interface SessionState {
  resourceBootstrapStarted: boolean;
  worldResourcesPending: boolean;
  worldResourcesReady: boolean;
  sessionResourcesReady: boolean;
  resourcesReady: boolean;
  resourceLoadFailed: boolean;
  assets: {
    overlayFont: number;
    clickSound: Sound | null;
    logoSprite3d: Sprite3D | null;
  };
  bgMusic: Music | null;
}

interface GameSession {
  client: GameClient;
  resourceManager: SessionResourceManager;
  state: SessionState;
  frameCommandBuffer: rl_frame_command_buffer_t;
  lastInput: ClientInputState | null;
  lastPickResult: RemotePickResult | null;
  pendingPickRequests: PickRequest[];
  pendingPickRids: Set<number>;
  nextPickRid: number;
}

let frameNumber = 0;

function createInitialWorldState(): WorldState {
  return {
    musicPlaying: false,
    resourcesReady: false,
    resourceLoadFailed: false,
    assets: {
      raywhiteColor: 0,
      whiteColor: 0,
      accentColor: 0,
      panelColor: 0,
      shadowColor: 0,
      logoSprite3d: null,
      logoTexture: null,
      blobShadowTexture: null,
      camera3d: null,
      gumshoeModel: null,
    },
  };
}

function createInitialSessionState(): SessionState {
  return {
    resourceBootstrapStarted: false,
    worldResourcesPending: false,
    worldResourcesReady: false,
    sessionResourcesReady: false,
    resourcesReady: false,
    resourceLoadFailed: false,
    assets: {
      overlayFont: 0,
      clickSound: null,
      logoSprite3d: null,
    },
    bgMusic: null,
  };
}

function lx(x: number, sx: number): number {
  return x * sx;
}

function ly(y: number, sy: number): number {
  return y * sy;
}

function getLayoutMetrics(input: ClientInputState | null): LayoutMetrics {
  const screenW = input?.screenWidth && input.screenWidth > 0 ? input.screenWidth : IDEAL_W;
  const screenH = input?.screenHeight && input.screenHeight > 0 ? input.screenHeight : IDEAL_H;
  const sx = screenW / IDEAL_W;
  const sy = screenH / IDEAL_H;
  const su = Math.min(sx, sy);

  return { screenW, screenH, sx, sy, su };
}

function calculatePositionAndDirectionOnCircle(timeS: number, radius:number) {
  const orbit = timeS * 0.9;
  const vX = -Math.sin(orbit);
  const vZ = Math.cos(orbit);

  return {
    x: Math.cos(orbit) * radius,
    y: 0.0,
    z: Math.sin(orbit) * radius,
    direction: Math.atan2(vX, vZ) * (180 / Math.PI),
  };
}

function getLogoSizeForInput(input: ClientInputState | null): number {
  const mouseLeftDown = input?.mouse.left === 1 || input?.mouse.left === 2;
  const spaceDown = input?.keyboard.keysDown.includes(32) ?? false;
  let logoSize = mouseLeftDown ? 1.5 : 1.0;

  if (spaceDown) {
    logoSize += 0.5;
  }

  return logoSize;
}

function getLogoTextureRotation(timeS: number): number {
  return Math.sin(timeS * 1.5) * 8.0;
}

function updateWorldState(
  world: WorldState,
  timeS: number,
): void {
  if (world.assets.gumshoeModel != null) {
  const result = calculatePositionAndDirectionOnCircle(timeS, GUMSHOE_ORBIT_RADIUS)
  world.assets.gumshoeModel.x = result.x;
  world.assets.gumshoeModel.y = result.y;
  world.assets.gumshoeModel.z = result.z;
  world.assets.gumshoeModel.scale = 1.0;
  world.assets.gumshoeModel.rotationX = 0.0;
  world.assets.gumshoeModel.rotationY = result.direction;
  world.assets.gumshoeModel.rotationZ = 0.0;
  world.assets.gumshoeModel.animationIndex = 1;
  world.assets.gumshoeModel.animationFrame = Math.floor(timeS * 60.0)
  }

  if (world.assets.logoSprite3d != null) {
    world.assets.logoSprite3d.x = -1.75;
    world.assets.logoSprite3d.y = 1.0 + Math.sin(timeS * 3.0) * 0.15;
    world.assets.logoSprite3d.z = 0.0;
    world.assets.logoSprite3d.size = 1.0;
  }
}

function updateSessionState(
  world: WorldState,
  session: GameSession,
  timeS: number,
): void {
  const logoSize = getLogoSizeForInput(session.lastInput);
  const logoSprite3d = session.state.assets.logoSprite3d;

  if (
    session.lastInput != null &&
    isButtonPressed(session.lastInput.mouse.left) &&
    session.state.assets.clickSound != null
  ) {
    session.state.assets.clickSound.play();
  }

  if (
    session.lastInput != null &&
    session.lastInput.keyboard.pressedKeys.includes(77) &&
    session.state.bgMusic != null
  ) {
    if (world.musicPlaying) {
      session.state.bgMusic.pause();
      world.musicPlaying = false;
    } else {
      session.state.bgMusic.play();
      world.musicPlaying = true;
    }
  }

  if (!session.state.worldResourcesReady || logoSprite3d == null) {
    return;
  }

  logoSprite3d.x = 1.75;
  logoSprite3d.y = 1.0 + Math.sin(timeS * 3.0) * 0.15;
  logoSprite3d.z = 0.0;
  logoSprite3d.size = logoSize;

  // testing, resize the world logo with the client mouse (crossing session-> world)
  if (world.assets.logoSprite3d != null && logoSize > 1.0) {
    world.assets.logoSprite3d.size = Math.max(world.assets.logoSprite3d.size, logoSize);
  }
}

function drawText(
  font: number,
  color: number,
  value: string,
  x: number,
  y: number,
  fontSize: number,
  spacing: number,
): void {
  if (font === 0 || color === 0) {
    return;
  }

  rl_text_draw_ex(font, value, x, y, fontSize, spacing, color);
}

function isButtonPressed(state: number): boolean {
  return state === 1;
}

function isButtonDown(state: number): boolean {
  return state === 1 || state === 2;
}

function isButtonReleased(state: number): boolean {
  return state === 3;
}

function buttonLabel(state: number): string {
  if (isButtonPressed(state)) {
    return "pressed";
  }
  if (state === 2) {
    return "down";
  }
  if (isButtonReleased(state)) {
    return "released";
  }
  return "up";
}

function generateWorldFrame(
  dt: number,
  timeS: number,
  world: WorldState,
  frame_commands: rl_frame_command_buffer_t,
): FrameSnapshot {
  rl_frame_commands_reset(frame_commands);
  set_frame_command_buffer(frame_commands);
  const frame_snapshot: FrameSnapshot = {
    frameNumber: frameNumber++,
    deltaTime: dt,
    commands: frame_commands.commands,
  };
  begin_frame_snapshot(frame_snapshot, frame_commands, timeS);
  rl_render_begin();

  if (!world.resourcesReady) {
    rl_render_end();
    end_frame_snapshot();
    return frame_snapshot;
  }

  rl_render_clear_background(world.assets.raywhiteColor);
  world.assets.camera3d?.sync();

  if (world.assets.blobShadowTexture && world.assets.shadowColor !== 0 && world.assets.logoSprite3d) {
    const groundY = 0.0;
    const baseSize = 1.35;
    const logoY = world.assets.logoSprite3d.y;
    const logoSize = world.assets.logoSprite3d.size;
    const height = Math.max(0.0, logoY - groundY);
    const t = Math.min(Math.max(height / (baseSize * 2.5 + 0.0001), 0.0), 1.0);
    const shadowSize = Math.max(baseSize * logoSize * (1 - t) * (1 - t), 0.05);

    world.assets.blobShadowTexture.drawGround(
      world.assets.logoSprite3d.x,
      groundY + 0.01,
      world.assets.logoSprite3d.z,
      shadowSize,
      shadowSize,
      world.assets.shadowColor,
    );
  }

  if (world.assets.logoSprite3d && world.assets.whiteColor !== 0) {
    world.assets.logoSprite3d.draw(world.assets.whiteColor);
  }

  if (world.assets.logoTexture && world.assets.whiteColor !== 0) {
    world.assets.logoTexture.drawEx(
      520.0,
      36.0,
      0.35,
      getLogoTextureRotation(timeS),
      world.assets.whiteColor,
    );
  }

  if (world.assets.gumshoeModel && world.assets.whiteColor !== 0) {
    world.assets.gumshoeModel.draw(world.assets.whiteColor);
  }

  rl_render_end();
  end_frame_snapshot();
  return frame_snapshot;
}

function drawSessionLogoAndShadow(
  world: WorldState,
  session: GameSession,
): void {
  const logoSprite3d = session.state.assets.logoSprite3d;

  if (!session.state.worldResourcesReady || logoSprite3d == null) {
    return;
  }
  const groundY = 0.0;
  const baseSize = 1.35;
  const logoY = logoSprite3d.y;
  const logoSize = logoSprite3d.size;

  if (world.assets.blobShadowTexture && world.assets.shadowColor !== 0) {
    const height = Math.max(0.0, logoY - groundY);
    const t = Math.min(Math.max(height / (baseSize * 2.5 + 0.0001), 0.0), 1.0);
    const shadowSize = Math.max(baseSize * logoSize * (1 - t) * (1 - t), 0.05);

    world.assets.blobShadowTexture.drawGround(
      logoSprite3d.x,
      groundY + 0.01,
      logoSprite3d.z,
      shadowSize,
      shadowSize,
      world.assets.shadowColor,
    );
  }

  if (world.assets.whiteColor !== 0) {
    logoSprite3d.draw(world.assets.whiteColor);
  }
}

function generateSessionFrame(
  dt: number,
  world: WorldState,
  session: GameSession,
  timeS: number,
  frame_commands: rl_frame_command_buffer_t,
  clientCount: number,
): FrameSnapshot {
  rl_frame_commands_reset(frame_commands);
  set_frame_command_buffer(frame_commands);
  const frame_snapshot: FrameSnapshot = {
    frameNumber: frameNumber++,
    deltaTime: dt,
    commands: frame_commands.commands,
  };
  begin_frame_snapshot(frame_snapshot, frame_commands, timeS);
  rl_render_begin();

  drawSessionLogoAndShadow(world, session);
  drawDebugOverlay(world, session, timeS, clientCount);
  session.state.assets.clickSound?.sync();
  session.state.bgMusic?.sync();

  rl_render_end();
  end_frame_snapshot();
  return frame_snapshot;
}

function drawDebugOverlay(
  world: WorldState,
  session: GameSession,
  timeS: number,
  clientCount: number,
): void {
  const { state, lastInput, lastPickResult } = session;

  if (!state.worldResourcesReady || !lastInput || state.assets.overlayFont === 0 || world.assets.panelColor === 0) {
    return;
  }

  const layout = getLayoutMetrics(lastInput);
  const mouse = lastInput.mouse;
  const keyboard = lastInput.keyboard;
  const mouseLeftPressed = isButtonPressed(mouse.left);
  const mouseRightPressed = isButtonPressed(mouse.right);
  const mouseMiddlePressed = isButtonPressed(mouse.middle);
  const mouseLeftReleased = isButtonReleased(mouse.left);
  const mouseRightReleased = isButtonReleased(mouse.right);
  const mouseMiddleReleased = isButtonReleased(mouse.middle);
  const spaceDown = keyboard.keysDown.includes(32);
  const leftDown = keyboard.keysDown.includes(263);
  const rightDown = keyboard.keysDown.includes(262);
  const upDown = keyboard.keysDown.includes(265);
  const downDown = keyboard.keysDown.includes(264);

  drawText(
    state.assets.overlayFont,
    world.assets.panelColor,
    `mouse=(${mouse.x}, ${mouse.y}) buttons=(L:${buttonLabel(mouse.left)} R:${buttonLabel(mouse.right)} M:${buttonLabel(mouse.middle)}) wheel=${mouse.wheel}`,
    24 * layout.sx,
    260 * layout.sy,
    20 * layout.su,
    layout.su,
  );

  drawText(
    state.assets.overlayFont,
    world.assets.panelColor,
    `kbd space=${spaceDown ? "down" : "up"} arrows=(${leftDown ? "L" : "-"} ${rightDown ? "R" : "-"} ${upDown ? "U" : "-"} ${downDown ? "D" : "-"})`,
    24 * layout.sx,
    290 * layout.sy,
    20 * layout.su,
    layout.su,
  );

  drawText(
    state.assets.overlayFont,
    world.assets.panelColor,
    `pressed counts=(${keyboard.pressedKeys.length}/${keyboard.pressedChars.length}) chars="${String.fromCharCode(...keyboard.pressedChars.filter((ch) => ch >= 32 && ch <= 255)).slice(0, 24)}"`,
    24 * layout.sx,
    320 * layout.sy,
    20 * layout.su,
    layout.su,
  );

  if (
    mouseLeftPressed || mouseRightPressed || mouseMiddlePressed ||
    mouseLeftReleased || mouseRightReleased || mouseMiddleReleased
  ) {
    drawText(
      state.assets.overlayFont,
      world.assets.panelColor,
      `edges=(L:${mouseLeftPressed ? "press" : mouseLeftReleased ? "release" : "-"} R:${mouseRightPressed ? "press" : mouseRightReleased ? "release" : "-"} M:${mouseMiddlePressed ? "press" : mouseMiddleReleased ? "release" : "-"})`,
      24 * layout.sx,
      350 * layout.sy,
      20 * layout.su,
      layout.su,
    );
  }

  if (lastPickResult) {
    drawText(
      state.assets.overlayFont,
      world.assets.accentColor || world.assets.panelColor,
      lastPickResult.hit
        ? `pick: hit d=${lastPickResult.distance.toFixed(2)} @ (${lastPickResult.point.x.toFixed(2)}, ${lastPickResult.point.y.toFixed(2)}, ${lastPickResult.point.z.toFixed(2)})`
        : "pick: miss",
      24 * layout.sx,
      380 * layout.sy,
      20 * layout.su,
      layout.su,
    );
  }

  drawText(
    state.assets.overlayFont,
    world.assets.accentColor || world.assets.panelColor,
    `music(M): ${world.musicPlaying ? "playing" : "paused"} clients=${clientCount} t=${timeS.toFixed(2)}`,
    24 * layout.sx,
    410 * layout.sy,
    20 * layout.su,
    layout.su,
  );
}

function flushPendingPickRequests(session: GameSession): void {
  if (session.pendingPickRequests.length === 0) {
    return;
  }

  const message: ServerPickRequestsMessage = {
    type: "pickRequests",
    pickRequests: session.pendingPickRequests,
  };

  session.client.send(message);
  session.pendingPickRequests = [];
}

function queueGumshoePickRequest(world: WorldState, session: GameSession): void {
  const { state, lastInput } = session;

  if (
    !state.worldResourcesReady ||
    lastInput == null ||
    world.assets.camera3d == null ||
    world.assets.gumshoeModel == null
  ) {
    return;
  }

  const request = world.assets.gumshoeModel.createPickRequest(
    session.nextPickRid,
    world.assets.camera3d.handle ?? 0,
    lastInput.mouse.x,
    lastInput.mouse.y,
  );

  if (request == null) {
    return;
  }

  session.pendingPickRequests.push(request);
  session.pendingPickRids.add(session.nextPickRid);
  session.nextPickRid++;
}

function applyPickResponse(session: GameSession, response: PickResponse): void {
  if (!session.pendingPickRids.has(response.rid)) {
    return;
  }

  session.pendingPickRids.delete(response.rid);
  session.lastPickResult = {
    hit: response.hit,
    distance: response.distance,
    point: response.point,
  };
}

function markResourceLoadFailed(session: GameSession, path: string): void {
  session.state.resourceLoadFailed = true;
  console.error(`[Game] Failed to load resource: ${path}`);
  session.client.disconnect();
}

function refreshResourceReadiness(world: WorldState, session: GameSession): void {
  const { state } = session;

  if (state.resourcesReady || state.resourceLoadFailed) {
    return;
  }

  if (!world.resourcesReady) {
    return;
  }

  if (
    !state.worldResourcesReady ||
    state.assets.overlayFont === 0 ||
    state.assets.clickSound == null ||
    state.assets.logoSprite3d == null ||
    state.bgMusic == null
  ) {
    return;
  }

  state.sessionResourcesReady = true;
  state.resourcesReady = true;
  console.log(`[Game] All resources ready`);
  state.bgMusic.loop = true;
  state.bgMusic.volume = 0.25;
  state.bgMusic.play();
  world.musicPlaying = true;
}

function queueAssetCreateTask(
  session: GameSession,
  path: string,
  on_success: () => void,
): void {
  const task = rl_loader_import_asset_async(path);
  const rc = rl_loader_add_task(
    task,
    path,
    () => on_success(),
    (failedPath) => markResourceLoadFailed(session, failedPath),
    undefined,
  );

  if (rc !== rl_loader_add_task_result_t.RL_LOADER_ADD_TASK_OK) {
    markResourceLoadFailed(session, path);
  }
}

function beginLoadWorldResources(world: WorldState): void {
  if (world.resourcesReady || world.resourceLoadFailed) {
    return;
  }

  void Promise.all([
    (set_color_resource_manager(WorldResources), rl_color_create(245, 245, 245, 255)),
    (set_color_resource_manager(WorldResources), rl_color_create(255, 255, 255, 255)),
    (set_color_resource_manager(WorldResources), rl_color_create(221, 87, 54, 255)),
    (set_color_resource_manager(WorldResources), rl_color_create(24, 107, 138, 255)),
    (set_color_resource_manager(WorldResources), rl_color_create(0, 0, 0, 64)),
  ])
    .then(([raywhite, white, accent, panel, shadow]) => {
      world.assets.raywhiteColor = raywhite;
      world.assets.whiteColor = white;
      world.assets.accentColor = accent;
      world.assets.panelColor = panel;
      world.assets.shadowColor = shadow;
      console.log("[Game] World colors ready");
    })
    .catch(() => {
      world.resourceLoadFailed = true;
    });

  void Camera3D.create(
    WorldResources,
    12.0, 12.0, 12.0,
    0.0, 1.0, 0.0,
    0.0, 1.0, 0.0,
    45.0, CAMERA_PERSPECTIVE,
  )
    .then((camera) => {
      world.assets.camera3d = camera;
      console.log(`[Game] World camera ready: ${camera.handle}`);
    })
    .catch(() => {
      world.resourceLoadFailed = true;
    });

  {
    const logoPath = "assets/sprites/logo/wg-logo-bw-alpha.png";
    const task = rl_loader_import_asset_async(logoPath);
    const rc = rl_loader_add_task(
      task,
      logoPath,
      () => {
        void Promise.all([
          Texture.load(WorldResources, logoPath),
          Sprite3D.load(WorldResources, logoPath),
        ])
          .then(([texture, sprite]) => {
            world.assets.logoTexture = texture;
            world.assets.logoSprite3d = sprite;
            console.log(`[Game] World logo texture ready: ${texture.handle}`);
            console.log(`[Game] World sprite ready: ${sprite.handle}`);
          })
          .catch(() => {
            world.resourceLoadFailed = true;
          });
      },
      () => {
        world.resourceLoadFailed = true;
      },
      undefined,
    );

    if (rc !== rl_loader_add_task_result_t.RL_LOADER_ADD_TASK_OK) {
      world.resourceLoadFailed = true;
    }
  }

  {
    const blobPath = "assets/textures/blobshadow.png";
    const task = rl_loader_import_asset_async(blobPath);
    const rc = rl_loader_add_task(
      task,
      blobPath,
      () => {
        void Texture.load(WorldResources, blobPath)
          .then((texture) => {
            world.assets.blobShadowTexture = texture;
            console.log(`[Game] World blob shadow ready: ${texture.handle}`);
          })
          .catch(() => {
            world.resourceLoadFailed = true;
          });
      },
      () => {
        world.resourceLoadFailed = true;
      },
      undefined,
    );

    if (rc !== rl_loader_add_task_result_t.RL_LOADER_ADD_TASK_OK) {
      world.resourceLoadFailed = true;
    }
  }

  world.assets.gumshoeModel = new Model(
    "assets/models/gumshoe/gumshoe.glb",
    WorldResources,
  );
  world.assets.gumshoeModel.load(
    (model) => {
      console.log(`[Game] World gumshoe ready: ${model.handle}`);
    },
    () => {
      world.resourceLoadFailed = true;
    },
  );
}

function refreshWorldResourceReadiness(world: WorldState): void {
  if (world.resourcesReady || world.resourceLoadFailed) {
    return;
  }

  if (
    world.assets.raywhiteColor === 0 ||
    world.assets.whiteColor === 0 ||
    world.assets.accentColor === 0 ||
    world.assets.panelColor === 0 ||
    world.assets.shadowColor === 0 ||
    world.assets.logoSprite3d == null ||
    world.assets.logoTexture == null ||
    world.assets.blobShadowTexture == null ||
    world.assets.gumshoeModel == null ||
    world.assets.gumshoeModel.handle == null ||
    world.assets.camera3d == null
  ) {
    return;
  }

  world.resourcesReady = true;
  console.log("[Game] Shared world resources ready");
}

function realizeSharedWorldResources(world: WorldState, session: GameSession): void {
  if (!world.resourcesReady || session.state.worldResourcesReady || session.state.worldResourcesPending) {
    return;
  }

  session.state.worldResourcesPending = true;
  const definitions = WorldResources.getResourceDefinitions();
  void Promise.all(
    definitions.map((definition: WorldResourceDefinition) =>
      session.resourceManager.requestResourceWithHandle(definition.handle, definition.request),
    ),
  )
    .then(() => {
      session.state.worldResourcesPending = false;
      session.state.worldResourcesReady = true;
      console.log("[Game] Shared world resources realized for session");
      refreshResourceReadiness(world, session);
    })
    .catch(() => {
      session.state.worldResourcesPending = false;
      markResourceLoadFailed(session, "world_resources");
    });
}

function beginLoadResources(world: WorldState, session: GameSession): void {
  const { state } = session;

  if (state.resourceBootstrapStarted) {
    return;
  }

  state.resourceBootstrapStarted = true;
  realizeSharedWorldResources(world, session);

  queueAssetCreateTask(session, "assets/fonts/Komika/KOMIKAH_.ttf", () => {
    set_font_resource_manager(session.resourceManager);
    void rl_font_create("assets/fonts/Komika/KOMIKAH_.ttf", 24)
      .then((handle) => {
        state.assets.overlayFont = handle;
        console.log(`[Game] Font ready: ${state.assets.overlayFont}`);
        refreshResourceReadiness(world, session);
      })
      .catch(() => markResourceLoadFailed(session, "assets/fonts/Komika/KOMIKAH_.ttf"));
  });

  queueAssetCreateTask(session, "assets/sounds/click_004.ogg", () => {
    void Sound.load(session.resourceManager, "assets/sounds/click_004.ogg")
      .then((sound) => {
        state.assets.clickSound = sound;
        console.log(`[Game] Click sound ready: ${sound.handle}`);
        refreshResourceReadiness(world, session);
      })
      .catch(() => markResourceLoadFailed(session, "assets/sounds/click_004.ogg"));
  });

  queueAssetCreateTask(session, "assets/sprites/logo/wg-logo-bw-alpha.png", () => {
    void Sprite3D.load(session.resourceManager, "assets/sprites/logo/wg-logo-bw-alpha.png")
      .then((sprite) => {
        state.assets.logoSprite3d = sprite;
        console.log(`[Game] Session sprite ready: ${sprite.handle}`);
        refreshResourceReadiness(world, session);
      })
      .catch(() => markResourceLoadFailed(session, "assets/sprites/logo/wg-logo-bw-alpha.png"));
  });

  queueAssetCreateTask(session, "assets/music/ethernight_club.mp3", () => {
    void Music.load(session.resourceManager, "assets/music/ethernight_club.mp3")
      .then((music) => {
        state.bgMusic = music;
        console.log(`[Game] Background music ready: ${music.handle}`);
        refreshResourceReadiness(world, session);
      })
      .catch(() => markResourceLoadFailed(session, "assets/music/ethernight_club.mp3"));
  });
}

class RemoteGameRuntime implements GameRuntime {
  private sessions = new Map<string, GameSession>();
  private timeS = 0.0;
  private worldState: WorldState = createInitialWorldState();
  private worldFrameCommandBuffer: rl_frame_command_buffer_t = create_frame_command_buffer();

  init(): void {
    this.timeS = 0.0;
    this.worldState = createInitialWorldState();
    beginLoadWorldResources(this.worldState);
    console.info("[GAME]: init")
  }

  destroy(): void {
    for (const session of this.sessions.values()) {
      void this.disposeSession(session);
    }
    this.sessions.clear();
    destroy_frame_command_buffer(this.worldFrameCommandBuffer);
  }

  private async disposeSession(session: GameSession): Promise<void> {
    session.resourceManager.clear();

    await Promise.allSettled([
      session.state.assets.overlayFont !== 0 ? (set_font_resource_manager(session.resourceManager), rl_font_destroy(session.state.assets.overlayFont)) : Promise.resolve(),
      session.state.assets.clickSound != null ? session.state.assets.clickSound.destroy() : Promise.resolve(),
      session.state.assets.logoSprite3d != null ? session.state.assets.logoSprite3d.destroy() : Promise.resolve(),
      session.state.bgMusic != null ? session.state.bgMusic.destroy() : Promise.resolve(),
    ]);

    destroy_frame_command_buffer(session.frameCommandBuffer);
  }

  async onConnect(client: GameClient): Promise<void> {
    console.log("[GAME]: client connected")
    const session: GameSession = {
      client,
      resourceManager: new SessionResourceManager(),
      state: createInitialSessionState(),
      frameCommandBuffer: create_frame_command_buffer(),
      lastInput: null,
      lastPickResult: null,
      pendingPickRequests: [],
      pendingPickRids: new Set<number>(),
      nextPickRid: 1,
    };

    this.sessions.set(client.id, session);
    client.send({ type: "reset", reason: "session_start" });
    beginLoadResources(this.worldState, session);
  }

  onDisconnect(clientId: string): void {
    const session = this.sessions.get(clientId);

    if (!session) {
      return;
    }

    void this.disposeSession(session);
    this.sessions.delete(clientId);
  }

  onMessage(clientId: string, message: ClientMessage): void {
    const session = this.sessions.get(clientId);

    if (!session) {
      return;
    }

    if (message.type === "resourceResponses" && message.resourceResponses) {
      for (const response of message.resourceResponses) {
        session.resourceManager.handleResponse(response);
      }
      return;
    }

    if (message.type === "pickResponses" && message.pickResponses) {
      for (const response of message.pickResponses) {
        applyPickResponse(session, response);
      }
      return;
    }

    if (message.type === "inputState" && message.inputState) {
      session.lastInput = message.inputState;
    }
  }

  tick(dt: number): void {
    this.timeS += dt;
    rl_loader_tick();
    refreshWorldResourceReadiness(this.worldState);

    if (this.sessions.size === 0) {
      return;
    }

    updateWorldState(this.worldState, this.timeS);
    for (const session of this.sessions.values()) {
      realizeSharedWorldResources(this.worldState, session);
      updateSessionState(this.worldState, session, this.timeS);

      if (session.lastInput) {
        if (isButtonPressed(session.lastInput.mouse.left)) {
          queueGumshoePickRequest(this.worldState, session);
        }
      }

    }

    const worldFrame = generateWorldFrame(
      dt,
      this.timeS,
      this.worldState,
      this.worldFrameCommandBuffer,
    );

    for (const session of this.sessions.values()) {
      const pendingRequests = session.resourceManager.getPendingRequests();
      const clientCount = this.sessions.size;
      const sessionFrame = generateSessionFrame(
        dt,
        this.worldState,
        session,
        this.timeS,
        session.frameCommandBuffer,
        clientCount,
      );

      if (pendingRequests.length > 0) {
        session.client.send({
          type: "resourceRequests",
          resourceRequests: pendingRequests,
        });
      }

      flushPendingPickRequests(session);

      session.client.send({
        type: "frameBegin",
        frameNumber: worldFrame.frameNumber,
        deltaTime: worldFrame.deltaTime,
      });
      if (session.state.worldResourcesReady) {
        session.client.send({
          type: "frameChunk",
          commands: worldFrame.commands,
        });
      }
      if (sessionFrame.commands.length > 0) {
        session.client.send({
          type: "frameChunk",
          commands: sessionFrame.commands,
        });
      }
      session.client.send({
        type: "frameEnd",
      });
    }
  }
}

export function createGameRuntime(): GameRuntime {
  return new RemoteGameRuntime();
}
