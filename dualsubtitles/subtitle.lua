local mp    = require "mp"
local msg   = require "mp.msg"
local utils = require "mp.utils"
local h     = require "helpers"
local this  = {}

local function detectSubtitleInfo(filename)

    local externalSubtitle = utils.file_info(filename)
    local lang             = filename:match(".+[%.%-%s]([a-zA-Z][a-zA-Z][a-zA-Z]?)[%.%-%s]")
    local bytes            = externalSubtitle and externalSubtitle.size or 0

    return lang, bytes
end

local function filterSubtitle(subtitle,wordstofilter)

    local stitle = subtitle.title and subtitle.title:lower() or nil

    if subtitle.forced or stitle and stitle:find("forced") then

        return false
    end

    if stitle and h.hasValue(wordstofilter, stitle) then

        return false
    end

    return true
end

local function getSidByLanguage(languageCodes)

    local selectedSubtitles = {}
    local founded           = false
    local unwantedsubtitles = h.splitString(this.options.ignoredWords)

    for _, userLang in ipairs(languageCodes) do

        for _, subtitle in ipairs(this.subtitles) do

            if subtitle.lang and subtitle.lang:lower() == userLang and filterSubtitle(subtitle, unwantedsubtitles) then

                founded = true
                table.insert(selectedSubtitles, subtitle)
            end
        end

        if founded then break end
    end

    local subId = 0

    if #selectedSubtitles == 1 then

        subId = selectedSubtitles[1].id
    elseif #selectedSubtitles > 1 then

        table.sort(selectedSubtitles, function(a, b)

            return tonumber(a.metadata.NUMBER_OF_BYTES) > tonumber(b.metadata.NUMBER_OF_BYTES)
        end)

        for _, subtitle in ipairs(selectedSubtitles) do

            local stitle = subtitle.title and subtitle.title:lower() or nil

            if not ((subtitle.hearing_impaired) or (stitle and stitle:find("sdh")) or (stitle and stitle:find("cc"))) then

                subId = subtitle.id
                break
            end
        end

        subId = (subId == 0) and selectedSubtitles[1].id or subId
    end

    return subId
end

local function getLanguageMap(allLanguages)

    local handle
    local files = {
        config   = mp.command_native({'expand-path', os.getenv("TEMP").."/mpvdualsubtitles/cachedlanguages.json"}),
        language = mp.command_native({'expand-path', mp.get_script_directory().."/language-codes-3b2.csv"}),
        script   = mp.command_native({'expand-path', mp.get_script_directory().."/dualsubtitles.lua"})
    }

    local scriptFileInfo = utils.file_info(files.script)
    local configFileInfo = utils.file_info(files.config)

    if scriptFileInfo and configFileInfo and tonumber(scriptFileInfo.mtime) > tonumber(configFileInfo.mtime) then os.remove(files.config) end

    handle = io.open(files.config, "r")

    if handle then

        local content = handle:read("*a")

        handle:close()

        return utils.parse_json(content)
    end

    local map       = {}
    local is_filled = false
    handle          = io.open(files.language, "r")

    if not handle then

        mp.osd_message("[dualsubtitles] Language map file not found! A file named 'language-codes-3b2.csv' must be placed in the plugin directory.", 5000)
    else

        allLanguages   = h.splitString(allLanguages)
        local langKeys = {}

        for _, lang in ipairs(allLanguages) do

            table.insert(langKeys, lang:find("%-") and lang:gsub("%-.+","") or lang)
        end

        for line in handle:lines() do

            local iso3, iso2, title = line:gsub('"', ''):gsub('[;,]?%s.+', ''):match("([^,]+),([^,]+),([^,]+)")

            if title and h.hasValue(langKeys, iso2) then

                map[iso2] = {iso3, title}

                if not is_filled then is_filled = true end
            end
        end

        handle:close()
    end

    if is_filled then

        local tempPath      = files.config:match("(.+)[/\\]")
        local ok, err, code = os.rename(tempPath, tempPath)

        if not ok then os.execute('mkdir ' ..tempPath:gsub("/", "\\")) end

        handle = io.open(files.config, "w")

        if handle then

            handle:write(utils.format_json(map))
            handle:close()
        else

            mp.osd_message("[dualsubtitles] Failed to create the cache file. Required for performance.", 5000)
        end
    else

        mp.osd_message("[dualsubtitles] You entered invalid languages, or the CSV file is broken.", 5000)
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

                msg.error("Map Error: Unrecognized language code")
            end
        else

            table.insert(languages, value)
        end
    end

    h.log(languages)

    return languages
end

local function getSubtitleList()

    local list   = {}
    local tracks = mp.get_property_native('track-list')

    for index, value in ipairs(tracks) do

        if value.type == "sub" then

            if value.external then

                local lang, bytes = detectSubtitleInfo(value["external-filename"])

                if lang and bytes > 0 then

                    value.lang = lang

                    if not value.metadata then value.metadata = {} end

                    value.metadata.NUMBER_OF_BYTES = bytes
                else

                    value.lang = nil

                    msg.error("Failed to get external subtitle info")
                end
            end

            table.insert(list, value)
        end
    end

    this.prevTrackCount = #tracks

    return list
end

function this.init(options)

    this.subtitles      = {}
    this.prevTrackCount = 0
    this.options        = options
    this.bottomSid      = 0
    this.topSid         = 0
end

function this.updateList(tracks)

    if #tracks ~= this.prevTrackCount then

        local firstUpdate = (this.prevTrackCount == 0) and true or false

        this.subtitles = getSubtitleList()

        if not firstUpdate then h.log("Subtitle list updated") end
    end
end

function this.load()

    local langMap  = getLanguageMap(this.options.preferredLanguages.bottom..","..this.options.preferredLanguages.top)

    this.bottomSid = getSidByLanguage(mergeLanguages(this.options.preferredLanguages.bottom, langMap))
    this.topSid    = getSidByLanguage(mergeLanguages(this.options.preferredLanguages.top,    langMap))

    if this.bottomSid > 0 and this.bottomSid == this.topSid then

        mp.osd_message("[dualsubtitles] The IDs of the top and bottom subtitles are the same.", 5000)
    end
end

function this.toggle(bottom, top)

    mp.set_property_native("sub-visibility",           (bottom == 1) and "yes" or "no")
    mp.set_property_native("secondary-sub-visibility", (top == 1)    and "yes" or "no")
end

function this.format(mode)

    local track = (mode == 1) and this.subtitles[this.bottomSid] or this.subtitles[this.topSid]
    local dst = ""

    if track.title then

        dst = dst..string.format("'%s' ", track.title)
    end

    dst = dst.."("

    if track.lang then

        dst = dst..string.format("%s ", track.lang)
    end

    local codec = track.codec and track.codec or "<unknown>"
    codec       = (codec == "subrip") and "subrip [Advanced Sub Station Alpha]" or codec

    dst = dst..codec
    dst = dst..")"

    local flags = {}

    if track["default"]          then table.insert(flags, "default")          end
    if track["forced"]           then table.insert(flags, "forced")           end
    if track["dependent"]        then table.insert(flags, "dependent")        end
    if track["visual-impaired"]  then table.insert(flags, "visual-impaired")  end
    if track["hearing-impaired"] then table.insert(flags, "hearing-impaired") end
    if track["external"]         then table.insert(flags, "external")         end

    if #flags > 0 then

        dst = dst.." ["..table.concat(flags, " ").."]"
    end

    dst = "("..track.id..") "..dst

    return dst
end

function this.count()

    return #this.subtitles
end

function this.set(mode)

    if mode == 1 then

        mp.set_property_native("sid",           this.bottomSid)
    elseif mode == 2 then

        mp.set_property_native("secondary-sid", this.topSid)
    else

        mp.set_property_native("sid",           this.bottomSid)
        mp.set_property_native("secondary-sid", this.topSid)
    end
end

function this.loadDefaults()

    this.bottomSid = mp.get_property_number("sid", 0)
    this.topSid    = mp.get_property_number("secondary-sid", 0)
end

return this