from .asset import Asset
from .time import Timestamp, Timeframe, TimeSeries, UTCDateTime
from .order import Size
from .money import Currency, USD

from std.utils import Variant, BlockingScopedLock, BlockingSpinLock
from std.random import random_float64, randn_float64, seed, random_ui64, shuffle
from std.os import abort
from std.collections import Set
from std.os import listdir
from std.pathlib import Path
from std.logger import Logger
from max.algorithm import parallelize
from std.memory import ArcPointer



comptime logger = Logger()

@fieldwise_init
struct Candle(Copyable):
    var open: Float64
    var high: Float64
    var low: Float64
    var close: Float64
    var volume: Float64

    def __init__(
        out self,
        open: StringSpan,
        high: StringSpan,
        low: StringSpan,
        close: StringSpan,
        volume: StringSpan,
    ) raises:
        """Create a Candle from string values (e.g. parsed from a CSV file)."""
        self.open = Float64(open)
        self.high = Float64(high)
        self.low = Float64(low)
        self.close = Float64(close)
        self.volume = Float64(volume)


    def to_array(self) -> Array[Float64, 5]:
        return [self.open, self.high, self.low, self.close, self.volume]

    def get_price(self, type: String = "DEFAULT") -> Float64:
        match type:
            case "OPEN": return self.open
            case "HIGH": return self.high
            case "LOW": return self.low
            case _: return self.close

    def get_volume(self, type: String = "DEFAULT") -> Float64:
        return self.volume

@fieldwise_init
struct TradePrice(Copyable):
    var price: Float64
    var volume: Float64

    def get_price(self, type: String = "DEFAULT") -> Float64:
        return self.price

    def get_volume(self, type: String = "DEFAULT") -> Float64:
        return self.volume


@fieldwise_init
struct Quote(Copyable):
    var ask_price: Float64
    var ask_volume: Float64
    var bid_price: Float64
    var bid_volume: Float64

    def get_price(self, type: String = "DEFAULT") -> Float64:
        match type:
            case "ASK": return self.ask_price
            case "BID": return self.bid_price
            case _: return (self.ask_price + self.bid_price) / 2

    def get_volume(self, type: String = "DEFAULT") -> Float64:
        match type:
            case "ASK": return self.ask_volume
            case "BID": return self.bid_volume
            case "AVG": return (self.ask_volume + self.bid_volume)/2
            case _: return min(self.ask_volume, self.bid_volume)

struct OrderBookEntry(Copyable):
    var price: Float64
    var volume: Float64 

@fieldwise_init
struct OrderBook(Copyable):
    var asset: Asset
    var ask: List[OrderBookEntry]
    var bid: List[OrderBookEntry]


@fieldwise_init
struct PriceItem(Copyable):
    
    var item: Variant[Candle, Quote, TradePrice]

    def get_price(self, type: String = "DEFAULT") -> Float64:
        if self.item.isa[Candle]():
            return self.item[Candle].get_price(type)
        elif self.item.isa[Quote]():
            return self.item[Quote].get_price(type)
        else:
            return self.item[TradePrice].get_price(type)

    def get_volume(self, type: String = "DEFAULT") -> Float64:
        if self.item.isa[Candle]():
            return self.item[Candle].get_volume(type)
        elif self.item.isa[Quote]():
            return self.item[Quote].get_volume(type)
        else:
            return self.item[TradePrice].get_volume(type)
      
    def isa[T:AnyType](self) -> Bool:
        return self.item.isa[T]()


@fieldwise_init
struct Event(Sized, Copyable, Comparable):
    var time: Timestamp
    var items: Dict[Asset, PriceItem]

    def __len__(self) -> Int:
        return len(self.items)

    def get_price(self, asset: Asset, type: String = "DEFAULT") -> Optional[Float64]:
        try: 
            return self.items[asset].get_price(type)
        except:
            return None

    def get_prices(self, type: String = "DEFAULT") -> List[Tuple[Asset, Float64]]:
        var result = List[Tuple[Asset, Float64]](capacity=len(self.items))
        for item in self.items.items():
            result.append((item.key,item.value.get_price(type)))
        return result^
 
    def get_volume(self, asset: Asset, type: String = "DEFAULT") -> Optional[Float64]:
        try:
            return self.items[asset].get_volume(type)
        except:
            return None

    def get_volumes(self, type: String = "DEFAULT") -> List[Tuple[Asset, Float64]]:
        var result = List[Tuple[Asset, Float64]](capacity=len(self.items))
        for item in self.items.items():
            result.append((item.key,item.value.get_volume(type)))
        return result^
    
    def __lt__(self, other: Event) -> Bool:
        return self.time < other.time

    def __gt__(self, other: Event) -> Bool:
        return self.time > other.time


  

@fieldwise_init
struct HistoricFeed:
    """Feed that contains historic market data."""

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
            return Timeframe.empty()
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
            if case .Some(price) = evt.get_price(asset):
                tl.append(evt.time)
                prices.append(price.value())
        return TimeSeries.univariate(asset.symbol().value, tl^, prices^)



def random_walk(start: String, end: String, step_seconds: Float64, n_assets: Int = 10, type: String = "candle") raises -> HistoricFeed:
    """
    A RandomWalkFeed generates a sequence of Events with randomized Bar price data for testing purposes.
    It simulates a random walk in asset prices over a specified time range and step interval.
    The feed can be used to test trading strategies and algorithms in a controlled environment.
    """

    var symbols = Set[String]()
    while len(symbols) < n_assets: 
        var symbol = String()
        for _ in range(4):
            var n = random_ui64(0,25)
            symbol += chr(Int(n) + ord('A'))
        symbols.add(symbol)

    var step_ns = Int(step_seconds * 1_000_000_000.0)
    var assets = {Asset.Stock(symbol) for symbol in symbols}
    var time = Timestamp.from_iso(start)
    var stop = Timestamp.from_iso(end)
    if stop <= time:
        raise Error("end has to be after start")

    var capacity = Int((stop - time) / step_ns) + 1
    var events = List[Event](capacity=capacity)

    # Select a different start price for each asset
    var prices = {asset:random_float64(50.0, 200.0) for asset in assets}

    while True:
        var items = Dict[Asset, PriceItem](capacity=n_assets*2)
        for asset in assets:
            var price = prices[asset]
            match type:
                case "trade":
                    var trade = TradePrice(price, 10_000)
                    var _ = items.insert(asset, PriceItem(trade^))
                case _:
                    var candle = Candle(price, price*1.01, price*0.99, price, 10_000)
                    var _ = items.insert(asset, PriceItem(candle^))
            prices[asset] = price * randn_float64(mean=1.0, standard_deviation=0.001)

        var evt = Event(time, items^)
        events.append(evt^)
        time += step_ns
        if time >= stop:
            break

    return HistoricFeed(events^)


def __parse_stooq_file(filename: String) -> List[Tuple[Timestamp, PriceItem]]:
    var result = List[Tuple[Timestamp, PriceItem]]()
    try:
        var file = open(filename, "r")
        var lines = file.read().split("\n")[1:]
        for line in lines:
            var row = line.strip().split(",")
            if len(row) < 8:
                continue
            try:
                var candle = Candle(row[4],row[5],row[6],row[7],row[8])
                var date = row[2]
                var dt = UTCDateTime(Int(date[codepoint=0:4]),Int(date[codepoint=4:6]),Int(date[codepoint=6:8]))
                var ts = dt.timestamp()
                result.append((ts, PriceItem(candle^)))
            except e:
                logger.warning(String(e))   
    except e:
        logger.warning(String(e)) 
    return result^


def csv_feed(dir_path: String, extension: String = ".csv", currency: Currency = USD) raises -> HistoricFeed:
    var data = Dict[Timestamp, Dict[Asset, PriceItem]]()
    var all_entries = listdir(dir_path)
    
    for entry in all_entries:
        if entry.endswith(extension):
            var symbol = entry.split(".")[0].upper()
            var asset = Asset.Stock(symbol, currency)
            var prices = __parse_stooq_file(dir_path + "/" + entry)
            for ts, item in prices:
                if ts in data:
                    data[ts][asset] = item.copy()
                else:
                    data[ts] = {asset:item.copy()}

    var events = [Event(elem.key,elem.value.copy()) for elem in data.items()]
    sort(events)
    return HistoricFeed(events^)

@fieldwise_init
struct CSVResult(Copyable):
    var filename: String
    var prices: List[Tuple[Timestamp, PriceItem]]

def csv_feed_parallel(dir_path: String, extension: String = ".csv", currency: Currency = USD) raises -> HistoricFeed:
    """Parse the CSV files in parallel."""

    var data = Dict[Timestamp, Dict[Asset, PriceItem]]()
    var file_entries = listdir(dir_path)
    var all_entries = [dir_path + "/" + entry for entry in file_entries if entry.endswith(extension)]
    var all_result = List[CSVResult](capacity=len(all_entries))
    var lock = BlockingSpinLock()

    def __parse(idx:Int) {all_entries, mut all_result, mut lock}:
        var result = List[Tuple[Timestamp, PriceItem]]()
        var filename = all_entries[idx]

        try:
            var file = open(filename, "r")
            var lines = file.read().split("\n")[1:]
            for line in lines:
                var row = line.strip().split(",")
                if len(row) < 8:
                    continue
                try:
                    var candle = Candle(row[4],row[5],row[6],row[7],row[8])
                    var date = row[2]
                    var dt = UTCDateTime(Int(date[codepoint=0:4]),Int(date[codepoint=4:6]),Int(date[codepoint=6:8]))
                    var ts = dt.timestamp()
                    result.append((ts, PriceItem(candle^)))
                except e:
                    logger.warning(String(e))   
        except e:
            logger.warning(String(e))

        with BlockingScopedLock(lock):
            all_result.append(CSVResult(filename,result^))
       
    # parse all files and wait for all to be done.
    parallelize(__parse, len(all_entries), min(len(all_entries), 64))

    for result in all_result:
        var symbol = result.filename.split(".")[0].upper()
        var asset = Asset.Stock(symbol, currency)
        for time, price_item in result.prices:
            if time in data:
                data[time][asset] = price_item.copy()
            else:
                data[time] = {asset: price_item.copy()}

    var events = [Event(elem.key,elem.value.copy()) for elem in data.items()]
    sort(events)
    return HistoricFeed(events^)