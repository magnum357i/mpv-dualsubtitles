local utils = require "mp.utils"
local this  = {}

local assStart = mp.get_property_osd("osd-ass-cc/0")
local assStop  = mp.get_property_osd("osd-ass-cc/1")

function this.log(str)

    if type(str) == "table" then

        print(utils.format_json(str))
    else

        print(str)
    end
end

function this.notify(msg,errType,level,duration,silent)

    duration = duration and duration or 5

    mp.msg[level](msg)

    local colors = {

        error = "&H3300AA&",
        warn  = "&H0077CC&"
    }

    local headers = {

        error = "Error",
        warn  = "Warning"
    }

    if not silent then

        local output = ""
        output = output..string.format("{%s\\b1}", colors[level] and "\\c"..colors[level] or "")
        output = output..string.format("[dualsubtitles:%s]{\\b0} ", errType)
        output = output..(headers[level] and string.format("%s! ", headers[level]) or "")
        output = output..msg

        mp.osd_message(assStart..output..assStop, duration)
    end
end

function this.splitString(str)

    local list = {}

    for val in string.gmatch(str, "([^,]+)") do

        table.insert(list, val)
    end

    return list
end

function this.hasItem(items, value)

    for _, item in ipairs(items) do

        if item == value then return true end
    end

    return false
end

function this.searchStrings(value, items)

    for _, item in ipairs(items) do

        if string.find(value, item, 1, true) then return true end
    end

    return false
end

function this.runAsync(cmd, handleSuccess, handleFail)

    local proc = mp.command_native_async(cmd, function(_, result, _)

        if result.status == 0 then

            handleSuccess()
        else

            this.log(cmd.args)
            handleFail(result.stderr)
        end
    end)
end

function this.runCommand(args)

    return mp.command_native({

        name           = 'subprocess',
        playback_only  = false,
        capture_stdout = true,
        capture_stderr = true,
        args           = args
    })
end

function this.hash(str)

    local h1, h2, h3 = 0, 0, 0

    for i = 1, #str do

        local b = str:byte(i)

        h1 = (h1 * 31 + b) % 2^32
        h2 = (h2 * 37 + b) % 2^32
        h3 = (h3 * 41 + b) % 2^32
    end

    return string.format("%08x%08x%08x", h1, h2, h3)
end

return this