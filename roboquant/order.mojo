from .asset import Asset
from .money import Amount
from std.os import abort
from decimo import Decimal128
from .time import Timestamp
from std.utils import Variant
from std.hash import Hasher


comptime Size = Decimal128

comptime Info = Dict[String, String]

@fieldwise_init
struct TIF(ImplicitlyCopyable, Writable, Equatable):
    """
    Until Mojo supports enums, we use this struct to represent the Time In Force (TIF) of an order.
    TIF specifies how long an order remains active before it is executed or expires.

    Attributes:
        DAY (TIF): The order is valid for the current trading day and will expire at the end of the day if not executed.
        GTC (TIF): The order remains active until it is explicitly cancelled by the trader, regardless of the trading day.
    """

    comptime DAY = Self(0)
    """Valid for the day."""

    comptime GTC = Self(1)
    """Valid until Cancelled."""

    var value : Int

    def write_to(self, mut writer: Some[Writer]):
        if self == Self.DAY:
            writer.write("DAY")
        elif self == Self.GTC:
            writer.write("GTC")
        else:
            writer.write("Unknown TIF")

struct NewOrder(Copyable, Writable):
    """
    A  new order represents a request to buy or sell a specific asset in the market.

    Attributes:
        asset: The underlying asset of the order.
        size: The size of the order.
        limit: Optionally a limit price for the order. If not set, the order is handled as a market order.
        tif: Time In Force, which specifies how long the order remains active before it is executed or expires.
        info: Arbitrary info included in the order. Typically only used by a broker implementation.
    """

    var asset: Asset
    """The underlying asset of the order."""

    var size: Size
    """The size of the order."""

    var limit: Optional[Float64]
    """Optionally a limit price for the order.
    If not set, the order is processed as a market order.
    """

    var tif: TIF
    """Time In Force, either DAY or GTC."""

    var info: Info

    def __init__(out self, asset: Asset, size: Size, limit: Optional[Float64], tif: TIF, var info: Info = Info()):
        self.asset = asset
        self.size = size
        self.limit = limit
        self.tif = tif
        self.info = info^

@fieldwise_init
struct CancelOrder(Copyable, Writable):
    """Cancel an existing order."""
    var id: String

@fieldwise_init
struct ModifyOrder(Copyable, Writable):
    var id: String
    var size: Optional[Size]
    var limit: Optional[Float64]


comptime OrderVariant = Variant[NewOrder, CancelOrder, ModifyOrder]

@fieldwise_init
struct Order(Copyable & Writable):
    var variant : OrderVariant

    @staticmethod
    def market_order(asset: Asset, size: Size, tif: TIF = TIF.GTC) -> Self:
        """Create a new Market Order."""
        return Self(NewOrder(asset, size, None, tif))

    @staticmethod
    def limit_order(asset: Asset, size: Size, limit: Float64, tif: TIF = TIF.GTC) -> Self:
        """Create a new Limit Order."""
        return Self(NewOrder(asset, size, limit, tif))

    def is_new_order(self) -> Bool:
        return self.variant.isa[NewOrder]()

    def get_new_order(self) -> Optional[NewOrder]:
        if self.is_new_order():
            return self.variant[NewOrder].copy()
        return None

    def isa[T: AnyType](self) -> Bool:
        return self.variant.isa[T]()


struct OrderTicket(Equatable & Hashable & Copyable):
    var id: String
    var fill: Size
    var time: Optional[Timestamp]
    var order: NewOrder

    def __init__(out self, id: String, var order: NewOrder):
        self.id = id
        self.fill = 0
        self.time = None
        self.order = order^

    def is_buy(self) -> Bool:
        """
        True if this is a BUY order, False otherwise.
        """
        return self.order.size > 0

    def is_sell(self) -> Bool:
        """
        True if this is a SELL order, False otherwise.
        """
        return self.order.size < 0

    def __eq__(self, other: OrderTicket) -> Bool :
        return self.id == other.id

    def __hash__[T: Hasher](self, mut hasher: T) -> None:
        self.id.__hash__(hasher)
    
    def remaining(self) -> Size:
        """Return the remaining size of the order that has not been filled yet."""
        try:
            return self.order.size - self.fill
        except:
            abort("Error calculating remaining size of the order.")

    def remaining_value(self, price: Float64) -> Amount:
        """Return the remaining value of the order that has not been filled yet."""
        if self.order.limit:
            return self.order.asset.value(self.remaining(), self.order.limit.value())
        else:
            return self.order.asset.value(self.remaining(), price)

    def cancel(self) -> CancelOrder:
        """Create a cancellation order."""
        return CancelOrder(self.id)

    def modify(self, size: Optional[Size], limit: Optional[Float64]) -> ModifyOrder:
        """Create a modify order. You can modify the size and/or limit of an existing order.
        If a parameter is not provided, the existing value will be retained.

        Args:
            size: The new size for the order. If None, the existing size will be retained.
            limit: The new limit price for the order. If None, the existing limit will be retained.

        Returns:
            A modify Order instance with the modified size and/or limit.
        """    
        return ModifyOrder(self.id, size, limit)

    
    def is_executable(self, price: Float64) -> Bool:
        """Will this order execute given the provided price. A market order will
        always execute, a limit order only if the price is right.

        Args:
            price: The current market price to check against the order's limit.

        Returns:
            True if the order can be executed at the given price, False otherwise.
        """
        if self.order.limit is None:
            return True
        
        var limit = self.order.limit.value()
        return price <= limit if self.is_buy() else price >= limit

