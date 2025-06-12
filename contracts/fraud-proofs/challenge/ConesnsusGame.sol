// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import "./Bisector.sol";
import "../../interfaces/network/ISilvaChainManager.sol";
import "../../interfaces/network/ISilvaChain.sol";
contract ConsensusGame is Bisector  {
    using ChallengeLib for ChallengeLib.Challenge;
    ISilvaChainManager chainManager;
    function createChallenge(
        uint16 chainId,
        address[2] memory participants,
        address settleAddress,
        ChallengeLib.Segment[2] memory segments
    ) external returns (uint64) {
        require(segments[0].height < segments[1].height, "ILLEGAL_HEIGHT");
        address chain = chainManager.getChainLib(chainId, segments[0].height);
        ChallengeLib.Round memory round = ISilvaChain(chain).initRound();

        ChallengeLib.validStep(round.step);

        uint64 challengeIndex = ++totalChallengeCreated;
        ChallengeLib.Challenge storage challenge = challenges[challengeIndex];
        challenge.referee = ChallengeLib.Player(participants[0], round.timeLeft);
        challenge.attester = ChallengeLib.Player(participants[1], round.timeLeft);
        challenge.chainId = chainId;
        challenge.settleAddress = settleAddress;
        challenge.lastMoveTimestamp = uint256(block.timestamp);
        challenge.step = round.step;

        bytes32[] memory segmentsHashs = new bytes32[](2);
        uint64 seq = 1;
        segmentsHashs[0] = segments[0].stateHash;
        segmentsHashs[1] = segments[1].stateHash;
        updateChallenge(challengeIndex, seq, chainId, segments[0].height, segments[1].height, segmentsHashs, bytes32(0));
        Dispute memory dispute = Dispute(chainId, segments[0].height, segments[1].height, segmentsHashs, bytes32(0));
        
        emit Published(challengeIndex, seq, round.step, challenge.attester.addr, challenge.lastMoveTimestamp + round.timeLeft, dispute);
        return challengeIndex;
    }

    function publishDisputes(
        ChallengeLib.Action calldata action,
        ChallengeLib.ChallState calldata oldState,
        bytes[] calldata publish,
        bytes calldata proof
    ) external {
        beforeCheck(action, ChallengeLib.PUBLISH1, oldState);

        address chain = chainManager.getChainLib(oldState.chainId, oldState.start);
        uint32 step = challenges[action.index].step;
        ChallengeLib.Game memory game = ISilvaChain(chain).validatePublish(step, oldState, publish, proof);
        _afterGame(action, game);
    }

    function publishDisputes2(
        ChallengeLib.Action calldata action,
        ChallengeLib.ChallState calldata oldState,
        bytes[] calldata publish,
        bytes calldata proof
    ) external {
        beforeCheck(action, ChallengeLib.PUBLISH2, oldState);
        uint32 eStep = ChallengeLib.PUBLISH2;
        address chain = chainManager.getChainLib(oldState.chainId, oldState.start);
        ChallengeLib.Game memory game = ISilvaChain(chain).validatePublish(eStep, oldState, publish, proof);
        _afterGame(action, game);
    }

    function challengeDispute(
        ChallengeLib.Action calldata action,
        uint32 disputeIndex,
        ChallengeLib.ChallState calldata oldState,
        bytes[] calldata datas
    ) external {

        beforeCheck(action, ChallengeLib.CHALLENGE, oldState);
        
        address chain = chainManager.getChainLib(oldState.chainId, oldState.start);
        ChallengeLib.Game memory game;
        game = ISilvaChain(chain).nextChallengeStep(disputeIndex, oldState, datas);
        _afterGame(action, game);
    }

    function _afterGame(ChallengeLib.Action calldata action, ChallengeLib.Game memory game) internal returns(bytes32 challengeStateHash) {
        ChallengeLib.validStep(game.round.step);
        require(game.state.segments.length == 2, "WRONG_SEGMENTS_LENGTH");
        uint64 seq = action.seq + 1;
        updateChallenge(action.index, seq, game.state.chainId, game.state.start, game.state.end, game.state.segments, game.state.extra);

        ChallengeLib.Challenge storage c = challenges[action.index];
        c.step = game.round.step;             
        if (game.round.timeLeft != 0) {
            c.referee.timeLeft = game.round.timeLeft;
            c.attester.timeLeft = game.round.timeLeft;
        }
        if (game.round.step == ChallengeLib.BISECT) {
            require(game.state.start != game.state.end, "ILLEGAL_START_END");
            c.responder = 1;
        } else {
            c.responder = ChallengeLib.turn(c.responder); 
            
        }
        c.lastMoveTimestamp = block.timestamp;
        uint deadline = c.lastMoveTimestamp + c.currentTimeLeft();
        emit Published(action.index, seq, game.round.step, c.currentResponder(), c.lastMoveTimestamp + game.round.timeLeft, Dispute(game.state.chainId, game.state.start, game.state.end, game.state.segments, game.state.extra));

    }
}