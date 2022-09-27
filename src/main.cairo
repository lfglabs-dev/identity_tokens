%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.small_merkle_tree import small_merkle_tree_update
from starkware.cairo.common.math import assert_le_felt
from src.utils.merkle_tree import assert_merkle_proof
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.hash import hash2

struct SSSBTData {
    token_id: Uint256,
    public_key: felt,
}

@storage_var
func data(sbt_id) -> (data: SSSBTData) {
}

@storage_var
func blacklisted(salt) -> (blacklisted: felt) {
}

struct IssuanceControler {
    merkle_root: felt,
    max_claim_date: felt,
}

@storage_var
func issuance_controler() -> (data: IssuanceControler) {
}

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    merkle_root, max_claim_date
) {
    issuance_controler.write(IssuanceControler(merkle_root, max_claim_date));
    return ();
}

@event
func sssbt_transfer(source: Uint256, target: Uint256, sbt) {
}

@view
func get_public_key{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(sbt_id) -> (
    public_key: felt
) {
    let (token_data) = data.read(sbt_id);
    return (public_key=token_data.public_key);
}

@view
func get_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(sbt_id) -> (
    token_id: Uint256
) {
    let (token_data) = data.read(sbt_id);
    return (token_id=token_data.token_id);
}

@external
func transfer{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(sbt_id, token_id: Uint256, salt, signature: (felt, felt)) {
    let (token_data) = data.read(sbt_id);
    with_attr error_message("Blacklisted salt") {
        let (is_blacklisted) = blacklisted.read(salt);
        assert is_blacklisted = FALSE;
    }

    with_attr error_message("Invalid signature") {
        let (message_hash) = hash2{hash_ptr=pedersen_ptr}(sbt_id, token_id.low);
        let (message_hash) = hash2{hash_ptr=pedersen_ptr}(message_hash, token_id.high);
        let (message_hash) = hash2{hash_ptr=pedersen_ptr}(message_hash, salt);
        verify_ecdsa_signature(message_hash, token_data.public_key, signature[0], signature[1]);
    }

    blacklisted.write(salt, TRUE);
    sssbt_transfer.emit(token_data.token_id, token_id, sbt_id);
    data.write(sbt_id, SSSBTData(token_id, token_data.public_key));

    return ();
}

@external
func claim{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(sbt_id, public_key, merkle_proof_len: felt, merkle_proof: felt*) {
    // todo: ask proof of ownership of public_key

    let (issuance_data) = issuance_controler.read();
    with_attr error_message("Merkle root is invalid") {
        tempvar merkle_branch_len = merkle_proof_len - 1;
        // assert merkle_proof_len = n; <- could be used to limit mint to 2^n
        assert_merkle_proof(
            issuance_data.merkle_root,
            merkle_proof[merkle_branch_len],
            merkle_branch_len,
            merkle_proof,
        );
    }

    with_attr error_message("Max mint date reached") {
        let (timestamp) = get_block_timestamp();
        assert_le_felt(timestamp, issuance_data.max_claim_date);
    }

    let (token_data) = data.read(sbt_id);

    with_attr error_message("SBT already minted") {
        assert token_data.public_key = 0;
    }

    data.write(SSSBTData(token_data.token_id, public_key));

    return ();
}
