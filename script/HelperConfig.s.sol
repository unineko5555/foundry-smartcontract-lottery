// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {CreateSubscription} from "./Interactions.s.sol";

abstract contract CodeConstants {
    /** VRF Mock Values */
    uint96 public MOCK_BASE_FEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_LINK = 1e9;
    // LINK / ETH price 
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is CodeConstants, Script {

    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
        address linkToken; //anvilにはlinkがないので、linkを追加
        address account; //追加の理由不明、40 --fork-urlが〜
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
    }

    function getConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];  //sepolia、事前に設定されたconfigを返す
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns(NetworkConfig memory) { /** view追加 */
        return getConfigByChainId(block.chainid); /** chainIdでなくchainid */
    }

    function getSepoliaEthConfig() public pure returns (NetworkConfig memory) 
    {
        return NetworkConfig({  /** NetworkConfigのインスタンスを返す */
            entranceFee: 0.01 ether, //1e16
            interval: 30, // 30 seconds
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000, //500,000 gas
            subscriptionId: 105430411853989173522216311743659453206426700180708717357013772925073966068140,
            linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0xCd77572F2301b68B8340cb447bB2D233439EAC1C //追加の理由不明、40 --fork-urlが~
            });
    }

    // function getLocalConfig() public pure returns (NetworkConfig memory) {
    //     return NetworkConfig({
    //         entranceFee: 0.01 ether,
    //         interval: 30, // 30 seconds
    //         vrfCoordinator: address(0),
    //         gasLane: "",
    //         callbackGasLimit: 500000,
    //         subscriptionId: 0
    //     });
    // }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory)
    {   
        // check to see if we set an active network config
        //すでに設定されたlocalNetworkConfigがあればそれを返す、むだなgasを使わない
        if(localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // Deploy mocks and such
        // uint96 baseFee = 0.25 ether; // To be understood as 0.25 LINK /** Warningが出るのでコメントアウト */
        // uint96 gasPriceLink = 1e9; // 1 gwei LINK

        vm.startBroadcast(); //localnetworkで動くからaccountは追加しない？よくわからない
        VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE_LINK,
            MOCK_WEI_PER_UINT_LINK
        );
        LinkToken linkToken = new LinkToken();
        uint256 subScriptionId = vrfCoordinatorMock.createSubscription();
        vm.stopBroadcast();  //localnetworkで動くからaccountは追加しない？よくわからない

        // CreateSubscription createSubscription = new CreateSubscription(); //HelperConffigとInteractionsactionsで循環参照エラーが生じるから削除
        // (uint256 newSubId, address updatedVrfCoordinator) = CreateSubscription(address(this)).createSubscriptionUsingConfig(); //newでなくstatic callにする
        
        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30, // 30 seconds
            vrfCoordinator: address(vrfCoordinatorMock),
            // doesn't matter
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            // subscriptionId: 110566495778243031254559780308907084962620741641434846954171779041067183519557, //subscriptionId=0ではanvilでエラーがでる。d If left as 0, our scripts will create one!
            // subscriptionId: 105430411853989173522216311743659453206426700180708717357013772925073966068140,
            // subscriptionId: 0, //なぜ0でしかtestがpassしないのか?addConsumer()がスキップされるから?
            subscriptionId: subScriptionId,
            callbackGasLimit: 500000, // might have to fix this
            linkToken: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });
        return localNetworkConfig;
    }
}
