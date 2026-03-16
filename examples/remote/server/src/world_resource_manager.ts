import type { AnyResourceRequestInput } from "./resource_protocol";
import { ResourceRequestType } from "./resource_protocol";
import {
  allocateWorldHandle,
  ResourceManager,
} from "./resource_manager";

export interface WorldResourceDefinition {
  handle: number;
  request: AnyResourceRequestInput;
}

function resourceKey(request: AnyResourceRequestInput): string {
  switch (request.type) {
    case ResourceRequestType.CREATE_COLOR:
      return `color:${request.r}:${request.g}:${request.b}:${request.a}`;
    case ResourceRequestType.CREATE_FONT:
      return `font:${request.filename}:${request.fontSize}`;
    case ResourceRequestType.CREATE_TEXTURE:
      return `texture:${request.filename}`;
    case ResourceRequestType.CREATE_MODEL:
      return `model:${request.filename}`;
    case ResourceRequestType.CREATE_SOUND:
      return `sound:${request.filename}`;
    case ResourceRequestType.CREATE_MUSIC:
      return `music:${request.filename}`;
    case ResourceRequestType.CREATE_CAMERA3D:
      return [
        "camera3d",
        request.posX, request.posY, request.posZ,
        request.targetX, request.targetY, request.targetZ,
        request.upX, request.upY, request.upZ,
        request.fovy, request.projection,
      ].join(":");
    case ResourceRequestType.CREATE_SPRITE3D:
      return `sprite3d:${request.filename}`;
    case ResourceRequestType.DESTROY_RESOURCE:
      return `destroy:${request.handle}`;
    default:
      return JSON.stringify(request);
  }
}

export class WorldResourceManager extends ResourceManager {
  private readonly handleByKey = new Map<string, number>();
  private readonly definitionsByHandle = new Map<number, AnyResourceRequestInput>();

  override async createResource(request: AnyResourceRequestInput): Promise<number> {
    const key = resourceKey(request);
    const existingHandle = this.handleByKey.get(key);
    if (existingHandle != null) {
      return existingHandle;
    }

    const handle = allocateWorldHandle();
    this.handleByKey.set(key, handle);
    this.definitionsByHandle.set(handle, request);
    return handle;
  }

  override async destroyResource(handle: number): Promise<void> {
    const definition = this.definitionsByHandle.get(handle);
    if (definition == null) {
      return;
    }

    this.definitionsByHandle.delete(handle);
    this.handleByKey.delete(resourceKey(definition));
  }

  getResourceDefinitions(): WorldResourceDefinition[] {
    const definitions: WorldResourceDefinition[] = [];

    for (const [handle, request] of this.definitionsByHandle) {
      definitions.push({ handle, request });
    }

    return definitions;
  }
}

export const WorldResources = new WorldResourceManager();
