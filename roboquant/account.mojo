from .money import Currency, Wallet, Amount
from .time import Timestamp
from .asset import Asset
from .order import Order, Size, OrderTicket
from std.os import abort


def sum[T:Deinitable, //, f: def(T) thin -> Amount](list: List[T]) -> Wallet:
    var result = Wallet()
    for elem in list:
        result.deposit(f(elem))
    return result^


@fieldwise_init
struct Trade(Copyable, Writable):
    """Represents a single executed trade with an asset, size, price, and realized PnL value.

    Attributes:
        asset (Asset): The underlying asset of the trade.
        size (Size): The size of the trade.
        price (Float64): The execution price of the trade.
        pnl_value (Float64): The realized Profit and Loss value of the trade.
        time: The time the trade was executed.
    """

    var asset: Asset
    var size: Size
    var price: Float64
    var pnl_value: Float64
    var time: Timestamp

    def pnl(self) -> Amount:
        """The realized Profit and Loss amount by this trade."""
        return Amount(self.asset.currency(), self.pnl_value)

    def value(self) -> Amount:
        return self.asset.value(self.size, self.price)

    def pnl_pct(self) -> Float64:
        return self.pnl_value / self.value().value


struct Position(Copyable, Writable):
    """
    Represents a position in a specific asset, including the size, average price, and market price.
    Attributes:
        asset (Asset): The underlying asset of the position.
        size (Size): The size of the position.
        avg_price (Float64): The average price at which the position was acquired.
        mkt_price (Float64): The current market price of the asset.
    """

    var asset: Asset
    var size: Size
    var avg_price: Float64
    var mkt_price: Float64

    def __init__(out self, asset: Asset, size: Size = Size(), avg_price: Float64 = 0.0, mkt_price: Float64 = 0.0):
        self.asset = asset
        self.size = size
        self.avg_price = avg_price
        self.mkt_price = mkt_price

    @staticmethod
    def empty(asset: Asset) -> Position:
        return Position(asset, Size(), 0, 0)

    def __iadd__(mut self, other: Size) -> None :
        try:
            self.size += other
        except:
            abort()

    def mkt_value(self) -> Amount:
        """The market value amount of the position."""
        return self.asset.value(self.size, self.mkt_price)

    def pnl(self) -> Amount:
        """The unrealized Profit and Loss amount by this position."""
        return self.asset.value(self.size, self.mkt_price - self.avg_price)    


@fieldwise_init
struct Account(Writable, Copyable):
    """Represents a trading account with positions, orders, trades, buying power, and cash.

    Attributes:
        last_update: The timestamp of the last update to the account.
        positions: A list of open positions in the account. Support for both hedging and non-hedging accounts is provided, allowing for multiple positions in the same asset.
        orders: A list of open orders in the account.
        buying_power: The available buying power in the account.
        cash: The cash balance in the account.
        trades: A list of executed trades during the last step.
    """

    var last_update: Timestamp
    var positions: List[Position]
    var orders: List[OrderTicket]
    var buying_power: Amount
    var cash: Wallet
    var trades: List[Trade]

    def base_currency(self) -> Currency:
        return self.buying_power.currency

    def mkt_value(self) -> Wallet:
        """The market value of the open positions."""
        var result = Wallet()
        for p in self.positions:
            result.deposit(p.mkt_value())
        return result^

    def get_position_size(self, asset: Asset) -> Size:
        try:
            var position_sizes = [p.size for ref p in self.positions if p.asset == asset]
            var total = Size()
            for size in position_sizes:
                total += size
            return total
        except:
            abort("Couldn't calculate position size")

    def unrealized_pnl(self) -> Wallet:
        """The unrealized Profit & Loss by open positions."""
        var result = Wallet()
        for p in self.positions:
            result.deposit(p.pnl())
        return result^

    def realized_pnl(self) -> Wallet:
        """The realized Profit & Loss made by executed trades."""
        return sum[lambda (t: Trade) -> Amount : t.pnl()](self.trades)

    def equity(self) -> Wallet:
        """The total equity of the account, which is the sum of cash and
        market value of positions."""
        var result = self.mkt_value()
        result.deposit(self.cash)
        return result^

    def write_to(self, mut writer: Some[Writer]):
        writer.write("last update : ", self.last_update.format())
        writer.write("\ncash        : ", self.cash)
        writer.write("\nbuying power: ", self.buying_power)
        writer.write("\nequity      : ", self.equity())

        writer.write("\npositions   : ")
        for pos in self.positions:
            writer.write(pos.size, "@", pos.asset.symbol(), " ")
        else:
            writer.write("none")
 
        writer.write("\norders      : ")
        for ticket in self.orders:
            writer.write(ticket.order.size, "@", ticket.order.asset.symbol(), " ") 
        else:
            writer.write("none")

        writer.write("\ntrades      : ")
        for trade in self.trades:
            writer.write(trade.size, "@", trade.asset.symbol(), " ") 
        else:
            writer.write("none")

        writer.write("\n")

        