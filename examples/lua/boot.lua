local function script_dir()
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

local dir = script_dir()
prepend_libs_cpath(dir)

require("hello_librl")




