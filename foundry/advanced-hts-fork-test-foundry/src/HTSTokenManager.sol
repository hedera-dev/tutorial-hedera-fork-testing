// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import {IHederaTokenService} from "hedera-forking/IHederaTokenService.sol";

/// @title HTSTokenManager
/// @notice Manages HTS fungible tokens via the Hedera Token Service precompile (0x167).
/// @dev Adapted from the Hardhat advanced HTS tutorial for Foundry usage.
///      This contract serves as treasury and holds both supply and admin keys
///      for tokens it creates.
///
///      The HTS precompile at address(0x167) is a Hedera-native system contract.
///      In fork testing, the hedera-forking library provides a Solidity emulation
///      layer that responds to the same function signatures at the same address.
contract HTSTokenManager {

    // -----------------------------------------------------------------------
    // Constants
    // -----------------------------------------------------------------------

    /// @dev The HTS precompile lives at this fixed address on Hedera.
    address constant HTS_PRECOMPILE = address(0x167);

    /// @dev HTS response code indicating success.
    int32 constant SUCCESS = 22;

    // -----------------------------------------------------------------------
    // State
    // -----------------------------------------------------------------------

    /// @notice The address of the last token created by this contract.
    address public tokenAddress;

    // -----------------------------------------------------------------------
    // Events
    // -----------------------------------------------------------------------

    event ResponseCode(int256 responseCode);
    event CreatedToken(address tokenAddress);
    event MintedToken(int64 newTotalSupply, int64[] serialNumbers);
    event TransferToken(address tokenAddress, address receiver, int64 amount);
    event TokenInfo(IHederaTokenService.TokenInfo tokenInfo);
    event FungibleTokenInfo(IHederaTokenService.FungibleTokenInfo tokenInfo);

    // -----------------------------------------------------------------------
    // Receive HBAR
    // -----------------------------------------------------------------------

    /// @dev Accept HBAR sent to this contract (needed to fund token creation).
    receive() external payable {}

    // -----------------------------------------------------------------------
    // Token Creation
    // -----------------------------------------------------------------------

    /// @notice Create an HTS fungible token with this contract as treasury.
    /// @dev Requires msg.value to cover the Hedera token creation fee (~$1 in HBAR).
    ///      The contract itself is assigned as both admin key and supply key so it
    ///      can mint and manage the token after creation.
    /// @param _name  Display name of the token
    /// @param _symbol Ticker symbol of the token
    function createFungibleTokenPublic(
        string memory _name,
        string memory _symbol
    ) public payable {
        // Build the HederaToken struct
        IHederaTokenService.HederaToken memory token;
        token.name = _name;
        token.symbol = _symbol;
        token.treasury = address(this);
        token.memo = "Created via HTSTokenManager";

        // Assign supply key and admin key to this contract
        IHederaTokenService.TokenKey[]
            memory keys = new IHederaTokenService.TokenKey[](2);

        // Supply key - bit 4 (0x10) in keyType bitmap
        keys[0] = IHederaTokenService.TokenKey({
            keyType: 0x10, // SUPPLY
            key: IHederaTokenService.KeyValue({
                inheritAccountKey: false,
                contractId: address(this),
                ed25519: bytes(""),
                ECDSA_secp256k1: bytes(""),
                delegatableContractId: address(0)
            })
        });

        // Admin key - bit 0 (0x01) in keyType bitmap
        keys[1] = IHederaTokenService.TokenKey({
            keyType: 0x01, // ADMIN
            key: IHederaTokenService.KeyValue({
                inheritAccountKey: false,
                contractId: address(this),
                ed25519: bytes(""),
                ECDSA_secp256k1: bytes(""),
                delegatableContractId: address(0)
            })
        });

        token.tokenKeys = keys;

        // Expiry - auto-renew via this contract, 90-day period
        token.expiry = IHederaTokenService.Expiry({
            second: 0,
            autoRenewAccount: address(this),
            autoRenewPeriod: 7_776_000 // 90 days in seconds
        });

        // Call HTS precompile to create the token
        (int256 responseCode, address createdToken) = IHederaTokenService(
            HTS_PRECOMPILE
        ).createFungibleToken{value: msg.value}(token, 0, 8);

        emit ResponseCode(responseCode);

        if (responseCode != SUCCESS) {
            revert("HTS: token creation failed");
        }

        tokenAddress = createdToken;
        emit CreatedToken(createdToken);
    }

    // -----------------------------------------------------------------------
    // Token Minting
    // -----------------------------------------------------------------------

    /// @notice Mint additional fungible tokens.
    /// @param token  The HTS token address to mint
    /// @param amount The amount to mint
    function mintTokenPublic(
        address token,
        int64 amount
    )
        public
        returns (
            int256 responseCode,
            int64 newTotalSupply,
            int64[] memory serialNumbers
        )
    {
        bytes[] memory metadata;

        (responseCode, newTotalSupply, serialNumbers) = IHederaTokenService(
            HTS_PRECOMPILE
        ).mintToken(token, amount, metadata);

        emit ResponseCode(responseCode);

        if (responseCode != SUCCESS) {
            revert("HTS: mint failed");
        }

        emit MintedToken(newTotalSupply, serialNumbers);
    }

    // -----------------------------------------------------------------------
    // Token Transfer
    // -----------------------------------------------------------------------

    /// @notice Transfer HTS tokens between accounts.
    /// @param token    The HTS token address
    /// @param sender   The sender address (must have sufficient balance)
    /// @param receiver The recipient address
    /// @param amount   The amount to transfer
    function transferTokenPublic(
        address token,
        address sender,
        address receiver,
        int64 amount
    ) public returns (int256 responseCode) {
        responseCode = IHederaTokenService(HTS_PRECOMPILE).transferToken(
            token,
            sender,
            receiver,
            amount
        );

        emit ResponseCode(responseCode);

        if (responseCode != SUCCESS) {
            revert("HTS: transfer failed");
        }

        emit TransferToken(token, receiver, amount);
    }

    // -----------------------------------------------------------------------
    // Token Queries
    // -----------------------------------------------------------------------

    /// @notice Get full token info for an HTS token.
    /// @param token The HTS token address to query
    function getTokenInfoPublic(
        address token
    )
        public
        returns (
            int256 responseCode,
            IHederaTokenService.TokenInfo memory tokenInfo
        )
    {
        (responseCode, tokenInfo) = IHederaTokenService(HTS_PRECOMPILE)
            .getTokenInfo(token);

        emit ResponseCode(responseCode);
        emit TokenInfo(tokenInfo);
    }

    /// @notice Get fungible-specific token info for an HTS token.
    /// @param token The HTS token address to query
    function getFungibleTokenInfoPublic(
        address token
    )
        public
        returns (
            int256 responseCode,
            IHederaTokenService.FungibleTokenInfo memory tokenInfo
        )
    {
        (responseCode, tokenInfo) = IHederaTokenService(HTS_PRECOMPILE)
            .getFungibleTokenInfo(token);

        emit ResponseCode(responseCode);
        emit FungibleTokenInfo(tokenInfo);
    }
}
