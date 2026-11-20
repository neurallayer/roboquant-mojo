
from .order import NewOrder, Order, TIF, OrderTicket, Size, CancelOrder, ModifyOrder
from .account import Account, Position, Trade
from .money import Wallet, Amount, Currency, Converter
from .asset import Asset
from .feed import Event
from .time import Timestamp
from std.logger import Logger
from std.os import abort

comptime logger = Logger()


trait Broker:
    """Broker if responsible for placing orders at the real broker and communicating
    back the latest state through the account object.

    Brokers are not copyable, since they typically hold connections 
    to a real brokers API end-points.""" 

    def place_orders(mut self, orders: List[Order]) -> None:
        """Place zero or more orders at the broker."""
        ...

    def sync(mut self, event: Event) -> Account:
        """"Sync the broker and return the updated account."""
        ...


struct SimBroker(Broker):
    """A simulated broker that tracks positions and a virtual cash wallet
    while simulating a market place."""

    var orders: List[OrderTicket]
    var positions: Dict[Asset, Position]
    var cash: Wallet
    var base_currency: Currency
    var order_id: Int
    var tz_offset_seconds: Int
    var fee_pct: Float64
    var converter: Converter

    def __init__(out self, deposit: Amount = Amount(Currency.USD, 100_000), tz_offset_seconds: Int = 0, fee_pct: Float64 = 0.0, currency_converter: Converter = Converter()):
        self.orders = []
        self.positions = {}
        self.cash = Wallet(deposit)
        self.base_currency = deposit.currency
        self.order_id = 0
        self.tz_offset_seconds = tz_offset_seconds
        self.fee_pct = fee_pct
        self.converter = currency_converter

    def place_orders(mut self, orders: List[Order]) -> None:
        for order in orders:
            ref variant = order.variant

            if variant.isa[NewOrder]():
                self.order_id += 1
                var id = String(self.order_id)
                self.orders.append(OrderTicket(id, variant[NewOrder].copy()))
            elif variant.isa[CancelOrder]():
                ref id = variant[CancelOrder].id
                if not self.__remove_order(id):
                    logger.warning("Couldn't find cancelled order")
            else:
                ref mo = variant[ModifyOrder]
                if not self.__modify_order(mo.id, mo.size, mo.limit):
                    logger.warning("Couldn't find modify order")


    def __modify_order(mut self, id: String, size: Optional[Size], limit: Optional[Float64]) -> Bool:
        for i in range(len(self.orders)):
            if self.orders[i].id == id:
                if case .Some(size) = size:
                    self.orders[i].order.size = size
                if case .Some(limit) = limit:
                    self.orders[i].order.limit = limit
                return True
        return False
 
    def __remove_order(mut self, id: String) -> Bool:
        for i in range(len(self.orders)):
            if self.orders[i].id == id:
                _ = self.orders.pop(i)
                return True
        return False


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

    def __update_position(mut self, asset: Asset, fill: Size, price: Float64) raises -> Amount:
        """update position based on a fill and return the realized pnl"""
        if fill.is_zero():
            return Amount(asset.currency(), 0.0)

        var pos = self.positions.get(asset, Position.zero(asset))

        var new_size = pos.size + fill
        var avg_price: Float64
        var pnl: Amount

        # position increase
        if (pos.size >= 0 and fill > 0) or (pos.size <= 0 and fill < 0):
            avg_price = (pos.avg_price * Float64(pos.size) + price * Float64(fill)) / Float64(new_size)
            pnl = Amount(asset.currency(), 0)

        # position decrease
        elif (pos.size >= 0 and new_size > 0) or (pos.size <= 0 and new_size < 0):
            avg_price = pos.avg_price
            pnl = asset.value(fill, price - pos.avg_price)

        # close or switch position side
        else:
            avg_price = price
            pnl = asset.value(pos.size, price - pos.avg_price)

        if new_size:
            self.positions[asset] = Position(asset, new_size, avg_price, pos.mkt_price)
        else:
            self.__close_position(pos)

        return pnl


    def __process_orders(mut self, ref event: Event) raises -> List[Trade]:
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
                    var pnl = self.__update_position(order.asset.copy(), ticket.remaining(), price)
                    var trade = Trade(order.asset, order.size, price, pnl, event.time)
                    self.cash.withdraw(trade.value())
                    trades.append(trade^)
                    continue
            
            orders.append(ticket.copy())

        self.orders = orders^
        return trades^
    
    def sync(mut self, event: Event) -> Account:
        try:
            # process the open orders
            var trades = self.__process_orders(event)

            # update the market price of the positions based on the latest prices from the event
            for ref pos in self.positions.values():
                if case .Some(price) = event.get_price(pos.asset):
                    pos.mkt_price = price

            var bp =  self.converter.convert(self.cash, self.base_currency, event.time)

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

