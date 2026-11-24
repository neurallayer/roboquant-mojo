from .money import Currency, Amount, USD
from .order import Size
from std.hash import Hasher
from std.memory import ArcPointer
from std.os import abort

@fieldwise_init
struct AssetType(ImplicitlyCopyable, Writable, Equatable, Hashable):
    """Until Mojo supports enums, we use this struct to represent the type of an Asset."""

    comptime STOCK = Self(0)
    comptime OPTION = Self(1)
    comptime FOREX = Self(2)
    comptime CRYPTO = Self(3)

    var value: Int 


struct Symbol(ImplicitlyCopyable, Writable, Equatable, Hashable):
    """
    The Symbol struct represents a unique identifier for a financial instrument.
    It is a wrapper around a string value that provides a convenient way to work with symbols.
    
    Attributes:
        value (String): The string value of the symbol.
    """

    var value: String

    @implicit
    def __init__(out self, value: String):
        self.value = value

@fieldwise_init
struct __AssetData:
    """
    The Asset struct represents a financial instrument that can be traded in the market.
    It is uniquely identified by only its symbol, which is a string representing the asset's ticker or identifier.
    The Asset struct also includes information about the currency in which the asset is denominated,
    the type of asset (e.g., stock, option, forex, crypto), and the contract size for trading purposes.

    Attributes:
        symbol (String): The unique symbol or ticker of the asset.
        currency (Currency): The currency in which the asset is denominated.
        type (AssetType): The type of the asset (e.g., stock, option, forex, crypto).
        contract_size (Size): The contract size for trading the asset.
    """

    var symbol: Symbol
    var currency: Currency
    var type: AssetType
    var contract_size: Size
 


@fieldwise_init
struct Asset(ImplicitlyCopyable, Writable, KeyElement, Equatable, Hashable):
    """
    The Asset struct represents a financial instrument that can be traded in the market.
    It is uniquely identified by only its symbol, which is a string representing the asset's ticker or identifier.
    The Asset struct also includes information about the currency in which the asset is denominated,
    the type of asset (e.g., stock, option, forex, crypto), and the contract size.
    """

    var data: ArcPointer[__AssetData]
   
    @staticmethod
    def Stock(symbol: Symbol, currency: Currency = USD) -> Asset:
        """Create a new Stock with the provided symbol and currency."""
        var data = __AssetData(symbol, currency, AssetType.STOCK, Size.one())
        return Asset(ArcPointer(data^))

    @staticmethod
    def Forex(symbol: Symbol, currency: Currency, contract_size: Size = Size.one()) -> Asset:
        """Create a new Forex with the provided symbol and currency."""
        var data = __AssetData(symbol, currency, AssetType.FOREX, contract_size)
        return Asset(ArcPointer(data^))

    @staticmethod
    def Crypto(symbol: Symbol, currency: Currency, contract_size: Size = Size.one()) -> Asset:
        """Create a new Crypto with the provided symbol and currency."""
        var data = __AssetData(symbol, currency, AssetType.FOREX, contract_size)
        return Asset(ArcPointer(data^))

    @staticmethod
    def Option(symbol: Symbol, currency: Currency = USD) -> Asset:
        """Create a new Option with the provided symbol and currency.
        This assumes the contract size is 100, as is common for US equity options.
        """
        var data = __AssetData(symbol, currency, AssetType.OPTION, Size(100))
        return Asset(ArcPointer(data^))

    @always_inline
    def symbol(self) -> ref[self.data[].symbol] Symbol:
        """Return the symbol of the asset."""
        return self.data[].symbol

    @always_inline
    def currency(self) -> ref[self.data[].currency] Currency:
        """Return the currency of the asset."""
        return self.data[].currency

    @always_inline
    def type(self) -> AssetType:
        """Return the type of the asset."""
        return self.data[].type

    def __hash__[T: Hasher](self, mut hasher: T) -> None:
        self.data[].symbol.__hash__(hasher)

    def __eq__(self, other: Self, /) -> Bool:
        return self.data[].symbol == other.data[].symbol

    def __ne__(self, other: Self, /) -> Bool:
        return self.data[].symbol != other.data[].symbol

    def value(self, size: Size, price: Float64) -> Amount:
        """Return the monetary amount given the size and price."""
        ref asset = self.data.ptr()[]
        var value = Float64(asset.contract_size) * Float64(size) * price
        return Amount(asset.currency, value)
    
    def write_to(self, mut writer: Some[Writer]):
        match self.type():
            case AssetType.STOCK: writer.write("Stock:")
            case AssetType.OPTION: writer.write("Option:")
            case AssetType.FOREX: writer.write("Forex:")
            case AssetType.CRYPTO: writer.write("Crypto:")
        writer.write(self.symbol().value,":",self.currency().code)



