--User Settings
--For ISO codes: https://www.wikiwand.com/en/articles/List_of_ISO_639_language_codes

options = {
    preferredLanguages = {bottom = "en,ja,jpn", top = "tr,tur"},
    ignoredSubtitles   = "sign,song",
}

--Global Variables

hideMode      = 0
subtitleCount = 0

--Helpers

function splitString(str)
local list = {}
for val in string.gmatch(str, "([^,]+)") do
table.insert(list, val)
end
return list
end

function getSubtitleList()
local list = {}
local index, value
for index, value in pairs(mp.get_property_native("track-list")) do
    if value.type == "sub" then
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
return subtitles[sid]
end

function filterSubtitle(subtitle)
local stitle = (subtitle.title) and string.lower(subtitle.title) or nil
if subtitle.forced or stitle and string.match(stitle, "forced") then
return false
end
if stitle and hasValue(splitString(options.ignoredSubtitles), stitle) then
return false
end
return true
end

function findSubtitle(languageCodes, subtitles)
local selectedSubtitles = {}
local firstFoundedLang  = ""
for _, userLang in ipairs(languageCodes) do
    for _, subtitle in pairs(subtitles) do
        if firstFoundedLang ~= "" and subtitle.lang ~= firstFoundedLang then break end
        if string.match(subtitle.lang, userLang) and filterSubtitle(subtitle) then
        firstFoundedLang = subtitle.lang
        table.insert(selectedSubtitles, subtitle)
        end
    end
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
        if not ((subtitle.hearing_impaired) or (stitle and string.match(stitle, "sdh")) or (stitle and string.match(stitle, "cc"))) then
        subId = subtitle.id
        break
        end
    end
return (subId == 0) and subtitle[1].id or subId
end
return 0
end

--Functions

function setSubtitles()
local subtitles         = getSubtitleList()
local bottomSid, topSid = findSubtitle(splitString(options.preferredLanguages.bottom), subtitles), findSubtitle(splitString(options.preferredLanguages.top), subtitles)
subtitleCount           = #subtitles
if bottomSid > 0 then mp.set_property_native("sid",           bottomSid) end
if topSid > 0    then mp.set_property_native("secondary-sid", topSid)    end
print(string.format("bottom %s, top %s", (bottomSid > 0) and bottomSid or "not set", (topSid > 0) and topSid or "not set"))
end

function switchForwardForSecondary()
local bottomSid, topSid = mp.get_property_number("sid"), mp.get_property_number("secondary-sid", 0)
topSid                  = topSid + 1
if topSid == bottomSid then topSid = topSid + 1 end
if topSid > subtitleCount then
mp.set_property_native("secondary-sid", 0)
mp.osd_message("Secondary: no")
else
local subtitleInfo = getSubtitleInfo(topSid)
    if subtitleInfo.title then
    mp.osd_message(string.format("Secondary: (%s) %s (\"%s\")", subtitleInfo.id, subtitleInfo.lang, subtitleInfo.title))
    else
    mp.osd_message(string.format("Secondary: (%s) %s", subtitleInfo.id, subtitleInfo.lang))
    end
mp.set_property_native("secondary-sid", topSid)
end
end

function switchBackwardForSecondary()
local bottomSid, topSid = mp.get_property_number("sid"), mp.get_property_number("secondary-sid", subtitleCount + 1)
topSid                  = topSid - 1
if topSid == bottomSid then topSid = topSid - 1 end
if topSid == 0 then
mp.set_property_native("secondary-sid", 0)
mp.osd_message("Secondary: no")
else
local subtitleInfo = getSubtitleInfo(topSid)
    if subtitleInfo.title then
    mp.osd_message(string.format("Secondary: (%s) %s (\"%s\")", subtitleInfo.id, subtitleInfo.lang, subtitleInfo.title))
    else
    mp.osd_message(string.format("Secondary: (%s) %s", subtitleInfo.id, subtitleInfo.lang))
    end
mp.set_property_native("secondary-sid", topSid)
end
end

function reverseSubtitles()
local bottomSid, topSid = mp.get_property_number("sid", 0), mp.get_property_number("secondary-sid", 0)
if bottomSid > 0 and topSid > 0 then
mp.set_property_native("sid", 0)
mp.set_property_native("secondary-sid", 0)
mp.set_property_native("sid", topSid)
mp.set_property_native("secondary-sid", bottomSid)
local subInfo1 = getSubtitleInfo(bottomSid)
local subInfo2 = getSubtitleInfo(topSid)
mp.osd_message(string.format("Top Subtitle: (%s) %s\nBottom Subtitle: (%s) %s", subInfo1.id, subInfo1.lang, subInfo2.id, subInfo2.lang))
else
mp.osd_message("Subtitles not reversed")
end
end

function hideSubtitles()
if hideMode == 0 then
hideMode = hideMode + 1
mp.set_property_native("sub-visibility", "yes")
mp.set_property_native("secondary-sub-visibility", "no")
mp.osd_message("Only the bottom subtitle visible")
elseif hideMode == 1 then
hideMode = hideMode + 1
mp.set_property_native("sub-visibility", "no")
mp.set_property_native("secondary-sub-visibility", "no")
mp.osd_message("Subtitles hidden")
elseif hideMode == 2 then
hideMode = 0
mp.set_property_native("sub-visibility", "yes")
mp.set_property_native("secondary-sub-visibility", "yes")
mp.osd_message("Subtitles visible")
end
end

mp.add_key_binding("k", "switchforwardforsecondary", switchForwardForSecondary)
mp.add_key_binding("K", "switchbackwardforsecondary", switchBackwardForSecondary)
mp.add_key_binding("u", "reversesubtitles", reverseSubtitles)
mp.add_key_binding("v", "hidesubtitles", hideSubtitles)

mp.register_event("file-loaded", setSubtitles)