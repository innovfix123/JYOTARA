# Bundled interface fonts

The active app interface uses Inter. Both `JyotaraSans` and the historical
`JyotaraEditorial` alias point to Inter. Chat uses Roboto through `JyotaraChat`.
Tamil uses the bundled Noto Sans Tamil fallback through `JyotaraTamil`.

Font source: [Google Fonts repository](https://github.com/google/fonts), pinned
at commit `2eb0b48d5f760f62e286216f0859a8c540dbc1bd`.

The TTFs are static instances of these upright variable sources:

- `ofl/inter/Inter[opsz,wght].ttf`, with optical size 14.
- `ofl/roboto/Roboto[wdth,wght].ttf`, with width 100.
- `ofl/notosanstamil/NotoSansTamil[wdth,wght].ttf`, with width 100.

Each family includes weights 400, 500, 600, and 700. Instances were created with
fontTools 4.60.2 `instantiateVariableFont` to give Flutter real static weight
faces. The original family names and copyright metadata are retained. All
three families use the SIL Open Font License 1.1; their complete license files
are packaged with the app. The previous Manrope and Cormorant source files are
retained for history and are not registered as active interface fonts.

All font assets are local; the app makes no font downloads at runtime.
