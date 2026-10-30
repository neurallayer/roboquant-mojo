from .feed import HistoricFeed
from .broker import Broker
from .trader import Trader
from .time import Timeframe, TIME_MIN
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
    ) raises:
    """
    The main run method that ties all components together. 
    Optionally limit the run to the provided timeframe.
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
