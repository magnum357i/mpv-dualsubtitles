local mp        = require "mp"
local msg       = require "mp.msg"
local utils     = require "mp.utils"
local h         = require "helpers"
local subtitle  = require "subtitle"
local resampler = require "resampler"
local assline   = require "assline"
local path      = require "path"
local this      = {

    subtitles      = {},
    prevTrackCount = 0,
    bottom         = nil,
    top            = nil,
    merged         = nil,
    hash           = nil,
    tempDir        = "mpvdualsubtitles"
}

local mergeStart

local function filter(subtitle,wordsToFilter)

    if subtitle.forced                                                           then return false end
    if subtitle.title and h.searchStrings(subtitle.title:lower(), wordsToFilter) then return false end

    return true
end

local function hasItalic(text)

    --SDH
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

    for _, value in ipairs(tracks) do

        if value.type == "sub" then table.insert(list, subtitle:new(value)) end
    end

    this.prevTrackCount = #tracks

    return list
end

local function mergeLanguages(configLangKey, map)

    if map == nil or next(map) == nil then h.notify("You entered invalid languages, or the CSV file is broken.", "languagecache", "error") end

    local preferredLanguages = h.splitString(config[configLangKey])
    local languageList       = {}
    local previousLangs      = {}
    local n                  = 1

    for _, val in ipairs(preferredLanguages) do

        local lang = val:gsub(":.+", "")

        if previousLangs[lang] then

            h.notify(string.format("Duplicate language detected: %s", lang), "languagecache", "warn", nil, true)
        else

            languageList[n] = {codes = {}, subCodes = {}}

            table.insert(languageList[n].codes, lang)

            if map[lang] then

                table.insert(languageList[n].codes, map[lang][1])
                table.insert(languageList[n].codes, map[lang][2])
            else

                h.notify(string.format("This value isn’t in the map table: %s", lang), "languagecache", "warn", nil, true)
            end

            local subCodes = h.splitString(val, ":")

            if next(subCodes) ~= nil then

                table.remove(subCodes, 1)

                for _, z in ipairs(subCodes) do

                    table.insert(languageList[n].subCodes, z)
                end
            end

            n                   = n + 1
            previousLangs[lang] = true
        end
    end

    h.log(utils.format_json({[configLangKey] = languageList}))

    return languageList
end

local function getLanguageMap()

    local configFileInfo = utils.file_info(this.getPath("configfile")) or utils.file_info(this.getPath("scriptfile"))
    local cacheFileInfo  = utils.file_info(this.getPath("cache/languagefile"))

    if configFileInfo and cacheFileInfo and tonumber(configFileInfo.mtime) > tonumber(cacheFileInfo.mtime) then path.removeFile(this.getPath("cache/languagefile")) end

    local mapContent = path.readFile(this.getPath("cache/languagefile"))

    if mapContent then return utils.parse_json(mapContent) end

    local csvContent = path.readFile(this.getPath("csvfile"))

    if not csvContent then

        h.notify("Language map file not found! A file named 'language-codes-3b2.csv' must be placed in the plugin directory.", "languagecache", "warn")

        return {}
    end

    local allPreferredLanguages = h.splitString(config.bottom_languages..","..config.top_languages)
    local map                   = {}
    local langKeys              = {}

    for _, val in ipairs(allPreferredLanguages) do

        val = val:gsub(":.+", "")

        langKeys[val] = true
    end

    for alpha3_b, alpha2, name in csvContent:gmatch( '"([^"]*)","([^"]*)","([^"]*)"') do

        if langKeys[alpha2] then

            name        = name:gsub("[,;].+", "")
            map[alpha2] = {alpha3_b, name:lower()}
        end
    end

    if next(map) ~= nil then

        path.createDir(this.getPath("cache"))

        local isFileCreated = path.createFile(this.getPath("cache/languagefile"), utils.format_json(map))

        if not isFileCreated then

            h.notify("Failed to create the cache file. Required for performance.", "languagecache", "error")
        end
    end

    return map
end

local function getSidByLanguage(configLangKey, langMap)

    local languageCodes     = mergeLanguages(configLangKey, langMap)
    local undesiredWords    = h.splitString(config.rejected_words)
    local selectedSubtitles = {}
    local missingMetadata   = false
    local foundLangId       = 0

    for idx, val in ipairs(languageCodes) do

        foundLangId              = idx
        local preferredLanguages = {}

        for _, l in ipairs(val.codes) do

            preferredLanguages[l] = true
        end

        for _, subtitle in ipairs(this.subtitles) do

            local sLang = subtitle.lang and subtitle.lang:gsub("%-.+", "") or nil

            if sLang then

                if preferredLanguages[sLang] and filter(subtitle, undesiredWords) then

                    table.insert(selectedSubtitles, subtitle)

                    if subtitle.size == 0 then missingMetadata = true end
                end
            end
        end

        if next(selectedSubtitles) ~= nil then break end
    end

    if #selectedSubtitles > 1 then

        if missingMetadata then h.notify("There are subtitles with missing metadata. Sorting may not work correctly.", "findsubtitle", "warn", nil, true) end

        --filter by subcodes

        if next(languageCodes[foundLangId].subCodes) ~= nil then

            local code = languageCodes[foundLangId].codes[1]
            local firstLang

            for n, val in ipairs(languageCodes[foundLangId].subCodes) do

                local subCode = string.format("%s-%s", code, val)

                for _, subtitle in ipairs(selectedSubtitles) do

                    if subtitle.lang == subCode then

                        firstLang = subtitle.lang
                        break
                    end
                end

                if firstLang then break end
            end

            if firstLang then

                h.removeItems(selectedSubtitles, function(_, val)

                    if val.lang and val.lang == firstLang then return true end

                    return false
                end, true)
            end

            if #selectedSubtitles == 1 then return selectedSubtitles[1].id end
        end

        --filter by preferred words

        if config.preferred_words ~= "" then

            local desiredWords = h.splitString(config.preferred_words)

            if next(desiredWords) ~= nil then

                h.removeItems(selectedSubtitles, function(_, val)

                    if val.title and h.searchStrings(val.title:lower(), desiredWords) then return true end

                    return false
                end, true)
            end

            if #selectedSubtitles == 1 then return selectedSubtitles[1].id end
        end

        --sort subtitles by size

        table.sort(selectedSubtitles, function(a, b)

            return tonumber(a.size) > tonumber(b.size)
        end)

        --get first text-based subtitle that is not SDH

        for _, subtitle in ipairs(selectedSubtitles) do

            if not subtitle.hearingimpaired and subtitle.textbased then

                return subtitle.id
            end
        end

        --get first subtitle that is not SDH

        for _, subtitle in ipairs(selectedSubtitles) do

            if not subtitle.hearingimpaired then

                return subtitle.id
            end
        end
    end

    --get first subtitle if nothing was found

    return selectedSubtitles[1] and selectedSubtitles[1].id or 0
end

local function copySubtitleToTemp(subtitle, key)

    local message    = ""
    local sourceFile = subtitle.path
    local targetFile = this.getPath("cache/"..key.."file")
    local result

    if subtitle.ext == ".ass" then

        if path.platform() == "windows" then

            h.runCommand({"powershell", "-NoProfile", "-Command", string.format("Copy-Item -LiteralPath \"%s\" -Destination \"%s\" -Force", sourceFile, targetFile)})
        else

            h.runCommand({"cp", sourceFile, targetFile})
        end
    else

        result = h.runCommand({"ffmpeg", "-i", sourceFile, "-c:s", "ass", targetFile})

        if result.status == -3 then message = "FFmpeg not installed." end
    end

    return path.checkPath(targetFile), message
end

local function mergeSubtitles()

    local data = {

        {style = "Primary",   subType = "bottom", ready = false},
        {style = "Secondary", subType = "top",    ready = false}
    }
    local styles = {}
    local lines  = {}

    for _, v in ipairs(data) do

        local sPath   = this.getPath("cache/"..v.subType.."file")
        local content = path.readFile(sPath)

        if content then

            local shouldResample
            local italicStyles = {}

            if config.keep_ts == v.subType then

                local playResX, playResY = assline:resolution(content)

                shouldResample = (playResX == 1920 and playResY == 1080) and false or true

                if shouldResample then resampler.setResolutions(playResX, playResY, 1920, 1080) end

                for style in assline:styles(content) do

                    if config.detect_italics and style.Italic then table.insert(italicStyles, style.Name) end

                    style.Name = v.style..style.Name

                    if shouldResample then resampler.resampleStyle(style) end

                    table.insert(styles, style:raw())
                end
            end

            local makeItalic, seen = false, {}

            for line in assline:lines(content) do

                local prevStyle

                if not v.ready then v.ready = true end

                local deleteThis = false

                if config.keep_ts == v.subType and line:isSign() then

                    line.Style = v.style..line.Style

                    if shouldResample then resampler.resampleDialogue(line) end
                elseif not line.Text:isShape() then

                    local text = line.Text:stripped()

                    if config.remove_repeating_lines then

                        local sKey = tostring(line.Start)..tostring(line.End)

                        if seen[sKey] and seen[sKey] == text then

                            deleteThis = true
                        else

                            seen[sKey] = text
                        end
                    end

                    if not deleteThis and config.detect_italics then

                        if prevStyle ~= line.Style and h.hasItem(italicStyles, line.Style) then

                            makeItalic = true
                        else

                            makeItalic = false
                        end

                        makeItalic = makeItalic or hasItalic(line.Text.original)
                    end

                    if not deleteThis and config.remove_sdh_entries then

                        text = sdhKiller(text)

                        if text == "" then

                            deleteThis = true
                        end
                    end

                    if not deleteThis and config[v.subType.."_tags"] ~= "" then

                        text = string.format("{%s}%s", config[v.subType.."_tags"], text)
                    end

                    if not deleteThis and makeItalic then

                        text = string.format("{%s}%s", "\\i1", text):gsub("}{", "")
                    end

                    --for copy
                    text = string.format("{*%s}%s", v.style:sub(1,1), text):gsub("}{", "")

                    line.Layer = 0
                    line.Style = v.style
                    line.Text  = text
                end

                if not deleteThis then table.insert(lines, line:raw()) end

                prevStyle = line.Style
            end

            path.removeFile(sPath)
        end
    end

    if not (data[1].ready or data[2].ready) then

        h.notify("There is a missing or corrupted subtitle.", "mergesubtitles", "error", 30)

        return
    end

    local header = [[
[Script Info]
; Script generated by mpvdualsubtitles
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

    header = header:gsub("<style1>", config.bottom_style:gsub("[^,]*:", ""))
    header = header:gsub("<style2>", config.top_style:gsub("[^,]*:", ""))

    if next(styles) ~= nil then

        header = header:gsub("<extrastyles>", table.concat(styles, "\n"))
    else

        header = header:gsub("\n<extrastyles>", "")
    end

    path.createFile(this.getPath("cache/mergedfile"), header..table.concat(lines, "\n"))
end

local function tryMerge()

    local ok, err = pcall(mergeSubtitles)

    if ok then

        this.set(0, 0)
        this.display()

        mp.commandv("sub-add", this.getPath("cache/mergedfile"))
        this.updateList(0)

        this.merged   = this.subtitles[mp.get_property_number("sid")]
        local elapsed = mp.get_time() - mergeStart
        mergeStart    = nil

        h.notify(string.format("Subtitles merged. Took %d seconds.", elapsed), "mergesubtitles", "info", 10)
    else

        h.notify(err, "mergesubtitles", "error")
        h.notify("See the console for details.", "mergesubtitles", "error")
    end
end

function this.deleteMerged()

    if not this.merged then return false end

    mp.commandv("sub-remove", this.merged.id)

    path.removeDir(this.getPath("cache/merge"))

    this.merged = nil

    return true
end

function this.merge()

    if not (this.bottom and this.top) then

        h.notify("Two subtitles are required to merge.", "mergesubtitles", "error")

        return
    end

    if not (this.bottom.textbased and this.top.textbased) then

        h.notify("One of the selected subtitles is not text-based.", "mergesubtitles", "error")

        return
    end

    h.notify("Please wait...", "mergesubtitles", "info", 9999)

    mergeStart = mp.get_time()

    path.createDir(this.getPath("cache/merge"))

    local remainingSubtitles = 2
    local cStatus, cErrorMessage

    for _, k in ipairs({"bottom", "top"}) do

        local subtitle = this[k]

        if subtitle.external then

            cStatus, cErrorMessage = copySubtitleToTemp(subtitle, k)

            if cStatus then

                remainingSubtitles = remainingSubtitles - 1
            else

                break
            end
        end
    end

    if cErrorMessage then

        h.notify(cErrorMessage, "mergesubtitles", "error")

        return
    end

    if remainingSubtitles == 0 then

        tryMerge()

        return
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

    local onSubtitleFail = function(result, status)

        if status == -3 then

            h.notify("FFmpeg not installed.", "mergesubtitles", "error")
        elseif string.find(result, "No such file or directory") then

            h.notify("No such file or directory.", "mergesubtitles", "error")
        elseif string.find(result, "Failed to set value") then

            h.notify("Wrong subtitle id.", "mergesubtitles", "error")
        else

            h.log(result)
            h.notify("See the console for details.", "mergesubtitles", "error")
        end
    end

    h.runCommandAsync(args, tryMerge, onSubtitleFail)
end

function this.isMergedSelected()

    local currentSid = mp.get_property_number("sid", 0)

    return this.merged and currentSid == this.merged.id
end

function this.getPath(key)

    this.hash = this.hash or h.hash(mp.get_property("path"))

    if key == "csvfile" then

        return path.join({"%scripts", mp.get_script_name(), "language-codes-3b2.csv"})
    elseif key == "scriptfile" then

        return path.join({"%scripts", mp.get_script_name(), "main.lua"})
    elseif key == "configfile" then

        return path.join({"%options", "dualsubtitles.conf"})
    elseif key == "videofile" then

        return mp.get_property("path")
    elseif key == "cache/languagefile" then

        return path.join({"%temp", this.tempDir, "cachedlanguages.json"})
    elseif key == "cache" then

        return path.join({"%temp", this.tempDir})
    elseif key == "cache/merge" then

        return path.join({"%temp", this.tempDir, this.hash})
    elseif key == "cache/bottomfile" then

        return path.join({"%temp", this.tempDir, this.hash, "primary.ass"})
    elseif key == "cache/topfile" then

        return path.join({"%temp", this.tempDir, this.hash, "secondary.ass"})
    elseif key == "cache/mergedfile" then

        return path.join({"%temp", this.tempDir, this.hash, "merged.ass"})
    end

    return nil
end

function this.updateList(currentTrackCount)

    if currentTrackCount ~= this.prevTrackCount then

        this.subtitles = getSubtitleList()
    end
end

function this.addStyleOverride(overrides, style, property, value)

    overrides = overrides:gsub(",?"..h.escape(string.format("%s.%s", style, property)).."=[^,]*", "")

    if value then

        overrides = overrides ~= "" and overrides.."," or overrides
        overrides = overrides..string.format("%s.%s=%s", style, property, value)
    end

    return overrides
end

function this.load()

    local langMap   = getLanguageMap()
    local bottomSid = getSidByLanguage("bottom_languages", langMap)
    local topSid    = getSidByLanguage("top_languages",    langMap)

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

    if path.checkPath(this.getPath("cache/mergedfile")) then

        mp.commandv("sub-add", this.getPath("cache/mergedfile"))

        local loaded = mp.get_property_native("current-tracks/sub")
        this.merged  = subtitle:new(loaded)

        return true
    end

    return false
end

function this.toggle(bottom, top)

    if this.isMergedSelected() then

        local overrideMode = mp.get_property("sub-ass-override", "")

        if not (overrideMode == "yes" or overrideMode == "scale") then h.notify("Style override functionality only works with \"--sub-ass-override=yes\" or \"--sub-ass-override=scale\".", "styleoverride", "warn", nil, true) end

        local overrides = mp.get_property("sub-ass-style-overrides", "")

        if bottom == 1 then

            overrides = this.addStyleOverride(overrides, "Primary", "AlphaLevel", nil)
        else

            overrides = this.addStyleOverride(overrides, "Primary", "AlphaLevel", "255")
        end

        if top == 1 then

            overrides = this.addStyleOverride(overrides, "Secondary", "AlphaLevel", nil)
        else

            overrides = this.addStyleOverride(overrides, "Secondary", "AlphaLevel", "255")
        end

        mp.set_property("sub-ass-style-overrides", overrides)
    else

        mp.set_property_native("sub-visibility",           bottom == 1 and "yes" or "no")
        mp.set_property_native("secondary-sub-visibility", top == 1    and "yes" or "no")
    end
end

function this.set(bottomSid, topSid)

    this.bottom = bottomSid > 0 and this.subtitles[bottomSid] or nil
    this.top    = topSid > 0    and this.subtitles[topSid]    or nil
end

function this.display()

    mp.set_property_native("sid",           this.bottom and this.bottom.id or 0)
    mp.set_property_native("secondary-sid", this.top    and this.top.id    or 0)
end

return this