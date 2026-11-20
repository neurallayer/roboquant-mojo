from .feed import HistoricFeed
from .broker import Broker
from .trader import Trader
from .time import Timeframe
from .account import Account
from .strategy import Strategy, Event
from .journal import Journal


def run(
        feed: HistoricFeed,
        mut strategy: Some[Strategy],
        mut trader: Some[Trader],
        mut broker: Some[Broker],
        mut journal: Some[Journal],
        timeframe: Optional[Timeframe] = None
    ):
    """Run the trading loop over all events produced by the feed.

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
    for evt in feed.play():
        if not timeframe or evt.time in timeframe.value():
            var account = broker.sync(evt)
            var signals = strategy.create_signals(evt)
            var orders = trader.create_orders(signals, account, evt)
            broker.place_orders(orders)
            journal.track(account, evt, signals, orders)
        else:
            if evt.time > timeframe.value():
                break
