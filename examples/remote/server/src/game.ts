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
  rl_frame_begin,
  rl_frame_clear_background,
  rl_frame_end,
} from "./rl/rl_frame";
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
import { rl_color_create } from "./rl/rl_color";
import { rl_font_create } from "./rl/rl_font";
import { rl_music_create } from "./rl/rl_music";
import { rl_sound_create, rl_sound_play } from "./rl/rl_sound";
import { rl_text_draw_ex } from "./rl/rl_text";
import { SharedResourceManager } from "./resource_manager";
import { Model } from "./model";
import { Camera3D } from "./camera3d";
import { Sprite3D } from "./sprite3d";
import { Texture } from "./texture";
import type {
  ClientInputState,
  ClientMessage,
  MusicCommand,
  PickRequest,
  PickResponse,
  ServerPickRequestsMessage,
  ServerFrameMessage,
  ServerMessage,
} from "./protocol";
import { MusicCommandType, PickRequestType } from "./protocol";

const IDEAL_W = 1024;
const IDEAL_H = 1280;
const CAMERA_PERSPECTIVE = 0;
const GUMSHOE_RADIUS = 3.5;

export interface LayoutMetrics {
  screenW: number;
  screenH: number;
  sx: number;
  sy: number;
  su: number;
}

export interface GumshoePose {
  x: number;
  y: number;
  z: number;
  rotationY: number;
  animationFrame: number;
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

interface GameState {
  resourceBootstrapStarted: boolean;
  resourcesReady: boolean;
  resourceLoadFailed: boolean;
  assets: {
    raywhite: number;
    white: number;
    accentColor: number;
    panelColor: number;
    shadowColor: number;
    font: number;
    logoSprite3d: Sprite3D | null;
    logoTexture: Texture | null;
    blobShadowTexture: Texture | null;
    clickSound: number;
    camera3d: Camera3D | null;
  };
  bgMusic: number | null;
  gumshoeModel: Model | null;
  musicPlaying: boolean;
}

interface GameSession {
  client: GameClient;
  state: GameState;
  frameCommandBuffer: rl_frame_command_buffer_t;
  lastInput: ClientInputState | null;
  lastPickResult: RemotePickResult | null;
  pendingMusicCommands: MusicCommand[];
  pendingPickRequests: PickRequest[];
  pendingPickRids: Set<number>;
  nextPickRid: number;
}

let frameNumber = 0;

function createInitialGameState(): GameState {
  return {
    resourceBootstrapStarted: false,
    resourcesReady: false,
    resourceLoadFailed: false,
    assets: {
      raywhite: 0,
      white: 0,
      accentColor: 0,
      panelColor: 0,
      shadowColor: 0,
      font: 0,
      logoSprite3d: null,
      logoTexture: null,
      blobShadowTexture: null,
      clickSound: 0,
      camera3d: null,
    },
    bgMusic: null,
    gumshoeModel: null,
    musicPlaying: false,
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

function getGumshoePose(timeS: number): GumshoePose {
  const gumshoeOrbit = timeS * 0.9;
  const gumshoeVx = -Math.sin(gumshoeOrbit);
  const gumshoeVz = Math.cos(gumshoeOrbit);

  return {
    x: Math.cos(gumshoeOrbit) * GUMSHOE_RADIUS,
    y: 0.0,
    z: Math.sin(gumshoeOrbit) * GUMSHOE_RADIUS,
    rotationY: Math.atan2(gumshoeVx, gumshoeVz) * (180 / Math.PI),
    animationFrame: Math.floor(timeS * 60.0),
  };
}

function updateGumshoeModel(model: Model | null, timeS: number): void {
  if (model == null) {
    return;
  }

  const pose = getGumshoePose(timeS);

  model.x = pose.x;
  model.y = pose.y;
  model.z = pose.z;
  model.scale = 1.0;
  model.rotationX = 0.0;
  model.rotationY = pose.rotationY;
  model.rotationZ = 0.0;
  model.animationIndex = 1;
  model.animationFrame = pose.animationFrame;
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

function queueInitialMusicCommands(state: GameState, session: GameSession): void {
  if (!state.bgMusic) {
    return;
  }

  state.musicPlaying = true;
  session.pendingMusicCommands.push(
    {
        type: MusicCommandType.SET_LOOP,
        handle: state.bgMusic,
      loop: true,
    },
    {
        type: MusicCommandType.SET_VOLUME,
        handle: state.bgMusic,
      volume: 0.25,
    },
    {
        type: MusicCommandType.PLAY,
        handle: state.bgMusic,
    },
  );
}

function getMusicCommandsForInput(
  state: GameState,
  input: ClientInputState | null,
): MusicCommand[] {
  if (!state.bgMusic || input == null) {
    return [];
  }

  if (!input.keyboard.pressedKeys.includes(77)) {
    return [];
  }

  if (state.musicPlaying) {
    state.musicPlaying = false;
    return [
      {
        type: MusicCommandType.PAUSE,
        handle: state.bgMusic,
      },
    ];
  }

  state.musicPlaying = true;
  return [
    {
      type: MusicCommandType.PLAY,
      handle: state.bgMusic,
    },
  ];
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

function generateFrameSnapshot(
  dt: number,
  timeS: number,
  state: GameState,
  frame_commands: rl_frame_command_buffer_t,
  clientCount: number,
  input: ClientInputState | null,
): FrameSnapshot {
  rl_frame_commands_reset(frame_commands);
  set_frame_command_buffer(frame_commands);
  const frame_snapshot: FrameSnapshot = {
    frameNumber: frameNumber++,
    deltaTime: dt,
    commands: frame_commands.commands,
  };
  begin_frame_snapshot(frame_snapshot, frame_commands, timeS);
  rl_frame_begin();

  if (!state.resourcesReady) {
    rl_frame_end();
    end_frame_snapshot();
    return frame_snapshot;
  }

  const { screenW, screenH, sx, sy, su } = getLayoutMetrics(input);
  const wobble = Math.sin(timeS * 2.0) * 24.0;
  const mouseLeftDown = input?.mouse.left === 1 || input?.mouse.left === 2;
  const spaceDown = input?.keyboard.keysDown.includes(32) ?? false;

  updateGumshoeModel(state.gumshoeModel, timeS);

  rl_frame_clear_background(state.assets.raywhite);
  state.assets.camera3d?.sync();

  if (state.assets.font !== 0) {
    drawText(state.assets.font, state.assets.accentColor, "server-driven frame", lx(24, sx), ly(140, sy) + wobble * sy, 32 * su, su);
    drawText(state.assets.font, state.assets.accentColor, `frame=${frameNumber} t=${timeS.toFixed(2)}`, lx(24, sx), ly(170, sy), 20 * su, su);
    drawText(state.assets.font, state.assets.panelColor, `screen=(${screenW}, ${screenH}) clients=${clientCount}`, lx(24, sx), ly(200, sy), 20 * su, su);
    drawText(state.assets.font, state.assets.panelColor, "Remote rendering via WebSocket", lx(24, sx), ly(230, sy), 20 * su, su);
  }

  {
    const logoY = 1.0 + Math.sin(timeS * 3.0) * 0.15;
    let logoSize = mouseLeftDown ? 1.5 : 1.0;
    const groundY = 0.0;
    const baseSize = 1.35;

    if (spaceDown) {
      logoSize += 0.5;
    }

    if (state.assets.blobShadowTexture && state.assets.shadowColor !== 0) {
      const height = Math.max(0.0, logoY - groundY);
      const t = Math.min(Math.max(height / (baseSize * 2.5 + 0.0001), 0.0), 1.0);
      const shadowSize = Math.max(baseSize * logoSize * (1 - t) * (1 - t), 0.05);

      state.assets.blobShadowTexture.drawGround(
        0.0,
        groundY + 0.01,
        0.0,
        shadowSize,
        shadowSize,
        state.assets.shadowColor,
      );
    }

    if (state.assets.logoSprite3d && state.assets.white !== 0) {
      state.assets.logoSprite3d.x = 0.0;
      state.assets.logoSprite3d.y = logoY;
      state.assets.logoSprite3d.z = 0.0;
      state.assets.logoSprite3d.size = logoSize;
      state.assets.logoSprite3d.draw(state.assets.white);
    }
  }

  if (state.assets.logoTexture && state.assets.white !== 0) {
    state.assets.logoTexture.drawEx(
      lx(520.0, sx),
      ly(36.0, sy),
      0.35 * su,
      Math.sin(timeS * 1.5) * 8.0,
      state.assets.white,
    );
  }

  if (state.gumshoeModel && state.assets.white !== 0) {
    state.gumshoeModel.draw(state.assets.white);
  }

  rl_frame_end();
  end_frame_snapshot();
  return frame_snapshot;
}

function drawDebugOverlay(
  session: GameSession,
  timeS: number,
  clientCount: number,
): void {
  const { state, lastInput, lastPickResult } = session;

  if (!lastInput || state.assets.font === 0 || state.assets.panelColor === 0) {
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
    state.assets.font,
    state.assets.panelColor,
    `mouse=(${mouse.x}, ${mouse.y}) buttons=(L:${buttonLabel(mouse.left)} R:${buttonLabel(mouse.right)} M:${buttonLabel(mouse.middle)}) wheel=${mouse.wheel}`,
    24 * layout.sx,
    260 * layout.sy,
    20 * layout.su,
    layout.su,
  );

  drawText(
    state.assets.font,
    state.assets.panelColor,
    `kbd space=${spaceDown ? "down" : "up"} arrows=(${leftDown ? "L" : "-"} ${rightDown ? "R" : "-"} ${upDown ? "U" : "-"} ${downDown ? "D" : "-"})`,
    24 * layout.sx,
    290 * layout.sy,
    20 * layout.su,
    layout.su,
  );

  drawText(
    state.assets.font,
    state.assets.panelColor,
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
      state.assets.font,
      state.assets.panelColor,
      `edges=(L:${mouseLeftPressed ? "press" : mouseLeftReleased ? "release" : "-"} R:${mouseRightPressed ? "press" : mouseRightReleased ? "release" : "-"} M:${mouseMiddlePressed ? "press" : mouseMiddleReleased ? "release" : "-"})`,
      24 * layout.sx,
      350 * layout.sy,
      20 * layout.su,
      layout.su,
    );
  }

  if (lastPickResult) {
    drawText(
      state.assets.font,
      state.assets.accentColor || state.assets.panelColor,
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
    state.assets.font,
    state.assets.accentColor || state.assets.panelColor,
    `music(M): ${state.musicPlaying ? "playing" : "paused"} clients=${clientCount} t=${timeS.toFixed(2)}`,
    24 * layout.sx,
    410 * layout.sy,
    20 * layout.su,
    layout.su,
  );
}

function flushPendingMusicCommands(session: GameSession): void {
  if (session.pendingMusicCommands.length === 0) {
    return;
  }

  session.client.send({
    type: "musicCommands",
    musicCommands: session.pendingMusicCommands,
  });
  session.pendingMusicCommands = [];
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

function queueGumshoePickRequest(session: GameSession, timeS: number): void {
  const { state, lastInput } = session;

  if (
    lastInput == null ||
    state.assets.camera3d == null ||
    state.gumshoeModel == null
  ) {
    return;
  }

  updateGumshoeModel(state.gumshoeModel, timeS);

  const request = state.gumshoeModel.createPickRequest(
    session.nextPickRid,
    state.assets.camera3d.handle ?? 0,
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

function refreshResourceReadiness(session: GameSession): void {
  const { state } = session;

  if (state.resourcesReady || state.resourceLoadFailed) {
    return;
  }

  if (
    state.assets.raywhite === 0 ||
    state.assets.white === 0 ||
    state.assets.accentColor === 0 ||
    state.assets.panelColor === 0 ||
    state.assets.shadowColor === 0 ||
    state.assets.font === 0 ||
    state.assets.logoSprite3d == null ||
    state.assets.logoTexture == null ||
    state.assets.blobShadowTexture == null ||
    state.gumshoeModel == null ||
    state.gumshoeModel.handle == null ||
    state.assets.clickSound === 0 ||
    state.bgMusic == null ||
    state.assets.camera3d == null
  ) {
    return;
  }

  state.resourcesReady = true;
  console.log(`[Game] All resources ready`);
  queueInitialMusicCommands(state, session);
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

function beginLoadResources(session: GameSession): void {
  const { state } = session;

  if (state.resourceBootstrapStarted) {
    return;
  }

  state.resourceBootstrapStarted = true;

  void Promise.all([
    rl_color_create(245, 245, 245, 255),
    rl_color_create(255, 255, 255, 255),
    rl_color_create(221, 87, 54, 255),
    rl_color_create(24, 107, 138, 255),
    rl_color_create(0, 0, 0, 64),
  ])
    .then(([raywhite, white, accent, panel, shadow]) => {
      state.assets.raywhite = raywhite;
      state.assets.white = white;
      state.assets.accentColor = accent;
      state.assets.panelColor = panel;
      state.assets.shadowColor = shadow;
      console.log(`[Game] Colors ready`);
      refreshResourceReadiness(session);
    })
    .catch(() => markResourceLoadFailed(session, "colors"));

  void Camera3D.create(
    12.0, 12.0, 12.0,
    0.0, 1.0, 0.0,
    0.0, 1.0, 0.0,
    45.0, CAMERA_PERSPECTIVE,
  )
    .then((camera) => {
      state.assets.camera3d = camera;
      console.log(`[Game] Camera ready: ${state.assets.camera3d.handle}`);
      refreshResourceReadiness(session);
    })
    .catch(() => markResourceLoadFailed(session, "camera3d"));

  queueAssetCreateTask(session, "assets/fonts/Komika/KOMIKAH_.ttf", () => {
    void rl_font_create("assets/fonts/Komika/KOMIKAH_.ttf", 24)
      .then((handle) => {
        state.assets.font = handle;
        console.log(`[Game] Font ready: ${state.assets.font}`);
        refreshResourceReadiness(session);
      })
      .catch(() => markResourceLoadFailed(session, "assets/fonts/Komika/KOMIKAH_.ttf"));
  });

  queueAssetCreateTask(session, "assets/sprites/logo/wg-logo-bw-alpha.png", () => {
    void Promise.all([
      Texture.load("assets/sprites/logo/wg-logo-bw-alpha.png"),
      Sprite3D.load("assets/sprites/logo/wg-logo-bw-alpha.png"),
    ])
      .then(([texture, sprite]) => {
        state.assets.logoTexture = texture;
        state.assets.logoSprite3d = sprite;
        console.log(`[Game] Logo texture ready: ${state.assets.logoTexture.handle}`);
        console.log(`[Game] Sprite3D ready: ${state.assets.logoSprite3d.handle}`);
        refreshResourceReadiness(session);
      })
      .catch(() => markResourceLoadFailed(session, "assets/sprites/logo/wg-logo-bw-alpha.png"));
  });

  queueAssetCreateTask(session, "assets/textures/blobshadow.png", () => {
    void Texture.load("assets/textures/blobshadow.png")
      .then((texture) => {
        state.assets.blobShadowTexture = texture;
        console.log(`[Game] Blob shadow ready: ${state.assets.blobShadowTexture.handle}`);
        refreshResourceReadiness(session);
      })
      .catch(() => markResourceLoadFailed(session, "assets/textures/blobshadow.png"));
  });

  state.gumshoeModel = new Model("assets/models/gumshoe/gumshoe.glb");
  state.gumshoeModel.load(
    (model) => {
      console.log(`[Game] Gumshoe model ready: ${model.handle}`);
      refreshResourceReadiness(session);
    },
    (path) => markResourceLoadFailed(session, path),
  );

  queueAssetCreateTask(session, "assets/sounds/click_004.ogg", () => {
    void rl_sound_create("assets/sounds/click_004.ogg")
      .then((handle) => {
        state.assets.clickSound = handle;
        console.log(`[Game] Click sound ready: ${state.assets.clickSound}`);
        refreshResourceReadiness(session);
      })
      .catch(() => markResourceLoadFailed(session, "assets/sounds/click_004.ogg"));
  });

  queueAssetCreateTask(session, "assets/music/ethernight_club.mp3", () => {
    void rl_music_create("assets/music/ethernight_club.mp3")
      .then((handle) => {
        state.bgMusic = handle;
        console.log(`[Game] Background music ready: ${state.bgMusic}`);
        refreshResourceReadiness(session);
      })
      .catch(() => markResourceLoadFailed(session, "assets/music/ethernight_club.mp3"));
  });
}

class RemoteGameRuntime implements GameRuntime {
  private sessions = new Map<string, GameSession>();
  private timeS = 0.0;

  init(): void {
    this.timeS = 0.0;
    console.info("[GAME]: init")
  }

  destroy(): void {
    for (const session of this.sessions.values()) {
      void this.disposeSession(session);
    }
    this.sessions.clear();
  }

  private async disposeSession(session: GameSession): Promise<void> {
    if (session.state.gumshoeModel) {
      try {
        await session.state.gumshoeModel.destroy();
      } catch (error) {
        console.warn("[Game] Failed to destroy model cleanly:", error);
      }
      session.state.gumshoeModel = null;
    }

    destroy_frame_command_buffer(session.frameCommandBuffer);
  }

  async onConnect(client: GameClient): Promise<void> {
    console.log("[GAME]: client connected")
    const session: GameSession = {
      client,
      state: createInitialGameState(),
      frameCommandBuffer: create_frame_command_buffer(),
      lastInput: null,
      lastPickResult: null,
      pendingMusicCommands: [],
      pendingPickRequests: [],
      pendingPickRids: new Set<number>(),
      nextPickRid: 1,
    };

    this.sessions.set(client.id, session);
    client.send({ type: "reset", reason: "session_start" });
    beginLoadResources(session);
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
        SharedResourceManager.handleResponse(response);
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

    if (this.sessions.size === 0) {
      return;
    }

    for (const session of this.sessions.values()) {
      const pendingRequests = SharedResourceManager.getPendingRequests();
      const clientCount = this.sessions.size;
      const frame = generateFrameSnapshot(
        dt,
        this.timeS,
        session.state,
        session.frameCommandBuffer,
        clientCount,
        session.lastInput,
      );
      const frame_commands = session.frameCommandBuffer;

      if (session.lastInput) {
        if (isButtonPressed(session.lastInput.mouse.left)) {
          queueGumshoePickRequest(session, this.timeS);

          if (session.state.assets.clickSound !== 0) {
            rl_sound_play(session.state.assets.clickSound);
          }
        }

        session.pendingMusicCommands.push(
          ...getMusicCommandsForInput(session.state, session.lastInput),
        );
      }

      drawDebugOverlay(session, this.timeS, clientCount);

      if (pendingRequests.length > 0) {
        session.client.send({
          type: "resourceRequests",
          resourceRequests: pendingRequests,
        });
      }

      flushPendingPickRequests(session);
      flushPendingMusicCommands(session);

      const frameMessage: ServerFrameMessage = {
        type: "frame",
        frame,
      };
      session.client.send(frameMessage);
    }
  }
}

export function createGameRuntime(): GameRuntime {
  return new RemoteGameRuntime();
}
