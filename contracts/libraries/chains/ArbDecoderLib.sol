// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;
import {Borsh} from "../../utils/borsh/Borsh.sol";
import {EVMHeaderLib} from "./EVMHeaderLib.sol";

library ArbDecoderLib {
    using Borsh for Borsh.Data;
    using EVMHeaderLib for Borsh.Data;
    using EVMHeaderLib for EVMHeaderLib.EVMHeader;
    struct Rollup{
        uint64 height;
        bytes32 blockHash;  // rlp hash
        bytes32 sendRoot;
    }

    function decodeRollup(Borsh.Data memory data) internal pure returns (Rollup memory rollup) {
        rollup.height = data.decodeU64();
        rollup.blockHash = data.decodeBytes32();
        rollup.sendRoot = data.decodeBytes32();
    }
    struct Node {
        // Hash of the state of the chain as of this node
        bytes32 stateHash;
        // Hash of the data that can be challenged
        bytes32 challengeHash;
        // Hash of the data that will be committed if this node is confirmed
        bytes32 confirmData;
        // Index of the node previous to this one
        uint64 prevNum;
        // Deadline at which this node can be confirmed
        uint64 deadlineBlock;
        // Deadline at which a child of this node can be confirmed
        uint64 noChildConfirmedBeforeBlock;
        // Number of stakers staked on this node. This includes real stakers and zombies
        uint64 stakerCount;
        // Number of stakers staked on a child node. This includes real stakers and zombies
        uint64 childStakerCount;
        // This value starts at zero and is set to a value when the first child is created. After that it is constant until the node is destroyed or the owner destroys pending nodes
        uint64 firstChildBlock;
        // The number of the latest child of this node to be created
        uint64 latestChildNumber;
        // The block number when this node was created
        uint64 createdAtBlock;
        // A hash of all the data needed to determine this node's validity, to protect against reorgs
        bytes32 nodeHash;
    }
    
    function arbHeaderStateHash(
        EVMHeaderLib.EVMHeader memory header
    ) internal pure returns (bytes32 hash) {
        hash = keccak256(
            abi.encodePacked(
                header.receiptsRoot,
                header.rlpEVMHeaderHash()
            )
        );
    }

    function validateRollup(Rollup memory rollup, EVMHeaderLib.EVMHeader memory l2Header) internal pure {
        bytes memory p = l2Header.extraData;
        bytes32 sendRoot = bytes32(0);
        if(p.length != 0){
            assembly{
                sendRoot:=mload(add(p,32))
            }
        }
        require(rollup.blockHash == l2Header.rlpEVMHeaderHash() &&  rollup.height == l2Header.number && rollup.sendRoot == sendRoot,"WRONG_ROLLUP");
    }

}
