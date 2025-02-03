// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../mocks/LinkToken.sol";

contract RaffleTest is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    address linkToken;
    /**
     * uint64ではエラーが出た
     */
    uint32 callbackGasLimit;
    address public PLAYER = makeAddr("player");
    /**
     * foundry用仮想アドレス生成
     */
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.deployContract();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasLane = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        // linkToken = LinkToken(config.linkToken); //linkTokenはアドレスなので、LinkTokenのインスタンスを生成する必要はない
        linkToken = config.linkToken;

        // (
        //     entranceFee,
        //     interval,
        //     vrfCoordinator,
        //     gasLane,
        //     subscriptionId,
        //     callbackGasLimit

        // ) = helperConfig.activeNetworkConfig();  //getConfig()の方がネットワークに応じた設定に適切に対処できる

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(uint256(raffle.getRaffleState()) == 0); // Raffle.RaffleState.OPEN -> 0
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/
    function testRaffleRevertWhenYouDontPayEnough() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Asset
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.prank(PLAYER);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        // Assert
        address playerRrecorded = raffle.getPlayer(0);
        assert(playerRrecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        // Arrange
        vm.prank(PLAYER);
        // Act / Assert
        //expect.Emit: 特定のイベントが発行されることを期待する
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testDontAllowPlayersToEnterWhileRaffleIsCalculating() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        /**
         * performUpkeep() を呼ぶことで、Chainlink VRF の consumer（コントラクト）として登録される可能性がある
         * つまり、VRF が fulfillRandomWords() をコールバックする準備が整う
         */

        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                            CHECKUPKEEP
    //////////////////////////////////////////////////////////////*/
    function testCheckUpkeepReturnsFalseIfItHasNoBalance() public {
        // Arrange
        //warpで時間を進める、rollでブロックナンバーを進める
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(raffleState == Raffle.RaffleState.CALCULATING);
        assert(upkeepNeeded == false);
    }

    // Challenge 1. testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed
    function testCheckUpkeepReturnsFalseIfEnoughTimeHasntPassed() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    // Challenge 2. testCheckUpkeepReturnsTrueWhenParametersGood
    function testCheckUpkeepReturnsTrueWhenParametersGood() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                            PERFORMUPKEEP
    //////////////////////////////////////////////////////////////*/
    // Perform Upkeep
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act / Assert
        // It doesnt revert
        raffle.performUpkeep("");
        /**
         * 条件が揃っているためrevertはされない
         */
    }

    function testPerformUpkeepRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState rState = raffle.getRaffleState();

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        currentBalance = currentBalance + entranceFee;
        numPlayers = 1;
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, rState)
        );
        raffle.performUpkeep("");
        /**
         * Raffle__UpkeepNotNeededがエラー(revert)されることを期待
         */
    }

    // Act
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    // What if we need to get data from emitted events in our tests?
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public raffleEntered {
        vm.recordLogs(); // performUpkeepの実行中に発行されるイベントログを記録
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs(); // performUpkeepの実行中に発行されたログをすべて取得し、entries配列に格納、vrfCoordinatorからの大きなイベントは最初に発行されることがわかっているので、我々のイベントは2番目、つまりentries[1]である
        bytes32 requestId = entries[1].topics[1]; // entries[1]から、トピックとして格納されているリクエストIDを取得(entries[0]にはvrfCoodinetor)
        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        // requestId = raffle.getLastRequestId();
        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // 0 = open, 1 = calculating
    }

    // fuzz test
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId)
        public
        raffleEntered
        skipFork
    {
        // Arrange/ Act / Assert
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle)); // randomRequestIdで256(foundry.toml)通りのテスト
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered skipFork {
        // Arrange
        uint256 additionalEntrances = 3; // 4 total
        uint256 startingIndex = 1; // We have starting index be 1 so we can start with address(1) and not address(0),address(0)はイーサリアムで重要を持つアドレスなので、テストに使うのは避ける
        address expectedWinner = address(1);

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether); // deal 1 eth to the player,deal + prank
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emits requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // get the requestId from the logs, #226と同様
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle)); //pretend to be the chainlink node
        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntrances + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);
    }
}
