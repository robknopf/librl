// Mirror of rl_module.h command types
export enum CommandType {
  CLEAR = 0,
  DRAW_TEXT = 1,
  DRAW_SPRITE3D = 2,
  PLAY_SOUND = 3,
  DRAW_MODEL = 4,
  DRAW_TEXTURE = 5,
  DRAW_CUBE = 6,
  DRAW_GROUND_TEXTURE = 7,
}

export type Handle = number;

export interface ClearCommand {
  type: CommandType.CLEAR;
  color: Handle;
}

export interface DrawTextCommand {
  type: CommandType.DRAW_TEXT;
  font: Handle;
  color: Handle;
  x: number;
  y: number;
  fontSize: number;
  spacing: number;
  text: string; // max 256 chars
}

export interface DrawSprite3DCommand {
  type: CommandType.DRAW_SPRITE3D;
  sprite: Handle;
  tint: Handle;
  x: number;
  y: number;
  z: number;
  size: number;
}

export interface PlaySoundCommand {
  type: CommandType.PLAY_SOUND;
  sound: Handle;
}

export interface DrawModelCommand {
  type: CommandType.DRAW_MODEL;
  model: Handle;
  tint: Handle;
  x: number;
  y: number;
  z: number;
  scale: number;
  rotationX: number;
  rotationY: number;
  rotationZ: number;
  animationIndex: number;
  animationFrame: number;
}

export interface DrawTextureCommand {
  type: CommandType.DRAW_TEXTURE;
  texture: Handle;
  tint: Handle;
  x: number;
  y: number;
  scale: number;
  rotation: number;
}

export interface DrawCubeCommand {
  type: CommandType.DRAW_CUBE;
  color: Handle;
  x: number;
  y: number;
  z: number;
  width: number;
  height: number;
  length: number;
}

export interface DrawGroundTextureCommand {
  type: CommandType.DRAW_GROUND_TEXTURE;
  texture: Handle;
  tint: Handle;
  x: number;
  y: number;
  z: number;
  width: number;
  length: number;
}

export type Command =
  | ClearCommand
  | DrawTextCommand
  | DrawSprite3DCommand
  | PlaySoundCommand
  | DrawModelCommand
  | DrawTextureCommand
  | DrawCubeCommand
  | DrawGroundTextureCommand;

export interface FrameBuffer {
  frameNumber: number;
  deltaTime: number;
  commands: Command[];
}
