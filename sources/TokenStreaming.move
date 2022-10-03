module TokenStreaming::Streaming {

    use std::signer;

    public entry fun start_streaming(sender: &signer) {
        let _address = signer::address_of(sender);
    }

}