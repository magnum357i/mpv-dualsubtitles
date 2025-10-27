--v1.2
local ass = {}

ass.__index = ass

local function newTime(str)

    return setmetatable({original=str}, {

        __index = {

            ms = function(self)

                local h, m, s, ms = self.original:match("^(%d?%d):(%d%d):(%d%d)%.(%d%d%d?)$")

                if not h then return 0 end

                if #self.original == 10 then ms = ms.."0" end

                return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) + tonumber(ms) / 1000
            end,

            fromMS = function(self, secs)

                if secs == 0 then self.original = "0:00:00.00" return end

                local h  = math.floor(secs / 3600)
                local m  = math.floor((secs % 3600) / 60)
                local s  = secs % 60
                local ms = math.floor((secs - math.floor(secs)) * 1000)

                self.original = string.format("%d:%02d:%02d.%02d", h, m, s, ms)
            end
        },

        __tostring = function(self) return self.original end
    })
end

local function newText(str)

    return setmetatable({original=str}, {

        __index = {

            stripped = function(self)

                strippedText = self.original
                :gsub("%{[^%}]*%}", "")
                :gsub("\\[nNh]", " ")
                :gsub("%s+", " ")

                return strippedText
            end,

            isSign = function(self)

                return (self.original:find("\\pos%([%d%s%.,]+%)") or self.original:find("\\move%([%d%s%.,]+%)")) and true or false
            end,

            isShape = function(self)

                return self.original:find("%}%s*m%s+%d+%s+%d+") and true or false
            end,

            isEmpty = function(self)

                return (self.original == "" or self.original:gsub("%s+", "") == "") and true or false
            end
        },

        __tostring = function(self) return self.original end
    })
end

local patterns = {

    Styles = "\n(Style):%s([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^\n]+)",
    Lines  = "\n(Dialogue):%s([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^,]*),([^\n]+)"
}

local parseMap = {

    Style = function(t)

        return {

            Class           = t[1],
            Name            = t[2],
            Fontname        = t[3],
            Fontsize        = tonumber(t[4]),
            PrimaryColour   = t[5],
            SecondaryColour = t[6],
            OutlineColour   = t[7],
            BackColour      = t[8],
            Bold            = t[9]  == "-1" and true or false,
            Italic          = t[10] == "-1" and true or false,
            Underline       = t[11] == "-1" and true or false,
            StrikeOut       = t[12] == "-1" and true or false,
            ScaleX          = tonumber(t[13]),
            ScaleY          = tonumber(t[14]),
            Spacing         = tonumber(t[15]),
            Angle           = tonumber(t[16]),
            BorderStyle     = tonumber(t[17]),
            Outline         = tonumber(t[18]),
            Shadow          = tonumber(t[19]),
            Alignment       = tonumber(t[20]),
            MarginL         = tonumber(t[21]),
            MarginR         = tonumber(t[22]),
            MarginV         = tonumber(t[23]),
            Encoding        = tonumber(t[24])
        }
    end,

    Dialogue = function(t)

        return {

            Class   = t[1],
            Layer   = tonumber(t[2]),
            Start   = newTime(t[3]),
            End     = newTime(t[4]),
            Style   = t[5],
            Actor   = t[6],
            MarginL = tonumber(t[7]),
            MarginR = tonumber(t[8]),
            MarginV = tonumber(t[9]),
            Effect  = t[10],
            Text    = newText(t[11])
        }
    end
}

local serializeMap = {

    Style = function(self)

        return string.format("Style: %s,%s,%d,%s,%s,%s,%s,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d,%d",

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
    end,

    Dialogue = function(self)

       return string.format("Dialogue: %d,%s,%s,%s,%s,%d,%d,%d,%s,%s",

            self.Layer,
            self.Start,
            self.End,
            self.Style,
            self.Actor,
            self.MarginL,
            self.MarginR,
            self.MarginV,
            self.Effect,
            self.Text
        )
    end
}

function ass:new(t)

    local obj = parseMap[t[1]](t)

    return setmetatable(obj, self)
end

function ass:raw()

    return serializeMap[self.Class](self)
end

function ass:resolution(content)

    return tonumber(content:match("PlayResX: (%d+)") or 0), tonumber(content:match("PlayResY: (%d+)") or 0)
end

function ass:styles(content)

    local iter = content:gmatch(patterns.Styles)

    return function()

        local line = {iter()}

        if not line[1] then return nil end

        return self:new(line)
    end
end

function ass:lines(content)

    local iter = content:gmatch(patterns.Lines)

    return function()

        local line = {iter()}

        if not line[1] then return nil end

        return self:new(line)
    end
end

return ass