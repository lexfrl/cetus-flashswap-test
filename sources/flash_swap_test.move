module flash_swap_test::flash_swap_module {
    use cetus_clmm::pool::{Pool as AMMPool};
    use cetus_clmm::pool;
    use cetus_clmm::config::GlobalConfig;
    use sui::clock::Clock;
    use sui::coin::Coin;
    use sui::coin;
    use sui::balance;

    public entry fun switch_loan<CoinTypeA, CoinTypeB>(
        config: &GlobalConfig,
        pool:  &mut AMMPool<CoinTypeA, CoinTypeB>,
        mut coin_a: Coin<CoinTypeA>,
        mut coin_b: Coin<CoinTypeB>,
        a2b: bool,
        by_amount_in: bool,
        amount: u64,
        sqrt_price_limit: u128,
        clock: &Clock,
        ctx: &mut TxContext
) {
    let (receive_a, receive_b, flash_receipt) = pool::flash_swap<CoinTypeA, CoinTypeB>(
        config,
        pool,
        a2b,
        by_amount_in,
        amount,
        sqrt_price_limit,
        clock
    );
    let (in_amount, out_amount) = (
        pool::swap_pay_amount(&flash_receipt),
        if (a2b) balance::value(&receive_b) else balance::value(&receive_a)
    );

    // pay for flash swap
    let (pay_coin_a, pay_coin_b) = if (a2b) {
        (coin::into_balance(coin::split(&mut coin_a, in_amount, ctx)), balance::zero<CoinTypeB>())
    } else {
        (balance::zero<CoinTypeA>(), coin::into_balance(coin::split(&mut coin_b, in_amount, ctx)))
    };

    coin::join(&mut coin_b, coin::from_balance(receive_b, ctx));
    coin::join(&mut coin_a, coin::from_balance(receive_a, ctx));

    pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
        config,
        pool,
        pay_coin_a,
        pay_coin_b,
        flash_receipt
    );
    }
}
