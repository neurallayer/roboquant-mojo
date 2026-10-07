from .asset import Asset
from .time import Timestamp, Timeframe


from std.random import random_float64, randn_float64, seed, random_ui64
from morrow import Morrow
from std.os import abort
from std.collections import Set



trait PriceItem(Copyable & Deinitable & Writable):
    """A PriceItem represents a single price data point for a specific asset at a specific time.
    It provides methods to retrieve the associated asset, price, and volume information.
    Common implementations of PriceItem include Bar and Quote, which represent different types of market data.
    """

    def get_asset(self) -> Asset:
        """Return the Asset associated with this PriceItem."""
        ...

    def get_price(self, price_type: String = "DEFAULT") -> Float64:
        """Return the price of the asset for the specified price type.
        Args:
            price_type (String): The type of price to retrieve (e.g., "OPEN", "HIGH", "LOW", "CLOSE", "ASK", "BID").
        Returns:
            Float64: The price of the asset for the specified price type.
        """
        ...

    def get_volume(self, volume_type: String = "DEFAULT") -> Float64:
        """Return the volume of the asset for the specified volume type.
        Args:
            volume_type (String): The type of volume to retrieve (e.g., "DEFAULT").
        Returns:
            Float64: The volume of the asset for the specified volume type.
        """
        ...


@fieldwise_init
struct Event[P: PriceItem](Copyable):
    """
    An Event represents a collection of price data points (PriceItems) for various
    assets at a specific timestamp.
    It provides methods to retrieve the timestamp and access the price data for specific assets.
    """


    var time: Timestamp
    var prices: List[Self.P]
    # var lookup: Dict[Asset, Self.P]

    # def __init__(out self,time: Timestamp, prices: List[Self.P]):
    #    self.time = time
    #    self.prices = prices.copy()
    #    self.lookup = {p.get_asset() : p.copy() for p in prices}


    def get_price(self, asset:Asset, type: String = "DEFAULT") -> Optional[Float64]:
        #if var p := self.lookup.get(asset):
        #    return p.value().get_price(type)
        #return None
        for ref price in self.prices:
            ref p = price.get_asset()
            if p == asset:
                return price.get_price(type)
        return None



struct Bar(PriceItem, Copyable, Writable):
    """Represents a Bar (a.k.a CandleStick) price-item with Open, High, Low, Close and Volume
    values."""

    var asset: Asset
    var ohlcv: Array[Float64,5]

    def get_asset(self) -> Asset:
        return self.asset

    def __init__(out self, asset: Asset, open: Float64, high: Float64, low: Float64, close: Float64, volume: Float64):
        self.asset = asset
        self.ohlcv = [open,high,low,close,volume]

    def get_price(self, price_type: String = "DEFAULT") -> Float64:
        if price_type == "OPEN":
            return self.ohlcv[0]
        elif price_type == "HIGH":
            return self.ohlcv[1]
        elif price_type == "LOW":
            return self.ohlcv[2]
        else:
            return self.ohlcv[3]

    def get_volume(self, volume_type: String = "DEFAULT") -> Float64:
        return self.ohlcv[4]


struct Quote(PriceItem):
    """Represents a Quote price-item with an asset and a single price value."""

    var asset: Asset
    var ohlcv: Array[Float64,4]

    def __init__(out self, asset: Asset, ask: Float64=100.0):
        self.asset = asset
        self.ohlcv = [ask,10_000,ask*0.99,10_000]

    def get_asset(self) -> Asset:
        return self.asset


    def get_price(self, price_type: String = "DEFAULT") -> Float64:
        if price_type == "ASK":
            return self.ohlcv[0]
        elif price_type == "BID":
            return self.ohlcv[2]
        else:
            return (self.ohlcv[0] + self.ohlcv[2])/2.0

    def get_volume(self, volume_type: String = "DEFAULT") -> Float64:
        return self.ohlcv[4]


@fieldwise_init
struct RandomWalkFeed:
    """
    A RandomWalkFeed generates a sequence of Events with randomized Bar price data for testing purposes.
    It simulates a random walk in asset prices over a specified time range and step interval.
    The feed can be used to test trading strategies and algorithms in a controlled environment.
    """

    var events: List[Event[Bar]]

    def __init__(out self, start: String, end: String, step_seconds: Float64 = 3600.0 * 24.0, n_assets: Int = 10):
        """
        Initialize a RandomWalkFeed with the specified parameters.
        Args:
            start (String): The starting timestamp of the feed in ISO format.
            end (String): The ending timestamp of the feed in ISO format.
            step_seconds (Float64): The time interval between consecutive Events in seconds.
            n_assets (Int): The number of unique assets to generate price data for.
        """

        self.events = Self.__gen_bar_feed(start, end, step_seconds, n_assets)

    def play(self) -> Span[Event[Bar], origin_of(self.events)]:
        """Return a Span of Events representing the generated feed."""
        return Span(self.events)

    def assets(self) -> Set[Asset]:
        var result = Set[Asset]()
        for evt in self.events:
            for price in evt.prices:
                result.add(price.asset)
        return result^

    def timeframe(self) -> Timeframe:
        """Return the timeframe of the generated feed, which is
        determined by the timestamps of the first and last events.
        """
        return Timeframe(self.events[0].time, self.events[len(self.events)-1].time, True)

    def count_bars(self) -> Int:
        var sum_bars = 0
        for evt in self.events:
            sum_bars += len(evt.prices)
        return sum_bars


    @staticmethod
    def __random_symbols(n: Int) -> Set[String]:  
        var result = Set[String]()
        while len(result) < n: 
            var symbol = String()
            for _ in range(4):
                var n = random_ui64(0,25)
                symbol += chr(Int(n) + ord('A'))
            result.add(symbol)
        return result^

    @staticmethod
    def __gen_bar_feed(start: String, end: String, step_seconds: Float64, n_assets: Int) -> List[Event[Bar]]:
        """Generate a test feed with randomized Bars."""
        try:
            seed(42)
            var symbols = Self.__random_symbols(n_assets)
            var assets = {Asset.Stock(symbol) for symbol in symbols}
            var events: List[Event[Bar]] = []
            var prices = {asset:random_float64(100.0, 200.0) for asset in assets}
            var time = Morrow.fromisoformat(start).float_timestamp()
            var stop = Morrow.fromisoformat(end).float_timestamp()
            while True:
                var items: List[Bar] = []
                for asset in assets:
                    var price = prices[asset]
                    var bar = Bar(asset, price, price*1.01, price*0.99, price, 10_000)
                    items.append(bar^)
                    prices[asset] = price * randn_float64(mean=1.0, standard_deviation=0.001)
                var evt = Event(time, items^)
                events.append(evt^)
                time += step_seconds
                if time >= stop:
                    break

            return events^
        except:
            abort()
