preferredLanguages = {bottom = {"eng","jpn"}, top = {"tur"}}

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

function hasValue(items, search)
local result = false
local item
for _, item in ipairs(items) do
	if item == search then
    result = true
	break
	end
end
return result
end

function setSubtitles()
local subtitles = getSubtitleList()
local bottomSid = 0
local topSid    = 0
for _, subtitle in pairs(subtitles) do
    if bottomSid == 0 and hasValue(preferredLanguages["bottom"], subtitle["lang"]) then
    bottomSid = subtitle["id"]
    elseif topSid == 0 and hasValue(preferredLanguages["top"], subtitle["lang"]) then
    topSid = subtitle["id"]
    end
end
if bottomSid > 0 then mp.set_property_native("sid", bottomSid) end
if topSid > 0 then mp.set_property_native("secondary-sid", topSid) end
end

mp.register_event("file-loaded", setSubtitles)
