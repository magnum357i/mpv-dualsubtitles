# mpv-dualsubtitles
Dual subtitles plugin for mpv.

![Example for Dual Subtitles](https://github.com/magnum357i/mpv-dualsubtitles/blob/main/mpv-shot0004.jpg)

# Key Bindings
- `k/K`: Cycle through the available subtitles for the top subtitle track. Use k to go forward and K (Shift + k) to go backward.
- `u`: Reverse subtitles. The top subtitle becomes the bottom subtitle, and the bottom subtitle becomes the top subtitle.
- `v`: Cycle through subtitle visibility modes. The modes are: (1) only bottom subtitle visible, (2) both subtitles hidden, and (3) both subtitles visible.

# Configuration
### Select Language
You can set the default subtitles using the preferredLanguages setting.
- **bottom**: primary subtitle (displayed at the bottom)
- **top**: secondary subtitle (displayed at the top)

```
preferredLanguages = {bottom = "en_gb,en,ja,jpn", top = "tr,tur"},
```

### Skip Ignored Subtitles
You can prevent undesired subtitles from being selected at startup. Simply add the keywords you want to ignore in the ignoredSubtitles setting:
```
ignoredSubtitles = {"sign,song"}
```

### Show the Top Subtitle as the Bottom Subtitle if the Bottom Subtitle Does Not Exist
Set the useTopAsBottom setting to true to enable this behavior:
```
useTopAsBottom = true
```

### External Subtitles
If an external subtitle is added through one of mpv’s auto-loading methods like sub-auto=fuzzy and sub-auto=auto, it can be automatically selected according to the preferredLanguages setting. Make sure the subtitle filename ends with a language code (e.g., en, eng).