# Wi-Fi while charging for KOReader

*Deutsch: [README.de.md](README.de.md)*

KOReader turns Wi-Fi off when hardly any data flows for a few minutes (setting "Disable Wi-Fi connection when inactive"). That saves battery, but interrupts e.g. long AI requests or downloads. While the e-reader is plugged in, this plugin prevents that. If you like, it also turns Wi-Fi on when you plug it in.

## Features

Menu: gear → Network → **"Wi-Fi while charging"**, right below "Disable Wi-Fi connection when inactive". Three levels:

- **Off:** KOReader behaves as usual.
- **Keep Wi-Fi on** (default): while plugged in, Wi-Fi that is on stays on. It is never turned on by itself. The careful choice, e.g. on a power bank or a plane.
- **Keep Wi-Fi on and turn it on when plugged in:** in addition, Wi-Fi goes on shortly after you plug in. Good for home.

Wi-Fi is never turned on by itself
- if you turned it off by hand (until you turn it on yourself),
- if the [AirPlaneMode](https://github.com/kodermike/airplanemode.koplugin) plugin is installed and airplane mode is on.

Once you unplug, the normal rule applies again. You can always turn Wi-Fi off by hand.

## Installation

1. Download and unpack the ZIP file from [Releases](../../releases), or download this project.
2. Copy the folder **`wifiwhilecharging.koplugin`** into KOReader's `plugins` folder. On a Kobo that is `.adds/koreader/plugins/`.
3. Restart KOReader.

## How it works

While plugged in, the e-reader does not fall asleep by itself (KOReader would turn Wi-Fi off then). The plugin uses KOReader's own switch for that. Closing the cover and the power button still work.

Also, every few minutes KOReader counts the data packets sent. While plugged in, the plugin reports "no reading" there, and KOReader skips turning Wi-Fi off. KOReader itself handles that case. If a KOReader update changes this internal spot, the plugin does not hook in and shows a note in its menu instead of crashing. Please open an [issue](../../issues) then.

## Tested on

Kobo Libra Colour with KOReader 2026.07.1 and ZenOS.

## Who made this

The code was written entirely by **Claude**, an AI by Anthropic (in Claude Code). The owner of this project had the idea, tested the plugin on the Kobo and gave feedback, but did not write any code.

There is no warranty and no fixed support. Bug reports are welcome as an [issue](../../issues). Please attach the `crash.log` from the KOReader folder.

## License

[MIT](LICENSE)
