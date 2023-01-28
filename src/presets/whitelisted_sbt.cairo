%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.starknet.common.syscalls import get_block_timestamp
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.math import assert_le
from cairo_contracts.src.openzeppelin.upgrades.library import Proxy
from src.uri_utils import set_uri_base, read_uri_base, append_number_ascii
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

@storage_var
func _max_timestamp() -> (max_timestamp: felt) {
}

@storage_var
func _blacklisted_whitelist(sig_x) -> (is_blacklisted: felt) {
}

@external
func initializer{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    proxy_admin,
    starknet_id_contract,
    whitelisting_key,
    max_timestamp,
    uri_base_len,
    uri_base: felt*,
) {
    Proxy.initializer(proxy_admin);
    _starknet_id_contract.write(starknet_id_contract);
    _whitelisting_key.write(whitelisting_key);
    _max_timestamp.write(max_timestamp);
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
    with_attr error_message("unfortunately your whitelist has already been used") {
        let (is_blacklisted) = _blacklisted_whitelist.read(whitelist_sig[0]);
        assert is_blacklisted = FALSE;
        _blacklisted_whitelist.write(whitelist_sig[0], TRUE);
    }

    with_attr error_message("unfortunately your whitelist is not valid") {
        verify_ecdsa_signature(message_hash, whitelisting_key, whitelist_sig[0], whitelist_sig[1]);
    }

    // assert minting is still possible
    let (current_timestamp) = get_block_timestamp();
    let (max_timestamp) = _max_timestamp.read();
    with_attr error_message("unfortunately the minting phase for this SBT is over") {
        assert_le(current_timestamp, max_timestamp);
    }

    // write sbt_id -> starknet_id mapping
    sbt_data.write(sbt_id, SBTData(starknet_id, sbt_key));
    return ();
}

@external
func sbt_transfer{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(sbt_id, starknet_id, salt, signature: (felt, felt)) {
    return _sbt_transfer(sbt_id, starknet_id, salt, signature);
}

@external
func upgrade{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    new_implementation: felt
) {
    Proxy.assert_only_admin();
    Proxy._set_implementation_hash(new_implementation);
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
