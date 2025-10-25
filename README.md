# mpv-dualsubtitles
Dual subtitles plugin for mpv.

![Example for Dual Subtitles](https://github.com/magnum357i/mpv-dualsubtitles/blob/main/mpv-shot0001.jpg)

# Dependencies

- FFmpeg (for merging)

# Key Bindings
| shortcut            | description                               |
| ------------------- | ----------------------------------------- |
| <kbd>k</kbd>        | switch secondary subtitle track           |
| <kbd>K</kbd>        | switch secondary subtitle track backwards |
| <kbd>u</kbd>        | swap subtitles                            |
| <kbd>v</kbd>        | cycle through subtitle visibility modes   |
| <kbd>Ctrl+r</kbd>   | move secondary subtitle down              |
| <kbd>Ctrl+R</kbd>   | move secondary subtitle up                |
| <kbd>Ctrl+b</kbd>   | merge subtitles into a single file        |
| <kbd>Ctrl+B</kbd>   | delete the merged file                    |
| <kbd>Ctrl+C</kbd>   | copy subtitles to clipboard               |

# How Does Auto-Selection Work?
- Get subtitles based on preferred languages. **[top_languages or bottom_languages]**
- Skip forced and ignored subtitles. **[rejected_words]**
- Sort subtitles by size.
- Remove non-preferred subtitles, if a match is found. **[preferred_words]**
- Find first text-based subtitle that is not SDH. Exit if found.
- Find first subtitle that is not SDH. Exit if found.
- Get first subtitle. (It will likely be an SDH or image-based subtitle.)

Forced subtitles are never selected when full subtitles are available, even if they are not properly marked. And hearing-impaired subtitles are better than no subtitle.

# Language Tag
You don’t have to specify every variation of a language. Just enter the language and region code, and it will create the variations. For example:

| Input Tag | Result                           |
|-----------|----------------------------------|
| `en:us`   | `en-us`, `en`, `eng`, `english`  |
| `ja`      | `ja`, `jpn`, `japanese`          |
| `tr`      | `tr`, `tur`, `turkish`           |

# Configuration

```ini
# Subtitles to Be Auto-Selected at Startup (The First One Has the Highest Priority)
#
#
# FORMAT
# <lang>:<region>
#
# Language list: https://en.wikipedia.org/wiki/List_of_ISO_639_language_codes
# Region list: https://en.wikipedia.org/wiki/List_of_ISO_3166_country_codes
#
#
# PRIORITY
# en:us = en-us > en / eng / english
# en = en / eng / english
top_languages=tr
bottom_languages=en:us,ja

# Use only the matching ones, if any subtitles contain these words.
preferred_words=

# Skip subtitles with these words in their title.
rejected_words=sign,song

# Set top subtitle as bottom subtitle if bottom subtitle is missing.
use_top_as_bottom=yes

# Display secondary subtitle on hover.
secondary_on_hover=no

# Secondary Subtitle Hover Area (50 = the top half of the screen)
hover_height_percent=50

# Style Settings for Merged Subtitles
# In MPV, styling options for secondary subtitles are quite limited. By merging subtitles, you can work around this limitation. If your video file is on an HDD, this process may take 2–3 minutes.
# Values are given in 1920×1080 resolution.
#
#
# Color format: <alpha><alpha><b><b><g><g><r><r>
# Example: 370DE2 (RGB) > E20D37 (BGR) > &H00E20D37 (ASS)
# You can convert any RGB value to BGR by swapping the first and last two characters. Just remember that the first two characters in an ASS color code represent the alpha channel.
#
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
# If the ASS file contains sign lines (lines with a pos tag) and you don’t want them to be stripped, you can use this option.
#
#
# Valid options: bottom, top, and none
keep_ts=none

# Removes entries like "(wind blowing)" or "MAN 1:".
# Don’t expect perfect results. If you have a SDH subtitle, and the cues are very distracting, you might want to try this setting.
remove_sdh_entries=no

# Enable extended search for external subtitles.
# Loads subtitles from subfolders with the same name as the video file. Useful for series.
#
#
# NOTE: Do not enable this setting if you are using something similar.
expand_subtitle_search=no

# Keep italics during merging.
detect_italics=yes

# Prevents you from seeing the same text 20 times on the screen.
remove_repeating_lines=no
```

# External Subtitles

### Naming
External subtitles loaded on startup can be automatically selected based on your preferred languages. Make sure the subtitle filename ends with a language code.

| Accepted Filename Formats for MPV |
|-----------------|
| `movie.en.srt`  |
| `movie.eng.srt` |

*Naming your subtitles this way will make MPV recognize their languages.*


| Accepted Filename Formats for My Plugin |
|--------------- -|
| `en.srt`        |
| `eng.srt`       |
| `movie.en.srt`  |
| `movie-en.srt`  |
| `movie en.srt`  |
| `movie.eng.srt` |
| `movie-eng.srt` |
| `movie eng.srt` |

*MPV won’t show the languages for most of these subtitles, but auto-selection will still work.*

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

# Copy Subtitles
Hold the shortcut key to copy the on-screen subtitles to the clipboard. Works with merged subtitles as well.

# Related Plugins
- [sidebarsubtitles](https://github.com/magnum357i/mpv-sidebarsubtitles)