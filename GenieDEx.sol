// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// importing the magical shield!
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract GenieDEx is ReentrancyGuard {
    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;
    uint256 public totalLiquidity;
    mapping(address => uint256) public liquidity;

    event Mint(address indexed sender, uint256 amountA, uint256 amountB);
    event Burn(address indexed sender, uint256 amountA, uint256 amountB);
    event Swap(address indexed sender, uint256 amountIn, uint256 amountOut);

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    // Shield UP! 'nonReentrant' stops the goblins!
    function addLiquidity(uint256 _amountA, uint256 _amountB) external nonReentrant returns (uint256) {
        tokenA.transferFrom(msg.sender, address(this), _amountA);
        tokenB.transferFrom(msg.sender, address(this), _amountB);

        uint256 liquidityMinted;
        if (totalLiquidity == 0) {
            liquidityMinted = _amountA; 
        } else {
            uint256 shareA = (_amountA * totalLiquidity) / reserveA;
            uint256 shareB = (_amountB * totalLiquidity) / reserveB;
            liquidityMinted = shareA < shareB ? shareA : shareB;
        }

        require(liquidityMinted > 0, "Must mint some liquidity!");
        liquidity[msg.sender] += liquidityMinted;
        totalLiquidity += liquidityMinted;
        
        _updateReserves();
        emit Mint(msg.sender, _amountA, _amountB);
        return liquidityMinted;
    }

    // Master, I added 'minAmountOut' to protect you from Slippage!
    function swapAforB(uint256 _amountIn, uint256 _minAmountOut) external nonReentrant {
        require(_amountIn > 0, "Cannot swap air!");

        uint256 amountInWithFee = (_amountIn * 997) / 1000; 
        uint256 amountOut = (amountInWithFee * reserveB) / (reserveA + amountInWithFee);

        // The Slippage Check! If the trade is bad, the spell fails!
        require(amountOut >= _minAmountOut, "Slippage limit reached! Trade cancelled.");
        require(amountOut < reserveB, "Not enough liquidity!");

        tokenA.transferFrom(msg.sender, address(this), _amountIn);
        tokenB.transfer(msg.sender, amountOut);

        _updateReserves();
        emit Swap(msg.sender, _amountIn, amountOut);
    }

    // Now users can take their gold back!
    function removeLiquidity(uint256 _liquidityAmount) external nonReentrant returns (uint256, uint256) {
        require(liquidity[msg.sender] >= _liquidityAmount, "Not enough shares!");

        // Math: (ShareAmount * Reserve) / TotalSupply
        uint256 amountA = (_liquidityAmount * reserveA) / totalLiquidity;
        uint256 amountB = (_liquidityAmount * reserveB) / totalLiquidity;

        liquidity[msg.sender] -= _liquidityAmount;
        totalLiquidity -= _liquidityAmount;

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        _updateReserves();
        emit Burn(msg.sender, amountA, amountB);
        return (amountA, amountB);
    }

    function _updateReserves() private {
        reserveA = tokenA.balanceOf(address(this));
        reserveB = tokenB.balanceOf(address(this));
    }
}