from std.testing import assert_equal, assert_true, assert_not_equal, assert_almost_equal, TestSuite
from roboquant.time import Timestamp


def test_timestamp() raises:
    var ts1: Timestamp = Timestamp.from_iso("2010-01-01")
    var dt1 = ts1.to_datetime()
    var ts2: Timestamp = dt1.timestamp()
    assert_equal(ts1, ts2)
    
    
def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()