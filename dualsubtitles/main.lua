--[[

https://github.com/magnum357i/mpv-dualsubtitles/

╔════════════════════════════════╗
║        MPV dualsubtitles       ║
║              v2.2.0            ║
╚════════════════════════════════╝

## Required ##
FFmpeg (for subtitle merging)

## Standardized Codes ##
Languages (ISO 639): https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes
Countries (ISO 3166): https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes

## Language Reference ##
CSV Data: https://github.com/datasets/language-codes/blob/main/data/language-codes-3b2.csv
]]

local mp       = require "mp"
local options  = require "mp.options"
local h        = require "helpers"
local subtitle = require "dualsubtitles"

local config   = {

    bottom_languages     = "en-us,ja-jp",
    top_languages        = "tr-tr",
    ignored_words        = "sign,song",
    use_top_as_bottom    = true,

    secondary_on_hover   = false,
    hover_height_percent = 50,

    bottom_style         = "fn:Arial,fs:70,1c:&H00FFFFFF,2c:&H000000FF,3c:&H00000000,4c:&H00000000,b:0,i:0,u:0,s:0,sx:100,sy:100,fsp:0,frz:0,bs:1,bord:3,shad:0,an:2,ml:0,mr:0,mv:40,enc:1",
    top_style            = "fn:Arial,fs:70,1c:&H0000DEFF,2c:&H000000FF,3c:&H00000000,4c:&H00000000,b:0,i:0,u:0,s:0,sx:100,sy:100,fsp:0,frz:0,bs:1,bord:3,shad:0,an:8,ml:0,mr:0,mv:40,enc:1",
    keep_ts              = "none" --bottom, top, none
}

options.read_options(config, "dualsubtitles")

local hideMode = 0

subtitle.init(config)

local function setSubtitles()

    local ok

    ok = subtitle.loadMerged()

    if ok then return end

    ok = subtitle.load()

    if ok and subtitle.bottom and subtitle.top and subtitle.bottom.id == subtitle.top.id then

        h.notify("The IDs of the top and bottom subtitles are the same.", "sameinput", "warn")
    end

    if config.use_top_as_bottom and not subtitle.bottom and subtitle.top then

        subtitle.set(subtitle.top.id, 0)
    end

    if config.secondary_on_hover and subtitle.bottom and subtitle.top then

        subtitle.toggle(1, 0)
    end

    subtitle.display()

    h.log(string.format("bottom %s, top %s", subtitle.bottom and subtitle.bottom.id or "not set", subtitle.top and subtitle.top.id or "not set"))
end

local function deleteMergedFile()

    local ok

    ok = subtitle.deleteMerged()

    if ok then

        h.notify("File deleted!", "deletemergedfile", "info")
    else

        h.notify("File not found!", "deletemergedfile", "error")
    end
end

local function mergeSubtitles()

    subtitle.loadDefaults()
    subtitle.merge()
end

local function reverseSubtitles()

    subtitle.loadDefaults()

    if subtitle.bottom and subtitle.top then

        local tempBottomSid = subtitle.bottom.id
        local tempTopSid    = subtitle.top.id

        subtitle.set(0, 0)
        subtitle.display()

        subtitle.set(tempTopSid, tempBottomSid)
        subtitle.display()

        mp.osd_message(string.format("Top: %s\nBottom: %s", tostring(subtitle.top), tostring(subtitle.bottom)))
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
mp.add_key_binding("Ctrl+r", "increasesecondaryposition", function() cycleSecondaryPosition(1) end, {repeatable = true})
mp.add_key_binding("Ctrl+R", "decreasesecondaryposition", function() cycleSecondaryPosition(2) end, {repeatable = true})

mp.add_key_binding("v",      "hidesubtitles",    hideSubtitles)
mp.add_key_binding("u",      "reversesubtitles", reverseSubtitles)
mp.add_key_binding("Ctrl+b", "mergesubtitles",   mergeSubtitles)
mp.add_key_binding("Ctrl+B", "deletemergedfile", deleteMergedFile)

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