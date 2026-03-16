import type {
  AnyResourceRequest,
  AnyResourceRequestInput,
  ResourceResponse,
} from "./resource_protocol";
import { ResourceRequestType } from "./resource_protocol";

interface PendingRequest {
  rid: number;
  request: AnyResourceRequest;
  worldHandle: number | null;
  resolve: (value: number | void) => void;
  reject: (error: string) => void;
  timeout: Timer;
}

let nextWorldHandle = 1;

export function allocateWorldHandle(): number {
  return nextWorldHandle++;
}

export class ResourceManager {
  private nextRid = 1;
  private readonly REQUEST_TIMEOUT_MS = 5000;
  private pendingRequests = new Map<number, PendingRequest>();
  private sentRequests = new Set<number>();

  protected createPendingRequest(
    request: AnyResourceRequest,
    worldHandle: number | null,
  ): Promise<number | void> {
    const rid = request.rid;

    return new Promise((resolve, reject) => {
      const timeout = setTimeout(() => {
        this.pendingRequests.delete(rid);
        this.sentRequests.delete(rid);
        reject(`Resource request ${rid} timed out`);
      }, this.REQUEST_TIMEOUT_MS);

      this.pendingRequests.set(rid, {
        rid,
        request,
        worldHandle,
        resolve,
        reject,
        timeout,
      });
    });
  }

  requestResourceWithHandle(
    handle: number,
    request: AnyResourceRequestInput,
  ): Promise<number> {
    const rid = this.nextRid++;
    const fullRequest = { ...request, rid, handle } as AnyResourceRequest;

    return this.createPendingRequest(fullRequest, handle) as Promise<number>;
  }

  async createResource(request: AnyResourceRequestInput): Promise<number> {
    return this.requestResourceWithHandle(allocateWorldHandle(), request);
  }

  async destroyResource(handle: number): Promise<void> {
    const rid = this.nextRid++;
    const fullRequest = {
      type: ResourceRequestType.DESTROY_RESOURCE,
      handle,
      rid,
    } as AnyResourceRequest;

    await this.createPendingRequest(fullRequest, null);
  }

  handleResponse(response: ResourceResponse): void {
    const pending = this.pendingRequests.get(response.rid);

    if (!pending) {
      return;
    }

    clearTimeout(pending.timeout);
    this.pendingRequests.delete(response.rid);
    this.sentRequests.delete(response.rid);

    if (response.success) {
      if (pending.worldHandle != null) {
        pending.resolve(pending.worldHandle);
      } else {
        pending.resolve();
      }
    } else {
      pending.reject("Resource creation failed");
    }
  }

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

  clear(): void {
    for (const pending of this.pendingRequests.values()) {
      clearTimeout(pending.timeout);
      pending.reject("Connection closed");
    }

    this.pendingRequests.clear();
    this.sentRequests.clear();
  }
}

export class SessionResourceManager extends ResourceManager {}
