%lang starknet

@contract_interface
namespace ISBT {
    // this one is optional for Soulbound property
    func get_uri(sbt_id) -> (uri_len: felt, uri: felt*) {
    }

    // those are required
    func get_sbt_key(sbt_id) -> (public_key: felt) {
    }

    func get_sbt_owner(sbt_id) -> (starknet_id: felt) {
    }

    func sbt_transfer(sbt_id, starknet_id, salt, signature: (felt, felt)) {
    }
}

@contract_interface
namespace IWhitelistedSBT {
    func claim(
        sbt_id, starknet_id, sbt_key, sbt_key_proof: (felt, felt), whitelist_sig: (felt, felt)
    ) {
    }
}
