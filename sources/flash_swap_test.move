module flash_swap_test::flash_swap_module {
    use cetus_clmm::pool::{Pool as AMMPool};
    use cetus_clmm::pool;
    use cetus_clmm::config::GlobalConfig;
    use sui::clock::Clock;
    use sui::coin::Coin;
    use sui::coin;
    use sui::balance;

    const SQRT_PRICE_LIMIT_A2B: u128 = 4295048016;
    const SQRT_PRICE_LIMIT_B2A: u128 = 79226673515401279992447579055;

    entry public fun swap<CoinTypeA, CoinTypeB>(
        coin_a: Coin<CoinTypeA>,
        amount: u64,
        a2b: bool,
        by_amount_in: bool,
        pool:  &mut AMMPool<CoinTypeA, CoinTypeB>,
        config: &GlobalConfig,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let sqrt_price_limit = if (a2b) { SQRT_PRICE_LIMIT_A2B } else {SQRT_PRICE_LIMIT_B2A};
        let (coin_a_out, coit_b_out) = do_swap(coin_a, coin::zero(ctx), amount, a2b, by_amount_in, sqrt_price_limit, pool, config, clock, ctx);
        sui::transfer::public_transfer(coin_a_out, ctx.sender());
        sui::transfer::public_transfer(coit_b_out, ctx.sender());
    }

    public fun do_swap<CoinTypeA, CoinTypeB>(
        mut coin_a: Coin<CoinTypeA>,
        mut coin_b: Coin<CoinTypeB>,
        amount: u64,
        a2b: bool,
        by_amount_in: bool,
        sqrt_price_limit: u128,
        pool:  &mut AMMPool<CoinTypeA, CoinTypeB>,
        config: &GlobalConfig,
        clock: &Clock,
        ctx: &mut TxContext
): (Coin<CoinTypeA>, Coin<CoinTypeB>) {
        let (receive_a, receive_b, flash_receipt) = pool::flash_swap<CoinTypeA, CoinTypeB>(
            config,
            pool,
            a2b,
            by_amount_in,
            amount,
            sqrt_price_limit,
            clock
        );
        let in_amount = pool::swap_pay_amount(&flash_receipt);

        let (pay_coin_a, pay_coin_b) = if (a2b) {
            (coin::into_balance(coin::split(&mut coin_a, in_amount, ctx)), balance::zero<CoinTypeB>())
        } else {
            (balance::zero<CoinTypeA>(), coin::into_balance(coin::split(&mut coin_b, in_amount, ctx)))
        };

        coin::join(&mut coin_a, coin::from_balance(receive_a, ctx));
        coin::join(&mut coin_b, coin::from_balance(receive_b, ctx));
        
        pool::repay_flash_swap<CoinTypeA, CoinTypeB>(
            config,
            pool,
            pay_coin_a,
            pay_coin_b,
            flash_receipt
        );
        (coin_a, coin_b)
    }
}
