--[[

https://github.com/magnum357i/mpv-dualsubtitles/

╔════════════════════════════════╗
║        MPV dualsubtitles       ║
║              v2.1.4            ║
╚════════════════════════════════╝

## Standardized Codes ##
Languages (ISO 639): https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes
Countries (ISO 3166): https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes

## Language Reference ##
CSV Data: https://github.com/datasets/language-codes/blob/main/data/language-codes-3b2.csv
]]

local mp       = require "mp"
local h        = require "helpers"
local subtitle = require "subtitle"

local options = {
    preferredLanguages = {bottom = "en-us,ja-jp", top = "tr-tr"},
    ignoredWords       = "sign,song",
    useTopAsBottom     = true,
    secondaryOnHover   = false,
    hoverHeightPercent = 50
}

local hideMode = 0

subtitle.init(options)

local function setSubtitles()

    subtitle.load()

    if options.useTopAsBottom and subtitle.bottomSid == 0 and subtitle.topSid > 0 then

        subtitle.bottomSid = subtitle.topSid
        subtitle.topSid    = 0
    end

    if options.secondaryOnHover and subtitle.bottomSid > 0 and subtitle.topSid > 0 then

        subtitle.toggle(1,0)
    end

    subtitle.set()

    h.log(string.format("bottom %s, top %s", (subtitle.bottomSid > 0) and subtitle.bottomSid or "not set", (subtitle.topSid > 0) and subtitle.topSid or "not set"))
end

local function secondaryForward()

    subtitle.loadDefaults()

    subtitle.topSid = subtitle.topSid + 1

    if subtitle.bottomSid > 0 and subtitle.topSid == subtitle.bottomSid then subtitle.topSid = subtitle.topSid + 1 end
    if subtitle.topSid > subtitle.count()                               then subtitle.topSid = 0                   end

    subtitle.set(2)

    if subtitle.topSid == 0 then

        mp.osd_message("Secondary: no")
    else

        mp.osd_message("Secondary: "..subtitle.format(2))
    end
end

local function secondaryBackward()

    subtitle.loadDefaults()

    subtitle.topSid = subtitle.topSid - 1

    if subtitle.topSid < 0                                              then subtitle.topSid = subtitle.count()    end
    if subtitle.bottomSid > 0 and subtitle.topSid == subtitle.bottomSid then subtitle.topSid = subtitle.topSid - 1 end

    subtitle.set(2)

    if subtitle.topSid == 0 then

        mp.osd_message("Secondary: no")
    else

        mp.osd_message("Secondary: "..subtitle.format(2))
    end
end

local function reverseSubtitles()

    subtitle.loadDefaults()

    if subtitle.bottomSid > 0 and subtitle.topSid > 0 then

        local tempBottomSid = subtitle.bottomSid
        local tempTopSid    = subtitle.topSid

        subtitle.bottomSid  = 0
        subtitle.topSid     = 0

        subtitle.set()

        subtitle.bottomSid  = tempTopSid
        subtitle.topSid     = tempBottomSid

        subtitle.set()

        mp.osd_message(string.format("Top: %s\nBottom: %s", subtitle.format(2), subtitle.format(1)))
    else

        mp.osd_message("Subtitles not reversed")
    end
end

local function hideSubtitles()

    if hideMode == 0 then

        hideMode = hideMode + 1

        subtitle.toggle(1,0)

        mp.osd_message("Only the bottom subtitle visible")
    elseif hideMode == 1 then

        hideMode = hideMode + 1

        subtitle.toggle(0,0)

        mp.osd_message("Subtitles hidden")
    elseif hideMode == 2 then

        hideMode = 0

        subtitle.toggle(1,1)

        mp.osd_message("Subtitles visible")
    end
end

local function updateSubtitleList(_, tracks)

    subtitle.updateList(tracks)
end

mp.register_event("file-loaded", setSubtitles)

mp.add_key_binding("k", "secondaryforward",  secondaryForward)
mp.add_key_binding("K", "secondarybackward", secondaryBackward)
mp.add_key_binding("u", "reversesubtitles",  reverseSubtitles)
mp.add_key_binding("v", "hidesubtitles",     hideSubtitles)

mp.observe_property("track-list", "native", updateSubtitleList)

if options.secondaryOnHover then

    local function showSecondaryOnHover(_, mouse)

        if not mp.get_property_number("secondary-sid", 0) then return end

        local windowHeight = mp.get_property_number("osd-height")
        local hoverArea    = (windowHeight * options.hoverHeightPercent) / 100

        if mouse.y >= 0 and mouse.y <= hoverArea then

            subtitle.toggle(1,1)
        else

            subtitle.toggle(1,0)
        end
    end

    mp.observe_property("mouse-pos", "native", showSecondaryOnHover)
end