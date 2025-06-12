// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

library ChallengeLib {
    using ChallengeLib for Challenge;

    struct Segment {
        uint64 height;
        bytes32 stateHash;
    }

    uint32 constant PUBLISH1 = 0x00010000;
    uint32 constant PUBLISH2 = 0x00020000;
    uint32 constant CHALLENGE = 0x00040000;
    uint32 constant BISECT = 0x00080000;
    uint32 constant CHOOSE = 0x00100000;
    uint32 constant END = 0x00200000;
    uint32 constant SETTLE = 0x00400000;
    uint constant HOUR = 60 * 60;


    function validStep(uint32 step) internal pure {
        require( step & (PUBLISH1|PUBLISH2|CHALLENGE|BISECT|CHOOSE|END) != 0, "INVALID_STEP");
    }                               



    struct Player {
        address addr;
        uint256 timeLeft;
    }

    struct Challenge {
        uint32 war;
        uint16 chainId;
        uint32 step;
        Player attester;
        Player referee;
        uint8 responder;  // 0-referee, 1-attester
        address settleAddress;
        uint256 lastMoveTimestamp;
        bytes32 challengeState;
    }

    struct Game {
        Round round;
        ChallState state;            
    }

    struct Round {
        uint32 step;
        uint timeLeft;
    }

    struct Action {
        uint64 index;
        uint64 seq;
    }

    struct ChallState {
        uint16 chainId;
        uint64 start;
        uint64 end;
        bytes32[] segments;
        bytes32 extra;
    }

    function challengeStateHash(
        uint64 seq,
        uint16 chainId,
        uint64 start,
        uint64 end,
        bytes32[] memory segments,
        bytes32 extra
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(chainId, seq, start, end, segments, extra));
    }

    function recoverSegments(
        uint64 start, uint64 end, uint64 claimPosition, bytes32[] calldata segments
    ) internal pure returns (uint64 segmentStart, uint64 segmentEnd) {
        uint64 oldBisectDegree = uint64(segments.length) - 1;
        uint64 oldSegmentLength = positiveLength(start, end);
        uint64 segmentLength = oldSegmentLength / oldBisectDegree;
        if (start > end) {
            segmentStart = start - segmentLength * (claimPosition - 1);
            segmentEnd = segmentStart - segmentLength;
            if (claimPosition == segments.length - 1) {
                segmentEnd -= oldSegmentLength % oldBisectDegree;
            }
            require(segmentStart > segmentEnd, "SEGMENT_ERROR");
        } else {
            segmentStart = start + segmentLength * (claimPosition - 1);
            segmentEnd = segmentStart + segmentLength;
            if (claimPosition == segments.length - 1) {
                segmentEnd += oldSegmentLength % oldBisectDegree;
            }
            require(segmentStart < segmentEnd, "SEGMENT_ERROR");
        }
    }

    function isTimedOut(
        Challenge storage challenge
    ) internal view returns (bool) {
        return challenge.timeUsedSinceLastMove() > challenge.currentTimeLeft();
    }

    function currentResponder(Challenge storage challenge) internal view returns (address) {
        return challenge.responder == 1 ? challenge.attester.addr : challenge.referee.addr;
    }

    function nextResponder(Challenge storage challenge) internal view returns (address) {
        return challenge.responder == 0 ? challenge.attester.addr : challenge.referee.addr;
    }

    function currentTimeLeft(Challenge storage challenge) internal view returns (uint) {
        return challenge.responder == 1 ? challenge.attester.timeLeft : challenge.referee.timeLeft;
    }

    function turn(uint8 current) internal pure returns (uint8) {
        return uint8((current^0xff)&0x01);
    }

    function timeUsedSinceLastMove(
        Challenge storage challenge
    ) internal view returns (uint256) {
        return block.timestamp - challenge.lastMoveTimestamp;
    }

    function positiveLength(
        uint64 start,
        uint64 end
    ) internal pure returns (uint64) {
        if (start < end) {
            return end -= start;
        } else {
            return start -= end;
        }
    }
}
