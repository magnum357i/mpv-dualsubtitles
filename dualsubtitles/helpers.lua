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

function this.hasValue(items, value)

    local result = false

    for _, item in ipairs(items) do

        if value:find(item) then

            result = true
            break
        end
    end

    return result
end

function this.runAsync(args, handleSuccess, handleFail)

    local proc = mp.command_native_async(args, function(_, result, _)

        if result.status == 0 then

            handleSuccess()
        else

            handleFail(result.stderr)
        end
    end)
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