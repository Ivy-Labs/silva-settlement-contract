// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;
import "./Bisector.sol";
import "../../interfaces/safety/challenge/ISilvaOneStepVM.sol";
contract ExecutionGame is Bisector {
    using ChallengeLib for ChallengeLib.Challenge;
    ISilvaOneStepVM vm;
    function createChallenge(
        uint16 chainId,
        address[2] memory participants,
        address settleAddress,
        ChallengeLib.Segment[2] memory segments
    ) external returns (uint64) {
        require(segments[0].height < segments[1].height, "ILLEGAL_HEIGHT");
        // initialize challenge
        uint64 challengeIndex = ++totalChallengeCreated;
        ChallengeLib.Challenge storage challenge = challenges[challengeIndex];
        challenge.referee = ChallengeLib.Player(participants[0], 0);
        challenge.attester = ChallengeLib.Player(participants[1], 0);
        challenge.chainId = chainId;
        challenge.settleAddress = settleAddress;
        challenge.lastMoveTimestamp = uint256(block.timestamp);
        if (segments[0].height + 1 == segments[1].height) {
            challenge.step = ChallengeLib.PUBLISH1;
        } else {
            challenge.step = ChallengeLib.BISECT;
        }

        bytes32[] memory segmentsHashs = new bytes32[](2);
        uint64 seq = 1;
        segmentsHashs[0] = segments[0].stateHash;
        segmentsHashs[1] = segments[1].stateHash;
        // update game
        updateChallenge(challengeIndex, seq, chainId, segments[0].height, segments[1].height, segmentsHashs, bytes32(0));
        Dispute memory dispute = Dispute(chainId, segments[0].height, segments[1].height, segmentsHashs, bytes32(0));
        
        emit Published(challengeIndex, seq, 0, challenge.attester.addr, challenge.lastMoveTimestamp, dispute);
        return challengeIndex;
    }

    function challengeExecution(ChallengeLib.Action calldata action, ChallengeLib.ChallState calldata oldState, uint256 numSteps) external {
        require(numSteps >= 1, "SHORT");
        beforeCheck(action, ChallengeLib.PUBLISH1, oldState);
        uint64 seq = action.seq + 1;
        updateChallenge(action.index, seq, oldState.chainId, 0, uint64(numSteps), oldState.segments, bytes32(0));
        (address responder, uint deadline) = _takeTurn(action.index, ChallengeLib.PUBLISH1, ChallengeLib.CHOOSE);
        Dispute memory dispute = Dispute(oldState.chainId, 0, uint64(numSteps), oldState.segments, bytes32(0));
        emit Published(action.index, seq, ChallengeLib.CHOOSE, responder, deadline, dispute);
    }

    function oneStepExecution(ChallengeLib.Action calldata action, ChallengeLib.ChallState calldata oldState, bytes calldata proof) external {
        require(vm.oneStep(oldState.end, oldState.segments[0], proof) == oldState.segments[1], "VALID");
        _takeTurn(action.index, ChallengeLib.PUBLISH1, ChallengeLib.END);
    }

}