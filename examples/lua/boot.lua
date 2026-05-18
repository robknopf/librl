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
rl.logger_set_level(rl.RL_LOGGER_LEVEL_DEBUG)

local SCRIPTS_ROOT = "assets/scripts/lua"
local RUNTIME_MODULE = "main"
local RUNTIME_ENTRY_MODULE = "runtime_wrapper"

-- check for --help or -h
for i = 1, #arg do
    if arg[i] == "--help" or arg[i] == "-h" then
        print("Usage: lua boot.lua [--root <script_root>] [<runtime_module>]")
        print("  --root <script_root> (default: " .. SCRIPTS_ROOT .. ")")
        print("  <runtime_module> (default: " .. RUNTIME_MODULE .. ")")
        return
    end
end

-- get the script root from the command line arguments (--root or -r) (default: assets/scripts/lua)
for i = 1, #arg do
    if arg[i] == "--root" or arg[i] == "-r" then
        SCRIPTS_ROOT = arg[i + 1]
        break
    end
end

-- add the SCRIPTS_ROOT to the search path
package.path = SCRIPTS_ROOT .. "/?.lua;" .. SCRIPTS_ROOT .. "/?/init.lua;" .. package.path

-- get the main script name from the command line arguments (default: simple).  it should be the last argument.
for i = 1, #arg do
    if arg[i]:sub(1, 1) ~= "-" then
        RUNTIME_MODULE = arg[i]
        break
    end
end


-- for now, use libRL's time
local now = rl.get_time

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
if rl.fileio_init() ~= 0 then
    rl.error("rl.fileio_init failed")
    return
end

if rl.fileio_set_asset_host("https://localhost:4444") ~= 0 then
    rl.error("rl.fileio_set_asset_host failed")
    return
end

-- check if the asset host is available
local rtt = rl.fileio_ping_asset_host()
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
        local task = rl.fileio_ensure_async(asset_path)
        if not task or task == 0 then
            rl.error("fileio_ensure_async failed for " .. asset_path)
        end
        while not rl.fileio_poll_task(task) do
            rl.fileio_tick()
            coroutine.yield("loading")
        end
        local rc = rl.fileio_finish_task(task)
        if rc ~= 0 then
            rl.error("import failed (rc=" .. tostring(rc) .. "): " .. asset_path)
        end
        local path = rl.fileio_get_task_path(task)
        rl.fileio_free_task(task)
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
-- note that we could just clear the main.lua file with rl.fileio_remove(MAIN_SCRIPT_PATH)
-- but we'll start with a clean slate during development
rl.info("clearing loader cache")
rl.fileio_clear()

---@enum ResultCode
ResultCode = {
    OK = 0,
    ERROR = -1,
    QUIT = 1
}

rl.info("loading "..RUNTIME_ENTRY_MODULE)
local runtime = require(SCRIPTS_ROOT .. "/" .. RUNTIME_ENTRY_MODULE)


--------------------------------------------------------------
-- act like we are the host and simulate the lifecycle pump for the runtime

local rc = runtime.rt_boot(RUNTIME_MODULE)
if rc ~= ResultCode.OK then return end

-- shutdown the loader, letting the runtime own full rl lifecycle
rl.fileio_deinit()


rc = runtime.rt_init(nil)
if rc ~= ResultCode.OK then return end

local last_time = now()
local current_time = last_time
local delta_time = 0
repeat
    current_time = now()
    delta_time = current_time - last_time
    last_time = current_time
    rc = runtime.rt_tick(delta_time)
until rc ~= ResultCode.OK
runtime.rt_shutdown()

---------------------------------------------------------------


