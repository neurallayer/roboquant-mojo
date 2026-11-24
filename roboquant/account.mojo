from .money import Currency, Wallet, Amount
from .time import Timestamp
from .asset import Asset
from .order import Order, Size, OrderTicket, NewOrder, TIF, Info
from std.os import abort

@always_inline
def sum[T:Deinitable, //, f: def(T) thin -> Amount](list: List[T]) -> Wallet:
    var result = Wallet()
    for elem in list:
        result.deposit(f(elem))
    return result^


@fieldwise_init
struct Trade(Copyable, Writable):
    """Represents a single executed trade with an asset, size, price, and realized PnL value.

    Attributes:
        asset: The underlying asset of the trade.
        size: The size of the trade.
        price: The execution price of the trade.
        pnl: The realized Profit and Loss value of the trade, typically denoted in 
            the same currency as the asset.
        time: The time the trade was executed.
    """

    var asset: Asset
    var size: Size
    var price: Float64
    var pnl: Amount
    var time: Timestamp

    def value(self) -> Amount:
        """Return the total value amount of the trade."""
        return self.asset.value(self.size, self.price)


struct Position(Copyable, Writable):
    """
    Represents a position in a specific asset, including the size, average price, and market price.

    Attributes:
        asset: The underlying asset of the position.
        size: The size of the position.
        avg_price: The average price at which the position was acquired.
        mkt_price: The current market price of the asset.
        info: Additional information about the position.
    """

    var asset: Asset
    var size: Size
    var avg_price: Float64
    var mkt_price: Float64
    var info: Info

    def __init__(out self, asset: Asset, size: Size, avg_price: Float64 = 0.0, mkt_price: Float64 = 0.0, var info: Info = Info()):
        self.asset = asset
        self.size = size
        self.avg_price = avg_price
        self.mkt_price = mkt_price
        self.info = info^

    @staticmethod
    def zero(asset: Asset) -> Position:
        """Create a zero position for the provided asset."""
        return Position(asset, Size(), 0, 0)

    def __iadd__(mut self, other: Size) -> None :
        try:
            self.size += other
        except:
            abort()

    def mkt_value(self) -> Amount:
        """The market value amount of the position."""
        return self.asset.value(self.size, self.mkt_price)

    def exposure(self) -> Amount:
        """The absolute market value amount of the position."""
        return self.asset.value(abs(self.size), self.mkt_price)

    def pnl(self) -> Amount:
        """The unrealized Profit and Loss amount by this position."""
        return self.asset.value(self.size, self.mkt_price - self.avg_price)

    def close_with_order(self, limit: Optional[Float64] = None, tif: TIF = TIF.GTC) -> Order:
        return Order(NewOrder(self.asset, -self.size, limit ,tif, self.info.copy()))    


@fieldwise_init
struct Account(Writable, Copyable):
    """Represents a trading account with positions, orders, trades, buying power, and cash.

    Attrs:
        last_update: The timestamp of the last update to the account.
        positions: A list of open positions in the account. Support for both hedging and non-hedging accounts
        is provided, allowing for multiple positions in the same asset.
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
        """Return the base currency of the account."""
        return self.buying_power.currency

    def mkt_value(self) -> Wallet:
        """The total market value of the open positions."""
        var result = Wallet()
        for p in self.positions:
            result.deposit(p.mkt_value())
        return result^

    def exposure(self) -> Wallet:
        """The total market value of the open positions."""
        var result = Wallet()
        for p in self.positions:
            result.deposit(p.exposure())
        return result^

    def get_position_size(self, asset: Asset) -> Size:
        """Return the netting position size for an asset.

        Args:
            asset: The asset for which to calculate the netting size.
        """

        try:
            var position_sizes = [p.size for ref p in self.positions if p.asset == asset]
            var total = Size()
            for size in position_sizes:
                total += size
            return total
        except:
            abort("Couldn't calculate position size")

    def get_position_value(self, asset: Asset, price: Float64) -> Amount:
        """Return the netting position value for an asset denoted in the currency
        of the underlying asset.

        Args:
            asset: The asset for which to calculate the netting value.
            price: The price to use.

        Returns:
            The netting Amount.
        """
        return asset.value(self.get_position_size(asset), price)

    def has_order(self, asset: Asset) -> Bool:
        """Return true is there are one or more orders for the provided asset.
        
        Args:
            asset: The asset to check for orders.

        Returns:
            True if there are one or more orders for the provided asset, False otherwise.
        """
        for ticket in self.orders:
            if ticket.order.asset == asset:
                return True
        return False

    def unrealized_pnl(self) -> Wallet:
        """The total unrealized Profit & Loss hold by the open positions."""
        var result = Wallet()
        for p in self.positions:
            result.deposit(p.pnl())
        return result^

    def realized_pnl(self) -> Wallet:
        """The realized Profit & Loss made by executed trades.
        Note that these are only the trades since the last sync.
        """
        return sum[lambda (t: Trade) -> Amount : t.pnl](self.trades)

    def equity(self) -> Wallet:
        """The total equity of the account, which is the sum of cash and
        market value of positions."""
        return self.mkt_value() + self.cash

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

    def close_orders(self, asset: Asset, limit: Optional[Float64] = None, tif: TIF = TIF.GTC) -> List[Order]:
        """Create orders to close all open positions for the provided asset.
        If a limit price is provided, the orders will be limit orders, otherwise market orders.
        
        Args:
            asset: The asset to close positions for.
            limit: The optional limit price for the orders.
            tif: The time in force for the orders.

        Returns:
            A list of orders to close all open positions for the provided asset.
        """
        var result = List[Order]()
        for pos in self.positions:
            if pos.asset == asset:
                result.append(pos.close_with_order(limit, tif))
        return result^

        