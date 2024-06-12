// SPDX-License-Identifier: MIT
pragma solidity >0.8.0;

// Tools:
// In this assignment we will be programming in Ethereum with Solidity.
// You should be familiar with solidity due to the "cryptozombies" tutorials.
// You can use remix.ethereum.org to gain access to a Solidity programming environment,
// and install the metamask.io browser extension to access an ethereum testnet wallet.

// Project:

// Implement the Nim board game (the "misere" version -- if you move last, you lose).
// See https://en.wikipedia.org/wiki/Nim for details about the game, but in essence
// there are N piles (think array length N of uint256) and in each turn a player must 
// take 1 or more items (player chooses) from only 1 pile.  If the pile is empty, of 
// course the player cannot take items from it.  The last player to take items loses.
// Also in our version, if a player makes an illegal move, it loses.

// To implement this game, you need to create a contract that implements the interface 
// "Nim" (see below).

// Nim.startMisere kicks things off.  It is given the addresses of 2 NimPlayer (contracts)
// and an initial board configuration (for example [1,2] would be 2 piles with 1 and 2 items in them).

// Your code must call the nextMove API alternately in each NimPlayer contract to receive 
// that player's next move, ensure its legal, apply it, and see if the player lost.
// Player a gets to go first.
// If the move is illegal, or the player lost, call the appropriate Uxxx functions
// (e.g. Uwon, Ulost, UlostBadMove) functions for both players, and award the winner
// all the money sent into "startMisere" EXCEPT your 0.001 ether fee for hosting the game.

// I have supplied an example player.
// You should submit your solution to Gradescope's auto-tester.  The tests in
// Gradescope are representative of the final tests we will apply to your submission,
// but are not comprehensive.

// To submit to Gradescope, create a zip file with a single file named nim.sol in it (no subdirectories!).
// This is an example Makefile to do this on Linux, if your work is in a subdirectory called "submission":
// nim_solution.zip: submission/nim.sol
//	(cd submission; 7z a ../nim_solution.zip nim.sol)


// TESTING IS A CRITICAL PART OF THIS ASSIGNMENT.
// You must think about how the game can be exploited and write your own
// misbehaving players to attack your own Nim game!

// If you rely on the autograder to be your tests, you will waste a huge amount
// of your own time because the autograder takes a while to run.

// Leave your tests in your submitted nim.sol file either commented out or as
// separate contracts.  The auto-graded points are not the final grade.  The
// graders will look at the quality of your tests and code and may bump you
// up/down based on our assessment of it.

// Good luck! You've got this!


interface NimPlayer
{
    // Given a set of piles, return a pile number and a quantity of items to remove
    function nextMove(uint256[] calldata piles) external returns (uint, uint256);
    // Called if you win, with your winnings!
    function Uwon() external payable;
    // Called if you lost :-(
    function Ulost() external;
    // Called if you lost because you made an illegal move :-(
    function UlostBadMove() external;
}


interface Nim
{
    // fee is 0.001 ether, award the winner the rest
    function startMisere(NimPlayer a, NimPlayer b, uint256[] calldata piles) payable external;  
}

contract NimBoard is Nim {

    uint private constant hostFee = 0.001 ether;
    uint256[] private gameboard;
    bool private invalidMove = false;
    uint private currentPlayer;
    uint private totalMoves;

    // Start a new game
    function startMisere(NimPlayer playerOne, NimPlayer playerTwo, uint256[] calldata piles) payable external override {
        // Ensure the host fee has been paid
        require(msg.value >= hostFee, "Insufficient fee!!");
        gameboard = piles;
        // Reset the move counter and current player
        totalMoves = 0;
        currentPlayer = 0;
        invalidMove = false;

        while (hasValidMoves() && !invalidMove) {
          // Determine the next move based on the current player
          if(currentPlayer == 0) {
                runPlayerMove(playerOne, playerTwo);
                currentPlayer = 1;
            } else {
                runPlayerMove(playerTwo, playerOne);
                currentPlayer = 0;
            }
            totalMoves++;
        }

        if (!invalidMove) {
            if (currentPlayer == 0) {
                // Transfer the winnings to player one and notify player two of the loss
                playerOne.Uwon{value: msg.value - hostFee}();
                playerTwo.Ulost();
            } else {
                // Transfer the winnings to player two and notify player one of the loss
                playerTwo.Uwon{value: msg.value - hostFee}();
                playerOne.Ulost();
            }
        }
    }

    function runPlayerMove(NimPlayer curPlayer, NimPlayer otherPlayer) internal {
        // Get the index and number of stones to remove from the pile
        uint index;
        uint number;
        (index, number) = curPlayer.nextMove(gameboard);
        if (!isValidMove(index, number)) {
            // Mark the move as invalid and notify the players
            invalidMove = true;
            curPlayer.UlostBadMove();
            otherPlayer.Uwon{value: msg.value - hostFee}();
            return;
        }
        // Update the game board with the player's move
        gameboard[index] -= number;
    }

    function hasValidMoves() internal view returns (bool) {
        for (uint i = 0; i < gameboard.length; i++) {
            if (gameboard[i] > 0) {
                return true;
            }
        }
        return false;
    }

    function isValidMove(uint index, uint256 number) internal returns (bool) {
        if (index >= gameboard.length) {
            return false;
        }
        if (number <= 0) {
            return false;
        }
        if (gameboard[index] < number) {
            return false;
        }
        return true;
    }
    // Retrieve the current game board state
    function getboardState() external view returns (uint256[] memory) {
        return gameboard;
    }

    // Get the number of moves played so far
    function getNumMoves() external view returns (uint) {
        return totalMoves;
    }
}
contract TrackingNimPlayer is NimPlayer
{
    uint losses=0;
    uint wins=0;
    uint faults=0;
    // Given a set of piles, return a pile number and a quantity of items to remove
    function nextMove(uint256[] calldata) virtual override external returns (uint, uint256)
    {
        return(0,1);
    }
    // Called if you win, with your winnings!
    function Uwon() override external payable
    {
        wins += 1;
    }
    // Called if you lost :-(
    function Ulost() override external
    {
        losses += 1;
    }
    // Called if you lost because you made an illegal move :-(
    function UlostBadMove() override external
    {
        faults += 1;
    }
    
    function results() external view returns(uint, uint, uint, uint)
    {
        return(wins, losses, faults, address(this).balance);
    }
    
    function reset() external {
        wins = 0;
        losses = 0;
        faults = 0;
    }
    
}

contract Boring1NimPlayer is TrackingNimPlayer
{
    // Given a set of piles, return a pile number and a quantity of items to remove
    function nextMove(uint256[] calldata piles) override external returns (uint, uint256)
    {
        for(uint i=0;i<piles.length; i++)
        {
            if (piles[i]>1) return (i, piles[i]-1);  // consumes all in a pile
        }
        for(uint i=0;i<piles.length; i++)
        {
            if (piles[i]>0) return (i, piles[i]);  // consumes all in a pile
        }
    }
}


/*
Test vectors:
deploy your contract NimBoard, call it C
deploy 2 Boring1NimPlayers, A & B
In remix set the value to 0.002 ether and call
c.startMisere(A,B,[1,1])
A should have 1 win and a balance of 1000000000000000 (0.001 ether)
B should have 1 loss
Now try c.startMisere(A,B,[1,2])
Now A and B should both have 1 win and 1 loss (and B should have gained however many coins you funded the round with)
*/

//contract NimTesting {

  //  NimBoard public nimBoardContract;
  //  TrackingNimPlayer public playerA;
  //  TrackingNimPlayer public playerB;
  //  uint256 public previousTestBalanceA;
  //  uint256 public previousTestBalanceB;
  //  uint256 public previousTestWinsA;
  //  uint256 public previousTestWinsB;
  //  uint256 public previousTestLossesA;
  //  uint256 public previousTestLossesB;

   // constructor(address _nimBoard, address _playerA, address _playerB) {
       // nimBoardContract = NimBoard(_nimBoard);
       // playerA = TrackingNimPlayer(payable(_playerA));
       // playerB = TrackingNimPlayer(payable(_playerB));
   // }

   // function testGameOne() external payable {
       // require(msg.value >= 0.002 ether, "Insufficient funds for test 1");

       // uint256[] memory initialPiles = new uint256[](2);
       // initialPiles[0] = 1;
       // initialPiles[1] = 1;

       // nimBoardContract.startMisere{value: 0.002 ether}(playerA, playerB, initialPiles);
    // }

   // function checkResultsGameOne() external {
       // (uint256 winsA, uint256 lossesA, uint256 faultsA, uint256 balanceA) = playerA.results();
       // (uint256 winsB, uint256 lossesB, uint256 faultsB, uint256 balanceB) = playerB.results();

       // require(winsA == 1, "Player A should have 1 win");
       // require(balanceA == 0.001 ether, "Player A should have gained 0.001 ether balance");

       // require(lossesB == 1, "Player B should have 1 loss");
   // }
// }