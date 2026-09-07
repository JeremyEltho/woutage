# woutage

A macOS menu bar app that shows how many watts your Mac is drawing, where that
power is going, and which apps are draining the battery.

Runs entirely as a normal user app. No privileged helper, no root, no login item.

## What it shows

- **Menu bar** — battery percentage and live wattage.
- **Battery** — time remaining (or time to full), power source, charging state.
- **Health** — temperature, cycle count, and maximum capacity.
- **Power distribution** — where the watts are going. On battery that is
  `battery → laptop`. On the charger it splits into what the charger supplies,
  what the laptop consumes, and what is going into the battery.
- **Apps with high energy usage** — the top energy consumers, with icons.

System processes are translated into plain English, so the list reads
`Display & graphics compositor` rather than `WindowServer`, with the raw
process name kept underneath for reference.

## Install

```sh
./build.sh
```

Compiles, ad-hoc signs, installs into `/Applications`, and launches. Requires
the Xcode command line tools and macOS 13 or later.

## How it works

Everything comes from APIs a normal user process can reach:

| Value | Source |
| --- | --- |
| Battery level, charging state, time remaining | `IOPSCopyPowerSourcesInfo` |
| Wattage, cycle count, temperature | `AppleSmartBattery` IOKit registry |
| Charger input | `PowerTelemetryData.SystemPowerIn` (milliwatts) |
| Battery health | `system_profiler SPPowerDataType` |
| Per-app energy impact | `systemstats_get_top_coalitions` |

Battery power is `voltage × amperage` from the gas gauge, signed so that
positive means discharging. The charger figure comes from IOKit power
telemetry, and the laptop's own draw is the sum of the two.

Per-app energy impact uses the same private `libsystemstats` call Activity
Monitor relies on, loaded with `dlopen`. It reports *coalitions* — the kernel's
own grouping of a process tree — so an app's helper processes are already
counted against the parent app rather than listed separately.

## Prior art

The power distribution layout follows
[BatFi](https://github.com/rurza/BatFi) by Adam Różyński, which is a far more
capable app and worth buying if you want charge limiting. BatFi reads its power
figures from SMC keys through a privileged helper; woutage derives the
equivalent values from IOKit so it can run unprivileged.
