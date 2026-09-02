"""Jarvis sur la Touch Bar. Chargé en mémoire par macarchy-dfr (kind
`touchbar-module`), nourri par bin/jarvis et le wake daemon à travers
`macarchy-dfr macarchy.jarvis <verbe>`.

Au repos, le poisson est un bouton (tap = press, appui long = sa page du
Control Center) qui porte l'état et les émotions comme le service QML. Le
reste — la scène qui prend toute la barre pendant qu'il écoute, réfléchit et
répond — vit dans la seconde moitié de ce fichier.

Il ne voit que `api` : pas de fichier écrit dans le dossier du plugin, rien
de lancé au chargement, et un verbe reçu de travers est ignoré, jamais levé.
"""
import math
import os
import weakref

from macarchy_dfr.layout import Layout, Row
from macarchy_dfr.widgets import Button, Label, Meter, Sprite

SPRITES_DIR = os.environ.get("JARVIS_SPRITES") or os.path.expanduser("~/.local/share/jarvis/sprites")
RUN_DIR = os.environ.get("JARVIS_RUN") or os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "jarvis")
FRAME_W, FRAME_H = 72, 56
# Images par seconde de chaque planche — la table `sheets` de Service.qml ;
# le nombre d'images se lit sur la largeur de la planche.
FPS = {"idle": 2.2, "listening": 4, "thinking": 3, "speaking": 8, "cancel": 6, "sleeping": 1.4,
       "tired": 1.6, "dnd": 2.2, "worried": 2.5, "proud": 2.2, "curious": 2.5, "celebrate": 6}
# Les états de la machine (bin/jarvis-fsm.sh), tels qu'on_state_change les envoie.
STATES = ("idle", "listening", "transcribing", "thinking", "speaking", "followup", "sleeping", "cancelling")
# Trois états n'ont pas de planche à eux et en empruntent une.
SHEET_FOR = {"transcribing": "thinking", "followup": "listening", "cancelling": "cancel"}
EMOTE_SECONDS = 6.0
CANCEL_SECONDS = 1.5


def sheet_path(name):
    return os.path.join(SPRITES_DIR, f"{name}.png")


def read_state():
    """L'état courant de la machine, pour prendre la barre à chaud."""
    try:
        with open(os.path.join(RUN_DIR, "state")) as f:
            s = f.read().strip()
    except OSError:
        return "idle"
    return s if s in STATES else "idle"


class Module:
    def setup(self, api):
        self.api = api
        self.state = read_state()
        self.emote, self.emote_until, self.cancel_until = None, 0.0, 0.0
        self.buttons = weakref.WeakSet()
        self._last = api.now()
        api.widget("fish", self.fish)
        api.ipc("state", self.on_state)
        api.ipc("emote", self.on_emote)
        api.ipc("abort", self.on_abort)
        api.every(0.05, self.animate)
        api.watch_file(os.path.join(SPRITES_DIR, ".look"), self.resheet)

    # ---- le bouton ----------------------------------------------------------
    def fish(self, api, **p):
        width = p.pop("width", Button.WIDTH)
        w = Sprite(api, pill=True, width=width, frame_w=FRAME_W, frame_h=FRAME_H,
                   on_tap=lambda: api.run_detached("omarchy-jarvis press"),
                   on_long_press=lambda: api.run_detached("omarchy-shell macarchy.control-center jarvis"), **p)
        self._dress(w, self.button_sheet())
        self.buttons.add(w)
        return w

    def button_sheet(self):
        now = self.api.now()
        if now < self.cancel_until:
            return "cancel"
        if self.state != "idle":
            return SHEET_FOR.get(self.state, self.state)
        if self.emote and now < self.emote_until:
            return self.emote
        return "idle"

    def _dress(self, sprite, name, force=False):
        if force or getattr(sprite, "_sheet_name", None) != name:
            sprite._sheet_name = name
            sprite.set_sheet(sheet_path(name), 0, FPS.get(name, 4))

    def _sync_buttons(self):
        name = self.button_sheet()
        for b in list(self.buttons):
            self._dress(b, name)

    def resheet(self):
        """`omarchy-jarvis look` a regénéré les planches : tout le monde relit la sienne."""
        for b in list(self.buttons):
            self._dress(b, self.button_sheet(), force=True)

    # ---- les verbes ---------------------------------------------------------
    def on_state(self, state="idle", *_):
        if state not in STATES:
            state = "idle"
        if state == self.state:
            return
        self.state = state
        if state == "cancelling":
            self.cancel_until = self.api.now() + CANCEL_SECONDS
        self._sync_scene()
        self._sync_buttons()

    def on_emote(self, name="", *_):
        if name in FPS and self.state == "idle":
            self.emote, self.emote_until = name, self.api.now() + EMOTE_SECONDS
            self._sync_buttons()

    def on_abort(self, *_):
        self.cancel_until = self.api.now() + CANCEL_SECONDS
        self.api.hide_scene("jarvis")
        self._sync_buttons()

    # ---- la scène (Task 5) ----------------------------------------------------
    def _sync_scene(self):
        self.api.hide_scene("jarvis")

    def animate(self):
        now = self.api.now()
        self._last = now
        self._sync_buttons()
