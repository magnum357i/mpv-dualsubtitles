# mpv-dualsubtitles
Dual subtitles plugin for mpv.

# Key Bindings
- `k/K`: Switch secondary subtitles. Cycle through the available subtitles for the top. Use k for forward and K (shift+k) for backward.
- `u`: Reverse subtitles. The top subtitle changes to the bottom subtitle, the bottom subtitle changes to the top subtitle.
- `v`: Hide the top subtitle and the bottom subtitle.

# Configuration
### Select Language
Subtitles can be selected by default and the `preferredLanguages` setting related to this. the **bottom** represents the primary subtitle or the subtitle located at the bottom, while the **top** represents the secondary subtitle or the subtitle located at the top.
```
preferredLanguages = {bottom = {"eng","jpn"}, top = {"tur"}},
```

### Skip Ignored Subtitles
Undesired subtitles can be set not to be selected at startup. For this, set `skipIgnoredSubtitles` to true and type your ignored words to the `ignoredubtitleMatch` setting.
```
skipIgnoredSubtitles = true
ignoredSubtitleMatch = {"signs", "songs", "forced"}
```
