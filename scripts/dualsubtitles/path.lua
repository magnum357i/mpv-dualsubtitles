--v1.0
local this      = {}
local seperator = package.config:sub(1,1)
local variables = {

    temp    = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp",
    config  = mp.command_native({"expand-path", "~~/"}),
    scripts = mp.command_native({"expand-path", "~~/scripts"}),
    options = mp.command_native({"expand-path", "~~/script-opts"})
}
local platform

local function runCommand(args)

    return mp.command_native({

        name           = 'subprocess',
        playback_only  = false,
        capture_stdout = true,
        capture_stderr = true,
        args           = args
    })
end

function this.platform()

    if platform then return platform end

    local detected = mp.get_property_native("platform")

    if not (detected == "windows" or detected == "darwin") then

        detected = (os.getenv("WAYLAND_DISPLAY") or os.getenv("WAYLAND_SOCKET")) and "wayland" or "x11"
    end

    platform = detected

    return platform
end

function this.join(parts)

    parts[1] = string.gsub(parts[1], "%%(.+)", function(vName)

        if variables[vName] then return variables[vName] end

        return ""
    end)

    return table.concat(parts, seperator)
end

function this.checkPath(path)

    return os.rename(path, path) and true or false
end

function this.removeFile(path)

    os.remove(path)
end

function this.removeDir(path)

    if this.platform() == "windows" then

        runCommand({"powershell", "-NoProfile", "-Command", string.format("Remove-Item -Recurse -Force -LiteralPath \"%s\"", path)})
    else

        runCommand({"rm", "-rf", path})
    end
end

function this.createDir(path)

    if not this.checkPath(path) then

        if this.platform() == "windows" then

            runCommand({"powershell", "-NoProfile", "-Command", string.format("New-Item -Path \"%s\" -ItemType Directory -Force", path)})
        else

            runCommand({"mkdir", "-p", path})
        end
    end
end

function this.readFile(path)

    local h = io.open(path, "r")

    if not h then return nil end

    local content = h:read("*all")

    h:close()

    return content
end

function this.createFile(path, content)

    local h = io.open(path, "w")

    if not h then return false end

    h:write(content)
    h:close()

    return true
end

return this