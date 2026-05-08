--[[
-- NOTE:  Commented, assumes the host has added them to globals
---@enum ResultCode
---General result codes.  Note that non-failure codes are > 0, error codes are < 0
ResultCode = ResultCode or {
    OK = 0,
    ERROR = -1,
    QUIT = 1
}
]]--

local main_module_path = "main"
local main = nil

---Initial bootstrap
---@param module_path? string name of the main module
---@return ResultCode
local function rt_boot(module_path)

    if module_path ~= nil then 
        main_module_path = module_path
    end

    if main_module_path == nil then
        print("main module not set")
        return ResultCode.ERROR
    end

    -- try to load the main module
    local ok, mod_or_err = pcall(require, main_module_path)
    if ok then
        main = mod_or_err
    else
        print("Failed to load module: ", mod_or_err)
        return ResultCode.ERROR
    end

    -- ensure the module returned a table
    if type(mod_or_err) ~= 'table' then
        print(main_module_path.." did not return a table")
        return ResultCode.ERROR
    end

    -- ensure the required callbacks were provided
    local required_callbacks = {
        "on_init",
        "on_tick",
        "on_shutdown"
    }
    for _, callback_name in ipairs(required_callbacks) do
        if type(mod_or_err[callback_name]) ~= "function" then
            print(main_module_path.." returned a table missing the '"..callback_name.."' callback")
            return ResultCode.ERROR
        end
    end

    return ResultCode.OK
end

---@return ResultCode
local function rt_init(_host_context)
    if main == nil then
        print("main module not set")
        return ResultCode.ERROR
    end
    return main.on_init()
end


---@param delta_time number in seconds
---@return ResultCode
local function rt_tick(delta_time)
    if main == nil then
        print("main module not set")
        return ResultCode.ERROR
    end
    return main.on_tick(delta_time)
end

---@return nil
local function rt_shutdown()
    if main == nil then
        print("main module not set")
        return ResultCode.ERROR
    end
    main.on_shutdown()
    main = nil
end


return {
    rt_boot = rt_boot,
    rt_init = rt_init,
    rt_tick = rt_tick,
    rt_shutdown = rt_shutdown
}
