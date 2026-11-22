from std.testing import assert_equal, assert_true, assert_not_equal, assert_almost_equal, TestSuite
from roboquant.time import Timestamp, Timeframe, Duration

def test_timestamp() raises:
    var ts1: Timestamp = Timestamp.from_iso("2010-01-01")
    var dt1 = ts1.to_datetime()
    var ts2: Timestamp = dt1.timestamp()
    assert_equal(ts1, ts2)
    
def test_timeframe() raises:
    var tf = Timeframe("2000", "2002")
    var ts1: Timestamp = Timestamp("2001-01-01")
    assert_true(ts1 in tf)

def test_duration() raises:
    var d = Duration(days=10, hours=2)
    assert_equal(d.nanoseconds, 10 * 24 * 3600 * 1_000_000_000 + 2 * 3600 * 1_000_000_000)
    assert_equal("{d}", "10d2h")
 
def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()