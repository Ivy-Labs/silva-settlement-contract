// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import {PacketLib} from "../../libraries/PacketLib.sol";

interface ISilvaVerification {
    function verifyReceipt(bytes32 _root, uint sizeOfSrcAddress, bytes calldata _proof) external pure returns(PacketLib.Packet memory packet);
}