from std.testing import assert_equal, assert_true, assert_not_equal, assert_almost_equal, TestSuite
from roboquant.money import Amount, Wallet, USD, EUR, Currency
from roboquant.time import Timestamp, TIME_MIN


def test_currency() raises:
    assert_equal(Currency("USD"), USD)
    assert_not_equal(Currency("USD"), EUR)
    
def test_amount() raises:
    var amt1 = 100@USD
    var amt2 = Amount("USD", 100)
    var amt3 = Amount(USD, 100)
    assert_true(amt1 == amt2 == amt3)

def test_wallet() raises:
    var amt1 = 100@USD

    var w1 = Wallet()
    w1.deposit(amt1)
    w1.deposit(amt1)
    assert_equal(w1["USD"], 200)

    w1 += amt1
    assert_equal(w1[USD], 300)

    w1.deposit(500@EUR)
    assert_equal(w1[EUR], 500)

    assert_equal(len(w1), 2)

def test_conversion() raises:
    var amt1 = 100@USD
    var amt2 = amt1.convert_to("USD", TIME_MIN)
    assert_equal(amt1, amt2)

    var amt_eur = amt1.convert_to(EUR, TIME_MIN)
    assert_almost_equal(amt1.value, amt_eur.value * 1.1)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()