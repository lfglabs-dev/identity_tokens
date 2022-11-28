// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts for Cairo v0.4.0 (token/erc721/presets/ERC721MintableBurnable.cairo)

%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.uint256 import Uint256
from starkware.starknet.common.syscalls import get_caller_address, get_block_timestamp

from cairo_contracts.src.openzeppelin.introspection.erc165.library import ERC165
from cairo_contracts.src.openzeppelin.token.erc721.library import ERC721

from starknetid.src.IStarknetID import IStarknetid
from src.library import Soulbound, IssuanceControler, issuance_controler

@event
func Transfer(from_: felt, to: felt, tokenId: Uint256) {
}

//
// Constructor
//

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    name, symbol, owner, merkle_root, max_claim_date
) {
    ERC721.initializer(name, symbol);
    issuance_controler.write(IssuanceControler(merkle_root, max_claim_date));
    return ();
}

//
// Getters
//

@view
func supportsInterface{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    interfaceId: felt
) -> (success: felt) {
    return ERC165.supports_interface(interfaceId);
}

@view
func name{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (name: felt) {
    return ERC721.name();
}

@view
func symbol{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() -> (symbol: felt) {
    return ERC721.symbol();
}

@view
func ownerOf{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(tokenId: Uint256) -> (
    owner: felt
) {
    let (starknet_id) = Soulbound.get_sbt_owner(tokenId.low);
    return IStarknetid.owner_of('0x', starknet_id);
}

@view
func tokenURI{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    tokenId: Uint256
) -> (tokenURI_len: felt, tokenURI: felt*) {
    alloc_locals;

    let (array) = alloc();

    assert array[0] = 104;
    assert array[1] = 116;
    assert array[2] = 116;
    assert array[3] = 112;
    assert array[4] = 115;

    return (5, array);
}

//
// Externals
//

@external
func claim{
    syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, ecdsa_ptr: SignatureBuiltin*
}(sbt_id, public_key, merkle_proof_len: felt, merkle_proof: felt*) {
    // todo: ask proof of ownership of private key
    // warning: sbt_it must be < 2**128, be careful when generating the merkle tree

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

    data.write(SSSBTData(token_data.starknet_id, public_key));
    let (caller) = get_caller_address();
    Transfer.emit(0, caller, sbt_id);

    return ();
}
