from std.time import perf_counter
from std.testing import assert_equal, assert_true, assert_not_equal, assert_almost_equal, TestSuite

from roboquant.feed import csv_feed, HistoricFeed
from roboquant.trader import FlexTrader
from roboquant.broker import SimBroker
from roboquant.journal import EquityTracker
from roboquant.time import Timeframe
from roboquant.run import run
from roboquant.strategy import EMACrossOver
from std.math import round


def _measure_run(feed: HistoricFeed, tf: Optional[Timeframe]) raises:
    var strategy = EMACrossOver()
    var trader = FlexTrader()
    var broker = SimBroker()
    var journal = EquityTracker()

    var start = perf_counter()
    run(feed, strategy, trader, broker, journal, tf)
    var performance = journal.get_performance() * 100.0
    print(tf or feed.timeframe(), "=>", round(perf_counter() - start,4), "seconds, equity:", round(performance,2), "%")
 

def test_run() raises:
    var feed = csv_feed("/Users/peter/data/daily/us/nasdaq stocks/1", extension = ".txt")
    assert_true(len(feed.assets()) > 200)
   
    # Run over the entire feed timeframe
    _measure_run(feed, None)

    # Simulate a walk forward
    for tf in feed.timeframe().split(4):
        _measure_run(feed, tf)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()