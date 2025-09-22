local mp        = require "mp"
local msg       = require "mp.msg"
local utils     = require "mp.utils"
local h         = require "helpers"
local subtitle  = require "subtitle"
local resampler = require "resampler"
local assline   = require "assline"

local this      = {

    isWindows      = package.config:sub(1, 1) ~= '/',
    seperator      = isWindows and "//" or "\\",
    subtitles      = {},
    prevTrackCount = 0,
    config         = {},
    bottom         = nil,
    top            = nil,
    merged         = nil,
    cacheDir       = "mpvdualsubtitles",
    hash           = nil,
    paths          = {

        temp   = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp",
        script = "~~/scripts/dualsubtitles",
        config = "~~/script-opts"
    },
    files          = {

        bottom   = "primary",
        top      = "secondary",
        merged   = "merged",
        language = "cachedlanguages"
    }
}

local function filterSubtitle(subtitle,wordstofilter)

    local stitle = subtitle.title and subtitle.title:lower() or nil

    if subtitle.forced and not subtitle.default          then return false end
    if stitle and h.searchStrings(stitle, wordstofilter) then return false end

    return true
end

local function hasItalic(text)

    --sdh
    text = text:gsub("^%s*%[.-%]", "")
    text = text:gsub("^%s*\\N", "")

    text = "{}"..text
    text = text:gsub("}%s*{", "")
    text = text:match("^[^%}]+")

    if text and text:find("\\i1") then return true end

    return false
end

local function sdhKiller(text)

    local count             = 0
    local soundDescriptions = "[%[%(].-[%]%)]"
    local speakerDash       = "%s*%-%s*"

    --sound descriptions with speaker lines (two lines)
    text, count = text:gsub("^"..speakerDash..soundDescriptions.."%s*\\N"..speakerDash..soundDescriptions.."%s*$", "")

    if count > 0 then return "" end

    --sound descriptions with speaker lines (first line)
    text = text:gsub("^"..speakerDash..soundDescriptions.."%s*\\N%s*%-%s-", "")

    --sound descriptions with speaker lines (second line)
    text, count = text:gsub(speakerDash..soundDescriptions.."%s*$", "")

    if count > 0 then

        text = text:gsub("^"..speakerDash, "")
    end

    --sound descriptions
    text = text:gsub("%s*"..soundDescriptions.."%s*", " ")

    --speaker names
    text = text:gsub("\\N"..speakerDash.."[^:]*:%s*", "\\N- ")
    text = text:gsub("^"..speakerDash.."[^:]*:%s*", "- ")

    --fixes
    text = text:gsub("^[^:]*:%s*", "")
    text = text:gsub("^%s*\\N%s*", "")
    text = text:gsub("%s*\\N%s*$", "")
    text = text:gsub("^"..speakerDash.."$", "")

    --trim
    text = text:match("^%s*(.-)%s*$")

    return text
end

local function getSubtitleList()

    local list   = {}
    local tracks = mp.get_property_native('track-list')

    for index, value in ipairs(tracks) do

        if value.type == "sub" then

            table.insert(list, subtitle:new(value))
        end
    end

    this.prevTrackCount = #tracks

    return list
end

local function checkPath(path)

    local ok = os.rename(path, path)

    return ok
end

local function removePath(path)

    local info = utils.file_info(path)

    if not info then return false end

    if info.is_file then

        os.remove(path)
    else

        if this.isWindows then

            h.runCommand({"powershell", "-NoProfile", "-Command", string.format("Remove-Item -Recurse -Force -LiteralPath \"%s\"", path)})
        else

            h.runCommand({"rm", "-rf", path})
        end
    end

    return true
end

local function getSidByLanguage(languageCodes)

    local selectedSubtitles = {}
    local founded           = false
    local unwantedSubtitles = h.splitString(this.config.ignored_words)
    local missingMetadata   = false

    for _, userLang in ipairs(languageCodes) do

        for _, subtitle in ipairs(this.subtitles) do

            if subtitle.lang and subtitle.lang:lower() == userLang and filterSubtitle(subtitle, unwantedSubtitles) then

                founded = true
                table.insert(selectedSubtitles, subtitle)

                if subtitle.size == 0 and not missingMetadata then missingMetadata = true end
            end
        end

        if founded then break end
    end

    if #selectedSubtitles > 1 and missingMetadata then h.notify("There are subtitles with missing metadata.", "findsubtitle", "warn") end

    local subId = (#selectedSubtitles > 0) and selectedSubtitles[1].id or 0

    if #selectedSubtitles > 1 then

        table.sort(selectedSubtitles, function(a, b)

            return tonumber(a.size) > tonumber(b.size)
        end)

        for _, subtitle in ipairs(selectedSubtitles) do

            if not subtitle.hearingimpaired then

                subId = subtitle.id
                break
            end
        end
    end

    return subId
end

local function getLanguageMap(allLanguages)

    local handle
    local configFileInfo = utils.file_info(this.getPath("configfile"))
    local cacheFileInfo  = utils.file_info(this.getPath("cache/languagefile"))

    if not configFileInfo then configFileInfo = utils.file_info(this.getPath("scriptfile")) end
    if configFileInfo and cacheFileInfo and tonumber(configFileInfo.mtime) > tonumber(cacheFileInfo.mtime) then removePath(this.getPath("cache/languagefile")) end

    handle = io.open(this.getPath("cache/languagefile"), "r")

    if handle then

        local content = handle:read("*a")

        handle:close()

        return utils.parse_json(content)
    end

    local map = {}
    handle    = io.open(this.getPath("csvfile"), "r")

    if not handle then

        h.notify("Language map file not found! A file named 'language-codes-3b2.csv' must be placed in the plugin directory.", "languagecache", "warn")
    else

        local isFilled = false
        allLanguages   = h.splitString(allLanguages)
        local langKeys = {}

        for _, lang in ipairs(allLanguages) do

            table.insert(langKeys, lang:find("-") and lang:gsub("%-.+","") or lang)
        end

        for line in handle:lines() do

            local iso3, iso2, title = line:gsub('"', ''):gsub('[;,]?%s.+', ''):match("([^,]+),([^,]+),([^,]+)")

            if title and h.hasItem(langKeys, iso2) then

                map[iso2] = {iso3, title}

                if not isFilled then isFilled = true end
            end
        end

        handle:close()

        if isFilled then

            local tempPath = this.getPath("cache")

            if not checkPath(tempPath) then

                if this.isWindows then

                    h.runCommand({"powershell", "-NoProfile", "-Command", "mkdir", tempPath})
                else

                    h.runCommand({"mkdir", "-p", tempPath})
                end
            end

            handle = io.open(this.getPath("cache/languagefile"), "w")

            if handle then

                handle:write(utils.format_json(map))
                handle:close()
            else

                h.notify("Failed to create the cache file. Required for performance.", "languagecache", "error")
            end
        else

            h.notify("You entered invalid languages, or the CSV file is broken.", "languagecache", "error")
        end
    end

    return map
end

local function mergeLanguages(preferred, map)

    local languages = {}
    preferred       = h.splitString(preferred:gsub("_","-"))

    for _, value in ipairs(preferred) do

        local langCode, langCountry = value:lower():match("([^%-][^%-])%-([^%-][^%-])")

        if langCode and langCountry then

            table.insert(languages, value)
            table.insert(languages, langCode)

            if map and map[langCode] then

                table.insert(languages, map[langCode][1]:lower())
                table.insert(languages, map[langCode][2]:lower())
            elseif #map > 0 then

                h.notify(string.format("Unrecognized language code: %s", value), "languagecache", "warn")
            end
        else

            table.insert(languages, value)
        end
    end

    h.log(languages)

    return languages
end

local function copySubtitleToTemp(subtitle, key)

    local sourceFile = subtitle.path
    local targetFile = this.getPath("cache/"..key.."file")

    if subtitle.ext == ".ass" then

        if this.isWindows then

            h.runCommand({"powershell", "-NoProfile", "-Command", string.format("Copy-Item -LiteralPath \"%s\" -Destination \"%s\" -Force", sourceFile, targetFile)})
        else

            h.runCommand({"cp", sourceFile, targetFile})
        end
    else

        h.runCommand({"ffmpeg", "-i", sourceFile, "-c:s", "ass", targetFile})
    end

    return checkPath(targetFile)
end

local function mergeSubtitles()

    local data = {

        {path = this.getPath("cache/bottomfile"), style = "Primary",   subType = "bottom"},
        {path = this.getPath("cache/topfile"),    style = "Secondary", subType = "top"}
    }

    local file
    local styles = {}
    local lines  = {}
    local scount = 0

    for _, v in ipairs(data) do

        file = io.open(v.path, "r")

        if file then

            local content = file:read("*all")

            file:close()

            local playResX, playResY, canResample
            local italicStyles = {}

            if this.config.keep_ts == v.subType then

                playResX    = content:match("PlayResX: (%d+)") or 0
                playResY    = content:match("PlayResY: (%d+)") or 0
                canResample = (tonumber(playResX) == 1920 and tonumber(playResY) == 1080) and false or true

                if canResample then resampler.setResolutions(playResX, playResY, 1920, 1080) end

                for style in content:gmatch("Style:[^\n]+") do

                    style = assline:new(style)

                    if style then

                        if this.config.detect_italics and style.Italic then table.insert(italicStyles, style.Name) end

                        style.Name = v.style..style.Name

                        if canResample then

                            style = resampler.resampleStyle(style)
                        end

                        table.insert(styles, style:raw())
                    end
                end
            end

            local makeItalic, seen = false, {}

            for line in content:gmatch("Dialogue:[^\n]+") do

                local prevStyle

                line = assline:new(line)

                if line then

                    local deleteThis = false

                    if this.config.keep_ts == v.subType and line:isSign() then

                        line.Style = v.style..line.Style

                        if canResample then

                            line = resampler.resampleDialogue(line)
                        end
                    elseif not line:isShape() then

                        local text = line:strippedText()

                        if this.config.remove_repeating_lines then

                            local sKey = tostring(line.Start)..tostring(line.End)

                            if seen[sKey] and seen[sKey] == text then

                                deleteThis = true

                                goto continue
                            else

                                seen[sKey] = text
                            end
                        end

                        if this.config.detect_italics then

                            if prevStyle ~= line.Style and h.hasItem(italicStyles, line.Style) then

                                makeItalic = true
                            else

                                makeItalic = false
                            end

                            makeItalic = makeItalic or hasItalic(line.Text)
                        end

                        if this.config.remove_sdh_entries then

                            text = sdhKiller(text)

                            if text == "" then

                                deleteThis = true

                                goto continue
                            end
                        end

                        if this.config[v.subType.."_tags"] ~= "" then

                            text = string.format("{%s}%s", this.config[v.subType.."_tags"], text)
                        end

                        if makeItalic then

                            text = string.format("{%s}%s", "\\i1", text):gsub("}{", "")
                        end

                        --for copy
                        text = string.format("{*%s}%s", v.style:sub(1,1), text):gsub("}{", "")

                        line.Layer = 0
                        line.Style = v.style
                        line.Text  = text
                    end

                    ::continue::

                    if not deleteThis then table.insert(lines, line:raw()) end

                    prevStyle = line.Style
                end
            end

            if #lines > 0 then scount = scount + 1 end

            removePath(v.path)
        end
    end

    if scount ~= 2 then

        h.notify("There is a missing or corrupted subtitle.", "mergesubtitles", "error", 30)

        return false
    end

    local header = [[
[Script Info]
Title: New subtitles
ScriptType: v4.00+
WrapStyle: 0
PlayResX: 1920
PlayResY: 1080
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Primary,<style1>
Style: Secondary,<style2>
<extrastyles>

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text

]]

    header = header:gsub("<style1>", this.config.bottom_style:gsub("[^,]*:", ""))
    header = header:gsub("<style2>", this.config.top_style:gsub("[^,]*:", ""))

    if #styles > 0 then

        header = header:gsub("<extrastyles>", table.concat(styles, "\n"))
    else

        header = header:gsub("\n<extrastyles>", "")
    end

    file = io.open(this.getPath("cache/mergedfile"), "w")

    file:write(header)

    for _, line in ipairs(lines) do file:write(line.."\n") end

    file:close()

    return true
end

local mergeStart

local function tryMerge()

    local ok, err = pcall(mergeSubtitles)

    if ok then

        this.set(0, 0)
        this.display()

        mp.commandv("sub-add", this.getPath("cache/mergedfile"))
        this.updateList(0)

        this.merged   = this.subtitles[mp.get_property_number("sid")]
        local elapsed = mp.get_time() - mergeStart

        h.notify(string.format("Subtitles merged. Took %d seconds.", elapsed), "mergesubtitles", "info", 30)
    else

        h.notify(err, "mergesubtitles", "error")
        h.notify("See the console for details.", "mergesubtitles", "error")
    end
end

function this.deleteMerged()

    if not this.merged then return false end

    mp.commandv("sub-remove", this.merged.id)

    removePath(this.getPath("cache/merge"))

    this.merged = nil

    return true
end

function this.merge()

    if not (this.bottom and this.top) then

        h.notify("Two subtitles are required to merge.", "mergesubtitles", "error")

        return false
    end

    if not this.bottom.textbased or not this.top.textbased then

        h.notify("One of the selected subtitles is not text-based.", "mergesubtitles", "error")

        return false
    end

    h.notify("Please wait...", "mergesubtitles", "info", 9999)

    mergeStart     = mp.get_time()
    local tempPath = this.getPath("cache/merge")

    if not checkPath(tempPath) then

        if this.isWindows then

            h.runCommand({"powershell", "-NoProfile", "-Command", "mkdir", tempPath})
        else

            h.runCommand({"mkdir", "-p", tempPath})
        end
    end

    local remainingSubtitles = 2
    local copyError          = false

    for _, value in ipairs({"bottom", "top"}) do

        if this[value].external then

            if copySubtitleToTemp(this[value], value) then

                remainingSubtitles = remainingSubtitles - 1
            else

                copyError = true
            end
        end
    end

    if copyError then

        h.notify("Subtitles could not be copied.", "mergesubtitles", "error")

        return false
    end

    if remainingSubtitles == 0 then

        tryMerge()

        return true
    end

    local args = {}

    table.insert(args, "ffmpeg")
    table.insert(args, "-i")
    table.insert(args, this.getPath("videofile"))

    if this.bottom and not this.bottom.external then

        table.insert(args, "-map")
        table.insert(args, string.format("0:s:%s", this.bottom.id - 1))
        table.insert(args, "-c:s")
        table.insert(args, "ass")
        table.insert(args, this.getPath("cache/bottomfile"))
    end

    if this.top and not this.top.external then

        table.insert(args, "-map")
        table.insert(args, string.format("0:s:%s", this.top.id - 1))
        table.insert(args, "-c:s")
        table.insert(args, "ass")
        table.insert(args, this.getPath("cache/topfile"))
    end

    table.insert(args, "-vn")
    table.insert(args, "-an")
    table.insert(args, "-dn")
    table.insert(args, "-y")

    local ffmpegCommand = {

        name           = "subprocess",
        capture_stdout = true,
        capture_stderr = true,
        playback_only  = false,
        args           = args
    }

    local onSubtitleFail = function (result)

        if string.match(result, "No such file or directory") then

            h.notify("No such file or directory.", "mergesubtitles", "error")
        elseif string.match(result, "Failed to set value") then

            h.notify("Wrong subtitle id.", "mergesubtitles", "error")
        else

            h.log(result)
            h.notify("See the console for details.", "mergesubtitles", "error")
        end
    end

    h.runAsync(ffmpegCommand, tryMerge, onSubtitleFail)

    return true
end

function this.isMergedSelected()

    local currentSid = mp.get_property_number("sid", 0)

    return (this.merged and currentSid == this.merged.id)
end

function this.getPath(key)

    this.hash = this.hash or h.hash(mp.get_property("path"))

    local fullPath

    if key == "csvfile" then

        fullPath = utils.join_path(this.paths.script, "language-codes-3b2.csv")
    elseif key == "scriptfile" then

        fullPath = utils.join_path(this.paths.script, "main.lua")
    elseif key == "configfile" then

        fullPath = utils.join_path(this.paths.config, "dualsubtitles.conf")
    elseif key == "videofile" then

        fullPath = mp.get_property("path")
    elseif key == "cache/languagefile" then

        fullPath = utils.join_path(this.paths.temp, this.cacheDir..this.seperator..this.files.language..".json")
    elseif key == "cache" then

        fullPath = utils.join_path(this.paths.temp, this.cacheDir)
    elseif key == "cache/merge" then

        fullPath = utils.join_path(this.paths.temp, this.cacheDir..this.seperator..this.hash)
    elseif key == "cache/bottomfile" then

        fullPath = utils.join_path(this.paths.temp, this.cacheDir..this.seperator..this.hash..this.seperator..this.files.bottom..".ass")
    elseif key == "cache/topfile" then

        fullPath = utils.join_path(this.paths.temp, this.cacheDir..this.seperator..this.hash..this.seperator..this.files.top..".ass")
    elseif key == "cache/mergedfile" then

        fullPath = utils.join_path(this.paths.temp, this.cacheDir..this.seperator..this.hash..this.seperator..this.files.merged..".ass")
    end

    fullPath = fullPath:gsub("\\", "/")
    fullPath = mp.command_native({'expand-path', fullPath})

    return fullPath
end

function this.updateList(trackcount)

    if trackcount ~= this.prevTrackCount then

        local firstUpdate = (this.prevTrackCount == 0)
        this.subtitles    = getSubtitleList()

        if not firstUpdate then h.log("Subtitle list updated") end
    end
end

function this.load()

    local langMap   = getLanguageMap(this.config.bottom_languages..","..this.config.top_languages)
    local bottomSid = getSidByLanguage(mergeLanguages(this.config.bottom_languages, langMap))
    local topSid    = getSidByLanguage(mergeLanguages(this.config.top_languages,    langMap))

    if bottomSid > 0 and bottomSid == topSid then

        h.notify("The IDs of the top and bottom subtitles are the same.", "sameinput", "error")

        return false
    end

    this.set(bottomSid, topSid)

    return this.bottom or this.top
end

function this.loadDefaults()

    local bottomSid = mp.get_property_number("sid",           0)
    local topSid    = mp.get_property_number("secondary-sid", 0)

    this.set(bottomSid, topSid)

    return this.bottom or this.top
end

function this.loadMerged()

    if checkPath(this.getPath("cache/mergedfile")) then

        mp.commandv("sub-add", this.getPath("cache/mergedfile"))

        local loaded = mp.get_property_native("current-tracks/sub")
        this.merged  = subtitle:new(loaded)

        return true
    end

    return false
end

function this.toggle(bottom, top)

    if this.isMergedSelected() then

        local overrides     = mp.get_property("sub-ass-style-overrides")
        local hidePrimary   = "Primary.AlphaLevel=255"
        local hideSecondary = "Secondary.AlphaLevel=255"

        if bottom == 1 then

            overrides = overrides:gsub(",?"..hidePrimary:gsub("%.", "%%."), "")
        else

            overrides = (overrides == "") and hidePrimary or overrides..","..hidePrimary
        end

        if top == 1 then

            overrides = overrides:gsub(",?"..hideSecondary:gsub("%.", "%%."), "")
        else

            overrides = (overrides == "") and hideSecondary or overrides..","..hideSecondary
        end

        mp.set_property("sub-ass-style-overrides", overrides)
    else

        mp.set_property_native("sub-visibility",           (bottom == 1) and "yes" or "no")
        mp.set_property_native("secondary-sub-visibility", (top == 1)    and "yes" or "no")
    end
end

function this.set(bottomSid, topSid)

    this.bottom = (bottomSid > 0) and this.subtitles[bottomSid] or nil
    this.top    = (topSid > 0)    and this.subtitles[topSid]    or nil
end

function this.display()

    mp.set_property_native("sid",           this.bottom and this.bottom.id or 0)
    mp.set_property_native("secondary-sid", this.top    and this.top.id    or 0)
end

function this.init(config)

    this.config = config
end

return this