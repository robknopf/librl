import type { FrameBuffer } from "./types";
import type { AnyResourceRequest, ResourceResponse } from "./resource_protocol";

export interface ServerFrameMessage {
  type: "frame";
  frame: FrameBuffer;
}

export interface ServerResourceRequestsMessage {
  type: "resourceRequests";
  resourceRequests: AnyResourceRequest[];
}

export type ServerMessage =
  | ServerFrameMessage
  | ServerResourceRequestsMessage;

export interface ClientResourceResponsesMessage {
  type: "resourceResponses";
  resourceResponses: ResourceResponse[];
}

export type ClientMessage = ClientResourceResponsesMessage;
