# Whistle Plugin for Counter-Strike: Source
Press E (use-key) to whistle to a player you're aiming at. Pretty funny, I think...
<br><br>

Whistle hear only you and target.

There's `1:50` chance to play the fun sound.

And a `1:5` chance to lose money after whistling.
<br><br>

You can use `whs` in console to whistle. Bind it to a button that you prefer. Also `!whs` and `/whs` works too, but who needs it :)
<br><br>

It's possible to set `min/max pitch` of sounds for fun. Basically it's used to slightly tweak played sound to hear it differently.
<br><br>

If you want to add your own sounds, check out:
```
#define SOUNDFORMAT ".mp3"
#define SOUNDQUANTITY 4	// except zero
```
whistle0 is the fun sound played when the fun chance procs. If you don't have the whistle0 sound, use `whs_funnychance "0"`

## Console Variariables:
<details>
  <summary>Autogenerated .cfg file</summary>
  
```
// Cooldown to whistle (in secs) {1, inf}
// -
// Default: "5"
// Minimum: "1.000000"
whs_cooldown "5"

// Enable whistle plugin. {0/1}
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "1.000000"
whs_enable "1"

// 1/n  Chance to play fun whistle. 0 - disabled {0, inf}
// -
// Default: "50"
// Minimum: "0.000000"
whs_funnychance "50"

// 1/n  Chance to loose money by whistle. 0 - disabled {0, inf}
// -
// Default: "5"
// Minimum: "0.000000"
whs_loosechance "5"

// Max distance to whistle. (in units) {0, inf}
// -
// Default: "800"
// Minimum: "0.000000"
whs_maxdistance "800"

// Message to target of whistle. 0 - disable chat messages, 1 - enable chat mesages, 2 - anonimyze chat messages. {0/1/2}
// -
// Default: "1"
// Minimum: "0.000000"
// Maximum: "2.000000"
whs_message "1"

// Money to loose by whistle
// -
// Default: "100"
whs_moneytoloose "100"

// Upper border of pitch (in %) {1, inf}
// -
// Default: "120"
// Minimum: "1.000000"
whs_pitchmax "120"

// Lower border of pitch (in %) {1, inf}
// -
// Default: "85"
// Minimum: "1.000000"
whs_pitchmin "85"

// Can whistle to: 0 - everyone, 1 - only ally, 2 - only enemy. {0/1/2}
// -
// Default: "0"
// Minimum: "0.000000"
// Maximum: "2.000000"
whs_restrictteam "0"
```
</details>
