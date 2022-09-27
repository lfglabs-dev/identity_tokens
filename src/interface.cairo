%lang starknet
from starkware.cairo.common.uint256 import Uint256

@contract_interface
namespace SSSBT {
    func get_public_key(sbt_id) -> (public_key: felt) {
    }

    func get_owner(sbt_id) -> (token_id: Uint256) {
    }

    func transfer(sbt_id, token_id: Uint256, salt, signature: (felt, felt)) {
    }
}
