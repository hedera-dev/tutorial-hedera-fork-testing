// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@hashgraph/smart-contracts/contracts/system-contracts/hedera-token-service/HederaTokenService.sol";
import "@hashgraph/smart-contracts/contracts/system-contracts/hedera-token-service/ExpiryHelper.sol";
import "@hashgraph/smart-contracts/contracts/system-contracts/hedera-token-service/KeyHelper.sol";
import "@hashgraph/smart-contracts/contracts/system-contracts/HederaResponseCodes.sol";
import "@hashgraph/smart-contracts/contracts/system-contracts/hedera-token-service/IHederaTokenService.sol";
import "@hashgraph/smart-contracts/contracts/system-contracts/hedera-token-service/FeeHelper.sol";

contract HTSTokenManager is
    HederaTokenService,
    ExpiryHelper,
    KeyHelper,
    FeeHelper
{
    bool finiteTotalSupplyType = true;

    event ResponseCode(int256 responseCode);
    event CreatedToken(address tokenAddress);
    event FungibleTokenInfo(IHederaTokenService.FungibleTokenInfo tokenInfo);
    event TransferToken(address tokenAddress, address receiver, int64 amount);
    event MintedToken(int64 newTotalSupply, int64[] serialNumbers);

    /**
     * @notice Creates a new fungible token using HTS
     */
    function createFungibleTokenPublic(
        string memory _name,
        string memory _symbol
    ) public payable {
        // Build token definition
        IHederaTokenService.HederaToken memory token;
        token.name = _name;
        token.symbol = _symbol;
        token.treasury = address(this);
        token.memo = "This is a fungible token";

        // Keys: SUPPLY + ADMIN -> contractId
        IHederaTokenService.TokenKey[]
            memory keys = new IHederaTokenService.TokenKey[](2);
        keys[0] = getSingleKey(
            KeyType.SUPPLY,
            KeyValueType.CONTRACT_ID,
            address(this)
        );
        keys[1] = getSingleKey(
            KeyType.ADMIN,
            KeyValueType.CONTRACT_ID,
            address(this)
        );
        token.tokenKeys = keys;

        (int256 responseCode, address tokenAddress) = HederaTokenService
            .createFungibleToken(token, 0, 0);

        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert();
        }
        emit CreatedToken(tokenAddress);
    }

    /**
     * @notice Mints tokens
     */
    function mintTokenPublic(
        address token,
        int64 amount,
        bytes[] memory metadata
    )
        public
        returns (
            int256 responseCode,
            int64 newTotalSupply,
            int64[] memory serialNumbers
        )
    {
        (responseCode, newTotalSupply, serialNumbers) = HederaTokenService
            .mintToken(token, amount, metadata);
        emit ResponseCode(responseCode);

        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert();
        }

        emit MintedToken(newTotalSupply, serialNumbers);
    }

    /**
     * @notice Transfers tokens using HTS transferToken
     * @dev This is a SUPPORTED method in hedera-forking
     */
    function transferTokenPublic(
        address token,
        address sender,
        address receiver,
        int64 amount
    ) public returns (int256 responseCode) {
        responseCode = HederaTokenService.transferToken(
            token,
            sender,
            receiver,
            amount
        );
        emit ResponseCode(responseCode);

        if (responseCode != HederaResponseCodes.SUCCESS) {
            revert();
        }
    }

    /**
     * @notice Gets token info
     */
    function getTokenInfoPublic(
        address token
    )
        public
        returns (
            int256 responseCode,
            IHederaTokenService.TokenInfo memory tokenInfo
        )
    {
        (responseCode, tokenInfo) = HederaTokenService.getTokenInfo(token);
        emit ResponseCode(responseCode);
    }

    /**
     * @notice Gets fungible token info
     */
    function getFungibleTokenInfoPublic(
        address token
    )
        public
        returns (
            int256 responseCode,
            IHederaTokenService.FungibleTokenInfo memory tokenInfo
        )
    {
        (responseCode, tokenInfo) = HederaTokenService.getFungibleTokenInfo(
            token
        );
        emit ResponseCode(responseCode);
        emit FungibleTokenInfo(tokenInfo);
    }
}
