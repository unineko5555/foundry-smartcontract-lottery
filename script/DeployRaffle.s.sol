// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/Interactions.s.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract DeployRaffle is Script {
    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        // local -> deploy mocks, get local config
        // sepolia -> get sepolia config
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        //Subscriptionの作成と、FundSubscriptionを行う
        if (config.subscriptionId == 0) {
            // Create subscription
            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId, config.vrfCoordinator) =
                createSubscription.createSubscription(config.vrfCoordinator, config.account);

            // Fund it!
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(config.vrfCoordinator, config.subscriptionId, config.linkToken, config.account);
            // helperConfig.setConfig(block.chainid, config); /** githubにはあるが動画にはないのでコメントアウト */
        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit
        );
        vm.stopBroadcast();
        //ここでconsumerを追加する
        AddConsumer addConsumer = new AddConsumer();
        //  don't need to broadcast because すでにInteractionsでfunction addConsumerはvm.broadcastしている
        addConsumer.addConsumer(address(raffle), config.vrfCoordinator, config.subscriptionId, config.account);
        return (raffle, helperConfig);
    }

    // function run() external returns (Raffle, HelperConfig) {
    //     HelperConfig helperConfig = new HelperConfig();
    //     (
    //     uint256 entranceFee,
    //     uint256 interval,
    //     address vrfCoordinator,
    //     bytes32 gasLane,
    //     uint64 subscriptionId,
    //     uint32 callbackGasLimit
    //     ) = helperConfig.activeNetworkConfig();

    //     vm.startBroadcast();
    //     Raffle raffle = new Raffle(
    //         entranceFee,
    //         interval,
    //         vrfCoordinator,
    //         gasLane,
    //         subscriptionId,
    //         callbackGasLimit
    //     );
    //     vm.stopBroadcast();

    //     return (raffle, helperConfig);

    // }
}
