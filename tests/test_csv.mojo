from std.time import perf_counter
from std.testing import assert_equal, assert_true, assert_not_equal, assert_almost_equal, TestSuite

from roboquant.feed import csv_feed, HistoricFeed, csv_feed_parallel
from roboquant.trader import FlexTrader
from roboquant.broker import SimBroker
from roboquant.journal import EquityTracker
from roboquant.time import Timeframe
from roboquant.run import run
from roboquant.strategy import EMACrossOver
from std.math import round


def test_csv_basic() raises:
    var start = perf_counter()
    var feed = csv_feed("/Users/peter/data/daily/us/nasdaq stocks/1", extension = ".txt")
    var end = perf_counter()
    print(feed.timeframe(), "=>", round(end - start,4), "seconds, assets:", len(feed.assets()))


def test_csv_parallel() raises:
    var start = perf_counter()
    var feed = csv_feed_parallel("/Users/peter/data/daily/us/nasdaq stocks/1", extension = ".txt")
    var end = perf_counter()
    print(feed.timeframe(), "=>", round(end - start,4), "seconds, assets:", len(feed.assets()))


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()