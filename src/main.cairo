%lang starknet
from starkware.cairo.common.math import assert_nn
from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.signature import verify_ecdsa_signature

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    return ();
}

struct SSSBTData {
    token_id: Uint256,
    public_key: felt,
}

@storage_var
func data(sbt_id) -> (data: SSSBTData) {
}

@view
func get_public_key{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(sbt_id) -> (
    public_key: felt
) {
    let (token_data) = data.read(sbt_id);
    return (token_data.public_key);
}

@view
func get_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(sbt_id) -> (
    token_id: Uint256
) {
    let (token_data) = data.read(sbt_id);
    return (token_data.token_id);
}

@external
func transfer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    sbt_id, token_id: Uint256, salt, signature: (felt, felt)
) {
    let (token_data) = data.read(sbt_id);
    with_attr error_message("Amount must be positive. Got: {amount}.") {
        let (message_hash) = hash2{hash_ptr=pedersen_ptr}(sbt_id, token_id.low);
        let (message_hash) = hash2{hash_ptr=pedersen_ptr}(message_hash, token_id.high);
        let (message_hash) = hash2{hash_ptr=pedersen_ptr}(message_hash, salt);
        verify_ecdsa_signature(message_hash, token_data.public_key, signature[0], signature[1]);
    }
    // todo: blacklist salt

    return ();
}
