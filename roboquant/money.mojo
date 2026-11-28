from .time import Timestamp
from std.os import abort, stat, mkdir
from std.os.path import exists, expanduser, join
from std.memory import ArcPointer
from std.python import Python, PythonObject
from std.logger import Logger

comptime logger = Logger()


struct Currency(ImplicitlyCopyable, Writable, Equatable, Hashable):
    """
    Currency represents a specific currency used in financial transactions. 
    Please note that only the first 4 characters are stored, which covers both 
    traditional 3-letter currency codes (like USD, EUR, GBP) and
    some extended codes (like USDT, USDC).
    """
   
    comptime USD = Self("USD")
    comptime EUR = Self("EUR")
    comptime GBP = Self("GBP")
    comptime JPY = Self("JPY")
    comptime USDT = Self("USDT")
    comptime USDC = Self("USDC")


    var __code: String

    @implicit
    def __init__(out self, code: String):
        self.__code = String(code)
 
    # Reconstruct and write the string representation instead of the raw integer
    def write_to(self, mut writer: Some[Writer]):
        self.__code.write_to(writer)

    def __rmatmul__(self, other: Float64) -> Amount:
        """Allow the use of the @ operator to create an Amount with the specified currency and value.

        Args:
            other: The monetary value to be associated with the currency.

        Returns:
            An Amount instance representing the specified value in the given currency.

        Example:
        ```mojo
        usd_amount = 100.0@USD  # Creates an Amount of 100 USD
        ```
        """
        return Amount(self, other)

    

trait CurrencyConverter(Deinitable & Movable):

    def convert(self, wallet: Wallet, to_currency: Currency, time: Timestamp) raises -> Amount:
        """Convert a wallet to a single amount."""

        # Optimization for single currency
        if wallet.is_single_currency(to_currency):
            return wallet[to_currency]

        # Multi-currency path
        var sum = 0.0
        for amount in wallet.amounts():
            sum += self.convert_float(amount, to_currency, time)
        return Amount(to_currency, sum)

    def convert(self, amount: Amount, to_currency: Currency, time: Timestamp) raises -> Amount:
        """Convert an amount into another amount."""
        return Amount(to_currency, self.convert_float(amount, to_currency, time))


    def convert_float(self, amount: Amount, to_currency: Currency, time: Timestamp) raises -> Float64:
        """Convert the monetary amount into another currency at the provided time.
        """
        ...


@fieldwise_init
struct NoConverter(CurrencyConverter):
    """Doesn't convert between different currencies."""

    def convert_float(self, amount: Amount, to_currency: Currency, time: Timestamp) raises -> Float64:
        if amount.currency == to_currency:
            return amount.value
        if amount.value == 0:
            return 0.0

        raise("No conversion possible")



@fieldwise_init
struct ExchangeRate(Copyable, TrivialRegisterPassable):
    var time: Timestamp
    var rate: Float64



struct Converter(CurrencyConverter, ImplicitlyCopyable):
    """
    A Converter is responsible for converting monetary amounts between different currencies
    based on historical exchange rates. It maintains a dictionary of exchange rates for different currencies
    and provides methods to convert amounts at specific timestamps.

    It assumes all the rates can be mapped to a single currency. 
    """

    var _rates: ArcPointer[Dict[Currency, List[ExchangeRate]]]

    def __init__(out self, var rates: Dict[Currency, List[ExchangeRate]]):
        self._rates = ArcPointer(rates^)

    def __init__(out self):
        self._rates = ArcPointer(Dict[Currency, List[ExchangeRate]]())

    @staticmethod
    def __bisect_left(arr: List[ExchangeRate], x: Timestamp) -> Int:
        var lo = 0
        var hi = len(arr)
        while lo < hi:
            var mid = lo + (hi - lo) // 2
            if arr[mid].time < x:
                lo = mid + 1
            else:
                hi = mid
        return lo


    def __init__(out self, *, copy: Self):
        self._rates = copy._rates.copy()

    def _get_rate(self, currency: Currency, time: Timestamp) raises -> Float64:
        ref rates = self._rates[][currency]
        var idx = Self.__bisect_left(rates, time) # type: ignore
        idx = min(idx, len(rates) - 1)
        return rates[idx].rate

    def convert_float(self, amount: Amount, to_currency: Currency, time: Timestamp) raises -> Float64:
        """Convert the monetary amount into another currency at the provided time.
        """
        if amount.currency == to_currency:
            return amount.value
        var value = amount.value * self._get_rate(to_currency, time) / self._get_rate(amount.currency, time)
        return value


def __download_ecb_exchange_rates() -> Bool:
    var python_code = '''
import io
import urllib.request
import zipfile
from pathlib import Path

url = "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-hist.zip"
with urllib.request.urlopen(url, timeout=10) as response:
    content = response.read()
with zipfile.ZipFile(io.BytesIO(content)) as z:
    p = Path.home() / ".roboquant"
    z.extractall(p)
    '''
    var success = Python().eval(code=python_code)
    return success

def load_ecb_exchange_rates() raises -> Converter:
    var roboquant_home = expanduser("~/.roboquant")
    if not exists(roboquant_home):
        logger.info("Creating roboquant home at ~/.roboquant")
        mkdir(roboquant_home)

    var filename = join(roboquant_home, "eurofxref-hist.csv")
    var today = Timestamp.now()
    if not exists(filename) or not today.same_day(Timestamp(stat(filename).st_birthtimespec.as_nanoseconds())):
        if not __download_ecb_exchange_rates():
            logger.warning("failed downloading new ECB rates, trying to process anyway.")
        
    var file = open(filename, "r")
    var lines = file.read().split("\n")
    var codes = lines[0].strip().removesuffix(",").split(",")[1:]
    var currencies = [Currency(String(code)) for code in codes]
    logger.debug(currencies)
 
    var rates = [List[ExchangeRate]() for _ in currencies]
    var l = len(codes)
    for line in lines[1:]:
        var row = line.strip().split(",")
        if len(row) <= l:
            continue 
        var dt = row[0]
        var time = Timestamp.from_iso(String(dt))
        for idx in range(l):
            try:         
                var rate = Float64(row[idx + 1]) 
                var exchange_rate = ExchangeRate(time, rate)
                rates[idx].append(exchange_rate)
            except:
                # expected since some rows contain N/A like text
                pass

    var all_rates = {currencies[idx]:rates[idx].copy() for idx in range(l)}
    all_rates[Currency.EUR] = [ExchangeRate(Timestamp.MIN, 1.0)]
    return Converter(all_rates^)



@fieldwise_init
struct Amount(ImplicitlyCopyable, Writable, Roundable, Equatable):
    """Holds the monetary value of a single currency."""

    var currency: Currency
    var value: Float64

    @staticmethod
    def zero(currency: Currency) -> Self:
        """Create a zero amount for the provided currency."""
        return Self(currency, 0.0)

    def __round__(self) -> Amount:
        return Self(self.currency, round(self.value))

    def __round__(self, number: Int) -> Amount:
        return Self(self.currency, round(self.value, number))

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.value, "@", self.currency)

    def __add__(self, other: Amount) -> Wallet:
        return Wallet(self, other)

    def __mul__(self, other: Float64) -> Amount:
        return Amount(self.currency, self.value * other)

    def __lt__(self, other: Float64) -> Bool:
        return self.value < other

    def __lte__(self, other: Float64) -> Bool:
        return self.value <= other

    def __gt__(self, other: Float64) -> Bool:
        return self.value > other

    def __gte__(self, other: Float64) -> Bool:
        return self.value >= other

    def __neg__(self) -> Self:
        return Amount(self.currency, - self.value)

    def __abs__(self) -> Self:
        return Amount(self.currency, abs(self.value))

struct Wallet(Copyable, Writable, Defaultable, Roundable, Sized):
    """Contains values of multiple currencies at the same time.
    This is a mutable struct.
    """

    var balances: Dict[Currency, Float64]

    def __init__(out self):
        self.balances = {}

    def __init__(out self, var balances: Dict[Currency, Float64]):
        self.balances = balances^

    def __init__(out self, *amounts: Amount):
        self.balances = {}
        for amount in amounts:
            var k = amount.currency
            var v = self.balances.get(k, 0.0)
            self.balances[k] = v + amount.value

    def __round__(self) -> Wallet:
        var rounded = {item.key: round(item.value) for item in self.balances.items()}
        return Self(rounded^)

    def __round__(self, number: Int) -> Wallet:
        var rounded = {item.key: round(item.value, number) for item in self.balances.items()}
        return Self(rounded^)
    
    def deposit(mut self, amount: Amount):
        ref k = amount.currency
        var v = self.balances.get(k, 0.0)
        self.balances[k] = v + amount.value

    def deposit(mut self, wallet: Wallet):
        for item in wallet.balances.items():
            var k = item.key
            var v = self.balances.get(k, 0.0)
            self.balances[k] = v + item.value

    def is_single_currency(self, currency: Currency) -> Bool:
        """Check if the wallet only contains the provided currency (or is empty)."""
        return (len(self.balances) == 0) or ((len(self.balances) == 1) and (currency in self.balances))

    def withdraw(mut self, wallet: Wallet):
        """Withdraw a wallet from this wallet."""
        for item in wallet.balances.items():
            var k = item.key
            var v = self.balances.get(k, 0.0)
            self.balances[k] = v - item.value

    def withdraw(mut self, amount: Amount):
        """Withdraw an amount from the wallet."""
        var k = amount.currency
        var v = self.balances.get(k, 0.0)
        self.balances[k] = v - amount.value

    def __sub__(self, wallet: Wallet) -> Wallet:
        var result = self.copy()
        result.withdraw(wallet)
        return result^

    def __isub__(mut self, wallet: Wallet):
        self.withdraw(wallet)

    def __isub__(mut self, amount: Amount):
        self.withdraw(amount)

    def __iadd__(mut self, wallet: Wallet):
        self.deposit(wallet)

    def __iadd__(mut self, amount: Amount):
        self.deposit(amount)
      
    def __add__(self, wallet: Wallet) -> Wallet:
        var result = self.copy()
        result.deposit(wallet)
        return result^

    def __sub__(self, amount: Amount) -> Wallet:
        var result = self.copy()
        result.withdraw(amount)
        return result^

    def __add__(self, amount: Amount) -> Wallet:
        var result = self.copy()
        result.deposit(amount)
        return result^

    def __contains__(self, currency: Currency) -> Bool:
        return self.balances.__contains__(currency)

    def convert_to(self, currency: Currency, time: Timestamp, converter: Some[CurrencyConverter]) raises -> Amount:
        return converter.convert(self, currency, time)

    def amounts(self) -> List[Amount]:
        return [Amount(item.key, item.value) for item in self.balances.items()]
    
    def write_to(self, mut writer: Some[Writer]):
        for item in self.amounts():
            writer.write(item, " ") 

    @inline(.always)
    def get(self, currency: Currency) -> Amount:
        """Get the amount for a specific currency.
        If the currency is not present, a zero amount is returned."""
        var value = self.balances.get(currency, 0.0)
        return Amount(currency, value) 

    def __getitem__(self, currency: Currency) -> Amount:
        return self.get(currency) 

    def __len__(self) -> Int:
        return len(self.balances)

