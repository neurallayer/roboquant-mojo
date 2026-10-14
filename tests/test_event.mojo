from std.testing import assert_equal, assert_true, assert_not_equal, assert_almost_equal, TestSuite
from roboquant.asset import Asset
from roboquant.feed import Event, Bar, Quote
from roboquant.time import Timestamp, now


def test_item() raises:
    var asset = Asset.Stock("ABC")
    var bar = Bar(asset, 100.0, 101.0, 99.0, 100.5, 10_000.0)
    assert_equal(bar.get_price(), 100.5)

    assert_equal(bar.get_type(), "Bar")
    
    

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()