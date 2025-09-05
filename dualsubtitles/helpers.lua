local utils = require "mp.utils"
local this  = {}

function this.log(str)

    if type(str) == "table" then

        print(utils.format_json(str))
    else

        print(str)
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

return this