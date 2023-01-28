from starkware.starknet.compiler.compile import get_selector_from_name
from starkware.crypto.signature.signature import private_to_stark_key
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.net.udc_deployer.deployer import Deployer
from starknet_py.net import AccountClient, KeyPair
from starknet_py.net.gateway_client import GatewayClient
from hashlib import sha256
import asyncio
import json
import sys

argv = sys.argv

deployer_account_addr = (
    0x048F24D0D0618FA31813DB91A45D8BE6C50749E5E19EC699092CE29ABE809294
)
deployer_account_private_key = int(argv[1])
admin = 0x048F24D0D0618FA31813DB91A45D8BE6C50749E5E19EC699092CE29ABE809294
# MAINNET: https://alpha-mainnet.starknet.io/
# TESTNET: https://alpha4.starknet.io/
# TESTNET2: https://alpha4-2.starknet.io/
network_base_url = "https://alpha-mainnet.starknet.io/"
chainid: StarknetChainId = StarknetChainId.MAINNET
max_fee = int(1e16)
deployer = Deployer()
starknet_id = 0x05DBDEDC203E92749E2E746E2D40A768D966BD243DF04A6B712E222BC040A9AF
password = argv[2]
whitelisting_key = int.from_bytes(sha256(password.encode("utf-8")).digest(), "big") % (
    3618502788666131213697322783095070105526743751716087489154079457884512865583
)
pub_whitelisting_key = private_to_stark_key(whitelisting_key)
# valid for 30 days
max_timestamp = 1675900800
uri_base = list(
    map(ord, "ipfs://bafkreifh2rr5a2ocgfas2b2voqmzl7uq4yws7nyz6x52x7ndoigbgn4uny?id=")
)
impl = "./build/whitelisted_sbt.json"


async def main():
    client: GatewayClient = GatewayClient(
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
    impl_file = open("./build/whitelisted_sbt.json", "r")
    declare_contract_tx = await account.sign_declare_transaction(
        compiled_contract=impl_file.read(), max_fee=max_fee
    )
    impl_file.close()
    impl_declaration = await client.declare(transaction=declare_contract_tx)
    impl_contract_class_hash = impl_declaration.class_hash
    print("implementation class hash:", hex(impl_contract_class_hash))

    proxy_file = open("./build/proxy.json", "r")
    proxy_content = proxy_file.read()

    declare_contract_tx = await account.sign_declare_transaction(
        compiled_contract=proxy_content, max_fee=max_fee
    )
    proxy_file.close()
    proxy_declaration = await client.declare(transaction=declare_contract_tx)
    proxy_contract_class_hash = proxy_declaration.class_hash
    print("proxy class hash:", hex(proxy_contract_class_hash))

    proxy_json = json.loads(proxy_content)
    abi = proxy_json["abi"]

    calldata = [admin, starknet_id, pub_whitelisting_key, max_timestamp, len(uri_base)]
    for char in uri_base:
        calldata.append(char)

    deploy_call, address = deployer.create_deployment_call(
        class_hash=proxy_contract_class_hash,
        abi=abi,
        calldata={
            "implementation_hash": impl_contract_class_hash,
            "selector": get_selector_from_name("initializer"),
            "calldata": calldata,
        },
    )

    resp = await account.execute(deploy_call, max_fee=int(1e16))
    print("deployment txhash:", hex(resp.transaction_hash))
    print("proxied contract address:", hex(address))


if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    loop.run_until_complete(main())
