// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import {Borsh} from "./borsh/Borsh.sol";
import {RLPReader} from "./rlp/RLPReader.sol";

library MerkleTree {
    using Borsh for Borsh.Data;
    using MerkleTree for Borsh.Data;
    using RLPReader for RLPReader.RLPItem;

    struct MerklePath {
        bytes32[] items;
        uint index;
    }

    function computeRoot(
        MerklePath memory proof,
        bytes32 leaf
    ) internal pure returns (bytes32 hash) {
        hash = leaf;
        for (uint i = 0; i < proof.items.length; i++) {
             if((proof.index >> i) & 0x01 == 1) {
                hash = keccak256(abi.encodePacked(proof.items[i], hash));
            } else {
                hash = keccak256(abi.encodePacked(hash, proof.items[i]));
            }
        }
    }
    function computeRootSha256(
        MerklePath memory proof,
        bytes32 leaf
    ) internal pure returns (bytes32 hash) {
        hash = leaf;
        for (uint i = 0; i < proof.items.length; i++) {
             if((proof.index >> i) & 0x01 == 1) {
                hash = sha256(abi.encodePacked(proof.items[i], hash));
            } else {
                hash = sha256(abi.encodePacked(hash, proof.items[i]));
            }
        }
    }

    function decodeMerklePath(
        Borsh.Data memory data
    ) internal pure returns (MerklePath memory path) {
        uint len = data.decodeU32();
        path.items = new bytes32[](len);
        for (uint i = 0; i < len; i++) {
            path.items[i] = data.decodeBytes32();
        }
        path.index = uint(data.decodeBytes32());
    }

    // 构建Merkle Tree
    function buildMerkleTree(
        bytes32[] memory leaves
    ) internal pure returns (bytes32) {
        if (leaves.length == 0) {
            return bytes32(0);
        }
        uint height = ceilLog2(leaves.length);
        uint size = leaves.length;
        for (uint h = 0; h < height; h++) {
            uint index = 0;
            for (uint i = 0; i < size; i += 2) {
                index = i / 2;
                if (i == size - 1 && i % 2 == 0) {
                    // 数量不是2的幂，直接使用原hash
                    leaves[index] = leaves[i];
                    continue;
                }
                leaves[index] = keccak256(
                    abi.encodePacked(leaves[i], leaves[i + 1])
                );
            }
            size = index + 1;
        }
        return leaves[0];
    }

    function buildMerkleTreeSha256(bytes32[] memory leaves) internal pure returns (bytes32) {
        if (leaves.length == 0) {
            return bytes32(0);
        }
        uint height = ceilLog2(leaves.length);
        uint size = leaves.length;
        for (uint h = 0; h < height; h++) {
            uint index = 0;
            for (uint i = 0; i < size; i += 2) {
                index = i / 2;
                if (i == size - 1 && i % 2 == 0) {
                    // 数量不是2的幂，直接使用原hash
                    leaves[index] = leaves[i];
                    continue;
                }
                leaves[index] = sha256(
                    abi.encodePacked(leaves[i], leaves[i + 1])
                );
            }
            size = index + 1;
        }
        return leaves[0];
    }

    // not safe
    function ceilLog2(uint x) internal pure returns (uint y) {
        y = 0;
        x -= 1;
        while (x > 0) {
            x >>= 1;
            y++;
        }
    }


    // MPT proof
    struct MPTPath {
        bytes[] nodes;
        uint[] paths;
    }

    struct LogPath {
        MPTPath mptPath;
        uint logIndex;
    }

    function decodeLogPath(Borsh.Data memory data) internal pure returns(LogPath memory path) {
        path.mptPath = data.decodeMPTPath();
        path.logIndex = data.decodeU32();
    }


    function decodeMPTPath(
        Borsh.Data memory data
    ) internal pure returns (MPTPath memory path) {
        uint len1 = data.decodeU32();
        path.nodes = new bytes[](len1);
        for (uint i = 0; i < len1; i++) {
            path.nodes[i] = data.decodeBytes();
        }
        uint len2 = data.decodeU32();
        require(len1 > 0 && len2 == len1, "PROOF_INDEX_LENGTH_DIFFERENT");
        path.paths = new uint[](len2);
        for (uint i = 0; i < len2; i++) {
            path.paths[i] = data.decodeU32();
        }
    }

    function validateMPTProof(
        MPTPath memory path,
        bytes32 root
    ) internal pure returns (bytes memory) {
        RLPReader.RLPItem memory item;
        bytes memory itemBytes;
        for (uint i = 0; i < path.nodes.length; i++) {
            itemBytes = path.nodes[i];
            require(
                root == keccak256(itemBytes),
                "INVALID_MPT_PROOF"
            );
            item = RLPReader.toRlpItem(itemBytes).safeGetItemByIndex(
                path.paths[i]
            );

            if (i < path.nodes.length - 1) {
                root = bytes32(item.toUint());
            }
        }
        // TODO: use mcopy
        return item.toBytes();
    }

    function validateMPTPProofWithKey(MPTPath memory path, bytes32 root) internal pure returns (bytes memory itemBytes, bytes32) {
       RLPReader.RLPItem memory item;
        uint key = 0;
        uint shifted = 0;
        for (uint i = 0; i < path.nodes.length ; i++) {
            // recovery mpt key
            itemBytes = path.nodes[i];
            require(root == keccak256(itemBytes), "INVALID_MPT_PROOF");
            item = RLPReader.toRlpItem(itemBytes);
            if(item.numItems() == 2){
                bytes memory reaminKey = item.safeGetItemByIndex(0).toBytes();
                uint8 byte0;
                assembly{
                    byte0:=byte(0, mload(add(reaminKey,32)))
                }
                byte0 = byte0 >> 4;  
                bytes32 tk = bytes32(reaminKey);  // less than 32 bytes
                if (byte0 == 0) {  // extention node
                    shifted = reaminKey.length*8 - 8;
                    tk = tk << 8;
                } else if (byte0 ==1) {  // extention node
                    shifted = reaminKey.length*8 - 4;
                    tk = tk << 4;
                } else if (byte0 == 2) {  // leaf node
                    shifted = reaminKey.length*8 - 8;
                    tk = tk << 8;
                } else if (byte0 == 3) {  // leaf node
                    shifted = reaminKey.length*8 - 4;
                    tk = tk << 4;
                }
                tk = tk >> (256 - shifted);
                key = key << shifted | uint(tk);     
            } else {
                // branch node
                key = key << 4 | path.paths[i];
            }
            item = item.safeGetItemByIndex(path.paths[i]);
            if (i < path.nodes.length - 1) {
                root = bytes32(item.toUint());
            }
        }
        return (item.toBytes(), bytes32(key));
    }
}
