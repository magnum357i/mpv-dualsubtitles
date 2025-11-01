# mpv-dualsubtitles

Dual subtitles plugin for MPV

![Example for Dual Subtitles](https://github.com/magnum357i/mpv-dualsubtitles/blob/main/mpv-shot0001.jpg)

# Dependencies

- `FFmpeg` (for merging)

# Installation

### Manual

Place `scripts` and `script-opts` folders into your config directory.

| OS        | Location         |
|-----------|------------------|
| Windows   | `%appdata%/mpv/` |
| GNU/Linux | `~/.config/mpv/` |

### Automatic

To install or update via command line:

#### Windows 10 (CMD)

```powershell
powershell -ExecutionPolicy ByPass -c "irm https://raw.githubusercontent.com/magnum357i/mpv-dualsubtitles/HEAD/installers/windows.ps1 | iex"
```

> [!NOTE]
> `winget` is used to install `ffmpeg`. This step is skipped if `ffmpeg` is installed.

#### Linux

```bash
curl -fsSL https://raw.githubusercontent.com/magnum357i/mpv-dualsubtitles/HEAD/installers/linux.sh | sh
```

# Key Bindings

| shortcut          | description                               |
|-------------------|-------------------------------------------|
| <kbd>k</kbd>      | switch secondary subtitle track           |
| <kbd>K</kbd>      | switch secondary subtitle track backwards |
| <kbd>u</kbd>      | swap subtitles                            |
| <kbd>v</kbd>      | cycle through subtitle visibility modes   |
| <kbd>Ctrl+r</kbd> | move secondary subtitle down              |
| <kbd>Ctrl+R</kbd> | move secondary subtitle up                |
| <kbd>Ctrl+b</kbd> | merge subtitles into a single file        |
| <kbd>Ctrl+B</kbd> | delete the merged file                    |
| <kbd>Ctrl+C</kbd> | copy subtitles to clipboard               |

# Auto-Selection

### How Does It Work?

1. Get subtitles based on preferred languages. **[top_languages or bottom_languages]**
2. Skip forced and ignored subtitles. **[rejected_words]**
3. Remove non-preferred subtitles. **[preferred_words]**
4. Sort subtitles by size.
5. Find first text-based subtitle that is not SDH.
6. Find first subtitle that is not SDH.
7. Get first subtitle. (It will likely be an SDH or image-based subtitle.)

Forced subtitles are never selected when full subtitles are available, even if they are not properly marked. And hearing-impaired subtitles are better than no subtitle.

### Input Tag

You don’t have to specify every variation of a language. Just use the two-letter code and the rest will be created automatically. For example:

| Tag          | Result                                                                    |
|--------------|---------------------------------------------------------------------------|
| `en:us`      | `en-us` (BCP 47) > `en` (639-1) / `eng` (639-2/B) / `english` (name)      |
| `ja`         | `ja` (639-1) / `jpn` (639-2/B) / `japanese` (name)                        |
| `tr`         | `tr` (639-1) / `tur` (639-2/B) / `turkish` (name)                         |
| `zh:hans-cn` | `zh-hans-cn` (BCP 47) > `zh` (639-1) / `chi` (639-2/B) / `chinese` (name) |

So, the two-letter language code is enough to select all subtitles in that language. If you need to add things like a region, separate them with a colon.

> [!WARNING]
> Don’t enter the same language (`ru:Cyrl-RU,ru:Latn-RU`) more than once because some features may not work. If you really need to do this, enter: `ru:Cyrl-RU:Latn-RU`

### Code Lists

- [Language](https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes) (Set 1 Column)
- [Region](https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes) (A-2 Column)

# Configuration

```ini
# Subtitles to Be Auto-Selected on Startup (The First One Has the Highest Priority)
#
# FORMAT
# <code>:<subcodes>
# code − language code with two letters (required) [language list: https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes]
# subcodes − script, region, etc. (optional) [region list: https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes]
#
# EXAMPLE
# en:us = en-us (BCP 47) > en (639-1) / eng (639-2/B) / english (name)
# ja = ja (639-1) / jpn (639-2/B) / japanese (name)
# tr = tr (639-1) / tur (639-2/B) / turkish (name)
# zh:hans-cn = zh-hans-cn (BCP 47) > zh (639-1) / chi (639-2/B) / chinese (name)
top_languages=tr
bottom_languages=en:us,ja

# Use only the matching subtitles if their titles contain these words.
preferred_words=

# Skip subtitles with these words in their title.
rejected_words=sign,song

# Set top subtitle as bottom subtitle if bottom subtitle is missing.
use_top_as_bottom=yes

# Display the secondary subtitle only when hovering.
secondary_on_hover=no

# Secondary Subtitle Hover Area (50 = the top half of the screen)
hover_height_percent=50

# Style Settings for Merged Subtitles
# In MPV, styling options for secondary subtitles are quite limited. By merging subtitles, you can work around this limitation. If your video file is on an HDD, this process may take 2–3 minutes.
# Values are given in 1920×1080 resolution.
#
# COLOR FORMAT
# <alpha><alpha><b><b><g><g><r><r>
# EXAMPLE
# 370DE2 (RGB) > E20D37 (BGR) > &H00E20D37 (ASS)
# You can convert any RGB value to BGR by swapping the first and last two characters. Note that the first two characters in an ASS color code represent the alpha channel.
#
# Live Preview: https://github.com/magnum357i/mpv-stylesmanager
top_style=fn:Segoe UI Semibold,fs:60,1c:&H0000DEFF,2c:&H000000FF,3c:&H00000000,4c:&H00000000,b:0,i:0,u:0,s:0,sx:100,sy:100,fsp:0,frz:0,bs:1,bord:4,shad:0,an:8,ml:0,mr:0,mv:40,enc:1
bottom_style=fn:Calibri,fs:60,1c:&H00FFFFFF,2c:&H000000FF,3c:&H00000000,4c:&H00000000,b:0,i:0,u:0,s:0,sx:100,sy:100,fsp:0,frz:0,bs:1,bord:1.5,shad:0,an:2,ml:0,mr:0,mv:40,enc:1

# ASS Tags for Merged Subtitles
# When a line is stripped based on your current settings, these tags will be added to it.
#
# ASS Tags Page (official): https://aegisub.org/docs/latest/ass_tags/
top_tags=
bottom_tags=\blur4

# Don’t strip sign lines.
# If the ASS file contains sign lines (=lines with pos tag) and you don’t want them stripped, you can use this setting.
#
# Valid options: bottom, top, and none
keep_ts=none

# Removes entries like "(wind blowing)" or "MAN 1:".
# Don’t expect perfect results. If you have a SDH subtitle, and the cues are very distracting, you might want to try this setting.
remove_sdh_entries=yes

# Enable extended search for external subtitles.
# Loads subtitles from subfolders with the same name as the video file. Useful for series.
#
# NOTE: Do not enable this setting if you are using something similar.
expand_subtitle_search=yes

# Keep italics during merging.
detect_italics=yes

# Prevents you from seeing the same text 20 times on the screen.
remove_repeating_lines=yes
```

# External Subtitles

### Naming

External subtitles loaded on startup can be automatically selected based on your preferred languages. Make sure the subtitle filename ends with a language code.

| Accepted Filename Formats for MPV |
|-----------------------------------|
| `movie.en.srt`                    |
| `movie.eng.srt`                   |

*Naming your subtitles this way will make MPV recognize their languages.*

| Accepted Filename Formats for My Plugin |
|-----------------------------------------|
| `en.srt`                                |
| `eng.srt`                               |
| `movie.en.srt`                          |
| `movie-en.srt`                          |
| `movie en.srt`                          |
| `movie.eng.srt`                         |
| `movie-eng.srt`                         |
| `movie eng.srt`                         |

*MPV does not display the languages for most of these subtitles, but auto-selection will still work.*

### Searching

Set up the following options to auto-load subtitles from folders.

1) **mpv.conf**

```ini
sub-auto=all
sub-file-paths=subs;subtitles
```

*Subtitles are usually located in these directories.*

2) **dualsubtitles.conf**

```ini
expand_subtitle_search=yes
```

# Merging Subtitles

Merging subtitles allows you to have more styling options.

![Example for Merging Subtitles](https://github.com/magnum357i/mpv-dualsubtitles/blob/main/mpv-shot0002.jpg)

> [!NOTE]
> Merged subtitles are a single subtitle file, so secondary options no longer apply. Even so, all features provided by this plugin, such as **swap** and **hide**, still apply to it.

# Copy Subtitles

Hold the shortcut key to copy on-screen subtitles to the clipboard. Works with merged subtitles as well.

# Related Plugins
- [sidebarsubtitles](https://github.com/magnum357i/mpv-sidebarsubtitles)

# FAQ

**- How do I change the vertical position of the top subtitle permanently? / How can I make both subtitles have equal margins?**

There is no margin option for secondary subtitles in MPV, but `secondary-sub-pos` can be used instead:

```
secondary-sub-pos=15
```

**- How do I disable the default subtitle track?**

```
sid=no
```