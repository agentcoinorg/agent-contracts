// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {Hooks, IHooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {LiquidityAmounts} from "@uniswap/v4-periphery/src/libraries/LiquidityAmounts.sol";
import {Actions} from "@uniswap/v4-periphery/src/libraries/Actions.sol";

struct UniswapPoolDeploymentInfo {
    /// @notice UNI V4 pool manager
    IPoolManager poolManager;
    /// @notice UNI V4 position manager
    IPositionManager positionManager;
    /// @notice Address of the collateral token
    address collateral;
    /// @notice Address of the agent token
    address agentToken;
    /// @notice Amount of collateral to provide to the pool
    uint256 collateralAmount; 
    /// @notice Amount of agent token to provide to the pool
    uint256 agentTokenAmount; 
    /// @notice Address of the recipient of the LP tokens (and any excess collateral/agent token)
    address lpRecipient;
    /// @notice LP fee
    uint24 lpFee;
    /// @notice Tick spacing
    int24 tickSpacing; 
    /// @notice Starting price
    uint160 startingPrice; 
    /// @notice Address of the UNI V4 hook contract
    address hook;
    /// @notice Permit2 contract address
    address permit2;
}

/// @title UniswapPoolDeployer
/// @notice Utility for initializing a Uniswap V4 pool and adding initial liquidity to it
library UniswapPoolDeployer {
    struct DeploymentInfo {
        uint256 amount0Max;
        uint256 amount1Max;
        int24 tickLower;
        int24 tickUpper;
    }

    /// @notice Deploy a new pool and add liquidity to it
    /// @param _poolInfo Pool information    
    function deployPoolAndAddLiquidity(UniswapPoolDeploymentInfo calldata _poolInfo) external returns (PoolKey memory) {
        DeploymentInfo memory deploymentInfo = DeploymentInfo({
            amount0Max: _poolInfo.collateral < _poolInfo.agentToken ? _poolInfo.collateralAmount : _poolInfo.agentTokenAmount,
            amount1Max: _poolInfo.collateral < _poolInfo.agentToken ? _poolInfo.agentTokenAmount : _poolInfo.collateralAmount,
            // Provide full-range liquidity to the pool
            tickLower: TickMath.minUsableTick(_poolInfo.tickSpacing),
            tickUpper: TickMath.maxUsableTick(_poolInfo.tickSpacing)
        });

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(_poolInfo.collateral < _poolInfo.agentToken ? _poolInfo.collateral : _poolInfo.agentToken),
            currency1: Currency.wrap(_poolInfo.collateral < _poolInfo.agentToken ? _poolInfo.agentToken : _poolInfo.collateral),
            fee: _poolInfo.lpFee,
            tickSpacing: _poolInfo.tickSpacing,
            hooks: IHooks(_poolInfo.hook)
        });

        _poolInfo.poolManager.initialize(poolKey, _poolInfo.startingPrice);

        uint256 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            _poolInfo.startingPrice,
            TickMath.getSqrtPriceAtTick(deploymentInfo.tickLower),
            TickMath.getSqrtPriceAtTick(deploymentInfo.tickUpper),
            deploymentInfo.amount0Max,
            deploymentInfo.amount1Max
        );

        bytes[] memory mintParams = new bytes[](4);

        mintParams[0] = abi.encode(
            poolKey,
            deploymentInfo.tickLower,
            deploymentInfo.tickUpper,
            liquidity,
            deploymentInfo.amount0Max,
            deploymentInfo.amount1Max,
            _poolInfo.lpRecipient,
            ""
        );
        mintParams[1] = abi.encode(poolKey.currency0, poolKey.currency1);
        mintParams[2] = abi.encode(poolKey.currency0, _poolInfo.lpRecipient);
        mintParams[3] = abi.encode(poolKey.currency1, _poolInfo.lpRecipient);

        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP), uint8(Actions.SWEEP));

        if (!poolKey.currency0.isAddressZero()) {
            IERC20(_poolInfo.collateral).approve(address(_poolInfo.permit2), type(uint256).max);
            IAllowanceTransfer(_poolInfo.permit2).approve(
                _poolInfo.collateral,
                address(_poolInfo.positionManager),
                type(uint160).max,
                type(uint48).max
            );
        }

        IERC20(_poolInfo.agentToken).approve(address(_poolInfo.permit2), type(uint256).max);
        IAllowanceTransfer(_poolInfo.permit2).approve(
            _poolInfo.agentToken,
            address(_poolInfo.positionManager),
            type(uint160).max,
            type(uint48).max
        );

        if (poolKey.currency0.isAddressZero()) {
            _poolInfo.positionManager.modifyLiquidities{value: deploymentInfo.amount0Max}(abi.encode(actions, mintParams), block.timestamp);
        } else {
            _poolInfo.positionManager.modifyLiquidities(abi.encode(actions, mintParams), block.timestamp);
        }

        return poolKey;
    }
}
