// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;
// Base
import {Ownable} from "lib/panoptic-v1.1/lib/openzeppelin-contracts/contracts/access/Ownable.sol";
// Libraries
import {Math} from "lib/panoptic-v1.1/contracts/libraries/Math.sol";
import {PanopticMath} from "lib/panoptic-v1.1/contracts/libraries/PanopticMath.sol";
// Interfaces
import {IERC20Partial} from "lib/panoptic-v1.1/contracts/tokens/interfaces/IERC20Partial.sol";
import {IV3CompatibleOracle} from "lib/panoptic-v1.1/contracts/interfaces/IV3CompatibleOracle.sol";
import {PanopticPool} from "lib/panoptic-v1.1/contracts/PanopticPool.sol";
// Types
import {LeftRightUnsigned} from "lib/panoptic-v1.1/contracts/types/LeftRight.sol";
import {LeftRightSigned} from "lib/panoptic-v1.1/contracts/types/LeftRight.sol";
import {LiquidityChunk} from "lib/panoptic-v1.1/contracts/types/LiquidityChunk.sol";
import {PositionBalance} from "lib/panoptic-v1.1/contracts/types/PositionBalance.sol";
import {TokenId} from "lib/panoptic-v1.1/contracts/types/TokenId.sol";

/// @author dyedm1
contract PanopticVaultAccountant is Ownable {
    /// @notice Holds the information required to compute the NAV of a PanopticPool
    /// @param pool The PanopticPool to compute the NAV of
    /// @param token0 The token0 of the pool
    /// @param token1 The token1 of the pool
    /// @param poolOracle The oracle for the pool
    /// @param oracle0 The oracle for token0-underlying
    /// @param isUnderlyingToken0InOracle0 Whether token0 in oracle0 is the underlying token
    /// @param oracle1 The oracle for token1-underlying
    /// @param isUnderlyingToken0InOracle1 Whether token0 in oracle1 is the underlying token
    /// @param maxPriceDeviation The maximum price deviation allowed for the oracle prices
    /// @param twapWindow The time window (in seconds)to compute the TWAP over
    struct PoolInfo {
        PanopticPool pool;
        IERC20Partial token0;
        IERC20Partial token1;
        IV3CompatibleOracle poolOracle;
        IV3CompatibleOracle oracle0;
        bool isUnderlyingToken0InOracle0;
        IV3CompatibleOracle oracle1;
        bool isUnderlyingToken0InOracle1;
        int24 maxPriceDeviation;
        uint32 twapWindow;
    }

    /// @notice Holds the prices provided by the vault manager
    /// @param poolPrice The price of the pool
    /// @param token0Price The price of token0 relative to the underlying
    /// @param token1Price The price of token1 relative to the underlying
    struct ManagerPrices {
        int24 poolPrice;
        int24 token0Price;
        int24 token1Price;
    }

    /// @notice An invalid list of pools was provided for the given vault
    error InvalidPools();

    /// @notice The vault manager provided an incorrect or incomplete position list for one or more pools
    error IncorrectPositionList();

    /// @notice One or more oracle prices are outside the maxPriceDeviation from a price provided by the vault manager
    error StaleOraclePrice();

    /// @notice The pools hash for this vault has been locked and cannot be updated
    error VaultLocked();

    /// @notice The hash of pool structs to query for each vault
    mapping(address vault => bytes32 poolsHash) public vaultPools;

    /// @notice Whether the list of pools for the vault is locked
    mapping(address vault => bool isLocked) public vaultLocked;

    /// @notice Updates the pools hash for a vault.
    /// @dev This function can only be called by the owner of the contract.
    /// @param vault The address of the vault to update the pools hash for
    /// @param poolsHash The new pools hash to set for the vault
    function updatePoolsHash(address vault, bytes32 poolsHash) external onlyOwner {
        if (vaultLocked[vault]) revert VaultLocked();
        vaultPools[vault] = poolsHash;
    }

    /// @notice Locks the vault from updating its pools hash.
    /// @dev This function can only be called by the owner of the contract.
    /// @param vault The address of the vault to lock

//@audit M no mechanism to unlock vault
    function lockVault(address vault) external onlyOwner {
        vaultLocked[vault] = true;
    }

    /// @notice Returns the NAV of the portfolio contained in `vault` in terms of its underlying token.
    /// @param vault The address of the vault to value
    /// @param underlyingToken The underlying token of the vault
    /// @param managerInput Input calldata from the vault manager consisting of price quotes from the manager, pool information, and a position lsit for each pool
    /// @return nav The NAV of the portfolio contained in `vault` in terms of its underlying token
    function computeNAV(
        address vault,
        address underlyingToken,
        bytes calldata managerInput
    ) external view returns (uint256 nav) {
        (
            ManagerPrices[] memory managerPrices,
            PoolInfo[] memory pools,
            TokenId[][] memory tokenIds
        ) = abi.decode(managerInput, (ManagerPrices[], PoolInfo[], TokenId[][]));

        if (keccak256(abi.encode(pools)) != vaultPools[vault]) revert InvalidPools();

        address[] memory underlyingTokens = new address[](pools.length * 2);

        // resolves stack too deep error
        address _vault = vault;

        for (uint256 i = 0; i < pools.length; i++) {
            if (
                Math.abs(
                    managerPrices[i].poolPrice -
                        PanopticMath.twapFilter(pools[i].poolOracle, pools[i].twapWindow)
                ) > pools[i].maxPriceDeviation
            ) revert StaleOraclePrice();

            uint256[2][] memory positionBalanceArray;
            int256 poolExposure0;
            int256 poolExposure1;
            {
                LeftRightUnsigned shortPremium;
                LeftRightUnsigned longPremium;

                (shortPremium, longPremium, positionBalanceArray) = pools[i]
                    .pool
                    .getAccumulatedFeesAndPositionsData(_vault, true, tokenIds[i]);

                poolExposure0 =
                    int256(uint256(shortPremium.rightSlot())) -
                    int256(uint256(longPremium.rightSlot()));
                poolExposure1 =
                    int256(uint256(longPremium.leftSlot())) -
                    int256(uint256(shortPremium.leftSlot()));
            }

            uint256 numLegs;
            for (uint256 j = 0; j < tokenIds[i].length; j++) {
                if (positionBalanceArray[j][1] == 0) revert IncorrectPositionList();
                uint256 positionLegs = tokenIds[i][j].countLegs();
                for (uint256 k = 0; k < positionLegs; k++) {
                    (uint256 amount0, uint256 amount1) = Math.getAmountsForLiquidity(
                        managerPrices[i].poolPrice,
                        PanopticMath.getLiquidityChunk(
                            tokenIds[i][j],
                            k,
                            uint128(positionBalanceArray[j][1])
                        )
                    );

                    if (tokenIds[i][j].isLong(k) == 0) {
                        unchecked {
                            poolExposure0 += int256(amount0);
                            poolExposure1 += int256(amount1);
                        }
                    } else {
                        unchecked {
                            poolExposure0 -= int256(amount0);
                            poolExposure1 -= int256(amount1);
                        }
                    }
                }

                (LeftRightSigned longAmounts, LeftRightSigned shortAmounts) = PanopticMath
                    .computeExercisedAmounts(tokenIds[i][j], uint128(positionBalanceArray[j][1]));

                poolExposure0 += int256(longAmounts.rightSlot()) - int256(shortAmounts.rightSlot());
                poolExposure1 += int256(longAmounts.leftSlot()) - int256(shortAmounts.leftSlot());

                numLegs += positionLegs;
            }

            if (numLegs != pools[i].pool.numberOfLegs(_vault)) revert IncorrectPositionList();

            if (address(pools[i].token0) == address(0))
                pools[i].token0 = IERC20Partial(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

            bool skipToken0 = false;
            bool skipToken1 = false;

            // optimized for small number of pools
            for (uint256 j = 0; j < underlyingTokens.length; j++) {
                if (underlyingTokens[j] == address(pools[i].token0)) skipToken0 = true;
                if (underlyingTokens[j] == address(pools[i].token1)) skipToken1 = true;

                if (underlyingTokens[j] == address(0)) {
                    if (!skipToken0) underlyingTokens[j] = address(pools[i].token0);
                    // ensure a gap is not created in the underlyingTokens array
                    if (!skipToken1)
                        underlyingTokens[j + (skipToken0 ? 0 : 1)] = address(pools[i].token1);
                    break;
                }
            }

            if (!skipToken0)
                poolExposure0 += address(pools[i].token0) ==
                    address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)
                    ? int256(address(_vault).balance)
                    : int256(pools[i].token0.balanceOf(_vault));
            if (!skipToken1) poolExposure1 += int256(pools[i].token1.balanceOf(_vault));

            uint256 collateralBalance = pools[i].pool.collateralToken0().balanceOf(_vault);
            poolExposure0 += int256(
                pools[i].pool.collateralToken0().previewRedeem(collateralBalance)
            );

            collateralBalance = pools[i].pool.collateralToken1().balanceOf(_vault);
            poolExposure1 += int256(
                pools[i].pool.collateralToken1().previewRedeem(collateralBalance)
            );

            // convert position values to underlying
            if (address(pools[i].token0) != underlyingToken) {
                int24 conversionTick = PanopticMath.twapFilter(
                    pools[i].oracle0,
                    pools[i].twapWindow
                );
                if (
                    Math.abs(conversionTick - managerPrices[i].token0Price) >
                    pools[i].maxPriceDeviation
                ) revert StaleOraclePrice();

                uint160 conversionPrice = Math.getSqrtRatioAtTick(
                    pools[i].isUnderlyingToken0InOracle0 ? -conversionTick : conversionTick
                );

                poolExposure0 = PanopticMath.convert0to1(poolExposure0, conversionPrice);
            }

            if (address(pools[i].token1) != underlyingToken) {
                int24 conversionTick = PanopticMath.twapFilter(
                    pools[i].oracle1,
                    pools[i].twapWindow
                );
                if (
                    Math.abs(conversionTick - managerPrices[i].token1Price) >
                    pools[i].maxPriceDeviation
                ) revert StaleOraclePrice();

                uint160 conversionPrice = Math.getSqrtRatioAtTick(
                    pools[i].isUnderlyingToken0InOracle1 ? conversionTick : -conversionTick
                );

                poolExposure1 = PanopticMath.convert1to0(poolExposure1, conversionPrice);
            }

            // debt in pools with negative exposure does not need to be paid back
            nav += uint256(Math.max(poolExposure0 + poolExposure1, 0));
        }

        // underlying cannot be native (0x000/0xeee)
        bool skipUnderlying = false;
        for (uint256 i = 0; i < underlyingTokens.length; i++) {
            if (underlyingTokens[i] == underlyingToken) skipUnderlying = true;
        }
        if (!skipUnderlying) nav += IERC20Partial(underlyingToken).balanceOf(_vault);
    }
}
