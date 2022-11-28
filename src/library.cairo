%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.small_merkle_tree import small_merkle_tree_update
from starkware.cairo.common.math import assert_le_felt
from starkware.cairo.common.bool import TRUE, FALSE
from starkware.cairo.common.hash import hash2

struct SSSBTData {
    starknet_id: felt,
    sbt_key: felt,
}

struct IssuanceControler {
    merkle_root: felt,
    max_claim_date: felt,
}

@storage_var
func data(sbt_id) -> (data: SSSBTData) {
}

@storage_var
func blacklisted(salt) -> (blacklisted: felt) {
}

@storage_var
func issuance_controler() -> (data: IssuanceControler) {
}

@event
func sssbt_transfer(source: felt, target: felt, sbt) {
}

namespace Soulbound {
    func get_sbt_key{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(sbt_id) -> (
        public_key: felt
    ) {
        let (token_data) = data.read(sbt_id);
        return (public_key=token_data.sbt_key);
    }

    func get_sbt_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(sbt_id) -> (
        starknet_id: felt
    ) {
        let (token_data) = data.read(sbt_id);
        return (starknet_id=token_data.starknet_id);
    }

    func sbt_transfer{
        syscall_ptr: felt*,
        pedersen_ptr: HashBuiltin*,
        range_check_ptr,
        ecdsa_ptr: SignatureBuiltin*,
    }(sbt_id, starknet_id: felt, salt, signature: (felt, felt)) {
        let (token_data) = data.read(sbt_id);
        with_attr error_message("Blacklisted salt") {
            let (is_blacklisted) = blacklisted.read(salt);
            assert is_blacklisted = FALSE;
        }

        with_attr error_message("Invalid signature") {
            let (message_hash) = hash2{hash_ptr=pedersen_ptr}(sbt_id, starknet_id);
            let (message_hash) = hash2{hash_ptr=pedersen_ptr}(message_hash, salt);
            verify_ecdsa_signature(message_hash, token_data.public_key, signature[0], signature[1]);
        }

        blacklisted.write(salt, TRUE);
        sssbt_transfer.emit(token_data.starknet_id, starknet_id, sbt_id);
        data.write(sbt_id, SSSBTData(starknet_id, token_data.public_key));

        return ();
    }
}
