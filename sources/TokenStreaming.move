module TokenStreaming::Streaming {

    use std::signer;

    use aptos_framework::coin;

    const EINVALID_TIME: u64 = 0;
    const ELOW_BALANCE: u64 = 1;
    const EALREADY_EXISTS: u64 = 2;

    struct StreamInfo<phantom CoinType> has key {
        start_time: u64,
        end_time: u64,
        withdraw_amount: u64,
        receiver: address,
        amount_per_second: u64,
        coin_store: coin::Coin<CoinType>
    }

    public entry fun start_streaming<CoinType>(sender: &signer, receiver: address, start_time: u64, end_time: u64, amount_per_second: u64) {
        let sender_address = signer::address_of(sender);

        assert!(start_time < end_time, EINVALID_TIME);
        let amount_to_withdraw = (end_time - start_time)*amount_per_second;
        assert!(coin::balance<CoinType>(sender_address) >= amount_to_withdraw, ELOW_BALANCE);

        let coins = coin::withdraw<CoinType>(sender, amount_to_withdraw);

        assert!(exists<StreamInfo<CoinType>>(sender_address), EALREADY_EXISTS);

        move_to<StreamInfo<CoinType>>(sender, StreamInfo{start_time: start_time, end_time: end_time, withdraw_amount: 0, receiver: receiver, amount_per_second: amount_per_second, coin_store: coins});

    }

}