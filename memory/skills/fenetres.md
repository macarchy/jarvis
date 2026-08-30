# Fenêtres et bureaux

Piloter Hyprland — la syntaxe dispatch est en Lua sur cette machine :

- Changer de bureau : `hyprctl eval 'hl.dispatch(hl.dsp.workspace(2))'`
- Lancer une app : `hyprctl eval 'hl.dispatch(hl.dsp.exec_cmd("kitty"))'`
- Lister les fenêtres : `hyprctl clients -j` (JSON : class, title,
  workspace) — utile pour répondre « qu'est-ce qui est ouvert ? ».
- Aller à la fenêtre d'une app : `omarchy-hyprland-focus-app <classe>`
  (ex. kitty, chromium, zed).
- Plein écran de la fenêtre active :
  `hyprctl eval 'hl.dispatch(hl.dsp.window.fullscreen())'` — si cette
  forme échoue, inspecter `hl.dsp.window` avant d'insister.
