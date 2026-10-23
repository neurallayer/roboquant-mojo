from .asset import Asset
from .time import Timestamp, Timeframe, TimeSeries
from .order import Size

from std.utils import Variant
from std.random import random_float64, randn_float64, seed, random_ui64, shuffle
from morrow import Morrow
from std.os import abort
from std.collections import Set


@fieldwise_init
struct Bar(Copyable):
    var open: Float64
    var high: Float64
    var low: Float64
    var close: Float64
    var volume: Float64

    def to_array(self) -> Array[Float64, 5]:
        return [self.open, self.high, self.low, self.close, self.volume]

@fieldwise_init
struct TradePrice(Copyable):
    var price: Float64
    var volume: Float64


@fieldwise_init
struct Quote(Copyable):
    var ask_price: Float64
    var ask_volume: Float64
    var bid_price: Float64
    var bid_volume: Float64


struct OrderBookEntry(Copyable):
    var price: Float64
    var volume: Float64 

@fieldwise_init
struct OrderBook(Copyable):
    var asset: Asset
    var ask: List[OrderBookEntry]
    var bid: List[OrderBookEntry]


comptime PriceItem = Variant[Bar, Quote, TradePrice]


@fieldwise_init
struct Price(Copyable):
    var item: Variant[Bar, Quote, TradePrice]

    def get_price(self) -> Float64:
        if self.item.isa[Bar]():
            ref c = self.item[Bar]
            return c.close
        elif self.item.isa[Quote]():
            ref q = self.item[Quote]
            return (q.ask_price + q.bid_price)/2
        else:
            ref t = self.item[TradePrice]
            return t.price   

    def isa[T:AnyType](self) -> Bool:
        return self.item.isa[T]()


@fieldwise_init
struct Event(Sized, Copyable):
    var time: Timestamp
    var items: Dict[Asset, Price]

    def __len__(self) -> Int:
        return len(self.items)

    @staticmethod
    def __get_price(item: PriceItem) -> Float64:
        if item.isa[Bar]():
            ref c = item[Bar]
            return c.close
        elif item.isa[Quote]():
            ref q = item[Quote]
            return (q.ask_price + q.bid_price)/2
        else:
            ref t = item[TradePrice]
            return t.price

    def get_price(self, asset: Asset) -> Optional[Float64]:
        try: 
            ref item = self.items[asset]
            return item.get_price()
        except:
            return None



@fieldwise_init
struct HistoricFeed:
    """
    A RandomWalkFeed generates a sequence of Events with randomized Bar price data for testing purposes.
    It simulates a random walk in asset prices over a specified time range and step interval.
    The feed can be used to test trading strategies and algorithms in a controlled environment.
    """

    var events: List[Event]

    def play(self) -> Span[Event, origin_of(self.events)]:
        """Return a Span of Events representing the generated feed."""
        return Span[mut=False](self.events)

    def assets(self) -> Set[Asset]:
        var result = Set[Asset]()
        for evt in self.events:
            result.update({asset for asset in evt.items.keys()})
        return result^

    def timeframe(self) -> Timeframe:
        """Return the timeframe of the generated feed, which is
        determined by the timestamps of the first and last events.
        """
        if not self.events:
            return Timeframe.EMPTY
        return Timeframe(self.events[0].time, self.events[len(self.events)-1].time, True)

    def count_items(self) -> Int:
        var sum_items = 0
        for evt in self.events:
            sum_items += len(evt.items)
        return sum_items


    def to_timeseries(self, asset: Asset) -> TimeSeries: 
        var l = len(self.events)
        var tl = List[Timestamp](capacity=l)
        var prices = List[Float64](capacity=l)
        for evt in self.play():
            var price = evt.get_price(asset)
            if price:
                tl.append(evt.time)
                prices.append(price.value())
        return TimeSeries.univariate(asset.symbol(), tl^, prices^)



def random_walk(start: String, end: String, step_seconds: Float64, n_assets: Int = 10) raises -> HistoricFeed:
    var symbols = Set[String]()
    while len(symbols) < n_assets: 
        var symbol = String()
        for _ in range(4):
            var n = random_ui64(0,25)
            symbol += chr(Int(n) + ord('A'))
        symbols.add(symbol)

    var assets = {Asset.Stock(symbol) for symbol in symbols}
    var time = Morrow.get(start).float_timestamp()
    var stop = Morrow.get(end).float_timestamp()
    assert stop > time, "end has to be after start"

    var capacity = Int((stop - time) / step_seconds) + 1
    var events = List[Event](capacity=capacity)

    # Select a different start price for each asset
    var prices = {asset:random_float64(50.0, 200.0) for asset in assets}

    while True:
        var items = Dict[Asset, Price](capacity=n_assets)
        for asset in assets:
            var price = prices[asset]
            var bar = Bar(price, price*1.01, price*0.99, price, 10_000)
            var _ = items.insert(asset, Price(bar^))
            prices[asset] = price * randn_float64(mean=1.0, standard_deviation=0.001)
        var evt = Event(time, items^)
        events.append(evt^)
        time += step_seconds
        if time >= stop:
            break

    return HistoricFeed(events^)
