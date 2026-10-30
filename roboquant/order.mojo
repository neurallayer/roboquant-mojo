from .asset import Asset
from .money import Amount
from std.os import abort
from decimo import Decimal128
from .time import Timestamp


comptime Size = Decimal128

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

struct Order(ImplicitlyCopyable, Writable):
    """
    An Order represents a request to buy or sell a specific asset in the market.

    Attributes:
        asset (Asset): The underlying asset of the order.
        size (Size): The size of the order.
        limit (Optional[Float64]): Optionally a limit price for the order. If not set, the order is handled as a market order.
        tif (TIF): Time In Force, which specifies how long the order remains active before it is executed or expires.
        id (Optional[String]): An optional identifier for the order, which can be used for tracking and management purposes.
    """

    var asset: Asset
    """The underlying asset of the order."""

    var size: Size
    """The size of the order."""

    var limit: Optional[Float64]
    """Optionally a limit price for the order.
    If not set, the order is handled as a market order.
    """

    var tif: TIF
    """Time In Force, DAY or GTC."""

    var id: Optional[String]
    """An optional identifier for the order.
    This should only be set by the Broker after it has been placed."""

    var fill: Size
    """The amount of the order that has been filled. This is used to track the progress of the order execution.
    This should only be set by the Broker."""

    var time: Optional[Timestamp]
    """The time when the order was placed. This should only be set by the Broker."""

    def __init__(out self, asset: Asset, size: Size, limit: Optional[Float64], tif: TIF = TIF.DAY, id: Optional[String] = None, fill: Size = Size.zero(), time: Optional[Timestamp] = None):
        self.asset = asset
        self.size = size
        self.limit = limit
        self.tif = tif
        self.id = id
        self.fill = fill
        self.time = time

    @staticmethod
    def new_mkt(asset: Asset, size: Size, tif: TIF = TIF.GTC) -> Order:
        """Create a new Market Order."""
        return Order(asset, size, None, tif)

    @staticmethod
    def new_limit(asset: Asset, size: Size, limit: Float64, tif: TIF = TIF.GTC) -> Order:
        """Create a new Limit Order."""
        return Order(asset, size, limit, tif)

    def value(self, price: Float64) -> Amount:
        """Return the total order value given the provided price. If the order has a limit set,
        that will be used instead of the price."""
        if self.limit:
            return self.asset.value(self.size, self.limit.value())
        else:
            return self.asset.value(self.size, price)

    def remaining(self) -> Size:
        """Return the remaining size of the order that has not been filled yet."""
        try:
            return self.size - self.fill
        except:
            abort("Error calculating remaining size of the order.")

    def remaining_value(self, price: Float64) -> Amount:
        """Return the remaining value of the order that has not been filled yet."""
        if self.limit:
            return self.asset.value(self.remaining(), self.limit.value())
        else:
            return self.asset.value(self.remaining(), price)

    def cancel(self) -> Order:
        """Create a cancellation order."""
        assert self.id is not None, "Id required"
        var result = self.copy()
        result.size = Size()
        return result^

    def is_buy(self) -> Bool:
        """
        True if this is a BUY order, False otherwise.
        """
        return self.size > 0

    def is_sell(self) -> Bool:
        """
        True if this is a SELL order, False otherwise.
        """
        return self.size < 0

    def is_cancelled(self) -> Bool:
        return self.size.is_zero()

    def modify(self, size: Optional[Size], limit: Optional[Float64]) -> Order:
        """Create a modify order. You can modify the size and/or limit of an existing order.
        If a parameter is not provided, the existing value will be retained.
        Args:
            size (Optional[Size]): The new size for the order. If None, the existing size will be retained.
            limit (Optional[Float64]): The new limit price for the order. If None, the existing limit will be retained.
        Returns:
            Order: A new Order instance with the modified size and/or limit.
        Raises:
            AssertionError: If the order does not have an ID, indicating that it has not been placed yet and cannot be modified.
        """
        assert self.id is not None, "Id required"
        var result = self.copy()
        if size:
            result.size = size.value()
        if limit:
            result.limit = limit.value()    
        
        return result^

    def is_executable(self, price: Float64) -> Bool:
        """Will this order execute given the provided price.
        Args:
            price: The current market price to check against the order's limit.
        Returns:
            True if the order can be executed at the given price, False otherwise.
        """
        if self.limit is None:
            return True
        
        var limit = self.limit.value()
        return price <= limit if self.is_buy() else price >= limit