#!/usr/bin/env python3
"""Figures for the paper, each with a CSV of exactly the values it plots.

    analysis/analyze.py results/2026-11-macmini --out analysis/out/2026-11-macmini
    analysis/figures.py analysis/out/2026-11-macmini results/2026-11-macmini/figures

Reads ratios.csv written by analyze.py. Needs matplotlib. Writes 300 dpi PNGs:

1. fig1-clean-noop     interface layout over single-module layout, clean and no-op builds, by app size
2. fig2-change-types   the same ratio for each change type in a hub feature (Notifications), static linking
3. fig3-recompiled     targets recompiled by each change type in each layout, 100 features, static linking

A ratio below 1 means the interface layout (api-impl) is faster.
"""
from __future__ import annotations

import csv
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

SLOTS = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4"]
INK, MUTED, GRID = "#0b0b0b", "#52514e", "#e4e3df"
SCENARIO_NAME = {"private-body": "Private body edit", "private-decl": "New private declaration",
                 "public-impl": "Public implementation edit", "api-change": "Interface change"}
plt.rcParams.update({
    "font.size": 9, "axes.edgecolor": MUTED, "axes.labelcolor": INK, "text.color": INK,
    "xtick.color": MUTED, "ytick.color": MUTED, "axes.spines.top": False, "axes.spines.right": False,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.6, "axes.axisbelow": True,
    "savefig.dpi": 300, "savefig.bbox": "tight", "legend.frameon": False,
})


def load(path: Path) -> list[dict]:
    rows = list(csv.DictReader(open(path)))
    for r in rows:
        r["n"] = int(r["n"])
        for k in ("ratio_api_over_tree", "ci_low", "ci_high", "tree_targets", "api_impl_targets",
                  "tree_median_s", "api_impl_median_s"):
            r[k] = float(r[k])
    return rows


def write_csv(path: Path, header: list[str], rows: list[list]) -> None:
    with open(path, "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(header)
        w.writerows(rows)


def reference(ax) -> None:
    ax.axhline(1.0, color=MUTED, linewidth=0.8, linestyle=(0, (3, 3)))
    ax.text(ax.get_xlim()[1], 1.0, " equal", va="center", ha="left", fontsize=7.5, color=MUTED)


def series(ax, xs, ys, lo, hi, color, label, dashed=False, marker="o"):
    ax.fill_between(xs, lo, hi, color=color, alpha=0.15, linewidth=0)
    ax.plot(xs, ys, color=color, linewidth=2, marker=marker, markersize=5, label=label,
            linestyle=(0, (4, 2)) if dashed else "-")
    ax.annotate(f"{ys[-1]:.2f}", (xs[-1], ys[-1]), textcoords="offset points", xytext=(6, 0), va="center",
                fontsize=7.5, color=MUTED)


def fig1(rows, out: Path) -> None:
    picks = [("static", "clean", "Clean build, static linking", SLOTS[0], False),
             ("static", "noop", "No-op build, static linking", SLOTS[1], False),
             ("dynamic", "clean", "Clean build, dynamic linking", SLOTS[2], True)]
    table = []
    fig, ax = plt.subplots(figsize=(6.2, 3.2))
    for linking, scenario, label, color, dashed in picks:
        rs = sorted((r for r in rows if r["linking"] == linking and r["scenario"] == scenario), key=lambda r: r["n"])
        if not rs:
            continue
        series(ax, [r["n"] for r in rs], [r["ratio_api_over_tree"] for r in rs], [r["ci_low"] for r in rs],
               [r["ci_high"] for r in rs], color, label, dashed)
        table += [[linking, scenario, r["n"], r["tree_median_s"], r["api_impl_median_s"], r["ratio_api_over_tree"],
                   r["ci_low"], r["ci_high"]] for r in rs]
    ax.set_xscale("log")
    ax.set_xticks([16, 25, 50, 100, 200], ["16", "25", "50", "100", "200"])
    ax.minorticks_off()
    ax.set_xlabel("Features in the app")
    ax.set_ylabel("Interface layout time over single-module")
    ax.set_ylim(0.9, max(1.7, max(t[7] for t in table) + 0.05))
    reference(ax)
    ax.legend(loc="upper left", fontsize=8)
    fig.savefig(out / "fig1-clean-noop.png")
    plt.close(fig)
    write_csv(out / "fig1-clean-noop.csv", ["linking", "scenario", "features", "single_module_median_s",
                                             "interface_median_s", "ratio", "ci_low", "ci_high"], table)


def fig2(rows, out: Path, hub: str = "Notifications") -> None:
    table = []
    fig, ax = plt.subplots(figsize=(6.2, 3.4))
    for i, scenario in enumerate(SCENARIO_NAME):
        rs = sorted((r for r in rows if r["linking"] == "static" and r["scenario"] == scenario and r["hub"] == hub),
                    key=lambda r: r["n"])
        if not rs:
            continue
        # private-decl and public-impl nearly coincide, so marker shape and dashes keep both visible
        series(ax, [r["n"] for r in rs], [r["ratio_api_over_tree"] for r in rs], [r["ci_low"] for r in rs],
               [r["ci_high"] for r in rs], SLOTS[i], SCENARIO_NAME[scenario],
               dashed=scenario == "private-decl", marker="osDv"[i])
        table += [[scenario, hub, r["n"], r["tree_median_s"], r["api_impl_median_s"], r["ratio_api_over_tree"],
                   r["ci_low"], r["ci_high"]] for r in rs]
    ax.set_xscale("log")
    ax.set_xticks([16, 25, 50, 100, 200], ["16", "25", "50", "100", "200"])
    ax.minorticks_off()
    ax.set_ylim(0, 1.6)
    ax.set_xlabel("Features in the app")
    ax.set_ylabel("Interface layout time over single-module")
    reference(ax)
    ax.legend(loc="center left", bbox_to_anchor=(1.08, 0.5), fontsize=8)
    fig.savefig(out / "fig2-change-types.png")
    plt.close(fig)
    write_csv(out / "fig2-change-types.csv", ["scenario", "hub", "features", "single_module_median_s",
                                               "interface_median_s", "ratio", "ci_low", "ci_high"], table)


def fig3(rows, out: Path, n: int = 100, hub: str = "Notifications") -> None:
    rs = {r["scenario"]: r for r in rows if r["linking"] == "static" and r["n"] == n and r["hub"] == hub}
    scenarios = [s for s in SCENARIO_NAME if s in rs]
    table = [[s, hub, n, rs[s]["tree_targets"], rs[s]["api_impl_targets"]] for s in scenarios]
    fig, ax = plt.subplots(figsize=(6.2, 2.8))
    h = 0.36
    for k, (col, label, color) in enumerate(((3, "Single-module layout", SLOTS[0]), (4, "Interface layout", SLOTS[1]))):
        ys = [i + (k - 0.5) * (h + 0.03) for i in range(len(scenarios))]
        bars = ax.barh(ys, [t[col] for t in table], height=h, color=color, label=label)
        for b in bars:
            ax.text(b.get_width() + 1, b.get_y() + b.get_height() / 2, f"{b.get_width():.0f}", va="center",
                    fontsize=7.5, color=MUTED)
    ax.set_yticks(range(len(scenarios)), [SCENARIO_NAME[s] for s in scenarios])
    ax.invert_yaxis()
    ax.set_xlabel(f"Targets recompiled, {n} features, change in {hub}")
    ax.set_xlim(0, max(max(t[3], t[4]) for t in table) * 1.12)
    ax.grid(axis="y", visible=False)
    ax.legend(loc="lower center", bbox_to_anchor=(0.5, 1.0), ncol=2, fontsize=8)
    fig.savefig(out / "fig3-recompiled.png")
    plt.close(fig)
    write_csv(out / "fig3-recompiled.csv", ["scenario", "hub", "features", "single_module_targets",
                                             "interface_targets"], table)


def main() -> None:
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    rows = load(src / "ratios.csv")
    for f in (fig1, fig2, fig3):
        f(rows, out)
        print("wrote", f.__name__)


if __name__ == "__main__":
    main()
