from std.time import perf_counter
from std.testing import (
    assert_equal,
    assert_true,
    assert_not_equal,
    assert_almost_equal,
    TestSuite,
)

from roboquant.feed import random_walk, HistoricFeed
from roboquant.trader import FlexTrader
from roboquant.broker import SimBroker
from roboquant.journal import EquityTracker
from roboquant.time import Timeframe, Duration
from roboquant.run import measured_run
from roboquant.strategy import EMACrossOver
from std.math import round


def _measure_run(feed: HistoricFeed, tf: Optional[Timeframe]) raises:
    var strategy = EMACrossOver()
    var trader = FlexTrader()
    var broker = SimBroker()
    var journal = EquityTracker()

    var start = perf_counter()
    var timings = measured_run(feed, strategy, trader, broker, journal, tf)
    var performance = journal.get_performance() * 100.0
    print(
        tf or feed.timeframe(),
        "=>",
        round(perf_counter() - start, 4),
        "seconds, equity:",
        round(performance, 2),
        "%",
    )
    for item in timings.items():
        print(item.key, "=>", round(item.value,4))


def test_run() raises:
    # 10-minute bars for 26 years
    var feed = random_walk(
        start="2000-01-01", end="2026-01-01", step=Duration(minutes=10), n_assets=10
    )

    # Run over the entire feed timeframe
    _measure_run(feed, None)

    # Simulate a walk forward
    for tf in feed.timeframe().split(4):
        _measure_run(feed, tf)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
