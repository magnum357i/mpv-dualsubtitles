local utils    = require "mp.utils"
local subtitle = {}

subtitle.__index = subtitle

local function isTextBased(track)

    return track.codec and (track.codec == "subrip" or track.codec == "ass")
end

local function isForced(track)

    if track.forced                                       then return true end
    if track.title and track.title:lower():find("forced") then return true end

    return false
end

local function isHearingImpaired(track)

    if track.hearing_impaired then return true  end
    if not track.title        then return false end

    local sTitle = track.title:lower()

    if sTitle:find("sdh") or sTitle:find("cc") then return true end

    return false
end

local function getExt(track)

    if not track.codec then return nil end

    local extensionList = {

        subrip            = ".srt",
        ass               = ".ass",
        hdmv_pgs_subtitle = ".sup"
    }

    return extensionList[track.codec]
end

local function detectSubtitleInfo(track)

    local lang      = track.title and string.match("."..track.title, "[%.%-%s]([a-zA-Z][a-zA-Z][a-zA-Z]?)%.[a-z][a-z][a-z]$") or nil
    local eSubtitle = utils.file_info(track["external-filename"])
    local bytes     = eSubtitle and eSubtitle.size or 0

    return lang, bytes
end

function subtitle:new(track)

    local obj           = {}
    obj.id              = track.id
    obj.title           = track.title
    obj.ext             = getExt(track)
    obj.textbased       = isTextBased(track)
    obj.external        = track.external
    obj.lang            = track.lang and track.lang:lower():gsub("_", "-") or nil
    obj.size            = track.metadata and track.metadata.NUMBER_OF_BYTES or 0
    obj.default         = track.default
    obj.forced          = isForced(track)
    obj.hearingimpaired = isHearingImpaired(track)
    obj.visualimpaired  = track["visual-impaired"]
    obj.path            = track["external-filename"]

    if obj.external then

        local lang, bytes = detectSubtitleInfo(track)
        obj.lang          = obj.lang or lang
        obj.size          = bytes
    end

    setmetatable(obj, self)

    return obj
end

function subtitle:__tostring()

    local dst = ""

    if self.title then

        dst = dst..string.format("'%s' ", self.title)
    end

    dst = dst.."("

    if self.lang then

        dst = dst..string.format("%s ", self.lang)
    end

    if     self.ext == ".srt" then codec = "subrip [Advanced Sub Station Alpha]"
    elseif self.ext == ".ass" then codec = "ass"
    elseif self.ext == ".sup" then codec = "hdmv_pgs_subtitle"
    else                           codec = "<unknown>" end

    dst = dst..codec
    dst = dst..")"

    local flags = {}

    if self.default         then table.insert(flags, "default")          end
    if self.forced          then table.insert(flags, "forced")           end
    if self.visualimpaired  then table.insert(flags, "visual-impaired")  end
    if self.hearingimpaired then table.insert(flags, "hearing-impaired") end
    if self.external        then table.insert(flags, "external")         end

    if #flags > 0 then

        dst = dst.." ["..table.concat(flags, " ").."]"
    end

    dst = "("..self.id..") "..dst

    return dst
end

return subtitle