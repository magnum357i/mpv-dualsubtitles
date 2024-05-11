--User Settings

options = {
    preferredLanguages = {bottom = {"eng","jpn"}, top = {"tur"}},
    skipIgnoredSubtitles = true,
    ignoredubtitleMatch = {"signs", "songs", "forced"}
}

--Global Variables

reversed = false
hided = false
hbid = 0
htid = 0
subtitleCount = 0

--Helpers

function getSubtitleList()
local list = {}
local index, value
for index, value in pairs(mp.get_property_native("track-list")) do
    if value["type"] == "sub" then
    table.insert(list, value)
    end
end
return list
end

function hasValue(items, value)
local result = false
local item
value = string.lower(value)
for _, item in pairs(items) do
	if string.match(value, item) then
    result = true
	break
	end
end
return result
end

function getSubtitleInfo(sid)
local subtitles = getSubtitleList()
local result
for _, subtitle in pairs(subtitles) do
    if subtitle["id"] == sid then
    result = subtitle
    break
    end
end
return result
end

--Functions

function setSubtitles()
local subtitles = getSubtitleList()
local bottomSid, topSid = 0, 0
subtitleCount = #subtitles
for _, userBottomLang in ipairs(options.preferredLanguages["bottom"]) do
    for _, subtitle in pairs(subtitles) do
        if userBottomLang == subtitle["lang"] and (options.skipIgnoredSubtitles and subtitle["title"] ~= nil and not hasValue(options.ignoredubtitleMatch, subtitle["title"])) then
        bottomSid = subtitle["id"]
        break
        end
    end
if bottomSid > 0 then break end
end
for _, userTopLang in ipairs(options.preferredLanguages["top"]) do
    for _, subtitle in pairs(subtitles) do
        if userTopLang == subtitle["lang"] and (options.skipIgnoredSubtitles and subtitle["title"] ~= nil and not hasValue(options.ignoredubtitleMatch, subtitle["title"])) then
        topSid = subtitle["id"]
        break
        end
    end
if topSid > 0 then break end
end
if bottomSid > 0 then mp.set_property_native("sid", bottomSid) end
if topSid > 0 then mp.set_property_native("secondary-sid", topSid) end
end

function switchForSecondary()
local bottomSid, topSid = mp.get_property_number("sid"), mp.get_property_number("secondary-sid", 0)
topSid = topSid + 1
if topSid == bottomSid then topSid = topSid + 1 end
if topSid > subtitleCount then
mp.set_property_native("secondary-sid", 0)
mp.osd_message("Secondary: no")
else
local subtitleInfo = getSubtitleInfo(topSid)
    if subtitleInfo["title"] then
    mp.osd_message(string.format("Secondary: (%s) %s (\"%s\")", subtitleInfo["id"], subtitleInfo["lang"], subtitleInfo["title"]))
    else
    mp.osd_message(string.format("Secondary: (%s) %s", subtitleInfo["id"], subtitleInfo["lang"]))
    end
mp.set_property_native("secondary-sid", topSid)
end
end

function reverseSubtitles()
local bottomSid, topSid = mp.get_property_number("sid", 0), mp.get_property_number("secondary-sid", 0)
if bottomSid > 0 and topSid > 0 then
mp.set_property_native("sid", 0)
mp.set_property_native("secondary-sid", 0)
    if reversed then
    reversed = false
    mp.set_property_native("sid", bottomSid)
    mp.set_property_native("secondary-sid", topSid)
    else
    reversed = true
    mp.set_property_native("sid", topSid)
    mp.set_property_native("secondary-sid", bottomSid)
    end
mp.osd_message("Subtitles reversed")
else
mp.osd_message("Subtitles not reversed")
end
end

function hideSubtitles()
if hided then
hided = false
mp.set_property_native("sid", hbid)
mp.set_property_native("secondary-sid", htid)
mp.osd_message("Subtitles visible")
else
local bottomSid, topSid = mp.get_property_number("sid", 0), mp.get_property_number("secondary-sid", 0)
hided = true
hbid = bottomSid
htid = topSid
mp.set_property_native("sid", 0)
mp.set_property_native("secondary-sid", 0)
mp.osd_message("Subtitles hidden")
end
end

mp.add_key_binding("k", "switchforsecondary", switchForSecondary)
mp.add_key_binding("u", "reversesubtitles", reverseSubtitles)
mp.add_key_binding("v", "hidesubtitles", hideSubtitles)

mp.register_event("file-loaded", setSubtitles)
