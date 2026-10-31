from std.testing import assert_equal, assert_true, assert_not_equal, assert_almost_equal, TestSuite
from roboquant.asset import Asset
from roboquant.feed import Event, Candle, Quote, Price
from roboquant.time import Timestamp


def test_item() raises:
    var bar = Candle(100.0, 101.0, 99.0, 100.5, 10_000.0)
    var price = Price(bar^)
    assert_equal(price.get_price(), 100.5)
    assert_true(price.isa[Candle]())
    
    

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()