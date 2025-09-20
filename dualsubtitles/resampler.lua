--[[

Resolution resampling logic inspired by Aegisub
https://github.com/Aegisub/Aegisub
Original BSD licensed code by Thomas Goyne

]]

local this         = {}

local rx, ry       = 0, 0
local shapeLetters = {"m", "n", "l", "b", "s", "p", "c"}

local function hasValue(items, value)

    local result = false

    for _, item in ipairs(items) do

        if value:find(item) then

            result = true
            break
        end
    end

    return result
end

local function split(str)

    local list = {}

    for s in str:gmatch("[^,]+") do

        s = tonumber(s)

        if s then table.insert(list, s) end
    end

    return list
end

local function toFloat(n, decimals)

    n = string.format("%."..decimals.."f", n)
    n = n:gsub("0+$", ""):gsub("%.$", "")

    return n
end

function this.setResolutions(sourceX, sourceY, destX, destY)

    rx = destX / sourceX
    ry = destY / sourceY
end

function this.resampleStyle(style)

    style.Fontsize = math.floor(style.Fontsize * ry + 0.5)
    style.Outline  = style.Outline * ry
    style.Shadow   = style.Shadow * ry
    style.Spacing  = style.Spacing * ry
    style.MarginL  = math.floor(style.MarginL * rx + 0.5)
    style.MarginR  = math.floor(style.MarginR * rx + 0.5)
    style.MarginV  = math.floor(style.MarginV * ry + 0.5)

    return style
end

local tagMap = {

    bord = function(p)

        if #p ~= 1 then return nil end

        return string.format("bord%s", toFloat(p[1] * ry, 1))
    end,

    xbord = function(p)

        if #p ~= 1 then return nil end

        return string.format("xbord%s", toFloat(p[1] * rx, 1))
    end,

    ybord = function(p)

        if #p ~= 1 then return nil end

        return string.format("ybord%s", toFloat(p[1] * ry, 1))
    end,

    shad = function(p)

        if #p ~= 1 then return nil end

        return string.format("shad%s", toFloat(p[1] * ry, 1))
    end,

    xshad = function(p)

        if #p ~= 1 then return nil end

        return string.format("xshad%s", toFloat(p[1] * rx, 1))
    end,

    yshad = function(p)

        if #p ~= 1 then return nil end

        return string.format("yshad%s", toFloat(p[1] * ry, 1))
    end,

    be = function(p)

        if #p ~= 1 then return nil end

        return string.format("be%d", p[1] * ry)
    end,

    blur = function(p)

        if #p ~= 1 then return nil end

        return string.format("blur%s", toFloat(p[1] * ry, 1))
    end,

    fs = function(p)

        if #p ~= 1 then return nil end

        return string.format("fs%d", p[1] * ry + 0.5)
    end,

    fsp = function(p)

        if #p ~= 1 then return nil end

        return string.format("fsp%d", p[1] * rx)
    end,

    pos = function(p)

        if #p ~= 2 then return nil end

        return string.format("pos(%s,%s)", toFloat(p[1] * rx, 3), toFloat(p[2] * ry, 3))
    end,

    move = function(p)

        if not (#p == 4 or #p == 6) then return nil end

        if #p == 4 then

            return string.format("move(%s,%s,%s,%s)",       toFloat(p[1] * rx, 3), toFloat(p[2] * ry, 3), toFloat(p[3] * rx, 3), toFloat(p[4] * ry, 3))
        elseif #p == 6 then

            return string.format("move(%s,%s,%s,%s,%d,%d)", toFloat(p[1] * rx, 3), toFloat(p[2] * ry, 3), toFloat(p[3] * rx, 3), toFloat(p[4] * ry, 3), p[5], p[6])
        else

            return nil
        end
    end,

    org = function(p)

        if #p ~= 2 then return nil end

        return string.format("org(%s,%s)", math.floor(p[1] * rx, 3), math.floor(p[2] * ry), 3)
    end,

    clip = function(p)

        if #p == 4 then

            return string.format("clip(%s,%s,%s,%s)", math.floor(p[1] * rx, 3), math.floor(p[2] * ry, 3), math.floor(p[3] * rx, 3), math.floor(p[4] * ry, 3))
        end

        return nil
    end,

    iclip = function(p)

        if #p == 4 then

            return string.format("clip(%s,%s,%s,%s)", math.floor(p[1] * rx, 3), math.floor(p[2] * ry, 3), math.floor(p[3] * rx, 3), math.floor(p[4] * ry, 3))
        end

        return nil
    end,
}

function this.resampleTag(name, params)

    params   = split(params:gsub("[%(%)%s]+", ""))
    local fn = tagMap[name]

    if fn then return fn(params) end

    return nil
end

function this.resampleDrawing(drawing)

    local isX   = true
    local parts = {}

    for cur in drawing:gmatch("%S+") do

        local num = tonumber(cur)

        if num then

            num = isX and num * rx or num * ry

            table.insert(parts, math.floor(num + 0.5))

            isX = not isX
        else

            local c = string.lower(cur)

            if hasValue(shapeLetters, c) then

                isX = true

                table.insert(parts, c)
            end
        end
    end

    return table.concat(parts, " ")
end

function this.resampleDialogue(line)

    if line.MarginL > 0 then line.MarginL = math.floor(line.MarginL * rx + 0.5) end
    if line.MarginR > 0 then line.MarginR = math.floor(line.MarginR * rx + 0.5) end
    if line.MarginV > 0 then line.MarginV = math.floor(line.MarginV * ry + 0.5) end

    line.Text = line.Text:gsub("\\([a-zx]+)([^\\%}]+)", function(name, params)

        local result = this.resampleTag(name, params)

        return "\\"..(result or name..params)
    end)

    line.Text = line.Text:gsub("([%}%(])%s*(m%s+[%d%-%.]+%s+[%d%-%.]+[%s%d%-%."..table.concat(shapeLetters, "").."]+)", function(p, drawing)

        return string.format("%s%s", p, this.resampleDrawing(drawing))
    end)

    return line
end

return this