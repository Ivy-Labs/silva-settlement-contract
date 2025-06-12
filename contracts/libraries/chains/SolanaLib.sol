// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;
import {Borsh} from "../../utils/borsh/Borsh.sol";
library SolanaLib {
    using Borsh for Borsh.Data;
    struct SolHeader {
        uint256 height;
        uint256 parentSlot;
        bytes32 blockHash;
        bytes32 parent;
    }

    function decodeSolHeader(Borsh.Data memory data) internal view returns(SolHeader memory header) {
        header.height = data.decodeU256();
        header.parentSlot = data.decodeU256();
        header.blockHash = data.decodeBytes32();
        header.parent = data.decodeBytes32();
    }

    function headerHash(SolHeader memory header) internal pure returns(bytes32 hash) {
        hash = keccak256(abi.encodePacked(header.height, header.parentSlot, header.blockHash, header.parent));
    } 

    function headerState(SolHeader memory header) internal pure returns(bytes32 hash) {
        hash = keccak256(abi.encodePacked(header.blockHash, headerHash(header)));
    }

}