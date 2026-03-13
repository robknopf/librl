// Combined protocol for frame commands and resource requests/responses

import type { FrameBuffer } from "./types";
import type { AnyResourceRequest, ResourceResponse } from "./resource_protocol";

// Message envelope that can contain both frame data and resource protocol
export interface ServerMessage {
  // Frame rendering commands (sent every frame)
  frame?: FrameBuffer;
  
  // Resource creation requests (sent when needed)
  resourceRequests?: AnyResourceRequest[];
}

export interface ClientMessage {
  // Resource creation responses (sent in response to requests)
  resourceResponses?: ResourceResponse[];
}
