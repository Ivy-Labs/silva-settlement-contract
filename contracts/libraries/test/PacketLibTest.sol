pragma solidity ^0.8;
import {PacketLib} from "../PacketLib.sol";

contract PacketLibTest {

    function getPacket(bytes memory data, uint sizeOfSrcAddress, bytes32 srcSilvaAddress) external pure returns(PacketLib.Packet memory) {
        return PacketLib.getPacket(data, sizeOfSrcAddress, srcSilvaAddress);
    }    
}