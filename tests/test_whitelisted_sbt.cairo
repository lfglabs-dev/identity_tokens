%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starknetid.src.IStarknetID import IStarknetid
from src.interfaces import INFT, ISBT, WhitelistedISBT

@external
func __setup__() {
    %{
        from starkware.starknet.compiler.compile import get_selector_from_name
        context.starknet_id_contract = deploy_contract("./lib/starknetid/src/StarknetId.cairo").contract_address
        sbt_contract_class_hash = declare("./src/presets/whitelisted_sbt.cairo").class_hash
        context.sbt_contract = deploy_contract("./lib/cairo_contracts/src/openzeppelin/upgrades/presets/Proxy.cairo", [sbt_contract_class_hash,
            get_selector_from_name("initializer"), 8,
            456,
            context.starknet_id_contract,
            # public key of private key 1
            0x1ef15c18599971b7beced415a40f0c7deacfd9b0d1819e03d723d8bc943cfca,
            # max timestamp
            9999999999999999999999,
            3,
            0,
            1,
            2]).contract_address
    %}
    return ();
}

@external
func test_uri{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    tempvar sbt_contract;
    %{ ids.sbt_contract = context.sbt_contract %}
    let (uri_len, uri) = INFT.get_uri(sbt_contract, 1);
    assert uri_len = 4;
    assert uri[0] = 0;
    assert uri[1] = 1;
    assert uri[2] = 2;
    assert uri[3] = 49;
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
        message_hash = pedersen_hash(ids.sbt_id, ids.starknet_id)
        (ids.sbt_key_proof_0, ids.sbt_key_proof_1) = sign(message_hash, 2)
        (ids.whitelist_sig_0, ids.whitelist_sig_1)  = sign(message_hash, 1)
    %}

    let (owner) = INFT.get_inft_owner(sbt_contract, sbt_id);
    assert owner = 0;

    WhitelistedISBT.claim(
        sbt_contract,
        sbt_id,
        starknet_id,
        sbt_key,
        (sbt_key_proof_0, sbt_key_proof_1),
        (whitelist_sig_0, whitelist_sig_1),
    );

    let (owner) = INFT.get_inft_owner(sbt_contract, sbt_id);
    assert owner = starknet_id;

    return ();
}

@external
func test_transfer_sbt{syscall_ptr: felt*, range_check_ptr, pedersen_ptr: HashBuiltin*}() {
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
        message_hash = pedersen_hash( ids.sbt_id, ids.starknet_id)
        (ids.sbt_key_proof_0, ids.sbt_key_proof_1) = sign(message_hash, 2)
        (ids.whitelist_sig_0, ids.whitelist_sig_1)  = sign(message_hash, 1)
    %}

    let (owner) = INFT.get_inft_owner(sbt_contract, sbt_id);
    assert owner = 0;

    WhitelistedISBT.claim(
        sbt_contract,
        sbt_id,
        starknet_id,
        sbt_key,
        (sbt_key_proof_0, sbt_key_proof_1),
        (whitelist_sig_0, whitelist_sig_1),
    );

    let (owner) = INFT.get_inft_owner(sbt_contract, sbt_id);
    assert owner = starknet_id;

    tempvar transfer_sig_0;
    tempvar transfer_sig_1;
    %{
        from starkware.crypto.signature.fast_pedersen_hash import pedersen_hash
        from starkware.crypto.signature.signature import sign
        message_hash = pedersen_hash(pedersen_hash(ids.sbt_id, 2), 12345)
        (ids.transfer_sig_0, ids.transfer_sig_1) = sign(message_hash, 2)
    %}
    ISBT.sbt_transfer(
        sbt_contract, sbt_id, starknet_id=2, salt=12345, signature=(transfer_sig_0, transfer_sig_1)
    );

    let (owner) = INFT.get_inft_owner(sbt_contract, sbt_id);
    assert owner = 2;

    return ();
}
