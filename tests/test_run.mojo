from std.time import perf_counter
from roboquant.feed import random_walk, HistoricFeed
from roboquant.trader import FlexTrader
from roboquant.broker import SimBroker
from roboquant.journal import EquityTracker
from roboquant.time import Timeframe
from roboquant.run import run
from roboquant.strategy import EMACrossOver
from std.math import round


def measure_run(feed: HistoricFeed, tf: Optional[Timeframe]) raises:
    var strategy = EMACrossOver()
    var trader = FlexTrader()
    var broker = SimBroker()
    var journal = EquityTracker()
    var start = perf_counter()
 
    run(feed, strategy, trader, broker, journal, tf)
    var performance = journal.get_performance() * 100.0
    print(tf or feed.timeframe(), "=>", round(perf_counter() - start,4), "seconds, equity:", round(performance,2), "%")
 

def main() raises:
    # 10-minute bars for 26 years
    var feed = random_walk(start="2000-01-01",end="2026-01-01", step_seconds = 600.0, n_assets=10)
    print("feed bars is ", feed.count_items())
  
    # Run over the entire feed timeframe
    measure_run(feed, None)

    # Simulate a walk forward
    for tf in feed.timeframe().split(4):
        measure_run(feed, tf)

