from .asset import Asset
from .feed import Event


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
    def buy(asset: Asset) -> Signal:
        return Self(asset, 1.0)

    @staticmethod
    def sell(asset: Asset) -> Signal:
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
        var signals: List[Signal]  = []
        for ref asset in event.items.keys():   
            var price = event.get_price(asset)
            var rating = self.create_rating(asset, price.value())
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

struct EMACrossOver(PricingStrategy):
    """Two different Exponential Moving Averages where a signal is generated
    if the one crosses the other moving overage.
    """

    var history: Dict[Asset, Tuple[Int, Float64, Float64]]
    var min_n: Int

    def __init__(out self, n: Int = 10):
        self.history = {}
        self.min_n = n

    def create_rating(mut self, asset: Asset, price: Float64) -> Float64:
    
        var (n, old_ema_fast, old_ema_slow) = self.history.get(asset, (0, price, price))
        n += 1

        # Calculate new EMA values
        var new_ema_fast = 0.9 * old_ema_fast + 0.1 * price
        var new_ema_slow = 0.95 * old_ema_slow + 0.05 * price

        self.history[asset] = (n, new_ema_fast, new_ema_slow)
   
        if n >= self.min_n:
            if new_ema_fast <= new_ema_slow and old_ema_fast > old_ema_slow:
                return self.SELL
            elif new_ema_fast >= new_ema_slow and old_ema_fast < old_ema_slow:
                return self.BUY

        return self.NO_RATING

