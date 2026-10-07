from account import Account, Trade
from feed import Event
from strategy import Signal
from order import Order
from money import Wallet
from std.time import perf_counter


trait Journal:
    """Log and/or store the progress of a run.
    """

    def track(mut self, account: Account, event: Event, signals: List[Signal], orders: List[Order]) -> None:
        ...


@fieldwise_init
struct EquityTracker(Journal, Writable):
    """Tracks the equity of the account over time."""

    var equity: List[Float64]
    
   
    def __init__(out self):
        self.equity = []

    def get_performance(self) -> Float64:
        """
        Calculate the performance equity percentage change from the
        start to the end of the run.
        """
        if len(self.equity) < 2:
            return 0.0
        return (self.equity[len(self.equity) - 1] / self.equity[0]) - 1.0
        
    def track(mut self, account: Account, event: Event, signals: List[Signal], orders: List[Order]) -> None:
        var w = account.equity()
        var amt = w.convert_to(account.base_currency(), event.time)
        self.equity.append(amt.value)


@fieldwise_init
struct Printer(Journal, Writable):

    var trades: Int
    var items: Int
    var signals: Int
    var orders: Int
    var events: Int
    var account: Optional[Account]

    def __init__(out self):
        self.trades = 0
        self.items = 0
        self.signals = 0
        self.orders = 0
        self.events = 0
        self.account = None

    def track(mut self, account: Account, event: Event, signals: List[Signal], orders: List[Order]) -> None:
        self.events += 1
        self.trades += len(account.trades)
        self.items += len(event.prices)
        self.signals += len(signals)
        self.orders += len(orders)
        self.account = account.copy()


@fieldwise_init
struct TradeTracker(Journal, Writable):
    """Tracks all the trades during a run."""

    var trades: List[Trade]

    def __init__(out self):
        self.trades = []

    def track(mut self, account: Account, event: Event, signals: List[Signal], orders: List[Order]) -> None:
        self.trades.extend(account.trades.copy())

    def pnl(self) -> Wallet:
        var result = Wallet()
        for trade in self.trades:
            result.deposit(trade.pnl())
        return result^
