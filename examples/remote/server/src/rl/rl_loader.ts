export type rl_loader_callback_fn = (path: string, userData?: unknown) => void;

export enum rl_loader_queue_task_result_t {
  RL_LOADER_QUEUE_TASK_OK = 0,
  RL_LOADER_QUEUE_TASK_ERR_INVALID = -1,
  RL_LOADER_QUEUE_TASK_ERR_QUEUE_FULL = -2,
}

type task_state_t = "pending" | "done" | "failed" | "freed";

export class rl_loader_task_t {
  private state: task_state_t = "pending";
  private status = 0;

  constructor(readonly paths: string[]) {}

  is_done(): boolean {
    return this.state === "done";
  }

  is_freed(): boolean {
    return this.state === "freed";
  }

  complete(result = 0): void {
    if (this.state !== "pending") {
      return;
    }

    this.status = result;
    this.state = "done";
  }

  fail(error: unknown): void {
    if (this.state !== "pending") {
      return;
    }

    this.status = typeof error === "number" ? error : -1;
    this.state = "failed";
  }

  free(): void {
    this.state = "freed";
  }

  get_status(): number {
    return this.status;
  }
}

interface rl_loader_managed_task_t {
  task: rl_loader_task_t;
  path: string;
  on_success?: rl_loader_callback_fn | null;
  on_failure?: rl_loader_callback_fn | null;
  user_data?: unknown;
  in_use: boolean;
}

let rl_loader_asset_host = "";
const rl_loader_managed_tasks: rl_loader_managed_task_t[] = Array.from({ length: 16 }, () => ({
  task: new rl_loader_task_t([]),
  path: "",
  on_success: null,
  on_failure: null,
  user_data: undefined,
  in_use: false,
}));

export function rl_loader_set_asset_host(assetHost: string): number {
  rl_loader_asset_host = assetHost;
  return 0;
}

export function rl_loader_get_asset_host(): string {
  return rl_loader_asset_host;
}

export function rl_loader_restore_fs_async(): rl_loader_task_t {
  const task = new rl_loader_task_t(["cache"]);

  queueMicrotask(() => task.complete(0));
  return task;
}

export function rl_loader_import_asset_async(filename: string): rl_loader_task_t {
  const task = new rl_loader_task_t([filename]);

  queueMicrotask(() => task.complete(0));
  return task;
}

export function rl_loader_import_assets_async(filenames: string[]): rl_loader_task_t {
  const task = new rl_loader_task_t(filenames.slice());

  queueMicrotask(() => task.complete(0));
  return task;
}

export function rl_loader_import_assets_from_scratch_async(filenameCount: number): rl_loader_task_t {
  const paths = Array.from({ length: filenameCount }, (_, index) => `scratch:${index}`);
  const task = new rl_loader_task_t(paths);

  queueMicrotask(() => task.complete(0));
  return task;
}

export function rl_loader_poll_task(task: rl_loader_task_t | null | undefined): boolean {
  if (task == null || task.is_freed()) {
    return false;
  }

  return task.is_done();
}

export function rl_loader_finish_task(task: rl_loader_task_t | null | undefined): number {
  if (task == null || task.is_freed()) {
    return -1;
  }

  if (!task.is_done()) {
    return -1;
  }

  return task.get_status();
}

export function rl_loader_free_task(task: rl_loader_task_t | null | undefined): void {
  if (task == null) {
    return;
  }

  task.free();
}

export function rl_loader_is_local(_filename: string): boolean {
  return false;
}

export function rl_loader_uncache_file(_filename: string): number {
  return 0;
}

export function rl_loader_clear_cache(): number {
  return 0;
}

export function rl_loader_queue_task(
  task: rl_loader_task_t | null | undefined,
  path: string,
  on_success?: rl_loader_callback_fn | null,
  on_failure?: rl_loader_callback_fn | null,
  user_data?: unknown,
): rl_loader_queue_task_result_t {
  if (task == null) {
    on_failure?.(path, user_data);
    return rl_loader_queue_task_result_t.RL_LOADER_QUEUE_TASK_ERR_INVALID;
  }

  const slot = rl_loader_managed_tasks.find((candidate) => !candidate.in_use);
  if (slot == null) {
    on_failure?.(path, user_data);
    rl_loader_free_task(task);
    return rl_loader_queue_task_result_t.RL_LOADER_QUEUE_TASK_ERR_QUEUE_FULL;
  }

  slot.task = task;
  slot.path = path;
  slot.on_success = on_success;
  slot.on_failure = on_failure;
  slot.user_data = user_data;
  slot.in_use = true;
  return rl_loader_queue_task_result_t.RL_LOADER_QUEUE_TASK_OK;
}

export function rl_loader_tick(): void {
  for (const slot of rl_loader_managed_tasks) {
    if (!slot.in_use) {
      continue;
    }

    if (slot.task.is_freed()) {
      slot.in_use = false;
      continue;
    }

    if (!rl_loader_poll_task(slot.task)) {
      continue;
    }

    const rc = rl_loader_finish_task(slot.task);

    if (rc === 0) {
      slot.on_success?.(slot.path, slot.user_data);
    } else {
      slot.on_failure?.(slot.path, slot.user_data);
    }

    rl_loader_free_task(slot.task);
    slot.path = "";
    slot.on_success = null;
    slot.on_failure = null;
    slot.user_data = undefined;
    slot.in_use = false;
  }
}
