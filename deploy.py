from starknet_py.net.models.chains import StarknetChainId
from starknet_py.net.gateway_client import GatewayClient
from starknet_py.net.udc_deployer.deployer import Deployer
from starknet_py.compile.compiler import create_contract_class
from starknet_py.net import AccountClient, KeyPair
import asyncio
import json
import sys

argv = sys.argv

deployer_account_addr = (
    0x048F24D0D0618FA31813DB91A45D8BE6C50749E5E19EC699092CE29ABE809294
)
deployer_account_private_key = int(argv[1])
# MAINNET: https://alpha-mainnet.starknet.io/
# TESTNET: https://alpha4.starknet.io/
# TESTNET2: https://alpha4-2.starknet.io/
network_base_url = "https://alpha4.starknet.io/"
chainid: StarknetChainId = StarknetChainId.TESTNET
max_fee = int(1e16)
deployer = Deployer()
starknet_id = 0x783A9097B26EAE0586373B2CE0ED3529DDC44069D1E0FBC4F66D42B69D6850D
whitelisting_key = 0x1EF15C18599971B7BECED415A40F0C7DEACFD9B0D1819E03D723D8BC943CFCA
uri_base = [1, 2, 3]
contract = "./build/whitelisted_sbt.json"


async def main():
    client = GatewayClient(
        net={
            "feeder_gateway_url": network_base_url + "feeder_gateway",
            "gateway_url": network_base_url + "gateway",
        }
    )
    account: AccountClient = AccountClient(
        client=client,
        address=deployer_account_addr,
        key_pair=KeyPair.from_private_key(deployer_account_private_key),
        chain=chainid,
        supported_tx_version=1,
    )

    contract_file = open(contract, "r")
    contract_content = contract_file.read()
    contract_file.close()
    declare_contract_tx = await account.sign_declare_transaction(
        compiled_contract=contract_content, max_fee=max_fee
    )
    contract_declaration = await client.declare(transaction=declare_contract_tx)
    contract_json = json.loads(contract_content)
    abi = contract_json["abi"]
    print("contract class hash:", hex(contract_declaration.class_hash))
    deploy_call, address = deployer.create_deployment_call(
        class_hash=contract_declaration.class_hash,
        abi=abi,
        calldata={
            "starknet_id_contract": starknet_id,
            "whitelisting_key": whitelisting_key,
            "uri_base": uri_base,
        },
    )

    resp = await account.execute(deploy_call, max_fee=int(1e16))
    print("deployment txhash:", hex(resp.transaction_hash))
    print("3sbt contract address:", hex(address))


if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    loop.run_until_complete(main())
