from std.time import perf_counter
from std.testing import (
    assert_equal,
    assert_true,
    assert_not_equal,
    assert_almost_equal,
    TestSuite,
)

from roboquant.feed import csv_feed, HistoricFeed, csv_feed_parallel
from roboquant.trader import FlexTrader
from roboquant.broker import SimBroker
from roboquant.journal import EquityTracker
from roboquant.time import Timeframe
from roboquant.run import run
from roboquant.strategy import EMACrossOver
from std.math import round
from std.os.path import expanduser, exists


def test_csv_basic() raises:  
    var dir = expanduser("~/data/daily/us/nasdaq stocks/1")
    if not exists(dir):
        print("skipping test, no data available")
        return

    var start = perf_counter()
    var feed = csv_feed(dir, extension=".txt")
    var end = perf_counter()
    print(
        feed.timeframe(),
        "=>",
        round(end - start, 4),
        "seconds sequential, assets:",
        len(feed.assets()),
    )


def test_csv_parallel() raises:   
    var dir = expanduser("~/data/daily/us/nasdaq stocks/1")
    if not exists(dir):
        print("skipping test, no data available")
        return

    var start = perf_counter()
    var feed = csv_feed_parallel(dir, extension=".txt")
    var end = perf_counter()
    print(
        feed.timeframe(),
        "=>",
        round(end - start, 4),
        "seconds parallel, assets:",
        len(feed.assets()),
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
