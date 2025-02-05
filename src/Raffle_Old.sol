// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

error NotEnoughEthSent();

/**
 * @title A sample Raffle Contract
 * @author Patrick Collins (or even better, you own name)
 * @notice This contract is for creating a sample raffle
 * @dev It implements Chainlink VRFv2 and Chainlink Automation
 */

 //Note: Chainlink VRF2.0
contract Raffle is
    VRFConsumerBaseV2Plus // VRFConsumerBaseV2→VRFConsumerBaseV2Plusに変更
{
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNotNeeded(uint256 balance, uint256 playersLength, uint256 raffleState);

    /* Type Declaration */
    enum RaffleState {
        OPEN, //0
        CALCULATING //1

    }
    /* State Variables */

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_entranceFee;
    // @dev The duration of the lottery in seconds
    // uint256 private immutable i_gasLane;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState; // start is open

    // // Chainlink VRF related variables
    // address immutable i_vrfCoordinator;
    // // Chainlink VRF related variables
    // VRFCoordinatorV2Interface private immutable i_vrfCoordinator;

    /* Events */
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator, //継承しているため
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        // s_vrfCoordinator.requestRandomWords();
        // i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        // i_gasLane = gasLane;
    }
    // Note: external, custom errorはガス効率が良い

    function enterRaffle() external payable {
        // require(msg.sender >= i_entranceFee, "Not enough ETH sent!");
        // require(msg.sender >= i_entranceFee, SendMoreToEnterRaffle());
        if (msg.value < i_entranceFee) revert Raffle__SendMoreToEnterRaffle();
        if (s_raffleState != RaffleState.OPEN) revert Raffle__RaffleNotOpen();

        s_players.push(payable(msg.sender));
        // 1. Makes migration easier
        // 2. Makes front end "indexing" easier
        emit RaffleEntered(msg.sender);
    }
    // When should the winner be picked?
    /**
     * @dev This is the function that the Chainlink node will call to see
     * if the lottery is ready to have a winner picked.
     * the following should be true in order for upkeepNeeded to be true;
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH(has a player)
     * 4. Implicity, your subscription is funded with LINK.
     * @param - ignore
     * @return upkeepNeeded - true if it's time to restart the lottery
     * @return - ignore
     */

    //Chainlink Automationの機能
    function checkUpkeep(bytes memory /* checkData */ )
        public
        /**
         * externalからpublicに変更すると通ったが理由不明
         */
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool isOpen = RaffleState.OPEN == s_raffleState;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, "");
    }

    // 1. Get a random number
    // 2. Use random number to pick a player
    // 3. Be automatically called

    // function pickWinner() external {
    //     // check to see if enough time has passed
    //     if (block.timestamp - s_lastTimeStamp < i_interval) revert();
    //     s_raffleState = RaffleState.CALCULATING;
    //     uint256 requestId = COORDINATOR.requestRandomWords(
    //         keyHash,
    //         s_subscriptionId,
    //         requestConfirmations,
    //         callbackGasLimit,
    //         numWords
    //     );

    // }
    // Chainlink Automationの機能、autmatically called
    // pickWinnerをperformUpkeepの一部にリファクタリング
    function performUpkeep(bytes calldata /* performData */ ) external {
        // check to see if enough time has passed
        (bool upkeepNeeded,) = checkUpkeep(""); //checkUpkeepの返り値はbytes memory型だがここではcheckDataを使わないのでで空のbytesを表す
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, uint256(s_raffleState));
        }

        s_raffleState = RaffleState.CALCULATING;
        // VRFV2PlusClientのstructを使って、requestRandomWordsイベントを呼び出す
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(
                // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
            )
        });
        //requestRandomWordsがRandomWordsRequestedイベントを発信すると、Chainlinkノードがその情報を受け取り、ノードはその情報を使って、fulfillRandomWordsをコールバックすることで、あなたにランダム性サービスを提供する
        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        // Quiz...this is redundant?
        emit RequestedRaffleWinner(requestId);
    }

    // CEI: Checks, Effect, Interactions Pattern
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // Checks
        // Effect (Internal Contract State)
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); //新しい空の配列に書き換え、s_player[](0)→payable[](0)に変更
        s_lastTimeStamp = block.timestamp; //新しいくじを始めるので、最後のタイムスタンプを更新
        // Effcectに入れるのは外部とのやりとりの前に状態更新をするため(ReentrancyAttack),ログ生成は内部的なもの

        // Interactions (External Contract Interactions)
        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success) revert Raffle__TransferFailed();
        emit WinnerPicked(s_recentWinner);
    }

    /**
     * Getter Function
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }
}
