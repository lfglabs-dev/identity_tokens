%lang starknet
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace SSSBT {
    func get_sbt_key(sbt_id) -> (public_key: felt) {
    }

    func get_sbt_owner(sbt_id) -> (starknet_id: felt) {
    }

    func sbt_transfer(sbt_id, starknet_id, salt, signature: (felt, felt)) {
    }
}
