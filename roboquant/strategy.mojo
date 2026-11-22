from .asset import Asset
from .feed import Event, Candle
from .time import Timestamp


@fieldwise_init
struct SignalType(Writable, ImplicitlyCopyable, Equatable):
    """Represents the type of a trading signal, which can be either
    an entry signal, an exit signal, or both."""
    comptime ENTRY = SignalType(0)
    comptime EXIT = SignalType(1)
    comptime ENTRY_EXIT = SignalType(2)

    var _variant: Int


struct Signal(Writable, Copyable):
    """Represents a trading signal for an asset with a rating.
    A rating has typically a value between -1.0 (strong sell) and 1.0 (strong buy).
    """

    var asset: Asset
    var rating: Float64
    var type: SignalType

    def __init__(out self, var asset: Asset, rating: Float64, type: SignalType = SignalType.ENTRY_EXIT):
        self.asset = asset
        self.rating = rating
        self.type = type

    def is_exit(self) -> Bool:
        """Returns true if this signal is an exit signal."""
        return self.type == SignalType.ENTRY_EXIT or self.type == SignalType.EXIT

    def is_entry(self) -> Bool:
        """Returns true if this signal is an entry signal."""
        return self.type == SignalType.ENTRY_EXIT or self.type == SignalType.ENTRY

    @staticmethod
    def buy(var asset: Asset) -> Signal:
        """Create a buy signal for the provided asset."""
        return Self(asset, 1.0)

    @staticmethod
    def sell(var asset: Asset) -> Signal:
        """Create a sell signal for the provided asset."""
        return Self(asset, -1.0)

    def is_buy(self) -> Bool:
        """Returns true if this signal is a buy signal."""
        return self.rating > 0

    def is_sell(self) -> Bool:
        """Returns true if this signal is a sell signal."""
        return self.rating < 0


trait Strategy:
    """A Strategy is responsible for creating trading signals based on market data events.
    This trait defines the interface for a Strategy.
    """

    def create_signals(mut self, event: Event) -> List[Signal]:
        """
        Strategies should implement this method and based on the event generate
        zero or more signals.

        Args:
            event: The event containing its timestamp and the market data.

        Returns:
            One or more signals.
        """
        ...


trait PricingStrategy(Strategy):
    """A pricing strategy that uses the price of an asset to generate signals.
    The price is obtained from the event using the price type returned by the
    `get_price_type` method. The default price type is `DEFAULT`."""

    comptime BUY = 1.0
    comptime SELL = -1.0
    comptime NO_RATING = 0.0

    def get_price_type(self) -> String:
        """The price type to use for the strategy, for example `CLOSE` or `OPEN`.
        Structs can overwrite this method to return a different price type."""
        return "DEFAULT"

    def create_signals(mut self, event: Event) -> List[Signal]:
        var signals: List[Signal] = []
        var type = self.get_price_type()
        for item in event.items.items():
            var price = item.value.get_price(type)
            var rating = self.create_rating(item.key, price)
            if rating:
                var signal = Signal(item.key, rating)
                signals.append(signal^)

        return signals^

    def create_rating(mut self, asset: Asset, price: Float64) -> Float64:
        """Create a rating for the given asset and price. The rating is a Float64 value where
        a positive value indicates a buy signal, a negative value indicates a sell signal, and zero
        indicates no signal. The rating can be used to determine the strength of the signal, but 
        is typically normalized to a value between -1 and 1."""
        ...


trait CandleStrategy(Strategy):

    def create_signals(mut self, event: Event) -> List[Signal]:
        var signals: List[Signal]  = []
        for item in event.items.items():  
            ref price = item.value.item
            if price.isa[Candle]():
                ref asset = item.key
                var rating = self.create_rating(asset, price[Candle])
                if rating:
                    var signal = Signal(asset, rating)
                    signals.append(signal^)
                
        return signals^

    def create_rating(mut self, asset: Asset, candle: Candle) -> Float64:
        """Create rating for the given asset and bars. The rating is a Float64 value where
        a positive value indicates a buy signal, a negative value indicates a sell signal, and zero
        indicates no signal. The rating can be used to determine the strength of the signal, but 
        is typically normalized to a value between -1 and 1."""
        ...


struct EMACrossOver(PricingStrategy):
    """Two different Exponential Moving Averages where a signal is generated
    if the one crosses the other moving overage.
    """

    var history: Dict[Asset, __EMACalc]
    var min_n: Int
    var fast: Float64
    var slow: Float64
    var price_type: String

    def __init__(out self, fast_period: Int = 13, slow_period: Int = 26, smoothing: Float64 = 2.0, min_n: Optional[Int] = None, price_type: String = "DEFAULT"):
        """Create a new EMA Cross Over strategy.

        Args:
            fast_period: The period for the fast EMA.
            slow_period: The period for the slow EMA.
            smoothing: The smoothing factor to use.
            min_n: The minimum number of observations before a signal can be generated.
            price_type: The price type to use for the strategy.
        """
        
        self.history = {}
        self.fast = 1.0 - (smoothing / Float64(fast_period + 1))
        self.slow = 1.0 - (smoothing / Float64(slow_period + 1))
        self.min_n = slow_period if not min_n else min_n.value()
        self.price_type = price_type

    def get_price_type(self) -> String:
        return self.price_type

    def create_rating(mut self, asset: Asset, price: Float64) -> Float64:
        try:
            ref calc = self.history[asset]
            var old = calc.is_above()
           
            # Calculate new EMA values
            calc.update(price)
           
            if calc.n >= self.min_n:
                var new = calc.is_above()
                if old != new:
                    return self.SELL if new else self.BUY

        except:
            self.history[asset] = __EMACalc(fast=self.fast, slow=self.slow, price=price)

        return self.NO_RATING

struct __EMACalc:
    var n: Int
    var fast: Float64
    var slow: Float64
    var ema_fast: Float64
    var ema_slow: Float64

    def __init__(out self, fast: Float64, slow: Float64, price: Float64):
        self.n = 0
        self.fast = fast
        self.slow = slow
        self.ema_fast = price
        self.ema_slow = price

    def is_above(self) -> Bool:
        return self.ema_fast > self.ema_slow

    def update(mut self, price: Float64):
        self.n += 1
        self.ema_fast = self.fast * self.ema_fast + (1.0 - self.fast) * price
        self.ema_slow = self.slow * self.ema_slow + (1.0 - self.slow) * price
       