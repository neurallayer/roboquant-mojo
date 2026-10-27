
from .order import Order, TIF
from .account import Account, Position, Trade
from .money import Wallet, Amount, Currency
from .asset import Asset
from .feed import Event
from .time import Timestamp, same_day, UTC, TimeZone
from std.logger import Logger

comptime logger = Logger()


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

    var orders: Dict[String, Order]
    var positions: Dict[Asset, Position]
    var cash: Wallet
    var base_currency: Currency
    var order_id: Int
    var tz: TimeZone

    def __init__(out self, deposit: Amount = Amount(Currency.USD, 100_000), timezone: TimeZone = UTC):
        self.orders = {}
        self.positions = {}
        self.cash = Wallet(deposit)
        self.base_currency = deposit.currency
        self.order_id = 0
        self.tz = timezone

    def place_orders(mut self, orders: List[Order]) -> None:
        for var order in orders:

            match order:
                case Order(id=.None): # new order
                    self.order_id += 1
                    order.id = String(self.order_id)
                    self.orders[order.id.value()] = order
                case Order(size=size) if size.is_zero(): # cancel order
                    self.__remove_order(order)
                case Order(id=.Some(id)) if id in self.orders: # update order
                    self.orders[id] = order
                case _: 
                    logger.warning("ignored order", order)

    def __update_positions(mut self, event: Event) -> None:
        try:
            for asset in self.positions:
                if case .Some(price) = event.get_price(asset):
                    self.positions[asset].mkt_price = price
        except e:
            logger.error("unexpected error:", e)


    def __has_expired(self, order: Order, time: Timestamp) -> Bool:
        if order.tif == TIF.GTC:
            return False
        elif order.tif == TIF.DAY:
            return not same_day(order.time.value(), time, self.tz)
        
        logger.error("Unknown TIF:", order.tif)
        return False

    def __remove_order(mut self, order: Order):
        try:
            var _ = self.orders.pop(order.id.value())
        except:
            pass

    def __close_position(mut self, pos: Position):
        try:
            var _ = self.positions.pop(pos.asset)
        except:
            pass


    def __process_orders(mut self, ref event: Event) -> List[Trade]:
        if not self.orders:
            return []
    
        var trades = List[Trade]()
      
        for var order in self.orders.values():
            if order.remaining().is_zero() or order.is_cancelled():
                self.__remove_order(order)
                continue
            
            if not order.time:
                order.time = event.time
            elif self.__has_expired(order, event.time):
                self.__remove_order(order)
                continue

            if case .Some(price) = event.get_price(order.asset):
                if order.is_executable(price):
                    var pos = self.positions.get(order.asset, Position.empty(order.asset)) 
                    pos += order.size
                    if pos.size.is_zero():
                        self.__close_position(pos)
                    else:
                        self.positions[order.asset] = pos^
                    self.cash.withdraw(order.value(price))
                    var trade = Trade(order.asset, order.size, price, 0.0, event.time)
                    trades.append(trade^)
                    self.__remove_order(order)
              
        return trades^
    
    def sync(mut self, event: Event) -> Account:
        var trades = self.__process_orders(event)

        # update the market price of the positions based on the latest prices from the event
        self.__update_positions(event)

        var bp = self.cash.convert_to(self.base_currency, event.time)

        return Account(
            last_update = event.time,
            positions = List(self.positions.values()),
            orders = List(self.orders.values()),
            buying_power=bp,
            cash=self.cash.copy(),
            trades=trades^
        )

