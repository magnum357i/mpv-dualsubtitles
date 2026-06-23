--[[

https://github.com/magnum357i/mpv-dualsubtitles/

╔════════════════════════════════╗
║        MPV dualsubtitles       ║
║              v2.3.5            ║
╚════════════════════════════════╝

## Required ##
- FFmpeg (for merging)
- Subtitle Edit (for PGS to ASS)

## Codes ##
- Language list: https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes
- Region list: https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes

## CSV Data Source ##
- https://github.com/datasets/language-codes/blob/main/data/language-codes-3b2.csv

]]

local mp      = require "mp"
local options = require "mp.options"
local h       = require "helpers"
local dual    = require "dualsubtitles"

config = {

    --auto select
    top_languages          = "tr",
    bottom_languages       = "en:us,ja",
    preferred_words        = "",
    rejected_words         = "sign,song",
    use_top_as_bottom      = true,

    --hover for secondary
    secondary_on_hover     = false,
    hover_height_percent   = 50,

    --merged subtitle
    top_style              = "fn:Segoe UI Semibold,fs:65,1c:&H0000DEFF,2c:&H000000FF,3c:&H00000000,4c:&H00000000,b:0,i:0,u:0,s:0,sx:100,sy:100,fsp:0,frz:0,bs:1,bord:4,shad:0,an:8,ml:0,mr:0,mv:40,enc:1",
    bottom_style           = "fn:Calibri,fs:65,1c:&H00FFFFFF,2c:&H000000FF,3c:&H00000000,4c:&H00000000,b:0,i:0,u:0,s:0,sx:100,sy:100,fsp:0,frz:0,bs:1,bord:1.5,shad:0,an:2,ml:0,mr:0,mv:40,enc:1",
    top_tags               = "",
    bottom_tags            = "\\blur4",
    detect_italics         = true,
    keep_ts                = "none", --bottom, top, none
    remove_sdh_entries     = false,
    remove_repeating_lines = false,

    --misc
    expand_subtitle_search = false,
    copy_format            = "(%s) %s",
    save_filename          = "dual",
    save_path              = "" --<empty> = <temp> | video = <samefolderasvideo> | <yourpath>
}

options.read_options(config)

config.top_languages    = config.top_languages:lower():gsub("_", "-")
config.bottom_languages = config.bottom_languages:lower():gsub("_", "-")

local hideMode = 0
local cSubs    = {bottom = {}, top = {}}
local timer

local function setSubtitles()

    local ok

    ok = dual.loadMerged()

    if ok then return end

    ok = dual.load()

    if not ok then return end

    if config.use_top_as_bottom and not dual.bottom and dual.top then

        dual.set(dual.top.id, 0)
    end

    if config.secondary_on_hover and dual.bottom and dual.top then

        dual.toggle(1, 0)
    end

    dual.display()

    h.log(string.format("bottom %s, top %s", dual.bottom and dual.bottom.id or "not set", dual.top and dual.top.id or "not set"))
end

local function mergeSubtitles()

    dual.loadDefaults()
    dual.merge()
end

local function deleteMergedFile()

    local ok = dual.deleteMerged()

    if ok then

        h.notify("File deleted!", "deletemergedfile", "info")
    else

        h.notify("File not found!", "deletemergedfile", "error")
    end
end

local function swapSubtitles()

    if dual.isMergedSelected() then

        local overrideMode = mp.get_property("sub-ass-override", "")

        if not (overrideMode == "yes" or overrideMode == "scale") then h.notify("Style override functionality only works with \"--sub-ass-override=yes\" or \"--sub-ass-override=scale\".", "styleoverride", "warn", nil, true) end

        local overrides  = mp.get_property("sub-ass-style-overrides", "")
        local alignments = {

            ["2"] = "2",
            ["8"] = "6"
        }

        if not string.find(overrides, "Primary.Alignment=", 1, true) then

            overrides = dual.addStyleOverride(overrides, "Primary",   "Alignment", alignments["8"])
            overrides = dual.addStyleOverride(overrides, "Secondary", "Alignment", alignments["2"])
        else

            overrides = dual.addStyleOverride(overrides, "Primary",   "Alignment", nil)
            overrides = dual.addStyleOverride(overrides, "Secondary", "Alignment", nil)
        end

        mp.set_property("sub-ass-style-overrides", overrides)

        return
    end

    dual.loadDefaults()

    if dual.bottom and dual.top then

        local tempBottomSid = dual.bottom.id
        local tempTopSid    = dual.top.id

        dual.set(0, 0)
        dual.display()

        dual.set(tempTopSid, tempBottomSid)
        dual.display()

        mp.osd_message(string.format("Top: %s\nBottom: %s", tostring(dual.top), tostring(dual.bottom)))
    else

        mp.osd_message("Subtitles not swapped")
    end
end

local function hideSubtitles()

    if hideMode == 0 then

        hideMode = hideMode + 1

        dual.toggle(1,0)

        mp.osd_message("Only the bottom subtitle visible")
    elseif hideMode == 1 then

        hideMode = hideMode + 1

        dual.toggle(0,0)

        mp.osd_message("Subtitles hidden")
    elseif hideMode == 2 then

        hideMode = 0

        dual.toggle(1,1)

        mp.osd_message("Subtitles visible")
    end
end

local function copySubtitlesOnPress()

    mp.set_property_bool("pause", false)
    mp.osd_message("▶ Collecting subtitles...", 9999)

    local merged = dual.isMergedSelected()

    local parseMerged = function (text)

        local text1 = ""

        for line in text:gmatch("%{%*P[^%}]*%}([^\n]+)") do

            text1 = text1..line:gsub("%s*\\N%s*", " ").." "
        end

        local text2 = ""

        for line in text:gmatch("%{%*S[^%}]*%}([^\n]+)") do

            text2 = text2..line:gsub("%s*\\N%s*", " ").." "
        end

        text1 = text1:gsub("%s+$", "")
        text2 = text2:gsub("%s+$", "")

        return text1, text2
    end

    local visible1 = mp.get_property_bool("sub-visibility")
    local visible2 = mp.get_property_bool("secondary-sub-visibility")

    timer = mp.add_periodic_timer(0.1, function()

        local bottomText, topText

        if merged and visible1 then

            bottomText, topText = parseMerged(mp.get_property("sub-text/ass"))
        else

            bottomText = visible1 and mp.get_property("sub-text", "")           or ""
            topText    = visible2 and mp.get_property("secondary-sub-text", "") or ""
        end

        if bottomText ~= "" then

            if #cSubs.bottom == 0 or cSubs.bottom[#cSubs.bottom] ~= bottomText then

                table.insert(cSubs.bottom, bottomText)
            end
        end

        if topText ~= "" then

            if #cSubs.top == 0 or cSubs.top[#cSubs.top] ~= topText then

                table.insert(cSubs.top, topText)
            end
        end
    end)
end

local function copySubtitlesOnUp()

    if timer then timer:kill() timer = nil end

    mp.set_property_bool("pause", true)
    mp.osd_message("", 0)

    if #cSubs.bottom > 0 or #cSubs.top > 0 then

        dual.loadDefaults()

        local sanitize = function (text)

            text = text:gsub("\n", " ")
            text = text:gsub("%s+", " ")

            return text
        end

        for i, v in ipairs(cSubs.bottom) do cSubs.bottom[i] = sanitize(v) end
        for i, v in ipairs(cSubs.top)    do cSubs.top[i]    = sanitize(v) end

        local result

        if #cSubs.bottom > 0 and #cSubs.top > 0 then

            result = string.format(config.copy_format.."\n"..config.copy_format, (dual.top and dual.top.lang or "S"), table.concat(cSubs.top, " "), (dual.bottom and dual.bottom.lang or "P"), table.concat(cSubs.bottom, " "))
        else

            result = #cSubs.top > 0 and table.concat(cSubs.top, " ") or table.concat(cSubs.bottom, " ")
        end

        mp.osd_message("⏸ Stopped. Subtitles copied.", 3)

        h.setClipboard(result)
    else

        h.notify("No subtitles on screen.", "copysubtitles", "error")
    end

    h.clearTable(cSubs.bottom)
    h.clearTable(cSubs.top)
end

local function updateSubtitleList(_, tracks)

    dual.updateList(#tracks)
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

mp.add_key_binding("k",      "dualsubtitles_secondaryforward",     function() cycleSecondary(1) end)
mp.add_key_binding("K",      "dualsubtitles_secondarybackward",    function() cycleSecondary(2) end)
mp.add_key_binding("Ctrl+r", "dualsubtitles_increasesecondarypos", function() cycleSecondaryPosition(1) end, {repeatable = true})
mp.add_key_binding("Ctrl+R", "dualsubtitles_decreasesecondarypos", function() cycleSecondaryPosition(2) end, {repeatable = true})

mp.add_key_binding("v",      "dualsubtitles_hide",         hideSubtitles)
mp.add_key_binding("u",      "dualsubtitles_swap",         swapSubtitles)
mp.add_key_binding("Ctrl+b", "dualsubtitles_merge",        mergeSubtitles)
mp.add_key_binding("Ctrl+B", "dualsubtitles_deletemerged", deleteMergedFile)
mp.add_key_binding("Ctrl+C", "dualsubtitles_copy", function(state)

    if state.event == "down" then

        copySubtitlesOnPress()
    elseif state.event == "up" then

        copySubtitlesOnUp()
    end
end, {complex=true})

mp.observe_property("track-list", "native", updateSubtitleList)

if config.expand_subtitle_search then

    local basePaths = mp.get_property_native("sub-file-paths")

    mp.add_hook("on_load", 50, function ()

        local newPaths = {}
        local filename = mp.get_property("filename/no-ext")

        for _, p in ipairs(basePaths) do

            table.insert(newPaths, p)
            table.insert(newPaths, p.."/"..filename)
        end

        if next(newPaths) ~= nil then mp.set_property_native("sub-file-paths", newPaths) end
    end)
end

if config.secondary_on_hover then

    mp.observe_property("mouse-pos", "native", function(_, mouse)

        if mp.get_property_number("sid", 0) == 0 or not dual.isMergedSelected() and mp.get_property_number("secondary-sid", 0) == 0 then return end

        local windowHeight = mp.get_property_number("osd-height")
        local hoverArea    = (windowHeight * config.hover_height_percent) / 100

        if mouse.y >= 0 and mouse.y <= hoverArea then

            dual.toggle(1,1)
        else

            dual.toggle(1,0)
        end
    end)
end