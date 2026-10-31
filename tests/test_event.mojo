from std.testing import assert_equal, assert_true, assert_not_equal, assert_almost_equal, TestSuite
from roboquant.asset import Asset
from roboquant.feed import Event, Candle, Quote, Price
from roboquant.time import Timestamp


def test_item() raises:
    var candle = Candle(100.0, 101.0, 99.0, 100.5, 10_000.0)
    var price = Price(candle^)
    assert_equal(price.get_price(), 100.5)
    assert_true(price.isa[Candle]())

    assert_equal(price.get_price("HIGH"), 101.0)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()