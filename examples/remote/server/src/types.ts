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
  SET_CAMERA3D = 8,
  SET_MODEL_TRANSFORM = 9,
  SET_SPRITE3D_TRANSFORM = 10,
  PLAY_MUSIC = 11,
  PAUSE_MUSIC = 12,
  STOP_MUSIC = 13,
  SET_MUSIC_LOOP = 14,
  SET_MUSIC_VOLUME = 15,
  SET_ACTIVE_CAMERA3D = 16,
  SET_SPRITE2D_TRANSFORM = 17,
  DRAW_SPRITE2D = 18,
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
}

export interface PlaySoundCommand {
  type: CommandType.PLAY_SOUND;
  sound: Handle;
  volume: number;
  pitch: number;
  pan: number;
}

export interface PlayMusicCommand {
  type: CommandType.PLAY_MUSIC;
  music: Handle;
}

export interface PauseMusicCommand {
  type: CommandType.PAUSE_MUSIC;
  music: Handle;
}

export interface StopMusicCommand {
  type: CommandType.STOP_MUSIC;
  music: Handle;
}

export interface SetMusicLoopCommand {
  type: CommandType.SET_MUSIC_LOOP;
  music: Handle;
  loop: boolean;
}

export interface SetMusicVolumeCommand {
  type: CommandType.SET_MUSIC_VOLUME;
  music: Handle;
  volume: number;
}

export interface DrawModelCommand {
  type: CommandType.DRAW_MODEL;
  model: Handle;
  tint: Handle;
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

export interface SetCamera3DCommand {
  type: CommandType.SET_CAMERA3D;
  camera: Handle;
  positionX: number;
  positionY: number;
  positionZ: number;
  targetX: number;
  targetY: number;
  targetZ: number;
  upX: number;
  upY: number;
  upZ: number;
  fovy: number;
  projection: number;
}

export interface SetModelTransformCommand {
  type: CommandType.SET_MODEL_TRANSFORM;
  model: Handle;
  positionX: number;
  positionY: number;
  positionZ: number;
  rotationX: number;
  rotationY: number;
  rotationZ: number;
  scaleX: number;
  scaleY: number;
  scaleZ: number;
}

export interface SetSprite3DTransformCommand {
  type: CommandType.SET_SPRITE3D_TRANSFORM;
  sprite: Handle;
  positionX: number;
  positionY: number;
  positionZ: number;
  size: number;
}

export interface SetActiveCamera3DCommand {
  type: CommandType.SET_ACTIVE_CAMERA3D;
  camera: Handle;
}

export interface SetSprite2DTransformCommand {
  type: CommandType.SET_SPRITE2D_TRANSFORM;
  sprite: Handle;
  x: number;
  y: number;
  scale: number;
  rotation: number;
}

export interface DrawSprite2DCommand {
  type: CommandType.DRAW_SPRITE2D;
  sprite: Handle;
  tint: Handle;
}

export type Command =
  | ClearCommand
  | DrawTextCommand
  | DrawSprite3DCommand
  | PlaySoundCommand
  | PlayMusicCommand
  | PauseMusicCommand
  | StopMusicCommand
  | SetMusicLoopCommand
  | SetMusicVolumeCommand
  | DrawModelCommand
  | DrawTextureCommand
  | DrawCubeCommand
  | DrawGroundTextureCommand
  | SetCamera3DCommand
  | SetModelTransformCommand
  | SetSprite3DTransformCommand
  | SetActiveCamera3DCommand
  | SetSprite2DTransformCommand
  | DrawSprite2DCommand;

export interface FrameSnapshot {
  frameNumber: number;
  deltaTime: number;
  commands: Command[];
}
