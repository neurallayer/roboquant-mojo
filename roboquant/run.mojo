from .feed import HistoricFeed
from .broker import Broker
from .trader import Trader
from .time import Timeframe
from .account import Account
from .strategy import Strategy, Event
from .journal import Journal
from std.time import perf_counter


struct __Timer:
    var value: Float64

    def __init__(out self):
        self.value = perf_counter()

    def elapsed(mut self) -> Float64:
        """The elapsed time since the last call to this method.
        The first call returns the elapsed time since the timer was created.
        """
        var old_time = self.value
        self.value = perf_counter()
        return self.value - old_time



def run(
        feed: HistoricFeed,
        mut strategy: Some[Strategy],
        mut trader: Some[Trader],
        mut broker: Some[Broker],
        mut journal: Some[Journal],
        timeframe: Optional[Timeframe] = None
    ):
    """Run the trading loop over all events produced by the feed optionally
    restricted to the supplied timeframe.

    For every event, the broker is synced with the event, the strategy
    creates signals, the trader converts those signals into orders, the
    broker places the orders and the journal tracks the resulting account
    state. When a `timeframe` is supplied, only events that fall outside of
    it (i.e. strictly after the timeframe) are skipped, and the loop stops
    once the event time exceeds the timeframe.

    Args:
        feed: The historic feed that produces the events to replay.
        strategy: The strategy used to create signals for each event.
        trader: The trader that turns signals into orders.
        broker: The broker that syncs the account and places orders.
        journal: The journal that records account, signal and order data.
        timeframe: Optional timeframe restricting which events are processed.
    """
    for evt in feed.play(timeframe):
        if not timeframe or evt.time in timeframe.value():
            var account = broker.sync(evt)
            var signals = strategy.create_signals(evt)
            var orders = trader.create_orders(signals, account, evt)
            broker.place_orders(orders)
            journal.track(account, evt, signals, orders)
        else:
            if evt.time > timeframe.value():
                break



def measured_run(
        feed: HistoricFeed,
        mut strategy: Some[Strategy],
        mut trader: Some[Trader],
        mut broker: Some[Broker],
        mut journal: Some[Journal],
        timeframe: Optional[Timeframe] = None
    ) -> Dict[String, Float64]:
    """Run the trading loop over all events produced by the feed. It also measures
    the time spend at each step. See also `run`.

    For every event, the broker is synced with the event, the strategy
    creates signals, the trader converts those signals into orders, the
    broker places the orders and the journal tracks the resulting account
    state. When a `timeframe` is supplied, only events that fall outside of
    it (i.e. strictly after the timeframe) are skipped, and the loop stops
    once the event time exceeds the timeframe.

    Args:
        feed: The historic feed that produces the events to replay.
        strategy: The strategy used to create signals for each event.
        trader: The trader that turns signals into orders.
        broker: The broker that syncs the account and places orders.
        journal: The journal that records account, signal and order data.
        timeframe: Optional timeframe restricting which events are processed.

    Returns:
        The accumulated time spent in each of the five stages of the trading loop.
    """
    var times = Array[Float64, 5](fill=0.0)
    var timer = __Timer()
    for evt in feed.play():
        if not timeframe or evt.time in timeframe.value():
            _ = timer.elapsed()
            var account = broker.sync(evt)
            times[0] += timer.elapsed()
            var signals = strategy.create_signals(evt)
            times[1] += timer.elapsed()
            var orders = trader.create_orders(signals, account, evt)
            times[2] += timer.elapsed()
            broker.place_orders(orders)
            times[3] += timer.elapsed()
            journal.track(account, evt, signals, orders)
            times[4] += timer.elapsed()
        else:
            if evt.time > timeframe.value():
                break
    return {
        "broker.sync" : times[0],
        "strategy.create_signals": times[1],
        "trader.create_orders": times[2],
        "broker.place_orders": times[3],
        "journal.track": times[4]
    }