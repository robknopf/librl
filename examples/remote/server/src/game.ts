import type { FrameBuffer, Command } from "./types";
import { CommandType } from "./types";
import { ResourceManager } from "./resource_manager";
import { Model } from "./model";
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
  resourcesReady: boolean;
  raywhiteHandle: number | null;
  whiteHandle: number | null;
  accentColor: number | null;
  panelColor: number | null;
  shadowColor: number | null;
  fontHandle: number | null;
  logoSprite3d: number | null;
  logoTexture: number | null;
  blobShadowTexture: number | null;
  gumshoeModel: Model | null;
  clickSound: number | null;
  bgMusic: number | null;
  musicPlaying: boolean;
  cameraHandle: number | null;
}

interface GameSession {
  client: GameClient;
  resourceManager: ResourceManager;
  state: GameState;
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
    resourcesReady: false,
    raywhiteHandle: null,
    whiteHandle: null,
    accentColor: null,
    panelColor: null,
    shadowColor: null,
    fontHandle: null,
    logoSprite3d: null,
    logoTexture: null,
    blobShadowTexture: null,
    gumshoeModel: null,
    clickSound: null,
    bgMusic: null,
    musicPlaying: false,
    cameraHandle: null,
  };
}

async function loadResources(state: GameState, rm: ResourceManager): Promise<void> {
  state.raywhiteHandle = await rm.createColor(245, 245, 245, 255);
  state.whiteHandle = await rm.createColor(255, 255, 255, 255);
  state.accentColor = await rm.createColor(221, 87, 54, 255);
  state.panelColor = await rm.createColor(24, 107, 138, 255);
  state.shadowColor = await rm.createColor(0, 0, 0, 64);
  console.log(`[Game] Colors ready`);

  state.cameraHandle = await rm.createCamera3D(
    12.0, 12.0, 12.0,
    0.0, 1.0, 0.0,
    0.0, 1.0, 0.0,
    45.0, CAMERA_PERSPECTIVE,
  );
  console.log(`[Game] Camera ready: ${state.cameraHandle}`);

  state.fontHandle = await rm.createFont("assets/fonts/Komika/KOMIKAH_.ttf", 24);
  console.log(`[Game] Font ready: ${state.fontHandle}`);

  state.logoTexture = await rm.createTexture("assets/sprites/logo/wg-logo-bw-alpha.png");
  console.log(`[Game] Logo texture ready: ${state.logoTexture}`);
  
  state.logoSprite3d = await rm.createSprite3D("assets/sprites/logo/wg-logo-bw-alpha.png");
  console.log(`[Game] Sprite3D ready: ${state.logoSprite3d}`);

  state.blobShadowTexture = await rm.createTexture("assets/textures/blobshadow.png");
  console.log(`[Game] Blob shadow ready: ${state.blobShadowTexture}`);

  state.gumshoeModel = await Model.load("assets/models/gumshoe/gumshoe.glb", rm);
  console.log(`[Game] Gumshoe model ready: ${state.gumshoeModel.handle}`);

  state.clickSound = await rm.createSound("assets/sounds/click_004.ogg");
  console.log(`[Game] Click sound ready: ${state.clickSound}`);

  state.bgMusic = await rm.createMusic("assets/music/ethernight_club.mp3");
  console.log(`[Game] Background music ready: ${state.bgMusic}`);

  state.resourcesReady = true;
  console.log(`[Game] All resources ready`);
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

function getInitialServerMessages(state: GameState): ServerMessage[] {
  const messages: ServerMessage[] = [
    { type: "reset", reason: "session_start" },
  ];

  if (!state.bgMusic) {
    return messages;
  }

  state.musicPlaying = true;
  messages.push({
    type: "musicCommands",
    musicCommands: [
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
    ],
  });

  return messages;
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

function generateFrame(
  dt: number,
  timeS: number,
  state: GameState,
  clientCount: number,
  input: ClientInputState | null,
): FrameBuffer {
  const commands: Command[] = [];

  if (!state.resourcesReady) {
    return { frameNumber: frameNumber++, deltaTime: dt, commands };
  }

  const { screenW, screenH, sx, sy, su } = getLayoutMetrics(input);
  const wobble = Math.sin(timeS * 2.0) * 24.0;
  const mouseLeftDown = input?.mouse.left === 1 || input?.mouse.left === 2;
  const spaceDown = input?.keyboard.keysDown.includes(32) ?? false;

  updateGumshoeModel(state.gumshoeModel, timeS);

  commands.push({
    type: CommandType.CLEAR,
    color: state.raywhiteHandle!,
  });

  if (state.fontHandle) {
    commands.push({
      type: CommandType.DRAW_TEXT,
      font: state.fontHandle,
      color: state.accentColor!,
      x: lx(24, sx),
      y: ly(140, sy) + wobble * sy,
      fontSize: 32 * su,
      spacing: su,
      text: "server-driven frame",
    });

    commands.push({
      type: CommandType.DRAW_TEXT,
      font: state.fontHandle,
      color: state.accentColor!,
      x: lx(24, sx),
      y: ly(170, sy),
      fontSize: 20 * su,
      spacing: su,
      text: `frame=${frameNumber} t=${timeS.toFixed(2)}`,
    });

    commands.push({
      type: CommandType.DRAW_TEXT,
      font: state.fontHandle,
      color: state.panelColor!,
      x: lx(24, sx),
      y: ly(200, sy),
      fontSize: 20 * su,
      spacing: su,
      text: `screen=(${screenW}, ${screenH}) clients=${clientCount}`,
    });

    commands.push({
      type: CommandType.DRAW_TEXT,
      font: state.fontHandle,
      color: state.panelColor!,
      x: lx(24, sx),
      y: ly(230, sy),
      fontSize: 20 * su,
      spacing: su,
      text: "Remote rendering via WebSocket",
    });
  }

  {
    const logoY = 1.0 + Math.sin(timeS * 3.0) * 0.15;
    let logoSize = mouseLeftDown ? 1.5 : 1.0;
    const groundY = 0.0;
    const baseSize = 1.35;

    if (spaceDown) {
      logoSize += 0.5;
    }

    if (state.blobShadowTexture && state.shadowColor) {
      const height = Math.max(0.0, logoY - groundY);
      const t = Math.min(Math.max(height / (baseSize * 2.5 + 0.0001), 0.0), 1.0);
      const shadowSize = Math.max(baseSize * logoSize * (1 - t) * (1 - t), 0.05);

      commands.push({
        type: CommandType.DRAW_GROUND_TEXTURE,
        texture: state.blobShadowTexture,
        tint: state.shadowColor,
        x: 0.0,
        y: groundY + 0.01,
        z: 0.0,
        width: shadowSize,
        length: shadowSize,
      });
    }

    if (state.logoSprite3d && state.whiteHandle) {
      commands.push({
        type: CommandType.DRAW_SPRITE3D,
        sprite: state.logoSprite3d,
        tint: state.whiteHandle,
        x: 0.0,
        y: logoY,
        z: 0.0,
        size: logoSize,
      });
    }
  }

  if (state.logoTexture && state.whiteHandle) {
    commands.push({
      type: CommandType.DRAW_TEXTURE,
      texture: state.logoTexture,
      tint: state.whiteHandle,
      x: lx(520.0, sx),
      y: ly(36.0, sy),
      scale: 0.35 * su,
      rotation: Math.sin(timeS * 1.5) * 8.0,
    });
  }

  if (state.gumshoeModel && state.whiteHandle) {
    state.gumshoeModel.draw(commands, state.whiteHandle);
  }

  return {
    frameNumber: frameNumber++,
    deltaTime: dt,
    commands,
  };
}

function appendDebugOverlay(
  frame: FrameBuffer,
  session: GameSession,
  timeS: number,
  clientCount: number,
): void {
  const { state, lastInput, lastPickResult } = session;

  if (!lastInput || !state.fontHandle || !state.panelColor) {
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

  frame.commands.push({
    type: CommandType.DRAW_TEXT,
    font: state.fontHandle,
    color: state.panelColor,
    x: 24 * layout.sx,
    y: 260 * layout.sy,
    fontSize: 20 * layout.su,
    spacing: layout.su,
    text:
      `mouse=(${mouse.x}, ${mouse.y}) ` +
      `buttons=(L:${buttonLabel(mouse.left)} ` +
      `R:${buttonLabel(mouse.right)} ` +
      `M:${buttonLabel(mouse.middle)}) ` +
      `wheel=${mouse.wheel}`,
  });

  frame.commands.push({
    type: CommandType.DRAW_TEXT,
    font: state.fontHandle,
    color: state.panelColor,
    x: 24 * layout.sx,
    y: 290 * layout.sy,
    fontSize: 20 * layout.su,
    spacing: layout.su,
    text:
      `kbd space=${spaceDown ? "down" : "up"} ` +
      `arrows=(${leftDown ? "L" : "-"} ${rightDown ? "R" : "-"} ` +
      `${upDown ? "U" : "-"} ${downDown ? "D" : "-"})`,
  });

  frame.commands.push({
    type: CommandType.DRAW_TEXT,
    font: state.fontHandle,
    color: state.panelColor,
    x: 24 * layout.sx,
    y: 320 * layout.sy,
    fontSize: 20 * layout.su,
    spacing: layout.su,
    text:
      `pressed counts=(${keyboard.pressedKeys.length}/${keyboard.pressedChars.length}) ` +
      `chars="${String.fromCharCode(...keyboard.pressedChars.filter((ch) => ch >= 32 && ch <= 255)).slice(0, 24)}"`,
  });

  if (
    mouseLeftPressed || mouseRightPressed || mouseMiddlePressed ||
    mouseLeftReleased || mouseRightReleased || mouseMiddleReleased
  ) {
    frame.commands.push({
      type: CommandType.DRAW_TEXT,
      font: state.fontHandle,
      color: state.panelColor,
      x: 24 * layout.sx,
      y: 350 * layout.sy,
      fontSize: 20 * layout.su,
      spacing: layout.su,
      text:
        `edges=(L:${mouseLeftPressed ? "press" : mouseLeftReleased ? "release" : "-"} ` +
        `R:${mouseRightPressed ? "press" : mouseRightReleased ? "release" : "-"} ` +
        `M:${mouseMiddlePressed ? "press" : mouseMiddleReleased ? "release" : "-"})`,
    });
  }

  if (lastPickResult) {
    frame.commands.push({
      type: CommandType.DRAW_TEXT,
      font: state.fontHandle,
      color: state.accentColor ?? state.panelColor,
      x: 24 * layout.sx,
      y: 380 * layout.sy,
      fontSize: 20 * layout.su,
      spacing: layout.su,
      text: lastPickResult.hit
        ? `pick: hit d=${lastPickResult.distance.toFixed(2)} @ (` +
          `${lastPickResult.point.x.toFixed(2)}, ` +
          `${lastPickResult.point.y.toFixed(2)}, ` +
          `${lastPickResult.point.z.toFixed(2)})`
        : "pick: miss",
    });
  }

  frame.commands.push({
    type: CommandType.DRAW_TEXT,
    font: state.fontHandle,
    color: state.accentColor ?? state.panelColor,
    x: 24 * layout.sx,
    y: 410 * layout.sy,
    fontSize: 20 * layout.su,
    spacing: layout.su,
    text: `music(M): ${state.musicPlaying ? "playing" : "paused"} clients=${clientCount} t=${timeS.toFixed(2)}`,
  });
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
    state.cameraHandle == null ||
    state.gumshoeModel == null
  ) {
    return;
  }

  updateGumshoeModel(state.gumshoeModel, timeS);

  const request = state.gumshoeModel.createPickRequest(
    session.nextPickRid,
    state.cameraHandle,
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
        await session.state.gumshoeModel.destroy(session.resourceManager);
      } catch (error) {
        console.warn("[Game] Failed to destroy model cleanly:", error);
      }
      session.state.gumshoeModel = null;
    }

    session.resourceManager.clear();
  }

  async onConnect(client: GameClient): Promise<void> {
    console.log("[GAME]: client connected")
    const session: GameSession = {
      client,
      resourceManager: new ResourceManager(),
      state: createInitialGameState(),
      lastInput: null,
      lastPickResult: null,
      pendingMusicCommands: [],
      pendingPickRequests: [],
      pendingPickRids: new Set<number>(),
      nextPickRid: 1,
    };

    this.sessions.set(client.id, session);
    client.send({ type: "reset", reason: "session_start" });

    try {
      await loadResources(session.state, session.resourceManager);
      if (!this.sessions.has(client.id)) {
        return;
      }

      for (const message of getInitialServerMessages(session.state)) {
        if (message.type === "musicCommands") {
          session.pendingMusicCommands.push(...message.musicCommands);
        } else if (message.type !== "reset") {
          client.send(message);
        }
      }
    } catch (error) {
      console.error(`[Game] Failed to load resources for ${client.id}:`, error);
      client.disconnect();
    }
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

    if (this.sessions.size === 0) {
      return;
    }

    for (const session of this.sessions.values()) {
      const pendingRequests = session.resourceManager.getPendingRequests();
      const clientCount = this.sessions.size;
      const frame = generateFrame(
        dt,
        this.timeS,
        session.state,
        clientCount,
        session.lastInput,
      );

      if (session.lastInput) {
        if (isButtonPressed(session.lastInput.mouse.left)) {
          queueGumshoePickRequest(session, this.timeS);

          if (session.state.clickSound) {
            frame.commands.push({
              type: CommandType.PLAY_SOUND,
              sound: session.state.clickSound,
            });
          }
        }

        session.pendingMusicCommands.push(
          ...getMusicCommandsForInput(session.state, session.lastInput),
        );
      }

      appendDebugOverlay(frame, session, this.timeS, clientCount);

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
