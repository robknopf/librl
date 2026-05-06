-- Bootstrap: set up cpath, init librl, async-fetch the app script, then require it.

local function this_dir()
    local source = debug.getinfo(1, "S").source
    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end
    source = source:gsub("\\", "/")
    return source:match("^(.*)/") or "."
end

local function prepend_libs_cpath(base_dir)
    local libs_dir = base_dir .. "/libs"
    local entries = {
        libs_dir .. "/?.so",
        libs_dir .. "/?.dylib",
        libs_dir .. "/?.dll",
    }
    package.cpath = table.concat(entries, ";") .. ";" .. package.cpath
end

prepend_libs_cpath(this_dir())

local rl = require("rl")
rl.logger_set_level(rl.RL_LOGGER_LEVEL_INFO)

local DEFAULT_SCRIPTS_ROOT = "assets/scripts/lua"
local DEFAULT_SCRIPT_NAME = "main"

-- check for --help or -h
for i = 1, #arg do
    if arg[i] == "--help" or arg[i] == "-h" then
        print("Usage: lua boot.lua [--root <script_root>] [<script_name>]")
        print("  --root <script_root> (default: " .. DEFAULT_SCRIPTS_ROOT .. ")")
        print("  <script_name> (default: " .. DEFAULT_SCRIPT_NAME .. ")")
        return
    end
end

-- get the script root from the command line arguments (--root or -r) (default: assets/scripts/lua)
local SCRIPTS_ROOT = DEFAULT_SCRIPTS_ROOT
for i = 1, #arg do
    if arg[i] == "--root" or arg[i] == "-r" then
        SCRIPT_ROOT = arg[i + 1]
        break
    end
end

-- get the main script name from the command line arguments (default: simple).  it should be the last argument.
local MAIN_SCRIPT_NAME = DEFAULT_SCRIPT_NAME
for i = 1, #arg do
    if arg[i]:sub(1, 1) ~= "-" then
        MAIN_SCRIPT_NAME = arg[i]
        break
    end
end

local MAIN_SCRIPT_PATH = SCRIPTS_ROOT .. "/" .. MAIN_SCRIPT_NAME .. ".lua"


-- for now, use libRL's time
local now = nil--rl.get_time

-- use socket for the time module, fall back to os.clock
do
    if not now then 
        local ok, socket = pcall(require, "socket")
        if ok and socket and socket.gettime then
            print("using socket.gettime for now()")
            now = socket.gettime
        else
            print("socket module unavailable, using os.clock() for now()")
            now = os.clock
        end
    else
        print("using rl.get_time")
    end
end

-- initialize only the loader runtime so boot can fetch the entry script
if rl.loader_init() ~= 0 then
    rl.error("rl.loader_init failed")
    return
end

if rl.loader_set_asset_host("https://localhost:4444") ~= 0 then
    rl.error("rl.loader_set_asset_host failed")
    return
end

-- check if the asset host is available
local rtt = rl.loader_ping_asset_host()
if rtt < 0 then
    rl.warn("asset host is not available, will not be able to fetch assets")
else
    rl.info("asset host is available, rtt=" .. tostring(rtt))
end

--[[
local function await_import_asset(asset_path)
    if rl.get_platform() == "web" then
        -- TODO: this used to be true, but we now have a jspi hook
        rl.error("blocking asset import is not supported on web: the loop must return to the browser/JS event loop so async fetch callbacks can complete. Poll loader tasks from rl.run/on_tick instead.")
        return
    end
    -- Coroutine: pump until import finishes, then just import the script
    local function load_entry_coroutine()
        local task = rl.loader_import_asset_async(asset_path)
        if not task or task == 0 then
            rl.error("loader_import_asset_async failed for " .. asset_path)
        end
        while not rl.loader_poll_task(task) do
            rl.loader_tick()
            coroutine.yield("loading")
        end
        local rc = rl.loader_finish_task(task)
        if rc ~= 0 then
            rl.error("import failed (rc=" .. tostring(rc) .. "): " .. asset_path)
        end
        local path = rl.loader_get_task_path(task)
        rl.loader_free_task(task)
        if not path or path == "" then
            rl.error("no local path after import: " .. asset_path)
        end
    end

    local co = coroutine.create(load_entry_coroutine)
    while coroutine.status(co) ~= "dead" do
        local ok, err = coroutine.resume(co)
        if not ok then
            rl.error("coroutine resume failed: " .. tostring(err))
        end
    end
end

await_import_asset(MAIN_SCRIPT_PATH)

]]--



-- require the main script to kick things off.
-- treat it like a runtime


-- debugging, force clear the cache
-- note that we could just clear the main.lua file with rl.loader_uncache_asset(MAIN_SCRIPT_PATH)
-- but we'll start with a clean slate during development
rl.loader_clear_cache()

rl.info("loading "..MAIN_SCRIPT_PATH)
local runtime = require(SCRIPTS_ROOT .. "/" .. MAIN_SCRIPT_NAME)

-- shutdown the loader, letting the runtime own full rl lifecycle

rl.info("cleared loader cache")

rl.loader_deinit()

--------------------------------------------------------------
-- act like we were hosted and simulate the lifecycle pump

---@enum RTResult
RTResult = {
    SUCCESS = 0,
    FAILED = -1,
    STOPPED = 1
}

local rc = runtime.rt_boot()
if rc ~= RTResult.SUCCESS then return end

rc = runtime.rt_init(nil)
if rc ~= RTResult.SUCCESS then return end

local last_time = now()
local current_time = last_time
local delta_time = 0
repeat
    current_time = now()
    delta_time = current_time - last_time
    last_time = current_time
    rc = runtime.rt_tick(delta_time)
until rc ~= RTResult.SUCCESS
runtime.rt_shutdown()

---------------------------------------------------------------



