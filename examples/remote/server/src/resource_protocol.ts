// Resource creation request/response protocol
// Server sends requests with RID, client responds with handle

export enum ResourceRequestType {
  CREATE_COLOR = 0,
  CREATE_FONT = 1,
  CREATE_TEXTURE = 2,
  CREATE_MODEL = 3,
  CREATE_SOUND = 4,
  CREATE_MUSIC = 5,
  CREATE_CAMERA3D = 6,
  CREATE_SPRITE3D = 7,
  DESTROY_RESOURCE = 99,
}

// Base request interface
export interface ResourceRequest {
  rid: number; // Request ID for matching response
  type: ResourceRequestType;
}

// Specific request types
export interface CreateColorRequest extends ResourceRequest {
  type: ResourceRequestType.CREATE_COLOR;
  r: number;
  g: number;
  b: number;
  a: number;
}

export interface CreateFontRequest extends ResourceRequest {
  type: ResourceRequestType.CREATE_FONT;
  filename: string;
  fontSize: number;
}

export interface CreateTextureRequest extends ResourceRequest {
  type: ResourceRequestType.CREATE_TEXTURE;
  filename: string;
}

export interface CreateModelRequest extends ResourceRequest {
  type: ResourceRequestType.CREATE_MODEL;
  filename: string;
}

export interface CreateSoundRequest extends ResourceRequest {
  type: ResourceRequestType.CREATE_SOUND;
  filename: string;
}

export interface CreateMusicRequest extends ResourceRequest {
  type: ResourceRequestType.CREATE_MUSIC;
  filename: string;
}

export interface CreateCamera3DRequest extends ResourceRequest {
  type: ResourceRequestType.CREATE_CAMERA3D;
  posX: number;
  posY: number;
  posZ: number;
  targetX: number;
  targetY: number;
  targetZ: number;
  upX: number;
  upY: number;
  upZ: number;
  fovy: number;
  projection: number;
}

export interface CreateSprite3DRequest extends ResourceRequest {
  type: ResourceRequestType.CREATE_SPRITE3D;
  filename: string;
}

export interface DestroyResourceRequest extends ResourceRequest {
  type: ResourceRequestType.DESTROY_RESOURCE;
  handle: number;
}

export type AnyResourceRequest =
  | CreateColorRequest
  | CreateFontRequest
  | CreateTextureRequest
  | CreateModelRequest
  | CreateSoundRequest
  | CreateMusicRequest
  | CreateCamera3DRequest
  | CreateSprite3DRequest
  | DestroyResourceRequest;

export type AnyResourceRequestInput =
  | Omit<CreateColorRequest, "rid">
  | Omit<CreateFontRequest, "rid">
  | Omit<CreateTextureRequest, "rid">
  | Omit<CreateModelRequest, "rid">
  | Omit<CreateSoundRequest, "rid">
  | Omit<CreateMusicRequest, "rid">
  | Omit<CreateCamera3DRequest, "rid">
  | Omit<CreateSprite3DRequest, "rid">
  | Omit<DestroyResourceRequest, "rid">;

// Response from client
export interface ResourceResponse {
  rid: number; // Matches request RID
  handle: number; // Created handle (0 if failed)
  success: boolean;
  error?: string;
}

// Message envelope for resource protocol
export interface ResourceMessage {
  requests?: AnyResourceRequest[];
  responses?: ResourceResponse[];
}
