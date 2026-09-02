#!/usr/bin/env python3
"""Le poisson sur la Touch Bar, sans Touch Bar : le module plugin/touchbar.py
chargé par le moteur de macarchy-dfr en mémoire, avec une horloge factice.

Le moteur n'est pas une dépendance de Jarvis : sans lui (pas de
`macarchy-dfr` sur le PATH, pas de dépôt voisin), ces tests sont sautés."""
import importlib.util
import os
import shutil
import sys

import pytest

HERE = os.path.dirname(os.path.realpath(__file__))
PLUGIN = os.path.join(os.path.dirname(HERE), "plugin", "touchbar.py")


def _engine_root():
    exe = shutil.which("macarchy-dfr")
    if exe:
        return os.path.dirname(os.path.dirname(os.path.realpath(exe)))
    sibling = os.path.join(os.path.dirname(os.path.dirname(HERE)), "macarchy-dfr")
    return sibling if os.path.isdir(sibling) else None


ROOT = _engine_root()
if ROOT is None or not os.path.exists(os.path.join(ROOT, "macarchy_dfr", "modules.py")):
    pytest.skip("macarchy-dfr introuvable", allow_module_level=True)
sys.path.insert(0, ROOT)

import cairo  # noqa: E402
from macarchy_dfr.loop import EventLoop  # noqa: E402
from macarchy_dfr.modules import ModuleHost, ModuleSpec, Registry  # noqa: E402
from macarchy_dfr.widgets import Button, Label, Meter, Sprite  # noqa: E402

SHEETS = {"idle": 6, "listening": 2, "thinking": 3, "speaking": 4, "cancel": 4, "sleeping": 4,
          "tired": 2, "dnd": 2, "worried": 2, "proud": 2, "curious": 2, "celebrate": 3}


class Hooks:
    context = None
    painter = None

    def __init__(self):
        self.calls, self.layouts, self.host = [], {}, None

    def invalidate(self, w=None): self.calls.append(("inv", w))
    def show_scene(self, module_id, name, factory, **k):
        # Like the real Bar: the layout is built right away, so the module's
        # `scene_widgets` are the widgets the test can look at.
        self.calls.append(("show", name, k))
        self.layouts[name] = factory(self.host.apis[module_id])
    def hide_scene(self, n): self.calls.append(("hide", n)); self.layouts.pop(n, None)
    def on_context(self, fn): pass
    def off_context(self, fn): pass
    def keys(self, names): self.calls.append(("keys", names))
    def open_group(self, n): pass
    def close_group(self): pass
    def is_group_open(self, n): return False
    def slide_into(self, n, x, y): pass
    def wake(self): self.calls.append(("wake",))


@pytest.fixture
def sprites(tmp_path, monkeypatch):
    d = tmp_path / "sprites"
    d.mkdir()
    for name, n in SHEETS.items():
        cairo.ImageSurface(cairo.FORMAT_ARGB32, 72 * n, 56).write_to_png(str(d / f"{name}.png"))
    (d / ".look").write_text("x")
    monkeypatch.setenv("JARVIS_SPRITES", str(d))
    monkeypatch.setenv("XDG_STATE_HOME", str(tmp_path / "state"))
    monkeypatch.setenv("XDG_RUNTIME_DIR", str(tmp_path / "run"))
    return d


class Rig:
    """The module loaded by the real host, on a clock the test turns by hand."""

    def __init__(self):
        self.t = 100.0
        self.loop = EventLoop(now=lambda: self.t)
        self.hooks = Hooks()
        self.host = ModuleHost(self.loop, self.hooks, Registry())
        self.hooks.host = self.host
        self.host.load(ModuleSpec("macarchy.jarvis", PLUGIN, 40))
        assert "macarchy.jarvis" not in self.host.broken, self.host.broken
        self.api = self.host.apis["macarchy.jarvis"]
        self.api.now = lambda: self.t
        self.ran = []
        self.api.run_detached = lambda cmd: self.ran.append(cmd)
        self.mod = self.host.modules["macarchy.jarvis"]
        self.mod._last = self.t

    def ipc(self, verb, *args):
        return self.host.dispatch_ipc("macarchy.jarvis", verb, list(args))

    def advance(self, seconds, step=0.05):
        end = self.t + seconds
        while self.t < end - 1e-9:
            self.t = min(end, self.t + step)
            self.mod.animate()

    def fish(self, **p):
        return self.host.registry.factory("macarchy.jarvis.fish")(self.api, **p)

    def scene(self):
        """The layout the bar would be showing: the same widgets the module holds in `scene_widgets`."""
        return self.hooks.layouts.get("jarvis")

    def last_show(self):
        shows = [c for c in self.hooks.calls if c[0] == "show"]
        return shows[-1] if shows else None


def test_setup_registers_the_fish_and_spawns_nothing(sprites):
    rig = Rig()
    assert "macarchy.jarvis.fish" in rig.host.registry.names("macarchy.jarvis")
    assert rig.loop.children == {}


def test_fish_is_a_pill_sprite_that_presses_and_opens_the_page(sprites):
    rig = Rig()
    w = rig.fish()
    assert isinstance(w, Sprite) and w.pill and w.measure() == Button.WIDTH
    assert w.frames == 6 and w.fps == 2.2                     # the idle sheet, read off its width
    w.on_tap(0, 0)
    w.on_long_press(0, 0)
    assert rig.ran == ["omarchy-jarvis press", "omarchy-shell macarchy.control-center jarvis"]


def test_sleeping_dresses_the_button_and_shows_no_scene(sprites):
    rig = Rig()
    w = rig.fish()
    assert rig.ipc("state", "sleeping") == "ok"
    assert w.sheet.endswith("sleeping.png") and w.frames == 4
    assert ("hide", "jarvis") in rig.hooks.calls and rig.last_show() is None


def test_an_emotion_at_rest_lasts_six_seconds(sprites):
    rig = Rig()
    w = rig.fish()
    rig.ipc("emote", "proud")
    rig.advance(0.1)
    assert w.sheet.endswith("proud.png")
    rig.advance(6.0)
    assert w.sheet.endswith("idle.png")


def test_an_emotion_is_refused_while_he_works_or_when_nobody_drew_it(sprites):
    rig = Rig()
    w = rig.fish()
    rig.ipc("state", "listening")
    rig.ipc("emote", "proud")
    rig.advance(0.1)
    assert w.sheet.endswith("listening.png")
    rig.ipc("state", "idle")
    assert rig.ipc("emote", "nonexistent") == "ok"
    rig.advance(0.1)
    assert w.sheet.endswith("idle.png")


def test_abort_recoils_for_a_moment_then_rests(sprites):
    rig = Rig()
    w = rig.fish()
    rig.ipc("state", "listening")
    rig.ipc("state", "idle")
    rig.ipc("abort")
    rig.advance(0.1)
    assert w.sheet.endswith("cancel.png")
    assert ("hide", "jarvis") in rig.hooks.calls
    rig.advance(1.6)
    assert w.sheet.endswith("idle.png")


def test_the_state_file_is_read_at_load(sprites, tmp_path):
    run = tmp_path / "run" / "jarvis"
    run.mkdir(parents=True)
    (run / "state").write_text("speaking\n")
    rig = Rig()
    assert rig.mod.state == "speaking"


def test_bad_arguments_never_break_the_module(sprites):
    rig = Rig()
    rig.ipc("state", "bogus")
    rig.ipc("state")
    rig.ipc("level", "abc")
    rig.ipc("level")
    rig.ipc("emote")
    assert rig.host.broken == {}
    assert rig.mod.state == "idle"


def test_regenerated_sheets_are_reloaded(sprites):
    rig = Rig()
    w = rig.fish()
    cairo.ImageSurface(cairo.FORMAT_ARGB32, 72 * 8, 56).write_to_png(str(sprites / "idle.png"))
    rig.mod.resheet()                       # what api.watch_file(".look") calls when `look` touches it
    assert w.frames == 8
