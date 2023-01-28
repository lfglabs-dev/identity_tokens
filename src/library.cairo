%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.hash import hash2
from starknetid.src.IStarknetID import IStarknetid

struct SBTData {
    starknet_id: felt,
    sbt_key: felt,
}

@storage_var
func _starknet_id_contract() -> (starknet_id_contract: felt) {
}

@storage_var
func sbt_data(sbt_id) -> (data: SBTData) {
}

@storage_var
func blacklisted_salt(salt) -> (blacklisted: felt) {
}

@event
func sbt_transfer(sbt, source, target) {
}

func assert_claimable{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(sbt_id, starknet_id, sbt_key, sbt_key_proof: (felt, felt)) -> (message_hash: felt) {

    // assert sbt_id was not already minted
    let (data) = sbt_data.read(sbt_id);
    assert data.sbt_key = 0;

    // assert starknet_id belongs to caller
    let (caller) = get_caller_address();
    let (starknet_id_contract) = _starknet_id_contract.read();
    let (owner) = IStarknetid.owner_of(starknet_id_contract, starknet_id);
    assert caller = owner;

    // assert sbt_key_proof is a signature of hash(starknet_id, sbt_id)
    let (message_hash) = hash2{hash_ptr=pedersen_ptr}(sbt_id, starknet_id);
    verify_ecdsa_signature(message_hash, sbt_key, sbt_key_proof[0], sbt_key_proof[1]);

    sbt_transfer.emit(sbt_id, 0, starknet_id);

    return (message_hash,);
}

func _sbt_transfer{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(sbt_id, starknet_id, salt, signature: (felt, felt)) {
    alloc_locals;
    with_attr error_message("Blacklisted salt") {
        let (is_blacklisted) = blacklisted_salt.read(salt);
        assert is_blacklisted = FALSE;
    }

    let (data) = sbt_data.read(sbt_id);
    with_attr error_message("Invalid signature") {
        let (message_hash) = hash2{hash_ptr=pedersen_ptr}(sbt_id, starknet_id);
        let (message_hash) = hash2{hash_ptr=pedersen_ptr}(message_hash, salt);
        verify_ecdsa_signature(message_hash, data.sbt_key, signature[0], signature[1]);
    }

    blacklisted_salt.write(salt, TRUE);
    sbt_transfer.emit(sbt_id, data.starknet_id, starknet_id);
    sbt_data.write(sbt_id, SBTData(starknet_id, data.sbt_key));
    return ();
}
