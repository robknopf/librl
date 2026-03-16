import type { Command } from "./types";
import type { AnyResourceRequest, ResourceResponse } from "./resource_protocol";

export interface ServerFrameBeginMessage {
  type: "frameBegin";
  frameNumber: number;
  deltaTime: number;
}

export interface ServerFrameChunkMessage {
  type: "frameChunk";
  commands: Command[];
}

export interface ServerFrameEndMessage {
  type: "frameEnd";
}

export interface ServerResourceRequestsMessage {
  type: "resourceRequests";
  resourceRequests: AnyResourceRequest[];
}

export enum PickRequestType {
  MODEL = 0,
  SPRITE3D = 1,
}

export interface ModelPickRequest {
  rid: number;
  type: PickRequestType.MODEL;
  camera: number;
  handle: number;
  mouseX: number;
  mouseY: number;
  x: number;
  y: number;
  z: number;
  scale: number;
  rotationX: number;
  rotationY: number;
  rotationZ: number;
}

export interface Sprite3DPickRequest {
  rid: number;
  type: PickRequestType.SPRITE3D;
  camera: number;
  handle: number;
  mouseX: number;
  mouseY: number;
  x: number;
  y: number;
  z: number;
  size: number;
}

export type PickRequest = ModelPickRequest | Sprite3DPickRequest;

export interface ServerPickRequestsMessage {
  type: "pickRequests";
  pickRequests: PickRequest[];
}

export interface ServerResetMessage {
  type: "reset";
  reason?: string;
}

export type ServerMessage =
  | ServerFrameBeginMessage
  | ServerFrameChunkMessage
  | ServerFrameEndMessage
  | ServerResourceRequestsMessage
  | ServerPickRequestsMessage
  | ServerResetMessage;

export interface ClientResourceResponsesMessage {
  type: "resourceResponses";
  resourceResponses: ResourceResponse[];
}

export interface ClientMouseState {
  x: number;
  y: number;
  wheel: number;
  left: number;
  right: number;
  middle: number;
}

export interface ClientKeyboardState {
  keysDown: number[];
  pressedKeys: number[];
  pressedChars: number[];
}

export interface ClientInputState {
  screenWidth: number;
  screenHeight: number;
  mouse: ClientMouseState;
  keyboard: ClientKeyboardState;
}

export interface ClientInputStateMessage {
  type: "inputState";
  inputState: ClientInputState;
}

export interface PickResponse {
  rid: number;
  hit: boolean;
  distance: number;
  point: {
    x: number;
    y: number;
    z: number;
  };
  normal: {
    x: number;
    y: number;
    z: number;
  };
}

export interface ClientPickResponsesMessage {
  type: "pickResponses";
  pickResponses: PickResponse[];
}

export type ClientMessage =
  | ClientResourceResponsesMessage
  | ClientPickResponsesMessage
  | ClientInputStateMessage;
