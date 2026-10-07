from .time import Timestamp
from std.os import abort

struct Currency(ImplicitlyCopyable, Writable, Equatable, Hashable):
    """
    Currency represents a specific currency used in financial transactions.
    It is uniquely identified by its code, which is a string representing the currency's code (e.g., "USD" for US Dollar, "EUR" for Euro).
    The Currency struct provides methods for comparison, hashing, and writing to output streams.
    """

    comptime USD = Self("USD")
    comptime EUR = Self("EUR")
    comptime GBP = Self("GBP")
    comptime JPY = Self("JPY")
   
    var code: String 

    @implicit
    def __init__(out self, code: String):
        self.code = code

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.code)

    def __rmatmul__(self, other: Float64) -> Amount:
        """Allow the use of the @ operator to create an Amount with the specified currency and value.
        Args:
            other (Float64): The monetary value to be associated with the currency.
        Returns:
            Amount: An Amount instance representing the specified value in the given currency.

        Example:
            usd_amount = 100.0@USD  # Creates an Amount of 100 USD
        """
        return Amount(self, other)

struct ExchangeRate(ImplicitlyCopyable, Comparable):

    var time: Timestamp
    var rate: Float64

    def __lt__(self, rhs: Self) -> Bool:
        return self.rate < rhs.rate


def bisect_left[T: Comparable & Movable](arr: List[T], x: T) -> Int:
    var lo = 0
    var hi = len(arr)
    while lo < hi:
        var mid = lo + (hi - lo) // 2
        if arr[mid] < x:
            lo = mid + 1
        else:
            hi = mid
    return lo

@fieldwise_init
struct Converter(ImplicitlyCopyable):
    """
    A Converter is responsible for converting monetary amounts between different currencies
    based on historical exchange rates. It maintains a dictionary of exchange rates for different currencies
    and provides methods to convert amounts at specific timestamps.
    """

    var _rates: Dict[Currency, Tuple[List[Timestamp], List[Float64]]]

    def __init__(out self):
        self._rates = {}
        self._rates[Currency.USD] = ([0.0], [1.0])
        self._rates[Currency.EUR] = ([0.0], [1.1])
        self._rates[Currency.GBP] = ([0.0], [1.2])


    def __init__(out self, *, copy: Self):
        self._rates = copy._rates.copy()

    def _get_rate(self, currency: Currency, time: Timestamp) raises -> Float64:
        ref timeline, rates = self._rates[currency]
        var idx = bisect_left(timeline, time) # type: ignore
        idx = min(idx, len(rates) - 1)
        return rates[idx]

    def convert(self, amount: Amount, to_currency: Currency, time: Timestamp) -> Amount:
        """Convert the monetary amount into another currency at the provided time.
        """
        try:
            var value = amount.value * self._get_rate(to_currency, time) / self._get_rate(amount.currency, time)
            return Amount(to_currency, value)
        except e:
            abort(String(e))
    


@fieldwise_init
struct Amount(ImplicitlyCopyable, Writable, Roundable):
    """Holds the monetary amount of a single currency. 
    Should be threated like an immutable struct."""

    comptime _CONVERTER = Converter()

    var currency: Currency
    var value: Float64

    def __init__(out self, currency_code: String, value: Float64):
        self.currency = Currency(currency_code)
        self.value = value

    def __round__(self) -> Amount:
        return Self(self.currency, round(self.value))

    def __round__(self, number: Int) -> Amount:
        return Self(self.currency, round(self.value, number))

    @staticmethod
    def empty(currency: Currency = Currency.USD) -> Self:
        return Self(currency, 0.0)

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.value, "@", self.currency)

    def convert_to(self, currency: Currency, time: Timestamp) -> Self:
        if self.currency == currency:
            return self.copy()
        if self.value == 0:
            return Self(currency, 0.0)

        var result = Self._CONVERTER.convert(self, currency, time)
        return result

    def __add__(self, other: Amount) -> Wallet:
        return Wallet(self, other)

    def __lt__(self, other: Float64) -> Bool:
        return self.value < other

struct Wallet(Copyable, Writable, Defaultable, Roundable):
    """Contains values of multiple currencies at the same time.
    This is a mutable struct.
    """

    var values: Dict[Currency, Float64]

    def __init__(out self):
        self.values = {}

    def __init__(out self, values: Dict[Currency, Float64]):
        self.values = values.copy()

    def __init__(out self, *amounts: Amount):
        self.values = {}
        for amount in amounts:
            var k = amount.currency
            var v = self.values.get(k, 0.0)
            self.values[k] = v + amount.value

    def __round__(self) -> Wallet:
        var rounded = {item.key: round(item.value) for item in self.values.items()}
        return Self(rounded)

    def __round__(self, number: Int) -> Wallet:
        var rounded = {item.key: round(item.value, number) for item in self.values.items()}
        return Self(rounded)
    
    def deposit(mut self, amount: Amount):
        var k = amount.currency
        var v = self.values.get(k, 0.0)
        self.values[k] = v + amount.value

    def deposit(mut self, wallet: Wallet):
        for item in wallet.values.items():
            var k = item.key
            var v = self.values.get(k, 0.0)
            self.values[k] = v + item.value

    def withdraw(mut self, wallet: Wallet):
        for item in wallet.values.items():
            var k = item.key
            var v = self.values.get(k, 0.0)
            self.values[k] = v - item.value

    def withdraw(mut self, amount: Amount):
        var k = amount.currency
        var v = self.values.get(k, 0.0)
        self.values[k] = v - amount.value

    def amounts(self) -> List[Amount]:
        return [Amount(item.key, item.value) for item in self.values.items()]
    
    def write_to(self, mut writer: Some[Writer]):
        for item in self.amounts():
            writer.write(item, " ") 

    def get(self, currency: Currency) -> Optional[Float64]:
        return self.values.get(currency)

    def get(self, currency_code: String) -> Optional[Float64]:
        return self.get(Currency(currency_code))

    def get(self, currency: Currency, default: Float64) -> Float64:
        return self.values.get(currency, default)

    def get(self, currency_code: String, default: Float64) -> Float64:
        return self.get(Currency(currency_code), default)

    def __getitem__(self, currency_code: String) raises -> Float64:
        return self.values[Currency(currency_code)]

    def __getitem__(self, currency: Currency) raises -> Float64:
        return self.values[currency]

    def convert_to(self, currency: Currency, time: Timestamp) -> Amount:
        var sum = 0.0
        for amount in self.amounts():
            sum += amount.convert_to(currency, time).value
        return Amount(currency, sum)