
from order import Order
from account import Account, Position, Trade
from money import Wallet, Amount, Currency
from asset import Asset
from feed import Event


trait Broker(Deinitable):
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
    var prices: Dict[Asset, Float64]
    var order_id: Int

    def __init__(out self, deposit: Amount = Amount(Currency.USD, 100_000)):
        self.orders = []
        self.positions = {}
        self.cash = Wallet(deposit)
        self.base_currency = deposit.currency
        self.prices = {}
        self.order_id = 0
    
    def __replace_order(mut self, new_order: Order) -> Bool:
        for idx, order in enumerate(self.orders):
            if order.id == new_order.id:
                self.orders[idx] = order
                return True
        return False

    def place_orders(mut self, orders: List[Order]) -> None:
        for var order in orders:
            if not order.id:
                assert not order.size.is_zero(), "New order cannot have size zero"
                self.order_id += 1
                order.id = String(self.order_id)
                self.orders.append(order)
            else:
                var success = self.__replace_order(order)
                if not success:
                    print("Unknown Order")
    
    def sync(mut self, event: Event) -> Account:
        var trades = List[Trade]()
        for item in event.prices:     
            self.prices[item.get_asset()] = item.get_price()   
     
        var remaining_orders = List[Order]()

        for order in self.orders:
            assert order.id != None, "Should have order assigned"
            var _price = self.prices.get(order.asset)
            if _price:
                var price = _price.value()
                var p = self.positions.get(order.asset)
                if p:
                    p.value() += order.size
                else:
                    self.positions[order.asset] = Position(order.asset, order.size, price)
                
                self.cash.withdraw(order.value(price))
                var trade = Trade(order.asset, order.size.copy(), price, 0.0)
                trades.append(trade^)
            else:
                remaining_orders.append(order)

        for asset in self.positions:
            var price = self.prices.get(asset)
            if price:
                try:
                    self.positions[asset].mkt_price = price.value()
                except e:
                    print("error:", e)
 
        self.orders = remaining_orders^
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
