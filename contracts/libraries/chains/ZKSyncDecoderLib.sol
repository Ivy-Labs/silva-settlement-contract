// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import {Borsh} from "../../utils/borsh/Borsh.sol";

library ZKSyncDecoderLib {
    using Borsh for Borsh.Data;
    using ZKSyncDecoderLib for Borsh.Data;
    using ZKSyncDecoderLib for ZKSyncHeader;

    // https://github.com/matter-labs/era-contracts/blob/87cd8d7b0f8c02e9672c0603a821641a566b5dd8/l1-contracts/contracts/zksync/interfaces/IExecutor.sol#L38C29-L38C29
    struct BatchInfo {
        uint64 batchNumber;
        bytes32 batchHash;
        uint64 indexRepeatedStorageChanges;
        uint256 numberOfLayer1Txs;
        bytes32 priorityOperationsHash;
        bytes32 l2LogsTreeRoot;
        uint256 timestamp;
        bytes32 commitment;
    }


    function decodeBatchInfo(Borsh.Data memory data) internal pure returns (BatchInfo memory blockInfo) {
        blockInfo.batchNumber = data.decodeU64();
        blockInfo.batchHash = data.decodeBytes32();
        blockInfo.indexRepeatedStorageChanges = data.decodeU64();
        blockInfo.numberOfLayer1Txs = data.decodeU256();
        blockInfo.priorityOperationsHash = data.decodeBytes32();
        blockInfo.l2LogsTreeRoot = data.decodeBytes32();
        blockInfo.timestamp = data.decodeU256();
        blockInfo.commitment = data.decodeBytes32();
    }

    function blockInfoHash(BatchInfo memory blockInfo) internal pure returns (bytes32 hash) {
        hash = keccak256(abi.encode(blockInfo));
    }

    struct ZKSyncHeader {
        bytes32 stateRoot;
        uint256 batchNumber;
    }

    function decodeZKSyncHeader(Borsh.Data memory data) internal pure returns (ZKSyncHeader memory zkHeader) {
        zkHeader.stateRoot = data.decodeBytes32();
        zkHeader.batchNumber = data.decodeU256();
    }

    function zksyncHeaderState(ZKSyncHeader memory zkHeader) internal pure returns (bytes32 state) {
        state = keccak256(abi.encodePacked(zkHeader.stateRoot, zkHeader.batchNumber));
    }
  
}
