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

function this.notify(msg,errType,level)

    mp.msg[level](msg)

    mp.osd_message(assStart..string.format("{\\c%s\\b1}[dualsubtitles:%s]{\\b0} %s! %s", (level == "error") and "&H3300AA&" or "&H0077CC&", errType, (level == "error") and "Error" or "Warning", msg)..assStop, 5)
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

return this