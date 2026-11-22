"""This module contains a demo that demonstrates how to use the roboquant library
to generate a random walk feed, run a trading strategy, and plot the results
using matplotlib."""

from std.time import perf_counter
from roboquant.feed import random_walk
from roboquant.trader import FlexTrader
from roboquant.broker import SimBroker
from roboquant.journal import EquityTracker
from roboquant.time import Timeframe, Duration
from roboquant.run import run
from roboquant.strategy import EMACrossOver
from std.math import round
from std.python import Python, PythonObject


def main() raises:
    var feed = random_walk(start="2025-01-01",end="2026-01-01", step = Duration(days=1), n_assets=8)

    var plt = Python.import_module("matplotlib.pyplot")
    var fig_axs = plt.subplots(4, 2, figsize=[12,8])

    var fig = fig_axs[0]
    var axs = fig_axs[1].flatten()

    for idx, asset in enumerate(feed.assets()):
        var ax = axs[idx]
        var ts1 = feed.to_timeseries(asset)
        ts1.plot(ax)
        ax.legend()
    fig.tight_layout()
    plt.show()

    var strategy = EMACrossOver()
    var trader = FlexTrader()
    var broker = SimBroker()
    var journal = EquityTracker()

    run(feed, strategy, trader, broker, journal)
    print("Performance:", round(journal.get_performance() * 100.0, 2), "%")
    var ts2 = journal.to_timeseries()
    ts2.plot("equity")
