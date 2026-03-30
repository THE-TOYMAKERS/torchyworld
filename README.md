# Torchy's World

A high-speed infinite runner for the [Playdate](https://play.date) handheld console.

## The Twist

Unlike traditional infinite runners, **Torchy's World** puts you on a circular track orbiting the center of the screen. Use the Playdate's **crank** to rotate your skateboard character 360 degrees around the track. Dodge obstacles, land on platforms, and survive as long as you can!

## Controls

| Input | Action |
|-------|--------|
| **Crank** | Rotate character around the circular track |
| **A Button** | Jump (dodge obstacles, clear gaps) |

## Gameplay

- You ride a skateboard on a circular orbital track
- Platforms appear as arc segments around the track — you must be on a platform or you'll fall!
- Obstacles (spikes, cones, fire) spawn on platforms — rotate away or jump over them
- Speed increases over time, and more obstacles appear
- Collect stars for bonus points
- Game ends when you hit an obstacle or fall off a platform gap
- Single-session game loop — try to beat your high score!

## Building

### Requirements
- [Playdate SDK](https://play.date/dev/) (tested with 2.6.2+)

### Compile
```bash
export PLAYDATE_SDK_PATH=/path/to/PlaydateSDK
pdc source Torchys-world.pdx
```

### Run in Simulator
```bash
PlaydateSimulator Torchys-world.pdx
```

### Sideload to Device
Transfer the `Torchys-world.pdx` folder to your Playdate via USB.

## Project Structure

```
source/
├── main.lua          # Entry point, game loop, state machine
├── player.lua        # Player character (skateboard, orbit, jump)
├── world.lua         # Scrolling background, visual effects
├── obstacles.lua     # Platform/obstacle/collectible management
├── hud.lua           # Score, speed, distance display
├── pdxinfo           # Playdate game metadata
├── images/           # 1-bit sprite assets
│   ├── player.png
│   ├── player-jump.png
│   ├── obstacle-spike.png
│   ├── obstacle-cone.png
│   ├── obstacle-fire.png
│   ├── platform.png
│   ├── star.png
│   ├── center-hub.png
│   └── launcher/
│       ├── card.png
│       └── icon.png
└── sounds/           # Sound effects (future)
```

## Credits

Built by **THE TOYMAKERS**

---

*Crank it up!*
