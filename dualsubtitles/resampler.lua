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

function this.parseStyle(rawStyle)

    local t = {rawStyle:match("^Style:%s(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-)$")}

    if not t[1] then return nil end

    return {

        Name            = t[1],
        Fontname        = t[2],
        Fontsize        = tonumber(t[3]),
        PrimaryColour   = t[4],
        SecondaryColour = t[5],
        OutlineColour   = t[6],
        ShadowColour    = t[7],
        Bold            = tonumber(t[8]),
        Italic          = tonumber(t[9]),
        Underline       = tonumber(t[10]),
        StrikeOut       = tonumber(t[11]),
        ScaleX          = tonumber(t[12]),
        ScaleY          = tonumber(t[13]),
        Spacing         = tonumber(t[14]),
        Angle           = tonumber(t[15]),
        BorderStyle     = tonumber(t[16]),
        Outline         = tonumber(t[17]),
        Shadow          = tonumber(t[18]),
        Alignment       = tonumber(t[19]),
        MarginL         = tonumber(t[20]),
        MarginR         = tonumber(t[21]),
        MarginV         = tonumber(t[22]),
        Encoding        = tonumber(t[23])
    }
end

function this.parseDialogue(rawDialogue)

    local t = {rawDialogue:match("^Dialogue:%s([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),(.+)$")}

    if not t[1] then return nil end

    return {

        Layer   = tonumber(t[1]),
        Start   = t[2],
        End     = t[3],
        Style   = t[4],
        Actor   = t[5],
        MarginL = tonumber(t[6]),
        MarginR = tonumber(t[7]),
        MarginV = tonumber(t[8]),
        Effect  = t[9],
        Text    = t[10]
    }
end

function this.resampleStyle(style)

    style = this.parseStyle(style)

    if not style then return nil end

    local newStyle = {}

    for k, v in pairs(style) do

        newStyle[k] = v
    end

    newStyle.Fontsize = math.floor(style.Fontsize * ry + 0.5)
    newStyle.Outline  = style.Outline * ry
    newStyle.Shadow   = style.Shadow * ry
    newStyle.Spacing  = style.Spacing * ry
    newStyle.MarginL  = math.floor(style.MarginL * rx + 0.5)
    newStyle.MarginR  = math.floor(style.MarginR * rx + 0.5)
    newStyle.MarginV  = math.floor(style.MarginV * ry + 0.5)

    return this.styleToString(newStyle)
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

    line = this.parseDialogue(line)

    if not line then return nil end

    local newLine = {}

    for k, v in pairs(line) do

        newLine[k] = v
    end

    if newLine.MarginL > 0 then newLine.MarginL = math.floor(newLine.MarginL * rx + 0.5) end
    if newLine.MarginR > 0 then newLine.MarginR = math.floor(newLine.MarginR * rx + 0.5) end
    if newLine.MarginV > 0 then newLine.MarginV = math.floor(newLine.MarginV * ry + 0.5) end

    newLine.Text = newLine.Text:gsub("\\([a-zx]+)([^\\%}]+)", function(name, params)

        local result = this.resampleTag(name, params)

        return "\\"..(result and result or name..params)
    end)

    newLine.Text = newLine.Text:gsub("([%}%(])%s*(m%s+[%d%-%.]+%s+[%d%-%.]+[%s%d%-%."..table.concat(shapeLetters, "").."]+)", function(p, drawing)

        return string.format("%s%s", p, this.resampleDrawing(drawing))
    end)

    return this.dialogueToString(newLine)
end

function this.styleToString(style)

    return string.format(
        "Style: %s,%s,%d,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",
        style.Name,
        style.Fontname,
        style.Fontsize,
        style.PrimaryColour,
        style.SecondaryColour,
        style.OutlineColour,
        style.ShadowColour,
        style.Bold,
        style.Italic,
        style.Underline,
        style.StrikeOut,
        style.ScaleX,
        style.ScaleY,
        style.Spacing,
        style.Angle,
        style.BorderStyle,
        style.Outline,
        style.Shadow,
        style.Alignment,
        style.MarginL,
        style.MarginR,
        style.MarginV,
        style.Encoding
    )
end

function this.dialogueToString(line)

    return string.format(
        "Dialogue: %d,%s,%s,%s,%s,%d,%d,%d,%s,%s",
        line.Layer,
        line.Start,
        line.End,
        line.Style,
        line.Actor,
        line.MarginL,
        line.MarginR,
        line.MarginV,
        line.Effect,
        line.Text
    )
end

return this