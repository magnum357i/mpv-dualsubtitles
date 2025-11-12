local mp        = require "mp"
local msg       = require "mp.msg"
local utils     = require "mp.utils"
local assdraw   = require "mp.assdraw"
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

local overlay   = mp.create_osd_overlay("ass-events")
local merge     = {
    current             = nil,
    progress            = {},
    progressHandler     = nil,
    progressTimer       = nil,
    progressBase        = 0,
    active              = nil,
    total               = 0,
    start               = 0,
    data                = {},
    defaultErrorMessage = "See the console for details.",
    flags               = {

        COPY               = 1,
        GETDURATION        = 2,
        EXTRACT            = 3,
        CONVERT_TEXTBASED  = 4,
        CONVERT_IMAGEBASED = 5,
        MERGE              = 6
    }
}

local function filter(subtitle, wordsToFilter)

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

    local count
    local speakerDash       = "%s*%-%s*"
    local soundDescriptions = "[%[%(][^%]%)]-[%]%)]"

    --sound descriptions with speaker dash (two lines)
    _, count = text:gsub("^"..speakerDash..soundDescriptions.."%s*\\N"..speakerDash..soundDescriptions.."%s*$", "")

    if count > 0 then return "" end

    --sound descriptions with speaker dash (first line)
    text = text:gsub("^"..speakerDash..soundDescriptions.."%s*\\N"..speakerDash, "")

    --sound descriptions with speaker dash (second line)
    text, count = text:gsub(speakerDash..soundDescriptions.."%s*$", "")

    if count > 0 then text = text:gsub("^"..speakerDash, "") end

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

local function copyCommand(s, t)

    if path.platform() == "windows" then

        return {"powershell", "-NoProfile", "-Command", string.format("Copy-Item -LiteralPath \"%s\" -Destination \"%s\" -Force", s, t)}
    else

        return {"cp", s, t}
    end
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

local function updateOverlay(content, x, y)

    if overlay.data == content and overlay.res_x == 1280 and overlay.res_y == 720 then return end

    overlay.data  = content
    overlay.res_x = (x and x > 0) and x or 1280
    overlay.res_y = (y and y > 0) and x or 720
    overlay.z     = 2000

    overlay:update()
end

function merge.closeGui()

    updateOverlay("", 0, 0)

    merge.active = false

    mp.remove_key_binding("dualsubtitles_closegui")
end

function merge.statusGui()

    local ass  = assdraw.ass_new()
    local posX = merge.data.marginX
    local posY = merge.data.marginY

    local header = function (title)

        ass:new_event()
        ass:an(7)
        ass:pos(posX, posY)
        ass:append(string.format("{\\bord%s\\fs%s\\b1}%s", merge.data.borderSize, merge.data.fontSize, title))

        posY = posY + merge.data.fontSize
    end

    local steps = function (titles)

        for i, z in ipairs(titles) do

            ass:new_event()
            ass:an(7)
            ass:pos(posX, posY)

            if merge.progress[i] then

                if merge.progress[i] == 100 then

                    ass:append(string.format("{\\bord%s\\fs%s}%s", merge.data.borderSize, merge.data.fontSize, merge.data.tab..merge.data.completedSymbol.." "..z))
                else

                    ass:append(string.format("{\\bord%s\\fs%s}%s... (%s%%)", merge.data.borderSize, merge.data.fontSize, merge.data.tab..z, merge.progress[i]))
                end
            else

                ass:append(string.format("{\\bord%s\\fs%s\\alpha&H%x&}%s", merge.data.borderSize, merge.data.fontSize, merge.data.alpha, merge.data.tab..z))
            end

            posY = posY + merge.data.fontSize
        end
    end

    header("Merging Subtitles")
    steps({"Extracting or copying", "Converting", "Finishing up"})

    if not merge.active then

        posY          = posY + merge.data.fontSize
        local elapsed = mp.get_time() - merge.start

        ass:new_event()
        ass:an(7)
        ass:pos(posX, posY)
        ass:append(string.format("{\\bord%s\\fs%s}%s", merge.data.borderSize, merge.data.fontSize, string.format("Took {\\b1}%d{\\b0} seconds. Press <ESC> to exit.", elapsed)))
    end

    updateOverlay(ass.text)
end

function merge.updateProgress(step, percent)

    if merge.progress[step] == nil then merge.progressBase = 0 end

    local p          = percent
    local twoActions = false

    if this.top then

        twoActions = true

        if merge.current == merge.flags.EXTRACT and not (this.bottom.external and this.top.external) then twoActions = false end
    end

    if twoActions then p = p / 2 end

    merge.progress[step] = merge.progressBase + math.floor(p)

    if twoActions and percent == 100 then

        merge.progressBase = 50
    end

    merge.statusGui()
end

function merge.process()

    local data = {

        {style = "Primary",   subType = "bottom", ready = false},
        {style = "Secondary", subType = "top",    ready = false}
    }
    local styles = {}
    local lines  = {}

    for _, v in ipairs(data) do

        local sPath   = this.getPath("cache/"..v.subType.."file"):gsub("<ext>", ".ass")
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

                    local text = line.Text:noTags()

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

            merge.updateProgress(3, 100)

            path.removeFile(sPath)
        end
    end

    if not data[1].ready and not data[2].ready then error("There is a missing or corrupted subtitle.") end

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
<bottomstyle>
<topstyle>
<extrastyles>

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text

]]

    header = header:gsub("<bottomstyle>", "Style: Primary,"..config.bottom_style:gsub("[^,]*:", ""))
    header = header:gsub("<topstyle>",    "Style: Secondary,"..config.top_style:gsub("[^,]*:", ""))

    if next(styles) ~= nil then

        header = header:gsub("<extrastyles>", table.concat(styles, "\n"))
    else

        header = header:gsub("\n<extrastyles>", "")
    end

    path.createFile(this.getPath("cache/mergedfile"), header..table.concat(lines, "\n"))
end

function merge.reset()

    merge.start   = 0
    merge.current = merge.flags.COPY
    merge.total   = 0

    h.clearTable(merge.progress)
    h.clearTable(merge.data)
end

function merge.preapare()

    path.createDir(this.getPath("cache/merge"))

    merge.active = true
    merge.start  = mp.get_time()
end

function merge.fillData()

    merge.data.borderSize      = mp.get_property_number("osd-border-size")
    merge.data.fontSize        = mp.get_property_number("osd-font-size")
    merge.data.marginX         = mp.get_property_number("osd-margin-x")
    merge.data.marginY         = mp.get_property_number("osd-margin-y")
    merge.data.tab             = string.rep("\\h", 4)
    merge.data.alpha           = 150
    merge.data.completedSymbol = "✓"
end

function merge.try()

    local ok, err = pcall(merge.process)

    if ok then

        this.set(0, 0)
        this.display()

        mp.commandv("sub-add", this.getPath("cache/mergedfile"))
        this.updateList(0)

        this.merged = this.subtitles[mp.get_property_number("sid")]

        mp.add_forced_key_binding("esc", "dualsubtitles_closegui", function()

            merge.closeGui()
        end)
    else

        merge.closeGui()

        h.notify(err, "mergesubtitles", "error")
        h.notify(merge.defaultErrorMessage, "mergesubtitles", "error")
    end
end

function merge.runNext()

    if merge.current == merge.flags.COPY then

        merge.preapare()
        merge.updateProgress(1, 0)

        local shouldExtract = false

        for _, k in ipairs({"bottom", "top"}) do

            local subtitle = this[k]

            if subtitle then

                if subtitle.external then

                    local sourceFile = subtitle.path
                    local targetFile = this.getPath(string.format("cache/%sfile", k)):gsub("<ext>", subtitle.ext)
                    local result     = h.runCommand(copyCommand(sourceFile, targetFile))

                    if result.status == 0 then

                        merge.updateProgress(1, 100)
                    else

                        merge.closeGui()

                        h.notify(merge.defaultErrorMessage, "commandfailed", "error")

                        return
                    end
                else

                    shouldExtract = true
                end
            end
        end

        merge.current = shouldExtract and merge.flags.GETDURATION or merge.flags.CONVERT_TEXTBASED

        merge.runNext()
    elseif merge.current == merge.flags.GETDURATION then

        local args = {}

        table.insert(args, "ffprobe")
        table.insert(args, "-v")
        table.insert(args, "error")
        table.insert(args, "-show_entries")
        table.insert(args, "format=duration")
        table.insert(args, "-of")
        table.insert(args, "default=noprint_wrappers=1:nokey=1")
        table.insert(args, this.getPath("videofile"))

        h.runCommandAsync(args,

            function(result)

                merge.total   = tonumber(result.stdout)
                merge.current = merge.flags.EXTRACT

                merge.runNext()
            end,

            function(result, status, default)

                merge.closeGui()

                if status == -3 then

                    h.notify("FFmpeg is not installed. Please install it first.", "missingdependencies", "error")
                else

                    h.notify(merge.defaultErrorMessage, "ffmpeg", "error")
                end
            end
        )
    elseif merge.current == merge.flags.EXTRACT then

        local args = {}

        if path.platform() == "windows" then

            table.insert(args, "cmd")
            table.insert(args, "/c")
        else

            table.insert(args, "bash")
            table.insert(args, "-c")
        end

        table.insert(args, "ffmpeg")
        table.insert(args, "-i")
        table.insert(args, this.getPath("videofile"))

        if this.bottom and not this.bottom.external then

            local bottomFile = this.getPath("cache/bottomfile"):gsub("<ext>", this.bottom.ext)

            table.insert(args, "-map")
            table.insert(args, string.format("0:s:%s", this.bottom.id - 1))
            table.insert(args, "-c")
            table.insert(args, "copy")
            table.insert(args, bottomFile)
        end

        if this.top and not this.top.external then

            local topFile = this.getPath("cache/topfile"):gsub("<ext>", this.top.ext)

            table.insert(args, "-map")
            table.insert(args, string.format("0:s:%s", this.top.id - 1))
            table.insert(args, "-c")
            table.insert(args, "copy")
            table.insert(args, topFile)
        end

        table.insert(args, "-vn")
        table.insert(args, "-an")
        table.insert(args, "-dn")
        table.insert(args, "-y")
        table.insert(args, "-progress")
        table.insert(args, "pipe:1")
        table.insert(args, ">")
        table.insert(args, this.getPath("cache/progressfile"))

        local lastPos = 0

        merge.progressTimer = mp.add_periodic_timer(0.5, function()

            if merge.progressHandler then

                merge.progressHandler:seek("set", lastPos)

                local newContent = merge.progressHandler:read("*all")
                lastPos          = merge.progressHandler:seek()
                local ms         = newContent:match("out_time_ms=(%d+)")

                if ms then

                    ms            = ms / 1000000
                    local percent = (ms / merge.total) * 100

                    merge.updateProgress(1, percent)
                end
            else

                merge.progressHandler = io.open(this.getPath("cache/progressfile"), "r")
            end
        end)

        h.runCommandAsync(args,

            function()

                merge.updateProgress(1, 100)

                merge.current = merge.flags.CONVERT_TEXTBASED

                merge.runNext()
            end,

            function(result, status, default)

                merge.closeGui()

                if string.find(result, "No such file or directory") then

                    h.notify("No such file or directory.", "ffmpeg", "error")
                elseif string.find(result, "Failed to set value") then

                    h.notify("Wrong subtitle id.", "ffmpeg", "error")
                else

                    h.notify(merge.defaultErrorMessage, "ffmpeg", "error")
                end
            end,

            function()

                path.removeFile(this.getPath("cache/progressfile"))

                if merge.progressTimer   then merge.progressTimer:kill()                                end
                if merge.progressHandler then merge.progressHandler:close() merge.progressHandler = nil end
            end
        )
    elseif merge.current == merge.flags.CONVERT_TEXTBASED then

        merge.updateProgress(2, 0)

        for _, k in ipairs({"bottom", "top"}) do

            local subtitle = this[k]

            if subtitle then

                if subtitle.ext == ".srt" then

                    local args       = {}
                    local sourceFile = this.getPath(string.format("cache/%sfile", k)):gsub("<ext>", this[k].ext)
                    local targetFile = this.getPath(string.format("cache/%sfile", k)):gsub("<ext>", ".ass")

                    table.insert(args, "ffmpeg")
                    table.insert(args, "-i")
                    table.insert(args, sourceFile)
                    table.insert(args, targetFile)

                    local result = h.runCommand(args)

                    if result.status ~= 0 then

                        merge.closeGui()

                        h.notify(merge.defaultErrorMessage, "ffmpeg", "error")

                        return
                    end

                    path.removeFile(sourceFile)

                    merge.updateProgress(2, 100)
                elseif subtitle.ext == ".ass" then

                    merge.updateProgress(2, 100)
                end
            end
        end

        merge.current = merge.flags.CONVERT_IMAGEBASED

        merge.runNext()
    elseif merge.current == merge.flags.CONVERT_IMAGEBASED then

        local convertProcess = function(key, success)

            if not this[key] or this[key].ext ~= ".sup" then success() return end

            local args       = {}
            local sourceFile = this.getPath(string.format("cache/%sfile", key)):gsub("<ext>", this[key].ext)

            if path.platform() == "windows" then

                table.insert(args, "cmd")
                table.insert(args, "/c")
            else

                table.insert(args, "bash")
                table.insert(args, "-c")
            end

            table.insert(args, "subtitleedit")
            table.insert(args, "/convert")
            table.insert(args, sourceFile)
            table.insert(args, "AdvancedSubStationAlpha")
            table.insert(args, ">")
            table.insert(args, this.getPath("cache/progressfile"))

            local lastPos = 0

            merge.progressTimer = mp.add_periodic_timer(0.5, function()

                if merge.progressHandler then

                    merge.progressHandler:seek("set", lastPos)

                    local newContent = merge.progressHandler:read("*all")
                    lastPos          = merge.progressHandler:seek()
                    local percent    = newContent:match("(%d+)%%")

                    if percent then merge.updateProgress(2, percent) end
                else

                    merge.progressHandler = io.open(this.getPath("cache/progressfile"), "r")
                end
            end)

            h.runCommandAsync(args,

                function()

                    merge.updateProgress(2, 100)

                    success()
                end,

                function(result, status, default)

                    merge.closeGui()

                    if status == 1 then

                        h.notify("Subtitle Edit is not installed. Please install it first.", "missingdependencies", "error")
                    else

                        h.notify(merge.defaultErrorMessage, "mergesubtitles", "error")
                    end
                end,

                function()

                    path.removeFile(this.getPath("cache/progressfile"))
                    path.removeFile(sourceFile)

                    if merge.progressTimer   then merge.progressTimer:kill()                                end
                    if merge.progressHandler then merge.progressHandler:close() merge.progressHandler = nil end
                end
            )
        end

        convertProcess("bottom", function()

            convertProcess("top", function()

                merge.current = merge.flags.MERGE

                merge.runNext()
            end)
        end)
    elseif merge.current == merge.flags.MERGE then

        merge.active = false

        merge.updateProgress(3, 0)
        merge.try()
        merge.reset()
    end
end

function this.merge()

    if this.merged then

        merge.closeGui()

        h.notify("Merged subtitle already exists.", "mergesubtitles", "error")

        return
    end

    if merge.active then return end

    if not this.bottom then

        h.notify("Bottom subtitle is required.", "mergesubtitles", "error")

        return
    end

    for _, k in ipairs({"bottom", "top"}) do

        local allowedExtensions = {".srt", ".ass", ".sup"}

        if this[k] and (not this[k].ext or not h.hasItem(allowedExtensions, this[k].ext)) then

            h.notify(string.format("The %s subtitle isn’t in the correct format (srt, ass, sup).", k), "mergesubtitles", "error")

            return
        end
    end

    merge.reset()
    merge.fillData()
    merge.runNext()
end

function this.deleteMerged()

    if not this.merged then return false end

    mp.commandv("sub-remove", this.merged.id)

    path.removeDir(this.getPath("cache/merge"))

    this.merged = nil

    return true
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

        return path.join({"%temp", this.tempDir, this.hash, "primary<ext>"})
    elseif key == "cache/topfile" then

        return path.join({"%temp", this.tempDir, this.hash, "secondary<ext>"})
    elseif key == "cache/mergedfile" then

        return path.join({"%temp", this.tempDir, this.hash, "merged.ass"})
    elseif key == "cache/progressfile" then

        return path.join({"%temp", this.tempDir, this.hash, "progress.txt"})
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