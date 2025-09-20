# mpv-dualsubtitles
Dual subtitles plugin for mpv.

![Example for Dual Subtitles](https://github.com/magnum357i/mpv-dualsubtitles/blob/main/mpv-shot0001.jpg)

# Key Bindings
| shortcut            | description                               |
| ------------------- | ----------------------------------------- |
| <kbd>k</kbd>        | switch secondary subtitle track           |
| <kbd>K</kbd>        | switch secondary subtitle track backwards |
| <kbd>u</kbd>        | reverse subtitles                         |
| <kbd>v</kbd>        | cycle through subtitle visibility modes   |
| <kbd>Ctrl+e</kbd>   | move secondary subtitle down              |
| <kbd>Ctrl+E</kbd>   | move secondary subtitle up                |
| <kbd>Ctrl+b</kbd>   | merge subtitles into a single file        |
| <kbd>Ctrl+B</kbd>   | delete the merged file                    |

# How Does Auto Selection Work?
- Find subtitles based on the preferred languages.
- Skip forced and ignored subtitles.
- Sort subtitles by size.
- Skip hearing-impaired subtitles.
- Select the first subtitle. If none, use a hearing-impaired subtitle.

Forced subtitles are never selected when full subtitles are available, even if they are not properly marked. And hearing-impaired subtitles are better than no subtitle.

# Configuration
Create a file named `dualsubtitles.conf` in the script-opts directory, and copy the content below into it. You can now modify the settings as desired.

```ini
# Subtitles to be auto-selected at startup
top_languages=tr-tr
bottom_languages=en-us,ja-jp

# Exclude subtitles with these words in their title
ignored_words=sign,song

# Set top subtitle as bottom subtitle if bottom subtitle is missing
use_top_as_bottom=yes

# Show secondary subtitle while hovering
secondary_on_hover=no

# Secondary subtitle hover area (50 = the top half of the screen)
hover_height_percent=50

# Style settings for the merged subtitle
# In MPV, styling options for the secondary subtitle are very limited.
# By merging the subtitles, you can work around this limitation. If your video file is on an HDD, this process may take 2–3 minutes.
top_style=fn:Arial,fs:70,1c:&H0000DEFF,2c:&H000000FF,3c:&H00000000,4c:&H00000000,b:0,i:0,u:0,s:0,sx:100,sy:100,fsp:0,frz:0,bs:1,bord:3,shad:0,an:8,ml:0,mr:0,mv:40,enc:1
bottom_style=fn:Arial,fs:70,1c:&H00FFFFFF,2c:&H000000FF,3c:&H00000000,4c:&H00000000,b:0,i:0,u:0,s:0,sx:100,sy:100,fsp:0,frz:0,bs:1,bord:3,shad:0,an:2,ml:0,mr:0,mv:40,enc:1

# ASS tags for the merged subtitle
# When a line is stripped based on your current settings, these tags will be added to it.
top_tags=
bottom_tags=\blur4

# Don’t strip sign lines
# If the ASS file contains sign lines (lines with a pos tag) and you don’t want them to be stripped, you can use this option.
# Valid options: bottom, top, and none
keep_ts=none

# Removes entries like "(wind blowing)" or "MAN 1:"
# Don’t expect perfect results. If you have a SDH subtitle, and the cues are very distracting, you might want to try this setting.
remove_sdh_entries=no

# Loads subtitles from subfolders with the same name as the video file
# Useful for series
expand_subtitle_search=no

# Italic lines in the source subtitle remain italic after merge.
detect_italics=yes

# Prevents you from seeing the same text 20 times on the screen.
remove_repeating_lines=none
```

# External Subtitles

### Naming
External subtitles loaded at startup can be automatically selected based on your preferred languages. Make sure the subtitle filename ends with a language code.

| Accepted Filename Formats for MPV |
|-----------------|
| `movie.en.srt`  |
| `movie.eng.srt` |

*Naming your subtitles this way will make MPV recognize their languages.*


| Accepted Filename Formats for My Plugin |
|-----------------|
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

*(Subtitles are usually located in these directories.)*

2) **dualsubtitles.conf**

```ini
expand_subtitle_search=yes
```

# Merging Subtitles
Merging subtitles allows you to have more styling options.

![Example for Merging Subtitles](https://github.com/magnum357i/mpv-dualsubtitles/blob/main/mpv-shot0002.jpg)

### Clean Up SDH Entries

If cues are distracting, enable the option below.

```ini
remove_sdh_entries=yes
```

**NOTE:** Perfect results are not possible.

### ASS Files

It’s possible to merge two ASS subtitles without altering the sign lines of one file.

![Example 2 for Merging Subtitles](https://github.com/magnum357i/mpv-dualsubtitles/blob/main/mpv-shot0003.jpg)
*TS: Kinoshita Hideyoshi*

For this, use the setting below.

```ini
keep_ts=bottom
```