// Server-side resource manager
// Tracks pending resource requests and matches responses from client

import type {
  AnyResourceRequest,
  AnyResourceRequestInput,
  ResourceResponse,
} from "./resource_protocol";
import { ResourceRequestType } from "./resource_protocol";

interface PendingRequest {
  rid: number;
  request: AnyResourceRequest;
  resolve: (handle: number) => void;
  reject: (error: string) => void;
  timeout: Timer;
}

export class ResourceManager {
  private nextRid = 1;
  private pendingRequests = new Map<number, PendingRequest>();
  private readonly REQUEST_TIMEOUT_MS = 5000;

  // Create a resource and return a promise that resolves with the handle
  async createResource(request: AnyResourceRequestInput): Promise<number> {
    const rid = this.nextRid++;
    const fullRequest = { ...request, rid } as AnyResourceRequest;

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(rid);
        reject(`Resource request ${rid} timed out`);
      }, this.REQUEST_TIMEOUT_MS);

      this.pendingRequests.set(rid, {
        rid,
        request: fullRequest,
        resolve,
        reject,
        timeout,
      });
    });
  }

  // Handle response from client
  handleResponse(response: ResourceResponse): void {
    const pending = this.pendingRequests.get(response.rid);
    
    if (!pending) {
      // This can happen if we receive duplicate responses or responses after timeout
      // Just log at debug level and ignore
      return;
    }
    
    clearTimeout(pending.timeout);
    this.pendingRequests.delete(response.rid);
    this.sentRequests.delete(response.rid);
    
    if (response.success) {
      pending.resolve(response.handle);
    } else {
      pending.reject("Resource creation failed");
    }
  }

  // Get all pending requests to send to client (and mark as sent)
  private sentRequests = new Set<number>();
  
  getPendingRequests(): AnyResourceRequest[] {
    const requests: AnyResourceRequest[] = [];
    for (const [rid, pending] of this.pendingRequests) {
      if (!this.sentRequests.has(rid)) {
        requests.push(pending.request);
        this.sentRequests.add(rid);
      }
    }
    return requests;
  }

  // Clear all pending requests (e.g., on disconnect)
  clear(): void {
    for (const pending of this.pendingRequests.values()) {
      clearTimeout(pending.timeout);
      pending.reject("Connection closed");
    }
    this.pendingRequests.clear();
    this.sentRequests.clear();
  }

  // Helper methods for common resource types
  async createColor(r: number, g: number, b: number, a: number): Promise<number> {
    return this.createResource({
      type: ResourceRequestType.CREATE_COLOR,
      r,
      g,
      b,
      a,
    });
  }

  async createFont(filename: string, fontSize: number): Promise<number> {
    return this.createResource({
      type: ResourceRequestType.CREATE_FONT,
      filename,
      fontSize,
    });
  }

  async createTexture(filename: string): Promise<number> {
    return this.createResource({
      type: ResourceRequestType.CREATE_TEXTURE,
      filename,
    });
  }

  async createModel(filename: string): Promise<number> {
    return this.createResource({
      type: ResourceRequestType.CREATE_MODEL,
      filename,
    });
  }

  async createSound(filename: string): Promise<number> {
    return this.createResource({
      type: ResourceRequestType.CREATE_SOUND,
      filename,
    });
  }

  async createMusic(filename: string): Promise<number> {
    return this.createResource({
      type: ResourceRequestType.CREATE_MUSIC,
      filename,
    });
  }

  async createCamera3D(
    posX: number, posY: number, posZ: number,
    targetX: number, targetY: number, targetZ: number,
    upX: number, upY: number, upZ: number,
    fovy: number, projection: number
  ): Promise<number> {
    return this.createResource({
      type: ResourceRequestType.CREATE_CAMERA3D,
      posX, posY, posZ,
      targetX, targetY, targetZ,
      upX, upY, upZ,
      fovy, projection,
    });
  }

  async createSprite3D(filename: string): Promise<number> {
    return this.createResource({
      type: ResourceRequestType.CREATE_SPRITE3D,
      filename,
    });
  }

  async destroyResource(handle: number): Promise<void> {
    await this.createResource({
      type: ResourceRequestType.DESTROY_RESOURCE,
      handle,
    });
  }
}

export const SharedResourceManager = new ResourceManager();
