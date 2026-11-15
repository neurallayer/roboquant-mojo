from std.testing import assert_equal, assert_true, assert_not_equal, assert_almost_equal, TestSuite
from roboquant.money import Amount, Wallet, USD, EUR, Currency
from roboquant.time import Timestamp


def test_currency() raises:
    assert_equal(Currency("USD"), USD)
    assert_not_equal(Currency("USD"), EUR)
    
def test_amount() raises:
    var amt1 = 100@USD
    var amt2 = Amount("USD", 100)
    var amt3 = Amount(USD, 100)
    assert_true(amt1 == amt2 == amt3)

    var amt4 = - amt2
    assert_equal(amt4, -100@USD)

def test_wallet() raises:
    var amt1 = 100@USD

    var w1 = Wallet()
    w1.deposit(amt1)
    w1.deposit(amt1)
    assert_equal(w1["USD"].value, 200)

    w1 += amt1
    assert_equal(w1[USD].value, 300)

    w1.deposit(500@EUR)
    assert_equal(w1[EUR].value, 500)
    assert_equal(len(w1), 2)

    var w2 = 100@EUR + 100@USD
    assert_equal(w2[USD].value, 100)
    assert_equal(w2[EUR].value, 100)

def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()