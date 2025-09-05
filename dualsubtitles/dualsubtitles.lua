--[[

https://github.com/magnum357i/mpv-dualsubtitles/

╔════════════════════════════════╗
║        MPV dualsubtitles       ║
║              v2.1.0            ║
╚════════════════════════════════╝

## Standardized Codes ##
Languages (ISO 639): https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes
Countries (ISO 3166): https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes

## Language Reference ##
CSV Data: https://github.com/datasets/language-codes/blob/main/data/language-codes-3b2.csv
]]

mp    = require "mp"
msg   = require "mp.msg"
utils = require "mp.utils"

--User Settings

options = {
    preferredLanguages = {bottom = "en-us,ja-jp", top = "tr-tr"},
    ignoredWords       = "sign,song",
    useTopAsBottom     = true
}

--Global Variables

hideMode       = 0
subtitles      = {}
prevTrackCount = 0

--Helpers

function log(str)
if type(str) == "table" then

    print(utils.format_json(str))
else

    print(str)
end
end

function splitString(str)
local list = {}

for val in string.gmatch(str, "([^,]+)") do

    table.insert(list, val)
end

return list
end

function detectSubtitleInfo(filename)
local externalSubtitle = utils.file_info(filename)
local lang             = filename:match(".+[%.%-%s]([a-zA-Z][a-zA-Z][a-zA-Z]?)[%.%-%s]")
local bytes            = externalSubtitle and externalSubtitle.size or 0

return lang, bytes
end

function getSubtitleList()
local list = {}

for index, value in ipairs(mp.get_property_native("track-list")) do

    if value.type == "sub" then

        if value.external then

            local lang, bytes = detectSubtitleInfo(value["external-filename"])

                if lang and bytes > 0 then

                    value.lang = lang

                    if not value.metadata then value.metadata = {} end

                    value.metadata.NUMBER_OF_BYTES = bytes
                else

                    value.lang = nil
                    mp.msg.error("Failed to get external subtitle info.")
                end
            end

            table.insert(list, value)
        end

    prevTrackCount = index
end

return list
end

function hasValue(items,value)
local result = false

for _, item in ipairs(items) do

	if value:find(item) then

        result = true
	    break
	end
end

return result
end

function filterSubtitle(subtitle,wordstofilter)
local stitle = subtitle.title and subtitle.title:lower() or nil

if subtitle.forced or stitle and stitle:find("forced") then

    return false
end

if stitle and hasValue(wordstofilter, stitle) then

    return false
end

return true
end

function findSubtitle(languageCodes)
local selectedSubtitles = {}
local founded           = false
local unwantedsubtitles = splitString(options.ignoredWords)

for _, userLang in ipairs(languageCodes) do

    for _, subtitle in ipairs(subtitles) do

        if subtitle.lang and subtitle.lang:lower() == userLang and filterSubtitle(subtitle, unwantedsubtitles) then

            founded = true
            table.insert(selectedSubtitles, subtitle)
        end

    end

if founded then break end
end

local subId = 0

if #selectedSubtitles == 1 then

    subId = selectedSubtitles[1].id
elseif #selectedSubtitles > 1 then

    table.sort(selectedSubtitles, function(a, b)

        return tonumber(a.metadata.NUMBER_OF_BYTES) > tonumber(b.metadata.NUMBER_OF_BYTES)
    end)

    for _, subtitle in ipairs(selectedSubtitles) do

        local stitle = subtitle.title and subtitle.title:lower() or nil

        if not ((subtitle.hearing_impaired) or (stitle and stitle:find("sdh")) or (stitle and stitle:find("cc"))) then

            subId = subtitle.id
            break
        end
    end

subId = (subId == 0) and selectedSubtitles[1].id or subId
end

return subId
end

function formatTrackData(subId)
local track = subtitles[subId]
local dst = ""

if track.title then

    dst = dst..string.format("'%s' ", track.title)
end

dst = dst.."("

if track.lang then

    dst = dst..string.format("%s ", track.lang)
end

local codec = track.codec and track.codec or "<unknown>"
codec       = (codec == "subrip") and "subrip [Advanced Sub Station Alpha]" or codec

dst = dst..codec
dst = dst..")"

local flags = {}

if track["default"]          then table.insert(flags, "default")          end
if track["forced"]           then table.insert(flags, "forced")           end
if track["dependent"]        then table.insert(flags, "dependent")        end
if track["visual-impaired"]  then table.insert(flags, "visual-impaired")  end
if track["hearing-impaired"] then table.insert(flags, "hearing-impaired") end
if track["external"]         then table.insert(flags, "external")         end

if #flags > 0 then

    dst = dst.." ["..table.concat(flags, " ").."]"
end

dst = "("..track.id..") "..dst

return dst
end

function getLanguageMap(allLanguages)
local handle
local files = {
    config   = mp.command_native({'expand-path', os.getenv("TEMP").."/mpvdualsubtitles/cachedlanguages.json"}),
    language = mp.command_native({'expand-path', mp.get_script_directory().."/language-codes-3b2.csv"}),
    script   = mp.command_native({'expand-path', mp.get_script_directory().."/dualsubtitles.lua"})
}

local scriptFileInfo = utils.file_info(files.script)
local configFileInfo = utils.file_info(files.config)

if scriptFileInfo and configFileInfo and tonumber(scriptFileInfo.mtime) > tonumber(configFileInfo.mtime) then os.remove(files.config) end

handle = io.open(files.config, "r")

if handle then

    local content = handle:read("*a")

    handle:close()

    return utils.parse_json(content)
end

local map       = {}
local is_filled = false
handle          = io.open(files.language, "r")

if not handle then

    mp.osd_message("[dualsubtitles] Language map file not found! A file named 'language-codes-3b2.csv' must be placed in the plugin directory.", 5000)
else

    allLanguages   = splitString(allLanguages)
    local langKeys = {}

    for _, lang in ipairs(allLanguages) do

        table.insert(langKeys, lang:find("%-") and lang:gsub("%-.+","") or lang)
    end

    for line in handle:lines() do

        local iso3, iso2, title = line:gsub('"', ''):gsub('[;,]?%s.+', ''):match("([^,]+),([^,]+),([^,]+)")

        if title and hasValue(langKeys, iso2) then

            map[iso2] = {iso3, title}

            if not is_filled then is_filled = true end
        end
    end

    handle:close()
end

if is_filled then

    local tempPath      = files.config:match("(.+)[/\\]")
    local ok, err, code = os.rename(tempPath, tempPath)

    if not ok then os.execute('mkdir ' ..tempPath:gsub("/", "\\")) end

    handle = io.open(files.config, "w")

    if handle then

        handle:write(utils.format_json(map))
        handle:close()
    else

        mp.osd_message("[dualsubtitles] Failed to create the cache file. Required for performance.", 5000)
    end
else

    mp.osd_message("[dualsubtitles] You entered invalid languages, or the CSV file is broken.", 5000)
end

return map
end

function mergeLanguages(preferred,map)
local languages = {}
preferred       = splitString(preferred:gsub("_","-"))

for _, value in ipairs(preferred) do

    local langCode, langCountry = value:lower():match("([^%-][^%-])%-([^%-][^%-])")

    if langCode and langCountry then

        table.insert(languages, value)
        table.insert(languages, langCode)

        if map and map[langCode] then

            table.insert(languages, map[langCode][1]:lower())
            table.insert(languages, map[langCode][2]:lower())
        elseif #map > 0 then

            mp.msg.error("Map Error: Unrecognized language code.")
        end
    else

        table.insert(languages, value)
    end
end

log(languages)

return languages
end

--Functions

function setSubtitles()
local langMap   = getLanguageMap(options.preferredLanguages.bottom..","..options.preferredLanguages.top)
local bottomSid = findSubtitle(mergeLanguages(options.preferredLanguages.bottom, langMap))
local topSid    = findSubtitle(mergeLanguages(options.preferredLanguages.top, langMap))

if options.useTopAsBottom and bottomSid == 0 and topSid > 0 then

    bottomSid = topSid
    topSid    = 0
end

if bottomSid > 0 then mp.set_property_native("sid",           bottomSid) end
if topSid > 0    then mp.set_property_native("secondary-sid", topSid)    end

log(string.format("bottom %s, top %s", (bottomSid > 0) and bottomSid or "not set", (topSid > 0) and topSid or "not set"))
end

function secondaryForward()
local bottomSid, topSid = mp.get_property_number("sid"), mp.get_property_number("secondary-sid", 0)
topSid                  = topSid + 1

if topSid == bottomSid then topSid = topSid + 1 end

if topSid > #subtitles then

    mp.set_property_native("secondary-sid", 0)
    mp.osd_message("Secondary: no")
else

    mp.set_property_native("secondary-sid", topSid)
    mp.osd_message("Secondary: "..formatTrackData(topSid))
end
end

function secondaryBackward()
local bottomSid, topSid = mp.get_property_number("sid"), mp.get_property_number("secondary-sid", #subtitles + 1)
topSid                  = topSid - 1

if topSid == bottomSid then topSid = topSid - 1 end

if topSid == 0 then

    mp.set_property_native("secondary-sid", 0)
    mp.osd_message("Secondary: no")
else

    mp.set_property_native("secondary-sid", topSid)
    mp.osd_message("Secondary: "..formatTrackData(topSid))
end
end

function reverseSubtitles()
local bottomSid, topSid = mp.get_property_number("sid", 0), mp.get_property_number("secondary-sid", 0)

if bottomSid > 0 and topSid > 0 then

    mp.set_property_native("sid",           0)
    mp.set_property_native("secondary-sid", 0)
    mp.set_property_native("sid",           topSid)
    mp.set_property_native("secondary-sid", bottomSid)

    mp.osd_message(string.format("Top: %s\nBottom: %s", formatTrackData(bottomSid), formatTrackData(topSid)))
else

    mp.osd_message("Subtitles not reversed")
end
end

function hideSubtitles()
if hideMode == 0 then

    hideMode = hideMode + 1

    mp.set_property_native("sub-visibility",           "yes")
    mp.set_property_native("secondary-sub-visibility", "no")

    mp.osd_message("Only the bottom subtitle visible")
elseif hideMode == 1 then

    hideMode = hideMode + 1

    mp.set_property_native("sub-visibility",           "no")
    mp.set_property_native("secondary-sub-visibility", "no")

    mp.osd_message("Subtitles hidden")
elseif hideMode == 2 then

    hideMode = 0

    mp.set_property_native("sub-visibility",           "yes")
    mp.set_property_native("secondary-sub-visibility", "yes")

    mp.osd_message("Subtitles visible")
end
end

mp.observe_property("track-list", "native", function(event,tracklist)

    if #tracklist ~= prevTrackCount then

        local firstUpdated = (prevTrackCount == 0) and true or false
        subtitles          = getSubtitleList()

        if not firstUpdated then log("Subtitle list updated.") end
    end
end)

mp.add_key_binding("k", "secondaryforward",  secondaryForward)
mp.add_key_binding("K", "secondarybackward", secondaryBackward)
mp.add_key_binding("u", "reversesubtitles",  reverseSubtitles)
mp.add_key_binding("v", "hidesubtitles",     hideSubtitles)

mp.register_event("file-loaded", setSubtitles)