from std.time import perf_counter
from roboquant.feed import RandomWalkFeed
from roboquant.trader import FlexTrader
from roboquant.broker import SimBroker
from roboquant.journal import EquityTracker
from roboquant.time import Timeframe
from roboquant.run import run
from roboquant.strategy import EMACrossOver
from std.math import round


def main() raises:
    # 10-minute bars for 26 years
    var feed = RandomWalkFeed(start="2025-01-01",end="2026-01-01", step_seconds = 3600.0 * 24.0)
    var strategy = EMACrossOver()
    var trader = FlexTrader()
    var broker = SimBroker()
    var journal = EquityTracker()

    run(feed, strategy, trader, broker, journal)
    print("Performance:", round(journal.get_performance() * 100.0, 2), "%")
    var ts = journal.to_timeseries()
    ts.plot("equity")
