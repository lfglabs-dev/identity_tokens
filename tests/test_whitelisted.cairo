%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starknetid.src.IStarknetID import IStarknetid
from src.interfaces import ISBT, IWhitelistedSBT

@external
func __setup__() {
    %{
        context.starknet_id_contract = deploy_contract("./lib/starknetid/src/StarknetId.cairo").contract_address
        context.sbt_contract = deploy_contract("./src/presets/whitelisted.cairo",
                [
                    context.starknet_id_contract,
                    # public key of private key 1
                    0x1ef15c18599971b7beced415a40f0c7deacfd9b0d1819e03d723d8bc943cfca,
                    3,
                    0,
                    1,
                    2
                ]
            ).contract_address
    %}
    return ();
}

@external
func test_claim_sbt{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
    tempvar starknet_id_contract;
    tempvar sbt_contract;
    %{
        ids.starknet_id_contract = context.starknet_id_contract
        ids.sbt_contract = context.sbt_contract
    %}

    tempvar starknet_id = 1;
    tempvar sbt_id = 1;
    // public key of private key 2
    tempvar sbt_key = 0x759ca09377679ecd535a81e83039658bf40959283187c654c5416f439403cf5;

    IStarknetid.mint(starknet_id_contract, starknet_id);

    tempvar sbt_key_proof_0;
    tempvar sbt_key_proof_1;
    tempvar whitelist_sig_0;
    tempvar whitelist_sig_1;
    %{
        from starkware.crypto.signature.fast_pedersen_hash import pedersen_hash
        from starkware.crypto.signature.signature import sign
        message_hash = pedersen_hash(ids.starknet_id, ids.sbt_id)
        (ids.sbt_key_proof_0, ids.sbt_key_proof_1) = sign(message_hash, 2)
        (ids.whitelist_sig_0, ids.whitelist_sig_1)  = sign(message_hash, 1)
    %}

    let (owner) = ISBT.get_sbt_owner(sbt_contract, sbt_id);
    assert owner = 0;

    IWhitelistedSBT.claim(
        sbt_contract,
        starknet_id,
        sbt_id,
        sbt_key,
        (sbt_key_proof_0, sbt_key_proof_1),
        (whitelist_sig_0, whitelist_sig_1),
    );

    let (owner) = ISBT.get_sbt_owner(sbt_contract, sbt_id);
    assert owner = starknet_id;

    return ();
}
