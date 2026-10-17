# Angel Aquarium Dream

A dreamlike aquarium wallpaper for KDE Plasma. The angelfish in it wear striped sweaters, and
each one stands for a part of your computer, the way things in a dream stand for something
else. How an angelfish looks and swims says how its part is doing: a busy CPU swims hard in a
full sweater, a hot one turns red, a drive being written to eats, a network that's down falls
asleep on the sand, and real trouble earns a halo, then wings.

It's meant to be funny as well as glanceable. It isn't a performance graph: precise numbers
belong in other tools (hover over a desktop widget for its figures). Dreamlike characters that
stand for moods rather than hardware are planned.

The same angelfish also come as five desktop widgets: CPU, GPU, Memory, Disk and Network
Angelfish.

![Five angelfish in the aquarium: CPU, GPU, Memory with a halo and wings, Disk eating, and Ethernet asleep near the sand](docs/aquarium.png)

## Reading an angelfish

Every angelfish follows the same rules, so learning one teaches all of them.

| What you see | What it means |
|---|---|
| Sweater colour | Which part it is: CPU navy, GPU green, memory purple, disk orange, network teal |
| Sweater stripes | How busy or full it is, filling from the collar towards the tail (CPU: one stripe per busy core) |
| Collar | A second gauge: GPU video memory, swap, how full a drive is, how close the network is to its fastest |
| Body colour | Temperature, blue to red (grey when the part has no temperature sensor) |
| Swimming, tail beat, open eyes | Activity right now |
| Eating flakes / blowing bubbles | Data flowing in / out: downloads and uploads, writes and reads |
| Gold stripes | The share of the traffic flowing in |
| Asleep on the sand | Not available, such as a network connection that's down |
| Halo, then wings | Harm to the hardware or to responsiveness: too hot for too long, a card slowing itself down, programs waiting for memory, a connection that was lost. It builds slowly and fades more slowly still |
| Name tag | What the angelfish is, in words |

## Requirements

- KDE Plasma 5.27 (Qt 5.15). A Plasma 6 version is planned.
- Plasma's system monitor service, `ksystemstats` (installed with Plasma).
- Optional: `nvidia-smi` for NVIDIA cards (correct video-memory figures, why a card slows itself
  down, and the desktop's own share of the GPU); `ping` for the network angelfish's connection
  check.

## Install

From the KDE Store: right-click the desktop, *Configure Desktop and Wallpaper…*, *Get New
Plugins…*, and search for Angel Aquarium Dream. Widgets: *Add Widgets…*, *Get New Widgets…*.

From a downloaded package:

```sh
kpackagetool5 -t Plasma/Wallpaper -i com.erikzoltan.aquarium-0.1.0.zip
kpackagetool5 -t Plasma/Applet -i com.erikzoltan.cpufish-0.1.0.plasmoid
```

From source: `make install` installs the wallpaper and all the widgets, with their icons.
`make dist` builds the store packages into `dist/`.

Then pick *Angel Aquarium Dream* as the wallpaper type under *Configure Desktop and Wallpaper*.
A newly installed wallpaper sometimes shows only after Plasma restarts
(`systemctl --user restart plasma-plasmashell`, or log out and back in).

## Settings

The aquarium has eight angelfish slots: CPU, Memory, GPU 1-2, Disk 1-2 and Network 1-2. Each
can be switched on or off, pointed at a device (graphics card, drive, network connection) and
renamed. Temperatures use each part's own limits, so there's nothing to set. The other settings
are about cost:

- **Sensor interval** (default 4 s). Readings are about half the cost.
- **Frame rate** (default 20 fps). Each frame redraws the whole screen.
- **Water speed.**

With five angelfish at the defaults, the aquarium takes about 10% of one CPU core and a few
percent of the GPU. It stops while a maximised or full-screen window covers it. With an NVIDIA
card, the settings page shows how much of the GPU the desktop is using, and the GPU angelfish's
tag can show it too, so the wallpaper's own load isn't mistaken for work.

With several screens, one tank spans all of them and the angelfish swim from one to the next.

## Privacy

Everything stays on your computer, with one exception: to tell whether you're online, the
network angelfish pings 1.1.1.1 (Cloudflare) or 8.8.8.8 (Google) every 15 seconds. It sends
nothing else.

## Licence

GPL-2.0-or-later. See `LICENSE`.
