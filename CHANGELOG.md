# Changelog

## v1.0.0
- Initial release.
- The enemy **Affinities** panel (**Display Unit Info**) now shows the elements you've tried that did **neutral** damage, as plain element icons next to the game's weakness and resistance icons.
- Neutral elements you haven't tried yet stay hidden, so the panel only shows what you've actually used. Set `ShowUntested = true` in `config.ini` to show them as **?** instead.
- Tried elements are remembered per monster type by the game's own save data, so they carry over to later battles.
- `config.ini` options: `NeutralRow` (turn the feature off), `ShowUntested` and `Debug`.
- No game files are modified; everything changes in memory while the game runs.
