"""Picklable adapter between openWakeWord's verifier call and sklearn.

openWakeWord hands the verifier the raw streaming feature window — shape
(1, 16, 96) — and reads predict_proba(...)[0][-1]. This shim flattens the
window into 16 embedding rows, scores each with the wrapped classifier,
and reports the window's best positive probability in the slot
openWakeWord reads. It must be importable wherever the pickle is loaded
(training script and jarvis-wake.py both add wake/ to sys.path).
"""

import numpy as np


class FlatVerifier:
    def __init__(self, clf):
        self.clf = clf

    def predict_proba(self, features):
        rows = np.asarray(features).reshape(-1, np.asarray(features).shape[-1])
        probs = np.sort(self.clf.predict_proba(rows)[:, -1])
        # Mean of the top three rows: a real wake phrase saturates several
        # consecutive frames, a phonetic collision rarely more than one.
        best = float(probs[-3:].mean())
        return np.array([[1.0 - best, best]])
