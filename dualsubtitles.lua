--User Settings
--For ISO codes: https://www.wikiwand.com/en/articles/List_of_ISO_639_language_codes

options = {
    preferredLanguages = {bottom = "en_gb,en,ja,jpn", top = "tr,tur"},
    ignoredWords       = "sign,song",
    useTopAsBottom     = true
}

--Global Variables

hideMode       = 0
subtitles      = {}
prevTrackCount = 0

--Helpers

function log(str)
print(str)
end

function splitString(str)
local list = {}
for val in string.gmatch(str, "([^,]+)") do
table.insert(list, val)
end
return list
end

function detectSubtitleInfo(filename)
local lang  = string.match(filename, ".+[%.%-%s%[]([a-zA-Z][a-zA-Z][a-zA-Z]?)[%.%-%s%]]")
local file  = io.open(filename, "rb")
local bytes = 0
if file then
file:seek("end", 0)
bytes = file:seek()
file:close()
end
return lang and string.lower(lang) or lang, bytes
end

function getSubtitleList()
local list              = {}
local externalsubtitles = false
for index, value in ipairs(mp.get_property_native("track-list")) do
    if value.type == "sub" then
        if value.external then
        local lang, bytes = detectSubtitleInfo(value["external-filename"])
            if lang and bytes > 0 then
            externalsubtitles              = true
            value.lang                     = lang
            if not value.metadata then value.metadata = {} end
            value.metadata.NUMBER_OF_BYTES = bytes
            else
            value.lang                     = nil
            log("Failed to get external subtitle info.")
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
	if string.find(value, item) then
    result = true
	break
	end
end
return result
end

function filterSubtitle(subtitle,wordstofilter)
local stitle = (subtitle.title) and string.lower(subtitle.title) or nil
if subtitle.forced or stitle and string.find(stitle, "forced") then
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
        if subtitle.lang and string.find(subtitle.lang, userLang) and filterSubtitle(subtitle, unwantedsubtitles) then
        founded = true
        table.insert(selectedSubtitles, subtitle)
        end
    end
if founded then break end
end
if #selectedSubtitles == 1 then
return selectedSubtitles[1].id
elseif #selectedSubtitles > 1 then
local subId = 0
    table.sort(selectedSubtitles, function(a, b)

        return tonumber(a.metadata.NUMBER_OF_BYTES) > tonumber(b.metadata.NUMBER_OF_BYTES)
    end)
    for _, subtitle in ipairs(selectedSubtitles) do
    local stitle = (subtitle.title) and string.lower(subtitle.title) or nil
        if not ((subtitle.hearing_impaired) or (stitle and string.find(stitle, "sdh")) or (stitle and string.find(stitle, "cc"))) then
        subId = subtitle.id
        break
        end
    end
return (subId == 0) and subtitle[1].id or subId
end
return 0
end

function formatTrackData(track)
local dst = ""
if track.title then
dst = dst..string.format("'%s' ", track.title)
end
dst = dst.."("
if track.lang then
dst = dst..string.format("%s ", track.lang)
end
local codec = track.codec and track.codec or "<unknown>"
codec = (codec == "subrip") and "subrip [Advanced Sub Station Alpha]" or codec
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

--Functions

function setSubtitles()
local bottomSid, topSid = findSubtitle(splitString(options.preferredLanguages.bottom)), findSubtitle(splitString(options.preferredLanguages.top))
bottomSid               = (options.useTopAsBottom and bottomSid == 0 and topSid > 0) and topSid or bottomSid
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
mp.osd_message("Secondary: "..formatTrackData(subtitles[topSid]))
mp.set_property_native("secondary-sid", topSid)
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
mp.osd_message("Secondary: "..formatTrackData(subtitles[topSid]))
mp.set_property_native("secondary-sid", topSid)
end
end

function reverseSubtitles()
local bottomSid, topSid = mp.get_property_number("sid", 0), mp.get_property_number("secondary-sid", 0)
if bottomSid > 0 and topSid > 0 then
mp.set_property_native("sid",           0)
mp.set_property_native("secondary-sid", 0)
mp.set_property_native("sid",           topSid)
mp.set_property_native("secondary-sid", bottomSid)
local subInfo1 = subtitles[bottomSid]
local subInfo2 = subtitles[topSid]
mp.osd_message(string.format("Top: %s\nBottom: %s", formatTrackData(subInfo1), formatTrackData(subInfo2)))
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