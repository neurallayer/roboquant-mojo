
from .order import NewOrder, Order, TIF, OrderTicket
from .account import Account, Position, Trade
from .money import Wallet, Amount, Currency
from .asset import Asset
from .feed import Event
from .time import Timestamp
from std.logger import Logger
from std.os import abort

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

    var orders: List[OrderTicket]
    var positions: Dict[Asset, Position]
    var cash: Wallet
    var base_currency: Currency
    var order_id: Int
    var tz_offset_seconds: Int

    def __init__(out self, deposit: Amount = Amount(Currency.USD, 100_000), tz_offset_seconds: Int = 0):
        self.orders = []
        self.positions = {}
        self.cash = Wallet(deposit)
        self.base_currency = deposit.currency
        self.order_id = 0
        self.tz_offset_seconds = tz_offset_seconds

    def place_orders(mut self, orders: List[Order]) -> None:
        for order in orders:
            if case .Some(new_order) = order.get_new_order():
                self.order_id += 1
                var id = String(self.order_id)
                self.orders.append(OrderTicket(id, new_order.copy()))
    
    def __update_positions(mut self, event: Event) -> None:
        for ref pos in self.positions.values():
            if case .Some(price) = event.get_price(pos.asset):
                pos.mkt_price = price
      

    def __has_expired(self, ticket: OrderTicket, time: Timestamp) -> Bool:
        match ticket.order.tif:
            case TIF.GTC:
                return False
            case TIF.DAY:
                return not time.same_day(ticket.time.value())
            case _:
                logger.error("Unknown TIF:", ticket.order.tif)
                return False

    def __close_position(mut self, pos: Position):
        try:
            var _ = self.positions.pop(pos.asset)
        except:
            pass


    def __process_orders(mut self, ref event: Event) -> List[Trade]:
        if not self.orders:
            return []
    
        var trades = List[Trade]()
        var orders = List[OrderTicket]()
      
        for ref ticket in self.orders:
            if ticket.remaining().is_zero():
                continue
            
            if not ticket.time:
                ticket.time = event.time
            elif self.__has_expired(ticket, event.time):
                continue

            ref order = ticket.order
            if case .Some(price) = event.get_price(order.asset):
                if ticket.is_executable(price):
                    var pos = self.positions.get(order.asset, Position.empty(order.asset)) 
                    pos += order.size
                    if pos.size.is_zero():
                        self.__close_position(pos)
                    else:
                        self.positions[order.asset] = pos^
                    self.cash.withdraw(order.value(price))
                    var trade = Trade(order.asset, order.size, price, 0.0, event.time)
                    trades.append(trade^)
                    continue
            
            orders.append(ticket.copy())

        self.orders = orders^
        return trades^
    
    def sync(mut self, event: Event) -> Account:
        try:
            var trades = self.__process_orders(event)

            # update the market price of the positions based on the latest prices from the event
            self.__update_positions(event)

            var bp = self.cash.convert_to(self.base_currency, event.time)

            return Account(
                last_update = event.time,
                positions = List(self.positions.values()),
                orders = self.orders.copy(),
                buying_power=bp,
                cash=self.cash.copy(),
                trades=trades^
            )
        except e:
            abort(String(e))

