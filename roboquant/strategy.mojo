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


struct Signal(Writable, ImplicitlyCopyable):
    """Represents a trading signal for an asset with a rating."""

    var asset: Asset
    var rating: Float64
    var type: SignalType

    def __init__(out self, var asset: Asset, rating: Float64, type: SignalType = SignalType.ENTRY_EXIT):
        self.asset = asset
        self.rating = rating
        self.type = type

    def is_exit(self) -> Bool:
        return self.type == SignalType.ENTRY_EXIT or self.type == SignalType.EXIT

    def is_entry(self) -> Bool:
        return self.type == SignalType.ENTRY_EXIT or self.type == SignalType.ENTRY

    @staticmethod
    def buy(var asset: Asset) -> Signal:
        return Self(asset, 1.0)

    @staticmethod
    def sell(var asset: Asset) -> Signal:
        return Self(asset, -1.0)

    def is_buy(self) -> Bool:
        return self.rating > 0

    def is_sell(self) -> Bool:
        return self.rating < 0


trait Strategy:
    """A Strategy is responsible for creating trading signals based on market data events.
    This trait defines the interface for a Strategy, which is used by the roboquant framework
    to generate signals for trading.
    """

    def create_signals(mut self, event: Event) -> List[Signal]:
        ...


trait PricingStrategy(Strategy):

    comptime BUY = 1.0
    comptime SELL = -1.0
    comptime NO_RATING = 0.0

  
    def create_signals(mut self, event: Event) -> List[Signal]:
        var signals: List[Signal] = []
        for ref asset in event.items.keys():   
            if case .Some(price) = event.get_price(asset):
                var rating = self.create_rating(asset, price)
                if rating:
                    var signal = Signal(asset, rating)
                    signals.append(signal)

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
                    signals.append(signal)
                
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

    var history: Dict[Asset, Tuple[Int, Float64, Float64]]
    var min_n: Int
    var fast: Float64
    var slow: Float64

    def __init__(out self, fast_period: Int = 13, slow_period: Int = 26, smoothing: Float64 = 2.0, min_n: Optional[Int] = None):
        self.history = {}
        self.fast = 1.0 - (smoothing / Float64(fast_period + 1))
        self.slow = 1.0 - (smoothing / Float64(slow_period + 1))
        self.min_n = slow_period if not min_n else min_n.value()

    def create_rating(mut self, asset: Asset, price: Float64) -> Float64:
    
        var (n, old_ema_fast, old_ema_slow) = self.history.get(asset, (0, price, price))
        n += 1

        var f, s = self.fast, self.slow

        # Calculate new EMA values
        var new_ema_fast = f * old_ema_fast + (1.0 - f) * price
        var new_ema_slow = s * old_ema_slow + (1.0 - s) * price

        self.history[asset] = (n, new_ema_fast, new_ema_slow)
   
        if n >= self.min_n:
            if new_ema_fast <= new_ema_slow and old_ema_fast > old_ema_slow:
                return self.SELL
            elif new_ema_fast >= new_ema_slow and old_ema_fast < old_ema_slow:
                return self.BUY

        return self.NO_RATING

