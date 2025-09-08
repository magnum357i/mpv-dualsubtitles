# mpv-dualsubtitles
Dual subtitles plugin for mpv.

![Example for Dual Subtitles](https://github.com/magnum357i/mpv-dualsubtitles/blob/main/mpv-shot0004.jpg)

# Key Bindings
| shortcut            | description                               |
| ------------------- | ----------------------------------------- |
| <kbd>k</kbd>        | switch secondary subtitle track           |
| <kbd>K</kbd>        | switch secondary subtitle track backwards |
| <kbd>u</kbd>        | reverse subtitles                         |
| <kbd>v</kbd>        | cycle through subtitle visibility modes   |
| <kbd>Ctrl+e</kbd>   | move secondary subtitle down              |
| <kbd>Ctrl+E</kbd>   | move secondary subtitle up                |

# How Does the Auto Selection Work?
- Find subtitles based on the preferred languages.
- Skip forced and ignored subtitles.
- Sort subtitles by size.
- Skip hearing-impaired subtitles.
- Select the first subtitle. If none, use a hearing-impaired subtitle.

Forced subtitles are never selected when full subtitles are available, even if they are not properly marked. And hearing-impaired subtitles are better than no subtitle.

# Configuration
Create a file named `dualsubtitles.conf` in the script-opts directory, and copy the content below into it. You can now modify the settings as desired.

```ini
# Bottom subtitle selection at startup (external subs included)
bottom_languages=en-us,ja-jp

# Top subtitle selection at startup (external subs included)
top_languages=tr-tr

# Exclude subtitles with these words in their title (does not work for external subs because their title is broken)
ignored_words=sign,song

# Set top subtitle as bottom subtitle if bottom subtitle is missing
use_top_as_bottom=yes

# Show secondary subtitle while hovering
secondary_on_hover=no

# Secondary subtitle hover area (50 = the top half of the screen)
hover_height_percent=50
```

### External Subtitles
External subtitles loaded at startup can be automatically selected based on your preferred languages. Make sure the subtitle filename ends with a language code.

| Accepted Filename Formats |
|-----------------|
| `movie.en.srt`  |
| `movie-en.srt`  |
| `movie en.srt`  |
| `movie.eng.srt` |
| `movie-eng.srt` |
| `movie eng.srt` |