--v1.1

local ass = {}

ass.__index = ass

function ass:new(rawLine)

    local class = rawLine:match("^([^:]-):")

    if not (class == "Dialogue" or class == "Style") then return nil end

    local t
    local obj = {}
    class     = class:lower()

    if class == "dialogue" then

        t = {rawLine:match("^Dialogue:%s([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),(.+)$")}

        if not t[1] then return nil end

        obj.Layer   = tonumber(t[1])
        obj.Start   = ass:time2ms(t[2])
        obj.End     = ass:time2ms(t[3])
        obj.Style   = t[4]
        obj.Actor   = t[5]
        obj.MarginL = tonumber(t[6])
        obj.MarginR = tonumber(t[7])
        obj.MarginV = tonumber(t[8])
        obj.Effect  = t[9]
        obj.Text    = t[10]
    elseif class == "style" then

        t = {rawLine:match("^Style:%s(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-),(.-)$")}

       if not t[1] then return nil end

       obj.Name            = t[1]
       obj.Fontname        = t[2]
       obj.Fontsize        = tonumber(t[3])
       obj.PrimaryColour   = t[4]
       obj.SecondaryColour = t[5]
       obj.OutlineColour   = t[6]
       obj.BackColour      = t[7]
       obj.Bold            = t[8]  == "-1" and true or false
       obj.Italic          = t[9]  == "-1" and true or false
       obj.Underline       = t[10] == "-1" and true or false
       obj.StrikeOut       = t[11] == "-1" and true or false
       obj.ScaleX          = tonumber(t[12])
       obj.ScaleY          = tonumber(t[13])
       obj.Spacing         = tonumber(t[14])
       obj.Angle           = tonumber(t[15])
       obj.BorderStyle     = tonumber(t[16])
       obj.Outline         = tonumber(t[17])
       obj.Shadow          = tonumber(t[18])
       obj.Alignment       = tonumber(t[19])
       obj.MarginL         = tonumber(t[20])
       obj.MarginR         = tonumber(t[21])
       obj.MarginV         = tonumber(t[22])
       obj.Encoding        = tonumber(t[23])
    end

    obj.Class = class

    setmetatable(obj, self)

    return obj
end

function ass:time2ms(uTime)

    local h, m, s, cs = uTime:match("(%d+):(%d+):(%d+)%.(%d+)")

    if not h then return 0 end

    return ((tonumber(h) * 3600) + (tonumber(m) * 60) + tonumber(s)) * 1000 + (tonumber(cs) * 10)
end

function ass:ms2time(uMS)

    if uMS == 0 then return "0:00:00.00" end

    local tSecs = math.floor(uMS / 1000)
    local h     = math.floor(tSecs / 3600)
    local m     = math.floor((tSecs % 3600) / 60)
    local s     = tSecs % 60
    local cs    = math.floor((uMS % 1000) / 10)

    return string.format("%d:%02d:%02d.%02d", h, m, s, cs)
end

function ass:strippedText()

    if self.Class == "dialogue" then

        return self.Text:gsub("%{[^%}]*%}", "")
    end

    return nil
end

function ass:isSign()

    if self.Class == "dialogue" then

        return self.Text:find("\\pos%([%d%s%.,]+%)") or self.Text:find("\\move%([%d%s%.,]+%)")
    end

    return nil
end

function ass:isShape()

    if self.Class == "dialogue" then

        return self.Text:match("%}%s*m%s+%d+%s+%d+")
    end

    return nil
end

function ass:isEmpty()

    if self.Class == "dialogue" then

        if self.Text == "" or self.Text:gsub("%s+", "") == "" then

            return true
        else

            return false
        end
    end

    return nil
end

function ass:raw()

    if self.Class == "dialogue" then

       return string.format(
           "Dialogue: %d,%s,%s,%s,%s,%d,%d,%d,%s,%s",
           self.Layer,
           ass:ms2time(self.Start),
           ass:ms2time(self.End),
           self.Style,
           self.Actor,
           self.MarginL,
           self.MarginR,
           self.MarginV,
           self.Effect,
           self.Text
       )
    elseif self.Class == "style" then

        return string.format(
            "Style: %s,%s,%d,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",
            self.Name,
            self.Fontname,
            self.Fontsize,
            self.PrimaryColour,
            self.SecondaryColour,
            self.OutlineColour,
            self.BackColour,
            (self.Bold      and -1 or 0),
            (self.Italic    and -1 or 0),
            (self.Underline and -1 or 0),
            (self.StrikeOut and -1 or 0),
            self.ScaleX,
            self.ScaleY,
            self.Spacing,
            self.Angle,
            self.BorderStyle,
            self.Outline,
            self.Shadow,
            self.Alignment,
            self.MarginL,
            self.MarginR,
            self.MarginV,
            self.Encoding
        )
    end

    return nil
end

return ass