--[[

https://github.com/magnum357i/mpv-dualsubtitles/

╔════════════════════════════════╗
║        MPV dualsubtitles       ║
║              v2.1.6            ║
╚════════════════════════════════╝

## Standardized Codes ##
Languages (ISO 639): https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes
Countries (ISO 3166): https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes

## Language Reference ##
CSV Data: https://github.com/datasets/language-codes/blob/main/data/language-codes-3b2.csv
]]

local mp       = require "mp"
local options  = require "mp.options"
local h        = require "helpers"
local subtitle = require "subtitle"

local config = {
    bottom_languages     = "en-us,ja-jp",
    top_languages        = "tr-tr",
    ignored_words        = "sign,song",
    use_top_as_bottom    = true,
    secondary_on_hover   = false,
    hover_height_percent = 50
}

options.read_options(config, "dualsubtitles")

local hideMode = 0

subtitle.init(config)

local function setSubtitles()

    subtitle.load()

    if config.use_top_as_bottom and subtitle.bottomSid == 0 and subtitle.topSid > 0 then

        subtitle.bottomSid = subtitle.topSid
        subtitle.topSid    = 0
    end

    if config.secondary_on_hover and subtitle.bottomSid > 0 and subtitle.topSid > 0 then

        subtitle.toggle(1,0)
    end

    subtitle.set()

    h.log(string.format("bottom %s, top %s", (subtitle.bottomSid > 0) and subtitle.bottomSid or "not set", (subtitle.topSid > 0) and subtitle.topSid or "not set"))
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

local function cycleSecondary(mode)

    if mode == 1 then

        mp.command("cycle secondary-sid")
    else

        mp.command("cycle secondary-sid down")
    end
end

local function cycleSecondaryPosition(mode)

    if mode == 1 then

        mp.command("add secondary-sub-pos +1")
    else

        mp.command("add secondary-sub-pos -1")
    end
end

mp.register_event("file-loaded", setSubtitles)

mp.add_key_binding("k",      "secondaryforward",          function() cycleSecondary(1) end)
mp.add_key_binding("K",      "secondarybackward",         function() cycleSecondary(2) end)
mp.add_key_binding("ctrl+r", "increasesecondaryposition", function() cycleSecondaryPosition(1) end, {repeatable = true})
mp.add_key_binding("ctrl+R", "decreasesecondaryposition", function() cycleSecondaryPosition(2) end, {repeatable = true})

mp.add_key_binding("v", "hidesubtitles",    hideSubtitles)
mp.add_key_binding("u", "reversesubtitles", reverseSubtitles)

mp.observe_property("track-list", "native", updateSubtitleList)

if config.secondary_on_hover then

    local function showSecondaryOnHover(_, mouse)

        if not mp.get_property_number("secondary-sid", 0) then return end

        local windowHeight = mp.get_property_number("osd-height")
        local hoverArea    = (windowHeight * config.hover_height_percent) / 100

        if mouse.y >= 0 and mouse.y <= hoverArea then

            subtitle.toggle(1,1)
        else

            subtitle.toggle(1,0)
        end
    end

    mp.observe_property("mouse-pos", "native", showSecondaryOnHover)
end