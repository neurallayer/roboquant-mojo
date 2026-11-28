from std.testing import assert_equal, assert_true, assert_not_equal, assert_almost_equal, TestSuite
from roboquant.util import SmallString2, SmallString4, SmallString8, SmallString16

def test_small_string() raises:
    var s0 = SmallString2("hi")  # 2 bytes
    var s1 = SmallString4("Hello")  # 4 bytes
    var s2 = SmallString8("World!")  # 8 bytes
    var s3 = SmallString16("Mojo 🔥")  # 16 bytes

    assert_equal(s0.to_string(), "hi")
    assert_equal(s1.to_string(), "Hell") # truncated last character
    assert_equal(s2.to_string(), "World!")
    assert_equal(s3.to_string(), "Mojo 🔥")
 
def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()