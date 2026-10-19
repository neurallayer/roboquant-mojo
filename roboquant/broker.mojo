
from .order import Order, TIF
from .account import Account, Position, Trade
from .money import Wallet, Amount, Currency
from .asset import Asset
from .feed import Event
from .time import Timestamp, same_day, UTC
from morrow import TimeZone


trait Broker:
    """Brokers are not copyable, since they typically hold connections 
    to a real brokers API end-points.""" 

    def place_orders(mut self, orders: List[Order]) -> None:
        """Place the orders at the broker."""
        ...

    def sync(mut self, event: Event) -> Account:
        """"Sync the broker and return the updated account."""
        ...

struct SimBroker(Broker):
    """A simulated broker that tracks positions and a virtual cash wallet while placing orders."""

    var orders: List[Order]
    var positions: Dict[Asset, Position]
    var cash: Wallet
    var base_currency: Currency
    var order_id: Int
    var tz: TimeZone

    def __init__(out self, deposit: Amount = Amount(Currency.USD, 100_000), timezone: TimeZone = UTC):
        self.orders = []
        self.positions = {}
        self.cash = Wallet(deposit)
        self.base_currency = deposit.currency
        self.order_id = 0
        self.tz = timezone

    def __replace_order(mut self, new_order: Order) -> Bool:
        for idx, order in enumerate(self.orders):
            if order.id == new_order.id:
                self.orders[idx] = order
                return True
        return False

    def place_orders(mut self, orders: List[Order]) -> None:
        for var order in orders:
            if not order.id:
                # We are creating a new order, so we need to assign an ID and add it to the list of orders
                assert not order.size.is_zero(), "New order cannot have size zero"
                self.order_id += 1
                order.id = String(self.order_id)
                self.orders.append(order)
            else:
                # We are updating an existing order, so we need to find it in the list of orders and replace it
                var success = self.__replace_order(order)
                if not success:
                    print("Unknown Order")

    def __update_positions(mut self, event: Event) -> None:
        for asset in self.positions:
            var price = event.get_price(asset)
            if price:
                try:
                    self.positions[asset].mkt_price = price.value()
                except e:
                    print("error:", e)


    def __has_expired(self, order: Order, time: Timestamp) -> Bool:
        if order.tif == TIF.GTC:
            return False
        elif order.tif == TIF.DAY:
            return not same_day(order.time.value(), time, self.tz)
        
        print("Unknown TIF:", order.tif)
        return False

    def __process_orders(mut self, ref event: Event) -> List[Trade]:
        if not self.orders:
            return []
    
        var trades = List[Trade]()
        var remaining_orders = List[Order]()
  
        for ref order in self.orders:
            assert order.id != None, "Should have order-id assigned"
            if order.remaining().is_zero():
                continue
            
            if order.time is None:
                order.time = event.time
            elif self.__has_expired(order, event.time):
                continue

            var _price = event.get_price(order.asset)
            if _price and order.is_executable(_price.value()):
                var price = _price.value()
                var pos = self.positions.get(order.asset, Position.empty(order.asset)) 
                pos += order.size
                self.positions[order.asset] = pos^
                self.cash.withdraw(order.value(price))
                var trade = Trade(order.asset, order.size, price, 0.0, event.time)
                trades.append(trade^)
            else:
                remaining_orders.append(order)

        self.orders = remaining_orders^
        return trades^
    
    def sync(mut self, event: Event) -> Account:
        var trades = self.__process_orders(event)

        # update the market price of the positions based on the latest prices from the event
        self.__update_positions(event)

        var bp = self.cash.convert_to(self.base_currency, event.time)

        var account = Account(
            last_update = event.time,
            positions = List(self.positions.values()),
            orders = self.orders.copy(),
            buying_power=bp,
            cash=self.cash.copy(),
            trades=trades^
        )
        return account^
