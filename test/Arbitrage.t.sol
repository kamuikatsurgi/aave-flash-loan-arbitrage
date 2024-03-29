// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Arbitrage} from "../src/Arbitrage.sol";
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";

contract ArbitrageTest is Test {
    address krishang;
    address constant USDC_E_ADDRESS = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    Arbitrage arbitrage;

    function setUp() public {
        krishang = vm.envAddress("ADDRESS");
        arbitrage = new Arbitrage();
    }

    function test_arbitrage() public {
        deal(USDC_E_ADDRESS, address(arbitrage), 1050e6, true);
        console.log("Dealed USDC.e balance: ", IERC20(USDC_E_ADDRESS).balanceOf(address(arbitrage)));
        arbitrage.requestFlashLoan(USDC_E_ADDRESS, 1000e6);
    }
}