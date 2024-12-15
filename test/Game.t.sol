//SPDX-License-Identifier:MIT

pragma solidity ^0.8.26;

import {Test, StdCheats} from "forge-std/Test.sol";
import {Game} from "../src/Game.sol";
import {Deploy} from "../script/Deploy.s.sol";
import {GameHarness} from "./Harnesses/GameHarness.sol";

contract GameTest is Test {
  Deploy public gameDeployer;
  GameHarness public game;
  address public PLAYER = makeAddr("PLAYER");

  function setUp() public {
    game = new GameHarness(
      "Game",
      "Description",
      block.timestamp + 1 hours,
      block.timestamp + 2 hours,
      1 hours,
      1 ether,
      //0xf490de2920c8a35fabeb13208852aa28c76f9be9b03a4dd2b3c075f7a26923b4
      keccak256(abi.encodePacked(int64(0), int64(0)))
    );
  }

  function testFuzz_EmitsDepositReceivedWhenPlayerDeposits(address _player) public {
    vm.assume(_player != address(0));

    uint256 registrationFee = game.registrationFee();
    vm.deal(_player, registrationFee);
    vm.startPrank(_player);
    vm.expectEmit();
    emit Game.DepositReceived(_player);
    game.deposit{value: registrationFee}();
    vm.stopPrank();
  }

  function testFuzz_EmitsADepositWithdrawnEventDuringRegistrationPhase(address _player) public {
    vm.assume(_player != address(0));
    vm.assume(_player.code.length == 0);
    assumeNotPrecompile(_player);

    uint256 registrationFee = game.registrationFee();
    vm.deal(_player, registrationFee);
    vm.startPrank(_player);

    game.deposit{value: registrationFee}();
    assertTrue(game.hasActiveDeposit(_player));

    vm.expectEmit();
    emit Game.DepositWithdrawn(_player);
    game.withdrawDeposit();

    assertFalse(game.hasActiveDeposit(_player));
    vm.stopPrank();
  }

  function testFuzz_playerDepositEqualsRegistrationFee(address _player) public payable {
    vm.assume(_player != address(0));
    vm.assume(_player != address(this));
    vm.assume(_player.code.length == 0);

    uint256 registrationFee = game.registrationFee();
    uint256 initialGameBalance = address(game).balance;

    vm.deal(_player, registrationFee);
    uint256 initialPlayerBalance = _player.balance;

    vm.startPrank(_player);

    vm.expectEmit();
    emit Game.DepositReceived(_player);

    game.deposit{value: registrationFee}();

    vm.stopPrank();

    assertEq(_player.balance, initialPlayerBalance - registrationFee);
    assertEq(initialPlayerBalance - _player.balance, address(game).balance - initialGameBalance);
    assertTrue(game.hasActiveDeposit(_player));
  }

  function testFuzz_playerDepositDoesNotEqualRegistrationFee(uint256 _amount, address _player)
    public
    payable
  {
    vm.assume(_player != address(0));
    vm.assume(_player != address(this));
    vm.assume(_player.code.length == 0);

    uint256 registrationFee = game.registrationFee();
    vm.assume(_amount != registrationFee);

    vm.deal(_player, _amount);

    vm.prank(_player);
    vm.expectRevert(abi.encodeWithSelector(Game.DepositAmountIncorrect.selector, _amount));
    game.deposit{value: _amount}();
  }

  function testFuzz_haverSineIsPositive(int64 _x, int64 _y) public view {
    uint256 distance = game.exposed_haversine(_x, _y);
    assert(distance >= 0);
  }
}
