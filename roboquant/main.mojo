from std.time import perf_counter
from feed import RandomWalkFeed
from trader import FlexTrader
from broker import SimBroker
from journal import Printer, EquityTracker
from time import Timeframe
from run import run
from strategy import EMACrossOver
from std.math import round


def measure_run(feed: RandomWalkFeed, tf: Optional[Timeframe]) raises:
    var strategy = EMACrossOver()
    var trader = FlexTrader()
    var broker = SimBroker()
    var journal = EquityTracker()

    var start = perf_counter()
    run(feed, strategy, trader, broker, journal, tf)
    var performance = journal.get_performance() * 100.0
    print(tf, "=>", round(perf_counter() - start,4), "seconds, equity:", round(performance,2), "%")

def main() raises:
    # 10-minute bars for 26 years
    var feed = RandomWalkFeed(start="2000-01-01",end="2026-01-01", step_seconds = 600.0)
  
    measure_run(feed, None)

    # Simulate a walk forward
    for tf in feed.timeframe().split(4):
        measure_run(feed, tf)

