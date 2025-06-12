// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import {PacketLib} from "../../libraries/PacketLib.sol";
import {SilvaChainLib} from "../../libraries/SilvaChainLib.sol";
import {MerkleTree} from "../../utils/MerkleTree.sol";
interface ISilvaChainManager {

    enum ChainType {
        ROLLUP,
        BRIDGE
    }

    struct BasicConfig{
        ChainType chainType;
        bool challengeable;
        uint64 addressSize;
        address verifier;
        bytes32 srcSilvaAddres;
    }


    struct ChainConfigB {
        uint64 srcHeight;
        address srcChainLib;
        bytes32 srcGenesis;
    }

    struct Auth {
        address signer;
        uint64 validEpoch;
    }
    struct ChainConfigR {
        uint64 srcHeight;
        address srcChainLib;
        bytes32 srcGenesis;
        Auth[] history;
    }

    event AddSilvaBlock(
        uint64 indexed silvaHeight,
        bytes32 combinedRoot,
        bytes data
    );

    event AddChain(
        uint16 chainId,
        uint64 srcAddressSize,
        uint64 srcHeight,
        address srcChainLib,
        address verifier,
        bytes32 srcChainSilva,
        bytes32 srcGenesis
    );

    event AddChainConfig(
        uint16 chainId,
        uint64 srcHeight,
        address srcChainLib,
        bytes32 srcGenesis
    );

    event RemoveChain(uint16 chainId, uint64 height);

    event SetChallengeable(uint16 chainId, bool challengeable);

    function addChain(
        ChainType chainType,
        uint16 _chainId,
        uint64 _srcAddressSize,
        uint64 _srcHeight,
        address _srcChainLib,
        address _verifier,
        bytes32 _srcChainSilva,
        bytes32 _srcGenesis
    ) external;

    function removeChain(uint16 _chainId, uint64 height) external;

    function updateChainBridgeConfig(uint16 _chainId, uint16 flag, bytes memory _config) external;

    function updateRollupAuth(uint16 _chainId, bytes memory _config) external;

    function setChallengeable(uint16 _chainId, bool _challengeable) external;

    function getChainLib(uint16 _chainId, uint64 _height) external view returns (address);
    function getChainType(uint16 chainId) external view returns(ChainType chainType);
    function getDefaultHeader(uint16 _chainId, uint64 _height) external view returns(SilvaChainLib.HeaderState memory header);
    function challengeable(uint16 _chainId, uint64 _start,uint64 _end) external view returns(bool ok);
    function verifyReceipt(
        uint16 _chainId,
        bytes32 _root,
        bytes calldata _proof
    ) external view returns (PacketLib.Packet memory packet);
}
