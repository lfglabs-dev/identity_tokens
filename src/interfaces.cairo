%lang starknet

@contract_interface
namespace INFT {
    // returns a json url describing how the token should be displayed
    func get_uri(sbt_id) -> (uri_len: felt, uri: felt*) {
    }

    // returns the starknet_id owner of the token
    func get_inft_owner(sbt_id) -> (starknet_id: felt) {
    }
}

@contract_interface
namespace ISBT {
    // returns the key capable of changing the inft owner
    func get_sbt_key(sbt_id) -> (public_key: felt) {
    }

    // transfers the sbt to a new starknet_id
    func sbt_transfer(sbt_id, starknet_id, salt, signature: (felt, felt)) {
    }
}

@contract_interface
namespace IWhitelistedSBT {
    // mints a sbt from a signature
    func claim(
        sbt_id, starknet_id, sbt_key, sbt_key_proof: (felt, felt), whitelist_sig: (felt, felt)
    ) {
    }
}
