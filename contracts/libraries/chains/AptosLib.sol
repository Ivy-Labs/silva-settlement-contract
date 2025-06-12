// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;
import {Borsh} from "../../utils/borsh/Borsh.sol";
library AptosLib {
    using Borsh for Borsh.Data;
    struct AptHeader{
        uint256 height;
        bytes32 blockHash;
        uint256 timestamp;
        uint64 firstVersion;
        uint64 lastVersion;
    }

    function decodeAptHeader(Borsh.Data memory data) internal pure returns(AptHeader memory header) {
        header.height = data.decodeU256();
        header.blockHash = data.decodeBytes32();
        header.timestamp = data.decodeU256();
        header.firstVersion = data.decodeU64();
        header.lastVersion = data.decodeU64();
    }

    function aptHeaderHash(AptHeader memory header) internal pure returns(bytes32 hash) {
        hash = keccak256(abi.encodePacked());
    }

    function aptHeaderState(AptHeader memory header) internal pure returns(bytes32 hash) {
        hash = keccak256(abi.encodePacked(header.blockHash, aptHeaderHash(header)));
    }

}