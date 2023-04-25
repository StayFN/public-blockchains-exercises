// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Open Zeppelin:

// Open Zeppelin NFT guide:
// https://docs.openzeppelin.com/contracts/4.x/erc721

// Open Zeppelin ERC721 contract implements the ERC-721 interface and provides
// methods to mint a new NFT and to keep track of token ids.
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol

// Open Zeppelin ERC721URIStorage extends the standard ERC-721 with methods
// to hold additional metadata.
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/extensions/ERC721URIStorage.sol

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
// TODO:
// Other openzeppelin contracts might be useful. Check the Utils!
// https://docs.openzeppelin.com/contracts/4.x/utilities

// Local imports:

// TODO:
// You might need to adjust paths to import accordingly.

// Import BaseAssignment.sol
import "../BaseAssignment.sol";

// You contract starts here:
// You need to inherit from multiple contracts/interfaces.
contract Assignment2 is BaseAssignment {
    using SafeMath for uint256;
    using Strings for uint256;

    constructor() BaseAssignment(0xbb94CBc84004548b9e174955bB4e26a1757cc5C3) {}

    string state = "waiting";
    uint256 gameCounter = 0;
    address public player1;
    address public player2;

    string private player1Choice;
    string private player2Choice;

    bytes32 private player1HashedChoice;
    bytes32 private player2HashedChoice;
    uint256 private feeCollected;

    uint256 public constant FEE = 0.001 ether; // 0.001 ETH

    uint256 private actionStartBlock;
    uint256 public startMaxTime = 10;
    uint256 public playMaxTime = 10;
    uint256 public revealMaxTime = 10;

    // Events
    event Started(uint256 indexed gameCounter, address indexed player1);
    event Playing(
        uint256 indexed gameCounter,
        address indexed player1,
        address indexed player2
    );

    event Ended(
        uint256 indexed gameCounter,
        address indexed winner,
        int256 outcome
    );

    function start() external payable returns (uint256) {
        require(
            msg.value >= FEE,
            "A fee of 0.001 ETH is required to start the game"
        );

        require(
            keccak256(abi.encodePacked(state)) == keccak256("waiting") ||
                keccak256(abi.encodePacked(state)) == keccak256("starting"),
            "start() can only be invoked under the 'waiting' and 'starting' state"
        );

        if (actionStartBlock + startMaxTime < getBlockNumber() && keccak256(abi.encodePacked(state)) == keccak256("starting")) {
            resetGame();
        }

        uint256 playerId = 1;

        feeCollected = feeCollected + msg.value;

        if (keccak256(abi.encodePacked(state)) == keccak256("waiting")) {
            emit Started(gameCounter, player1);
        } else if (
            keccak256(abi.encodePacked(state)) == keccak256("starting")
        ) {
            emit Playing(gameCounter, player1, player2);
        }

        actionStartBlock = getBlockNumber();

        if (keccak256(abi.encodePacked(state)) == keccak256("waiting")) {
            player1 = msg.sender;
            state = "starting";
            gameCounter++;
            playerId = 1;
        } else if (
            keccak256(abi.encodePacked(state)) == keccak256("starting")
        ) {
            require(msg.sender != player1, "Player1 cannot also be Player2");
            player2 = msg.sender;
            state = "playing";
            playerId = 2;
        }

        return playerId;
    }

    function play(string memory choice) public returns (int256) {
        require(
            keccak256(abi.encodePacked(state)) == keccak256("playing"),
            "play() can only be invoked under the 'playing' state"
        );
        require(
            msg.sender == player1 || msg.sender == player2,
            "Only player1 and player2 can invoke play()"
        );
        require(
            keccak256(abi.encodePacked(choice)) == keccak256("rock") ||
                keccak256(abi.encodePacked(choice)) == keccak256("paper") ||
                keccak256(abi.encodePacked(choice)) == keccak256("scissors"),
            "Invalid choice: only 'rock', 'paper', or 'scissors' are allowed"
        );
        require(
            msg.sender == player2 ||
                (msg.sender == player1 && bytes(player1Choice).length == 0),
            "Player1 already played"
        );
        require(
            !checkMaxTime(),
            "play() can only be invoked within the playMaxTime"
        );
        

        if (msg.sender == player1) {
            player1Choice = choice;
        } else {
            player2Choice = choice;
        }
        actionStartBlock = getBlockNumber();

        if (
            bytes(player1Choice).length == 0 || bytes(player2Choice).length == 0
        ) {
            if (bytes(player1Choice).length != 0) {
                emit Ended(gameCounter, player1, 1);
            } else {
                emit Ended(gameCounter, player2, 2);
            }

            return -1;
        }

        int256 result = computeOutcome();

        // Distribute the fee collected to the winner
        if (result == 1) {
            (bool sent, bytes memory data) = player1.call{value: feeCollected}(
                ""
            );
            require(sent, "Failed to send Ether");
            emit Ended(gameCounter, player1, result);
            // Reset the fee collected for the next game
            feeCollected = 0;
        } else if (result == 2) {
            (bool sent, bytes memory data) = player2.call{value: feeCollected}(
                ""
            );
            require(sent, "Failed to send Ether");
            emit Ended(gameCounter, player2, result);
            // Reset the fee collected for the next game
            feeCollected = 0;
        } else {
            // In case of a draw, the fee is kept by the contract
        }

        resetGame();

        return result;
    }

    function playPrivate(bytes32 hashedChoice) public {
        require(
            keccak256(abi.encodePacked(state)) == keccak256("playing"),
            "playPrivate() can only be invoked when state is 'playing'"
        );
        require(
            msg.sender == player1 || msg.sender == player2,
            "Only registered players can submit their choices"
        );
        require(
            msg.sender == player2 ||
                (msg.sender == player1 && player1HashedChoice == 0),
            "Player1 already played"
        );

        if (msg.sender == player1) {
            player1HashedChoice = hashedChoice;
        } else {
            player2HashedChoice = hashedChoice;
        }

        if (player1HashedChoice != 0 && player2HashedChoice != 0) {
            state = "revealing";
            actionStartBlock = getBlockNumber();
        }
    }

    function reveal(string memory plainChoice, string memory seed) public {
        require(
            keccak256(abi.encodePacked(state)) == keccak256("revealing"),
            "reveal() can only be invoked when state is 'revealing'"
        );
        require(
            msg.sender == player1 || msg.sender == player2,
            "Only registered players can reveal their choices"
        );

        bytes32 hashedChoice = keccak256(
            abi.encodePacked(string.concat(seed, "_", plainChoice))
        );

        if (msg.sender == player1 && player1HashedChoice == hashedChoice) {
            player1Choice = plainChoice;
        } else if (
            msg.sender == player2 && player2HashedChoice == hashedChoice
        ) {
            player2Choice = plainChoice;
        } else {
            revert("Invalid choice or seed");
        }

        if (bytes(player1Choice).length != 0 && bytes(player2Choice).length != 0) {
            int256 result = computeOutcome(); 
            payWinner(result);
            resetGame();
        }        
    }

    function payWinner(int256 result) private {
        if (result == 1) {
            player1.call{value: feeCollected}("");
        } else if (result == 2) {
            player2.call{value: feeCollected}("");
        } else {
            // In case of a draw, the fee is kept by the contract
        }
    }

    function computeOutcome() private view returns (int256) {
        if (
            keccak256(abi.encodePacked(player1Choice)) ==
            keccak256(abi.encodePacked(player2Choice))
        ) {
            return 0;
        }
        if (
            (keccak256(abi.encodePacked(player1Choice)) == keccak256("rock") &&
                keccak256(abi.encodePacked(player2Choice)) ==
                keccak256("scissors")) ||
            (keccak256(abi.encodePacked(player1Choice)) == keccak256("paper") &&
                keccak256(abi.encodePacked(player2Choice)) ==
                keccak256("rock")) ||
            (keccak256(abi.encodePacked(player1Choice)) ==
                keccak256("scissors") &&
                keccak256(abi.encodePacked(player2Choice)) ==
                keccak256("paper"))
        ) {
            return 1;
        } else {
            return 2;
        }
    }

    function setMaxTime(string memory action, uint256 maxTime) external {
        require(
            keccak256(abi.encodePacked(state)) == keccak256("waiting"),
            "setMaxTime() can only be invoked when state is 'waiting'"
        );

        if (keccak256(abi.encodePacked(action)) == keccak256("start")) {
            startMaxTime = maxTime;
        } else if (keccak256(abi.encodePacked(action)) == keccak256("play")) {
            playMaxTime = maxTime;
        } else {
            revert("Invalid action: only 'start' and 'play' are allowed");
        }
    }

    function checkMaxTime() public returns (bool) {
        if (
            keccak256(abi.encodePacked(state)) == keccak256("starting") &&
            getBlockNumber() > actionStartBlock + startMaxTime
        ) {
            state = "waiting";
            (bool sent, bytes memory data) = player1.call{value: feeCollected}(
                ""
            );
            require(sent, "Failed to send Ether");
            resetGame();
            return true;
        } else if (
            keccak256(abi.encodePacked(state)) == keccak256("playing") &&
            getBlockNumber() > actionStartBlock + playMaxTime
        ) {
            state = "waiting";
            address winner;
            int256 outcome;
            if (
                bytes(player1Choice).length != 0 ||
                bytes(player2Choice).length != 0
            ) {
                winner = bytes(player1Choice).length != 0 ? player1 : player2;
                (bool sent, bytes memory data) = winner.call{
                    value: feeCollected
                }("");
                require(sent, "Failed to send Ether");
            }

            if (
                bytes(player1Choice).length != 0 ||
                bytes(player2Choice).length != 0
            ) {
                outcome = 1;
            } else {
                outcome = -1;
            }

            emit Ended(gameCounter, winner, outcome);

            resetGame();

            return true;
        } else if (
            keccak256(abi.encodePacked(state)) == keccak256("revealing") &&
            getBlockNumber() > actionStartBlock + revealMaxTime
        ) {
            if (
                bytes(player1Choice).length != 0 &&
                bytes(player2Choice).length == 0
            ) {
                (bool sent, bytes memory data) = player1.call{
                    value: feeCollected
                }("");
                require(sent, "Failed to send Ether");
                emit Ended(gameCounter, player1, 1);
            } else if (
                bytes(player1Choice).length == 0 &&
                bytes(player2Choice).length != 0
            ) {
                (bool sent, bytes memory data) = player2.call{
                    value: feeCollected
                }("");
                require(sent, "Failed to send Ether");
                emit Ended(gameCounter, player2, 2);
            } else {
                emit Ended(gameCounter, address(0), 0);
            }
        }
        resetGame();
        return false;
    }

    function getState() public view returns (string memory) {
        return state;
    }

    //Write a getgame function that returns the current game number
    function getGameCounter() public view returns (uint256) {
        return gameCounter;
    }

    function resetGame() private {
        state = "waiting";
        player1 = address(0);
        player2 = address(0);
        player1Choice = "";
        player2Choice = "";
        player1HashedChoice = 0;
        player2HashedChoice = 0;
        startMaxTime = 10;
        playMaxTime = 10;
        revealMaxTime = 10;
        actionStartBlock = 0;
    }

    function forceReset() public {
        require(
            isValidator(msg.sender),
            "Only the validator can force reset the game"
        );
        resetGame();
    }
}