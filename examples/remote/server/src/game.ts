import type { FrameBuffer, Command } from "./types";
import { CommandType } from "./types";
import type { ResourceManager } from "./resource_manager";

// Layout constants (matching lua_demo)
const IDEAL_W = 1024;
const IDEAL_H = 1280;
const CAMERA_PERSPECTIVE = 0;

export interface GameState {
  resourcesReady: boolean;
  // Colors
  raywhiteHandle: number | null;
  whiteHandle: number | null;
  accentColor: number | null;
  panelColor: number | null;
  shadowColor: number | null;
  // Assets
  fontHandle: number | null;
  logoSprite3d: number | null;
  logoTexture: number | null;
  blobShadowTexture: number | null;
  gumshoeModel: number | null;
  cameraHandle: number | null;
  // Animation state
  timeS: number;
}

let frameNumber = 0;

export function createInitialGameState(): GameState {
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
    cameraHandle: null,
    timeS: 0,
  };
}

export async function loadResources(state: GameState, rm: ResourceManager): Promise<void> {
  // Colors (sync on client side)
  state.raywhiteHandle = await rm.createColor(245, 245, 245, 255);
  state.whiteHandle = await rm.createColor(255, 255, 255, 255);
  state.accentColor = await rm.createColor(221, 87, 54, 255);
  state.panelColor = await rm.createColor(24, 107, 138, 255);
  state.shadowColor = await rm.createColor(0, 0, 0, 64);
  console.log(`[Game] Colors ready`);

  // Camera
  state.cameraHandle = await rm.createCamera3D(
    12.0, 12.0, 12.0,   // position
    0.0, 1.0, 0.0,      // target
    0.0, 1.0, 0.0,      // up
    45.0, CAMERA_PERSPECTIVE
  );
  console.log(`[Game] Camera ready: ${state.cameraHandle}`);

  // Font (async on client side - needs file fetch)
  state.fontHandle = await rm.createFont("assets/fonts/Komika/KOMIKAH_.ttf", 24);
  console.log(`[Game] Font ready: ${state.fontHandle}`);

  // Textures & models (async - need file fetch)
  state.logoSprite3d = await rm.createSprite3D("assets/sprites/logo/wg-logo-bw-alpha.png");
  console.log(`[Game] Sprite3D ready: ${state.logoSprite3d}`);

  state.logoTexture = await rm.createTexture("assets/sprites/logo/wg-logo-bw-alpha.png");
  console.log(`[Game] Logo texture ready: ${state.logoTexture}`);

  state.blobShadowTexture = await rm.createTexture("assets/textures/blobshadow.png");
  console.log(`[Game] Blob shadow ready: ${state.blobShadowTexture}`);

  state.gumshoeModel = await rm.createModel("assets/models/gumshoe/gumshoe.glb");
  console.log(`[Game] Gumshoe model ready: ${state.gumshoeModel}`);

  state.resourcesReady = true;
  console.log(`[Game] All resources ready`);
}

function lx(x: number, sx: number): number { return x * sx; }
function ly(y: number, sy: number): number { return y * sy; }

export function generateFrame(dt: number, state: GameState, clientCount: number): FrameBuffer {
  const commands: Command[] = [];

  // Update time
  state.timeS += dt;

  if (!state.resourcesReady) {
    return { frameNumber: frameNumber++, deltaTime: dt, commands };
  }

  const screenW = IDEAL_W;
  const screenH = IDEAL_H;
  const sx = screenW / IDEAL_W;
  const sy = screenH / IDEAL_H;
  const su = Math.min(sx, sy);

  const wobble = Math.sin(state.timeS * 2.0) * 24.0;
  const gumshoeOrbit = state.timeS * 0.9;
  const gumshoeRadius = 3.5;
  const gumshoeVx = -Math.sin(gumshoeOrbit);
  const gumshoeVz = Math.cos(gumshoeOrbit);

  // Clear background
  commands.push({
    type: CommandType.CLEAR,
    color: state.raywhiteHandle!,
  });

  // -- 2D Text overlay --
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
      text: `frame=${frameNumber} t=${state.timeS.toFixed(2)}`,
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

  // -- 3D: Sprite3D logo with bobbing + blob shadow --
  {
    const logoY = 1.0 + Math.sin(state.timeS * 3.0) * 0.15;
    const logoSize = 1.0;
    const groundY = 0.0;
    const baseSize = 1.35;

    // Shadow scales with distance from ground (matching shadow.lua)
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

  // -- 2D: Logo texture in corner with rotation --
  if (state.logoTexture && state.whiteHandle) {
    commands.push({
      type: CommandType.DRAW_TEXTURE,
      texture: state.logoTexture,
      tint: state.whiteHandle,
      x: lx(520.0, sx),
      y: ly(36.0, sy),
      scale: 0.35 * su,
      rotation: Math.sin(state.timeS * 1.5) * 8.0,
    });
  }

  // -- 3D: Gumshoe model orbiting --
  if (state.gumshoeModel && state.whiteHandle) {
    const gumshoeX = Math.cos(gumshoeOrbit) * gumshoeRadius;
    const gumshoeZ = Math.sin(gumshoeOrbit) * gumshoeRadius;
    const gumshoeRotY = Math.atan2(gumshoeVx, gumshoeVz) * (180 / Math.PI);
    const animFrame = Math.floor(state.timeS * 60.0);

    commands.push({
      type: CommandType.DRAW_MODEL,
      model: state.gumshoeModel,
      tint: state.whiteHandle,
      x: gumshoeX,
      y: 0.0,
      z: gumshoeZ,
      scale: 1.0,
      rotationX: 0.0,
      rotationY: gumshoeRotY,
      rotationZ: 0.0,
      animationIndex: 1,
      animationFrame: animFrame,
    });
  }

  return {
    frameNumber: frameNumber++,
    deltaTime: dt,
    commands,
  };
}
