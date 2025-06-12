// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;
import {ChallengeLib} from "../../libraries/ChallengeLib.sol";
import "../../interfaces/safety/challenge/ISilvaChallengeManager.sol";
interface ISilvaChallengeResultReceiver {
    /// @dev resolve challenge
    function settleChallenge(
        uint64 challengeIndex,
        address winner,
        address loser,
        bool bothWin
    ) external;
}
abstract contract Bisector is ISilvaChallengeManager {
    using ChallengeLib for ChallengeLib.Challenge;
    mapping(uint64 => ChallengeLib.Challenge) public challenges;
    uint public constant MAX_CHALLENGE_DEGREE = 30;
    uint64 public totalChallengeCreated;

    /// @dev bisect state segment
    function bisectSegment(
        ChallengeLib.Action calldata action,
        ChallengeLib.ChallState calldata oldState,
        bytes32[] calldata newSegments
    ) external {

        beforeCheck(action, ChallengeLib.BISECT, oldState);

        {
            uint64 expectedDegree = ChallengeLib.positiveLength(oldState.start, oldState.end);
            require(expectedDegree > 1,"TOO_SHORT");
            if (expectedDegree > MAX_CHALLENGE_DEGREE) {
                expectedDegree = uint64(MAX_CHALLENGE_DEGREE);
            }
            require(newSegments.length == expectedDegree + 1, "WRONG_DEGREE");
            validEndpoint(oldState, newSegments[0], newSegments[newSegments.length - 1]);
        }

        uint64 seq = action.seq + 1;
        updateChallenge(action.index, seq, oldState.chainId, oldState.start, oldState.end, newSegments, bytes32(0));
        (address responder, uint deadline) = _takeTurn(action.index, ChallengeLib.BISECT, ChallengeLib.CHOOSE);
        emit Published(action.index, seq, ChallengeLib.BISECT, responder, deadline,  Dispute(oldState.chainId, oldState.start, oldState.end, newSegments, bytes32(0))); 
    }

    function validEndpoint(ChallengeLib.ChallState calldata oldState, bytes32 startPoint, bytes32 endPoint) internal pure {
        require(oldState.segments[0] == startPoint, "WRONG_START");
        require(oldState.segments[1] == endPoint, "WRONG_END");
    }

    /// @dev choose dispute
    function chooseSegment(
        ChallengeLib.Action calldata action,                                      
        ChallengeLib.ChallState calldata oldState,
        uint64 claimPosition
    ) external  {

        beforeCheck(action, ChallengeLib.CHOOSE, oldState);

        uint64 challengeStart;
        uint64 challengeEnd;
        {
            require(claimPosition > 0 && claimPosition < oldState.segments.length,"WRONG_CLAIM_POSITION");

            (challengeStart, challengeEnd) = ChallengeLib.recoverSegments(oldState.start, oldState.end, claimPosition, oldState.segments);
        }
        uint32 nextStep = ChallengeLib.CHOOSE;
        if(ChallengeLib.positiveLength(challengeStart, challengeEnd) == 1){
            nextStep = ChallengeLib.PUBLISH1;
        }

        bytes32[] memory newSegments = new bytes32[](2);
        newSegments[0] = oldState.segments[claimPosition - 1];
        newSegments[1] = oldState.segments[claimPosition];

        uint64 seq = action.seq + 1;
        updateChallenge(action.index, seq, oldState.chainId,  challengeStart, challengeEnd, newSegments, bytes32(0));
        (address responder, uint deadline) = _takeTurn(action.index, ChallengeLib.CHOOSE, nextStep);
        Dispute memory ds = Dispute(oldState.chainId, oldState.start, oldState.end, newSegments, bytes32(0));
        emit Published(action.index, seq, nextStep, responder, deadline, ds);
    }

    function timeout(uint64 challengeIndex) external {
        ChallengeLib.Challenge storage challenge = challenges[challengeIndex];
        require(challenge.isTimedOut(), "NOT_DEADLINE");
        address current = challenge.currentResponder();
        address next = challenge.nextResponder();
        uint32 step = challenge.step & 0xffff0000;
        if (step == ChallengeLib.PUBLISH2) {
            ISilvaChallengeResultReceiver(challenge.settleAddress).settleChallenge(challengeIndex, next, current, true);
        } else {
            ISilvaChallengeResultReceiver(challenge.settleAddress).settleChallenge(challengeIndex, next, current, false);
        }
        challenge.step = ChallengeLib.SETTLE;

        delete challenges[challengeIndex];
        emit ChallengeEnded(challengeIndex);
    }


    function getPlayers(uint64 challengeIndex) external view returns(address referee, address attester) {
        
    }

    function getChallengeStep(uint64 challengeIndex) external view returns(uint32 step) {

    }

    function _takeTurn(uint64 challengeIndex, uint32 currentStep, uint32 nextStep) internal returns (address, uint){
        ChallengeLib.Challenge storage c = challenges[challengeIndex];
        c.step = nextStep;
        if (currentStep == ChallengeLib.BISECT) {
            c.attester.timeLeft -= block.timestamp - c.lastMoveTimestamp;
        } else {
            c.referee.timeLeft -= block.timestamp - c.lastMoveTimestamp;
        }
        c.lastMoveTimestamp = block.timestamp;
        c.responder = ChallengeLib.turn(c.responder);
        return (c.currentResponder(), c.lastMoveTimestamp + c.currentTimeLeft());
    }
    
    function updateChallenge(        
        uint64 index,
        uint64 seq,
        uint16 chainId,
        uint64 challengeStart,
        uint64 challengeEnd,
        bytes32[] memory segments,
        bytes32 extra
    ) internal {
        require(segments.length >= 2, "UNEXPECTED_SEGMENT_SIZE");
        challenges[index].challengeState = ChallengeLib.challengeStateHash(
            seq,
            chainId,
            challengeStart,
            challengeEnd,
            segments,
            extra
        );
    }

    function beforeCheck(ChallengeLib.Action calldata action,  uint32  should, ChallengeLib.ChallState calldata oldState) internal view {
        ChallengeLib.Challenge storage c = challenges[action.index];
        // step check
        require(c.step & should != 0, "WRONG_STEP");
        // timeout check
        require(c.isTimedOut(), "CHAL_DEADLINE");
        // responder check
        require(msg.sender == c.currentResponder(), "CHAL_SENDER");
        // segment length check
        require(ChallengeLib.positiveLength(oldState.start, oldState.end) >= 1,"UNEXPECTED_SEGMENT_LENGTH");
        // challenge progress state check
        require(
            c.challengeState == ChallengeLib.challengeStateHash(
                action.seq,
                oldState.chainId,
                oldState.start,
                oldState.end,
                oldState.segments,
                oldState.extra
                ),
            "CHALLENGE_STATE_ERROR"
        );
    }

    function currentResponder(
        uint64 challengeIndex
    ) public view returns (address) {
        return challenges[challengeIndex].currentResponder();
    }

    function isTimeout(uint64 challengeIndex) public view returns (bool) {
        return challenges[challengeIndex].isTimedOut();
    }

    function getChallenge(uint64 challengeIndex) external view returns(ChallengeLib.Challenge memory) {
        return challenges[challengeIndex];
    }

}