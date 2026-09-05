"""Jarvis sur la Touch Bar. Chargé en mémoire par macarchy-touchbar (kind
`touchbar-module`), nourri par bin/jarvis et le wake daemon à travers
`macarchy-touchbar macarchy.jarvis <verbe>`.

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

from macarchy_touchbar.layout import Layout, Row
from macarchy_touchbar.widgets import Button, Label, Meter, Sprite

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
TYPE_CPS = 40           # machine à écrire, caractères par seconde
LEVEL_STALE = 0.3       # sans `level` depuis ce temps, le vumètre respire seul
BANDS = 12
IDLE_LINGER = 4.0       # la scène reste après la réponse
SCENE_STATES = ("listening", "transcribing", "thinking", "speaking", "followup")


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


def bands_for(level, n, t):
    """Un niveau réparti sur n bandes : une bosse au milieu, un peu de vie sur
    les côtés, pour qu'un seul nombre se lise comme une voix."""
    out = []
    for i in range(n):
        x = (i + 0.5) / n * 2 - 1                    # -1 … 1
        env = 1.0 - 0.6 * x * x
        wobble = 0.15 * math.sin(t * 9.0 + i * 1.7)
        out.append(max(0.0, min(1.0, level * (env + wobble))))
    return out


def breathing(t):
    """Le niveau que le vumètre s'invente quand personne ne le nourrit."""
    return 0.18 + 0.10 * math.sin(2 * math.pi * 0.8 * t)


def tail_that_fits(text, width, measure):
    """La fin de `text` qui tient dans `width` px, derrière « … », coupée sur
    un mot quand c'est possible."""
    if measure(text) <= width:
        return text
    budget = max(0, width - measure("…"))
    lo, hi = 0, len(text)
    while lo < hi:                                   # plus petit début dont la queue tient
        mid = (lo + hi) // 2
        if measure(text[mid:]) <= budget:
            hi = mid
        else:
            lo = mid + 1
    tail = text[lo:]
    sp = tail.find(" ")
    if 0 <= sp < len(tail) // 2:
        tail = tail[sp + 1:]
    return "…" + tail.lstrip()


class Typewriter:
    """Un texte qui s'écrit à TYPE_CPS. `set` garde sa place quand le nouveau
    texte ne fait que prolonger l'ancien (la machine renvoie toute la réponse
    à chaque phrase), et repart de zéro sinon."""

    def __init__(self):
        self.target, self.shown, self._acc = "", 0, 0.0

    def set(self, text):
        if not text.startswith(self.target):
            self.shown, self._acc = 0, 0.0
        self.target = text

    def advance(self, dt):
        self._acc += dt * TYPE_CPS
        n = int(self._acc)
        if n:
            self._acc -= n
            self.shown = min(len(self.target), self.shown + n)
        return self.target[:self.shown]

    @property
    def done(self):
        return self.shown >= len(self.target)


def tappable(widget, fn):
    """Un widget de la scène qui, touché, la ferme : `on_tap` est posé sur
    l'instance (la barre appelle `w.on_tap(x, y)`)."""
    widget.on_tap = lambda x, y: fn()
    return widget


class Module:
    def setup(self, api):
        self.api = api
        self.state = read_state()
        self.emote, self.emote_until, self.cancel_until = None, 0.0, 0.0
        self.buttons = weakref.WeakSet()
        self._last = api.now()
        self.heard, self.reply = "", ""
        self.level, self.level_at = 0.0, float("-inf")
        self.writer = Typewriter()
        self.scene_widgets = {}          # ce que la scène affichée contient, par rôle ; vide = pas de scène
        self._last_text = None
        self._linger = None              # le minuteur des quatre secondes de fin d'échange
        self._anim = None                # le minuteur de 20 Hz, à la demande seulement
        api.widget("fish", self.fish)
        api.ipc("state", self.on_state)
        api.ipc("emote", self.on_emote)
        api.ipc("abort", self.on_abort)
        api.scene("jarvis", self.build_scene)
        api.ipc("heard", self.on_heard)
        api.ipc("reply", self.on_reply)
        api.ipc("level", self.on_level)
        api.watch_file(os.path.join(SPRITES_DIR, ".look"), self.resheet)

    def _ensure_animating(self):
        """Démarre le minuteur de 20 Hz s'il ne tourne pas déjà : rien ne
        l'entretient tant que personne ne l'a réveillé."""
        if self._anim is None:
            self._anim = self.api.every(0.05, self.animate)

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
        self._ensure_animating()

    # ---- les verbes ---------------------------------------------------------
    def on_state(self, state="idle", *_):
        if state not in STATES:
            state = "idle"
        if state == self.state:
            return
        self.state = state
        if state == "cancelling":
            self.cancel_until = self.api.now() + CANCEL_SECONDS
            self._ensure_animating()
        if state == "listening":
            self.heard, self.reply = "", ""
            self.writer = Typewriter()
            self.api.wake()
        self._sync_scene()
        self._sync_buttons()

    def on_emote(self, name="", *_):
        if name in FPS and self.state == "idle":
            self.emote, self.emote_until = name, self.api.now() + EMOTE_SECONDS
            self._sync_buttons()
            self._ensure_animating()

    def on_abort(self, *_):
        self.cancel_until = self.api.now() + CANCEL_SECONDS
        self._dismiss()
        self._sync_buttons()
        self._ensure_animating()

    def on_heard(self, *words):
        # No rebuild: every scene has its text label, `animate` types into it.
        self.heard = " ".join(words).strip()
        self.writer.set(self.heard)

    def on_reply(self, *words):
        self.reply = " ".join(words).strip()
        self.writer.set(self.reply)

    def on_level(self, value="", *_):
        try:
            v = float(value)
        except (TypeError, ValueError):
            return
        self.level, self.level_at = max(0.0, min(1.0, v)), self.api.now()

    # ---- la scène -------------------------------------------------------------
    def _sync_scene(self):
        if self.state in SCENE_STATES:
            self.api.show_scene("jarvis", priority=50, dismissable=False)
            self._ensure_animating()
        elif self.state == "idle" and self.scene_widgets:
            # Fin de l'échange : la scène reste quatre secondes, un tap la ferme.
            self.api.show_scene("jarvis", priority=50, timeout=IDLE_LINGER)
            self._arm_linger()
            self._ensure_animating()
        else:
            self._dismiss()

    def _arm_linger(self):
        if self._linger:
            self._linger.cancel()
        self._linger = self.api.after(IDLE_LINGER, self._forget_scene)

    def _forget_scene(self):
        self._linger = None
        if self.state == "idle":
            self.scene_widgets = {}

    def _dismiss(self):
        if self._linger:
            self._linger.cancel()
        self._linger = None
        self.scene_widgets = {}
        self.api.hide_scene("jarvis")

    def build_scene(self, api):
        st = self.state
        theme = api.theme
        fish = Sprite(api, width=96, frame_w=FRAME_W, frame_h=FRAME_H)
        self._dress(fish, "idle" if st == "idle" else SHEET_FOR.get(st, st))
        w = {"fish": fish}
        if st in ("listening", "followup"):
            w["meter"] = Meter(api, bands=BANDS, width=300,
                               color=theme.FG_DIM if st == "followup" else theme.FG)
        if st == "listening":
            w["text"] = Label(api, text="J'écoute…", stretch=1, align="left", color=theme.FG_DIM, _role="text")
        else:
            w["text"] = Label(api, text=self.writer.advance(0), stretch=1, align="left", _role="text")
        if st in ("transcribing", "thinking"):
            w["dots"] = Label(api, text="·", width=70, size=34, color=theme.FG_DIM, _role="dots")
        if st == "listening":
            close = Button(api, icon="close", on_tap=lambda: api.run_detached("omarchy-jarvis cancel"))
        elif st in SCENE_STATES:
            close = Button(api, icon="close", on_tap=lambda: api.run_detached("omarchy-jarvis press"))
        else:
            close = Button(api, icon="close", on_tap=self._dismiss)
            for x in w.values():
                tappable(x, self._dismiss)
        order = [w["fish"]] + [w[k] for k in ("meter", "text", "dots") if k in w] + [close]
        self.scene_widgets = w
        self._last_text = None
        return Layout(Row(order), Row([]))

    def animate(self):
        now = self.api.now()
        dt, self._last = now - self._last, now
        w = self.scene_widgets
        if w:
            if "meter" in w:
                level = self.level if now - self.level_at < LEVEL_STALE else breathing(now)
                if self.state == "followup":
                    level *= 0.5
                w["meter"].set_bands(bands_for(level, BANDS, now))
            if "text" in w and self.state != "listening":
                text = self.writer.advance(dt)
                if text != self._last_text:
                    self._last_text = text
                    if self.state in ("speaking", "followup", "idle"):
                        width = w["text"].rect.w if w["text"].rect else 1200
                        text = tail_that_fits(text, width, self.api.measure_text)
                    w["text"].set_text(text)
            if "dots" in w:
                w["dots"].set_text("·" * (1 + int(now * 3) % 3))
        self._sync_buttons()
        if not w and now >= self.emote_until and now >= self.cancel_until:
            if self._anim:
                self._anim.cancel()
            self._anim = None
