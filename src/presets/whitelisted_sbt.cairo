%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from src.uri_utils import set_uri_base, read_uri_base, append_number_ascii
from starkware.cairo.common.signature import verify_ecdsa_signature
from src.library import (
    SBTData,
    _starknet_id_contract,
    sbt_data,
    assert_claimable,
    blacklisted_salt,
    _sbt_transfer,
)

@storage_var
func _whitelisting_key() -> (whitelisting_key: felt) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    starknet_id_contract, whitelisting_key, uri_base_len, uri_base: felt*
) {
    _starknet_id_contract.write(starknet_id_contract);
    _whitelisting_key.write(whitelisting_key);
    set_uri_base(uri_base_len, uri_base);
    return ();
}

@external
func claim{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(sbt_id, starknet_id, sbt_key, sbt_key_proof: (felt, felt), whitelist_sig: (felt, felt)) {
    // message_hash = hash(starknet_id, sbt_id)
    let (message_hash) = assert_claimable(sbt_id, starknet_id, sbt_key, sbt_key_proof);

    // assert sbt_id is whitelisted for this starknet_id (otherwise MEV possible)
    let (whitelisting_key) = _whitelisting_key.read();
    verify_ecdsa_signature(message_hash, whitelisting_key, whitelist_sig[0], whitelist_sig[1]);

    // write sbt_id -> starknet_id mapping
    sbt_data.write(sbt_id, SBTData(starknet_id, sbt_key));
    return ();
}

@view
func get_uri{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(sbt_id) -> (
    uri_len: felt, uri: felt*
) {
    alloc_locals;
    let (arr_len, arr) = read_uri_base(0);
    let (size) = append_number_ascii(sbt_id, arr + arr_len);
    return (arr_len + size, arr);
}

@view
func get_sbt_key{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(sbt_id) -> (
    public_key: felt
) {
    let (data) = sbt_data.read(sbt_id);
    return (data.sbt_key,);
}

@view
func get_inft_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(sbt_id) -> (
    starknet_id: felt
) {
    let (data) = sbt_data.read(sbt_id);
    return (data.starknet_id,);
}

@external
func sbt_transfer{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(sbt_id, starknet_id, salt, signature: (felt, felt)) {
    return _sbt_transfer(sbt_id, starknet_id, salt, signature);
}
