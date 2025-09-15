local utils    = require "mp.utils"
local subtitle = {}

subtitle.__index = subtitle

local function isForced(trackInfo)

    if trackInfo.forced     then return true  end
    if not trackInfo.title  then return false end

    local stitle = trackInfo.title:lower()

    return stitle:find("forced") and true or false
end

local function isHearingImpaired(trackInfo)

    if trackInfo.hearing_impaired then return true  end
    if not trackInfo.title        then return false end

    local stitle = trackInfo.title:lower()

    return (stitle:find("sdh") or stitle:find("cc")) and true or false
end

local function getExt(trackInfo)

    if     trackInfo.codec == "subrip"            then return ".srt"
    elseif trackInfo.codec == "ass"               then return ".ass"
    elseif trackInfo.codec == "hdmv_pgs_subtitle" then return ".sup" end

    return nil
end

local function detectSubtitleInfo(path)

    local externalSubtitle = utils.file_info(path)
    local lang             = path:match(".+[%.%-%s]([a-zA-Z][a-zA-Z][a-zA-Z]?)[%.%-%s]")
    local bytes            = externalSubtitle and externalSubtitle.size or 0

    return lang, bytes
end

function subtitle:new(trackInfo)

    local obj           = {}

    obj.id              = trackInfo.id
    obj.title           = trackInfo.title
    obj.ext             = getExt(trackInfo)
    obj.textbased       = (obj.ext and obj.ext == ".srt" or obj.ext and obj.ext == ".ass")
    obj.external        = trackInfo.external
    obj.lang            = trackInfo.lang
    obj.size            = trackInfo.metadata and trackInfo.metadata.NUMBER_OF_BYTES or 0
    obj.default         = trackInfo.default
    obj.forced          = isForced(trackInfo)
    obj.hearingimpaired = isHearingImpaired(trackInfo)
    obj.visualimpaired  = trackInfo["visual-impaired"] and true or false
    obj.path            = trackInfo["external-filename"]

    if obj.external then

        local lang, bytes = detectSubtitleInfo(obj.path)

        obj.lang = lang
        obj.size = bytes
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