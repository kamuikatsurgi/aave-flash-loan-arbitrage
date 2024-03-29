// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;
pragma abicoder v2;

import {FlashLoanSimpleReceiverBase} from "@aave/core-v3/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import {IPoolAddressesProvider} from "@aave/core-v3/contracts/interfaces/IPoolAddressesProvider.sol";
import {IERC20} from "@aave/core-v3/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import {ISwapRouter} from "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {console} from "forge-std/Test.sol";

contract Arbitrage is FlashLoanSimpleReceiverBase {
    address constant USDC_E_ADDRESS = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant WETH_ADDRESS = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address constant AAVE_ADDRESS_PROVIDER = 0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb;
    address constant UNISWAP_ROUTER_ADDRESS = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address constant SUSHISWAP_ROUTER_ADDRESS = 0x0aF89E1620b96170e2a9D0b68fEebb767eD044c3;

    // We will set the pool fee to 0.3% because USDC.e/WETH is a Medium Risk Pair
    uint24 constant poolFee = 3000;

    address payable owner;

    ISwapRouter uniswapRouter = ISwapRouter(UNISWAP_ROUTER_ADDRESS);
    ISwapRouter sushiswapRouter = ISwapRouter(SUSHISWAP_ROUTER_ADDRESS);

    IERC20 usdc = IERC20(USDC_E_ADDRESS);
    IERC20 weth = IERC20(WETH_ADDRESS);

    constructor() FlashLoanSimpleReceiverBase(IPoolAddressesProvider(AAVE_ADDRESS_PROVIDER))
    {
        owner = payable(msg.sender);
    }

    /**
        This function is called after your contract has received the flash loaned amount
     */
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address /* initiator */,
        bytes calldata /* params */
    ) external override returns (bool) {
        // Additional logic goes here
        console.log("USDC.e Flash Loan from AAVE: ", amount);
        console.log("Premium: ", premium);

        // UniSwap USDC.e -> WETH Swap
        usdc.approve(address(uniswapRouter), amount);

        ISwapRouter.ExactInputSingleParams memory paramsOne = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: USDC_E_ADDRESS,
                tokenOut: WETH_ADDRESS,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amount,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        uint256 amountOutWETH = uniswapRouter.exactInputSingle(paramsOne);
        console.log("WETH received from UniSwap: ", amountOutWETH);  

        // SushiSwap WETH -> USDC.e Swap
        weth.approve(address(sushiswapRouter), amountOutWETH);

        ISwapRouter.ExactInputSingleParams memory paramsTwo = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: WETH_ADDRESS,
                tokenOut: USDC_E_ADDRESS,
                fee: poolFee,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountOutWETH,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });

        uint256 amountOutUSDC = sushiswapRouter.exactInputSingle(paramsTwo);
        console.log("USDC.e received from SushiSwap: ", amountOutUSDC);      

        // Approve the Aave Pool contract allowance to *pull* the owed amount
        uint256 amountOwed = amount + premium;
        IERC20(asset).approve(address(POOL), amountOwed);
        return true;
    }

    function requestFlashLoan(address _token, uint256 _amount) public {
        address receiverAddress = address(this);
        address asset = _token;
        uint256 amount = _amount;
        bytes memory params = "0x";
        uint16 referralCode = 0;

        POOL.flashLoanSimple(
            receiverAddress,
            asset,
            amount,
            params,
            referralCode
        );
    }

    modifier onlyOwner() {
        require(
            msg.sender == owner,
            "Only the contract owner can call this function"
        );
        _;
    }

    function withdraw(address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    receive() external payable {}
}