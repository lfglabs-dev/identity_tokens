from starkware.starknet.compiler.compile import get_selector_from_name
from starknet_py.net.models.chains import StarknetChainId
from starknet_py.net.udc_deployer.deployer import Deployer
from starknet_py.net import AccountClient, KeyPair
from starknet_py.net.gateway_client import GatewayClient
import asyncio
import sys

argv = sys.argv

deployer_account_addr = (
    0x048F24D0D0618FA31813DB91A45D8BE6C50749E5E19EC699092CE29ABE809294
)
deployer_account_private_key = int(argv[1])
# MAINNET: https://alpha-mainnet.starknet.io/
# TESTNET: https://alpha4.starknet.io/
# TESTNET2: https://alpha4-2.starknet.io/
network_base_url = "https://alpha-mainnet.starknet.io/"
chainid: StarknetChainId = StarknetChainId.MAINNET
max_fee = int(1e16)
# deployer_address=0x041A78E741E5AF2FEC34B695679BC6891742439F7AFB8484ECD7766661AD02BF
deployer = Deployer()


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
    print("declaration tx hash:", hex(impl_declaration.transaction_hash))
    print("implementation class hash:", hex(impl_contract_class_hash))


if __name__ == "__main__":
    loop = asyncio.get_event_loop()
    loop.run_until_complete(main())
