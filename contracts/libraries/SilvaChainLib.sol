// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import {MerkleTree} from "../utils/MerkleTree.sol";
import {Borsh} from "../utils/borsh/Borsh.sol";

library SilvaChainLib {
    using Borsh for Borsh.Data;
    using SilvaChainLib for Borsh.Data;
    using MerkleTree for Borsh.Data;
    
    struct HeaderState {
        uint16 chainId;
        uint64 height;
        bytes32 stateHash;
    }
    
    struct Log {
        bytes32 ContractAddress;
        bytes32 topicSig;
        bytes data;
    }

    struct SilvaProof {
        uint16 chainId;
        uint64 height;
        bytes32 receiptRoot;
        bytes32 headerInfo;
        MerkleTree.MerklePath proofPath;
    }

    function headerStateHash(
        SilvaProof memory proof
    ) internal pure returns (bytes32 hash) {
        bytes32 state = keccak256(
            abi.encodePacked(proof.receiptRoot, proof.headerInfo)
        );
        hash = keccak256(abi.encodePacked(proof.chainId, proof.height, state));
    }

    function decodeHeaderStates(
        Borsh.Data memory data
    ) internal pure returns (HeaderState[] memory headers) {
        uint length = data.decodeU32();
        headers = new HeaderState[](length);
        for (uint i = 0; i < length; i++) {
            headers[i] = data.decodeHeaderState();
        }
    }

    function decodeHeaderState(
        Borsh.Data memory data
    ) internal pure returns (HeaderState memory header) {
        header.chainId = data.decodeU16();
        header.height = data.decodeU64();
        header.stateHash = data.decodeBytes32();
    }

    function decodeSilvaProof(
        Borsh.Data memory data
    ) internal pure returns (SilvaProof memory silvaProof) {
        silvaProof.chainId = data.decodeU16();
        silvaProof.height = data.decodeU64();
        silvaProof.receiptRoot = data.decodeBytes32();
        silvaProof.headerInfo = data.decodeBytes32();
        silvaProof.proofPath = data.decodeMerklePath();
    }
}
