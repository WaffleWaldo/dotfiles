"""Build the Coldwire neural-map dataset from the Obsidian vault.

Scans ~/Documents/brain for [[wikilinks]], runs a small force layout, and
writes ~/.cache/coldwire/vault-graph.json for the coldwire-net panel.
Excludes Sensitive/ and Ren/ (vault rules), plus non-note folders.
"""
import json
import os
import re
import numpy as np

VAULT = os.path.expanduser("~/Documents/brain")
OUT = os.path.expanduser("~/.cache/coldwire/vault-graph.json")
SKIP_DIRS = {".obsidian", ".git", ".trash", "Sensitive", "Ren", "Attachments", "Templates"}
MAX_NODES = 130
LINK_RE = re.compile(r"\[\[([^\]|#\n]+)")

notes = {}  # basename(lower) -> {name, path, links:set}
for dirpath, dirnames, filenames in os.walk(VAULT):
    dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
    for fn in filenames:
        if not fn.endswith(".md"):
            continue
        full = os.path.join(dirpath, fn)
        rel = os.path.relpath(full, VAULT)[:-3]
        name = fn[:-3]
        key = name.lower()
        try:
            with open(full, encoding="utf-8", errors="ignore") as f:
                text = f.read()
        except OSError:
            continue
        targets = {t.strip().lower() for t in LINK_RE.findall(text)}
        if key not in notes:  # first wins on basename collision
            notes[key] = {"name": name, "path": rel, "links": targets}

# resolve links to existing notes, undirected edge set
keys = list(notes.keys())
idx = {k: i for i, k in enumerate(keys)}
edges = set()
for k in keys:
    for t in notes[k]["links"]:
        if t in idx and t != k:
            a, b = sorted((idx[k], idx[t]))
            edges.add((a, b))

deg = [0] * len(keys)
for a, b in edges:
    deg[a] += 1
    deg[b] += 1

# declutter: cap drawn edges per node (favor leaf attachments over hub-hub webs)
capped = []
slots = {}
for a, b in sorted(edges, key=lambda e: deg[e[0]] + deg[e[1]]):
    if slots.get(a, 0) < 8 and slots.get(b, 0) < 8:
        capped.append((a, b))
        slots[a] = slots.get(a, 0) + 1
        slots[b] = slots.get(b, 0) + 1
edges = set(capped)

# keep only linked notes; cap by degree
linked = [i for i in range(len(keys)) if deg[i] > 0]
linked.sort(key=lambda i: -deg[i])
keep = sorted(linked[:MAX_NODES])
remap = {old: new for new, old in enumerate(keep)}
edges = [(remap[a], remap[b]) for a, b in edges if a in remap and b in remap]
n = len(keep)

# 3D force layout (seeded for stability run-to-run)
rng = np.random.default_rng(31)
pos = rng.random((n, 3)) * 0.8 + 0.1
E = np.array(edges) if edges else np.zeros((0, 2), dtype=int)
for it in range(300):
    disp = np.zeros_like(pos)
    delta = pos[:, None, :] - pos[None, :, :]
    dist2 = (delta ** 2).sum(-1) + 1e-4
    rep = 0.0016 / dist2
    np.fill_diagonal(rep, 0)
    disp += (delta * rep[:, :, None]).sum(1)
    if len(E):
        d = pos[E[:, 0]] - pos[E[:, 1]]
        pull = d * 1.6
        np.add.at(disp, E[:, 0], -pull)
        np.add.at(disp, E[:, 1], pull)
    disp += (np.array([0.5, 0.5, 0.5]) - pos) * 0.02  # gentle centering
    step = 0.028 * (1 - it / 300) + 0.002
    length = np.sqrt((disp ** 2).sum(-1, keepdims=True)) + 1e-9
    pos += disp / length * np.minimum(length, step)
    pos = np.clip(pos, 0.04, 0.96)

# normalize spread
pos -= pos.min(0)
span = pos.max(0)
span[span == 0] = 1
pos = pos / span * 0.88 + 0.06

# amber = signal, so it must be rare: only the top hubs get it
hub_cut = sorted((deg[i] for i in keep), reverse=True)[:8][-1] if keep else 0
out = {
    "nodes": [
        {
            "n": notes[keys[old]]["name"],
            "p": notes[keys[old]]["path"],
            "x": round(float(pos[remap[old]][0]), 4),
            "y": round(float(pos[remap[old]][1]), 4),
            "z": round(float(pos[remap[old]][2]), 4),
            "d": deg[old],
            "a": 1 if deg[old] >= hub_cut else 0,
        }
        for old in keep
    ],
    "links": [[a, b] for a, b in edges],
}
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w") as f:
    json.dump(out, f)
print(f"vault-graph: {n} nodes, {len(edges)} links")
