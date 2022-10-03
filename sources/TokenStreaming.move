module TokenStreaming::Streaming {

    use std::signer;

    use aptos_framework::coin;
    use aptos_framework::aptos_account;
    use aptos_framework::managed_coin;


    const EINVALID_TIME: u64 = 0;
    const ELOW_BALANCE: u64 = 1;
    const EALREADY_EXISTS: u64 = 2;
    const EINVALID_BALANCE: u64 = 3;
    const EINVALID_RECEIVER: u64 = 4;

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

        assert!(!exists<StreamInfo<CoinType>>(sender_address), EALREADY_EXISTS);

        move_to<StreamInfo<CoinType>>(sender, StreamInfo{start_time: start_time, end_time: end_time, withdraw_amount: 0, receiver: receiver, amount_per_second: amount_per_second, coin_store: coins});

    }

    public entry fun withdraw_from_stream<CoinType>(withdrawer: &signer, sender: address, current_time: u64) acquires StreamInfo {

        let withdraw_addr = signer::address_of(withdrawer);

        let stream_info = borrow_global_mut<StreamInfo<CoinType>>(sender);
        assert!(stream_info.receiver == withdraw_addr, EINVALID_RECEIVER);

        let amount_to_withdraw = ((current_time - stream_info.start_time)*stream_info.amount_per_second) - stream_info.withdraw_amount; 

        let coin = coin::extract(&mut stream_info.coin_store, amount_to_withdraw);
        coin::deposit<CoinType>(withdraw_addr, coin);

        stream_info.withdraw_amount = stream_info.withdraw_amount + amount_to_withdraw;

    }

    #[test_only]
    struct FakeCoin {}

    #[test_only]
    public fun initialize_coin_and_mint(admin: &signer, user: &signer, mint_amount: u64) {
        let user_addr = signer::address_of(user);
        managed_coin::initialize<FakeCoin>(admin, b"fake", b"F", 9, false);
        aptos_account::create_account(user_addr);
        managed_coin::register<FakeCoin>(user);
        managed_coin::mint<FakeCoin>(admin, user_addr, mint_amount); 
    }

    #[test(sender = @0x2, receiver = @0x3, module_owner = @TokenStreaming)]
    public fun can_stream(sender: signer, receiver: signer, module_owner: signer) acquires StreamInfo {

        let sender_addr = signer::address_of(&sender);
        let receiver_addr = signer::address_of(&receiver);

        let initial_mint_amount = 10000;

        let start_time = 1000;
        let end_time = 1200; 
        let amount_per_second = 20;

        let deposit_amount = (end_time - start_time)*amount_per_second;

        initialize_coin_and_mint(&module_owner, &sender, initial_mint_amount);
        assert!(coin::balance<FakeCoin>(sender_addr) == initial_mint_amount, EINVALID_BALANCE);

        start_streaming<FakeCoin>(&sender, receiver_addr, start_time, end_time, amount_per_second);
        assert!(coin::balance<FakeCoin>(sender_addr) == initial_mint_amount - deposit_amount, EINVALID_BALANCE);        

        let current_time = 1100;

        aptos_account::create_account(receiver_addr);
        managed_coin::register<FakeCoin>(&receiver);
        withdraw_from_stream<FakeCoin>(&receiver, sender_addr, current_time);

        let withdraw_amount = (current_time - start_time)*amount_per_second;
        assert!(coin::balance<FakeCoin>(receiver_addr) == withdraw_amount, EINVALID_BALANCE);

    }

}