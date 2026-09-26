// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Docket} from "../src/Docket.sol";
import {TestBase, Vm} from "./helpers/TestBase.sol";

/// @dev Independent model is built from decoded logs, not copied from contract returns.
contract DocketHandler is TestBase {
    Docket public immutable docket;
    uint256 public modelIdeas;
    mapping(uint256 => uint256) public modelComments;

    constructor(Docket target) {
        docket = target;
    }

    function create(uint256 seed, address caller) external {
        string memory title = filled(1 + seed % 120);
        string memory body = filled(1 + seed % 4000);
        uint256 beforeCount = docket.ideaCount();
        vm.recordLogs();
        vm.prank(caller);
        uint256 result = docket.createIdea(title, body);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assert(logs.length == 1 && logs[0].emitter == address(docket));
        assert(logs[0].topics.length == 3);
        assert(logs[0].topics[0] == keccak256("IdeaCreated(uint256,address,string,string)"));
        uint256 loggedId = uint256(logs[0].topics[1]);
        assert(loggedId == modelIdeas + 1 && loggedId == result);
        assert(logs[0].topics[2] == bytes32(uint256(uint160(caller))));
        (string memory loggedTitle, string memory loggedBody) = abi.decode(logs[0].data, (string, string));
        assert(same(title, loggedTitle) && same(body, loggedBody));
        modelIdeas = loggedId;
        assert(docket.ideaCount() == beforeCount + 1);
        _checkAllCounters();
    }

    function post(uint256 seed, uint256 bodySeed, address caller) external {
        if (modelIdeas == 0) return;
        uint256 ideaId = 1 + seed % modelIdeas;
        string memory body = filled(1 + bodySeed % 2000);
        uint256 beforeCount = docket.commentCount(ideaId);
        vm.recordLogs();
        vm.prank(caller);
        uint256 result = docket.comment(ideaId, body);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        assert(logs.length == 1 && logs[0].emitter == address(docket));
        assert(logs[0].topics.length == 4);
        assert(logs[0].topics[0] == keccak256("CommentPosted(uint256,uint256,address,string)"));
        assert(uint256(logs[0].topics[1]) == ideaId);
        uint256 loggedId = uint256(logs[0].topics[2]);
        assert(loggedId == modelComments[ideaId] + 1 && loggedId == result);
        assert(logs[0].topics[3] == bytes32(uint256(uint160(caller))));
        assert(same(abi.decode(logs[0].data, (string)), body));
        modelComments[ideaId] = loggedId;
        assert(docket.commentCount(ideaId) == beforeCount + 1);
        _checkAllCounters();
    }

    function reject(uint256 seed, address caller) external {
        uint256 kind = seed % 4;
        bytes memory data;
        bytes4 expected;
        if (kind == 0) {
            data = abi.encodeCall(Docket.createIdea, ("", "b"));
            expected = Docket.BadLength.selector;
        } else if (kind == 1) {
            data = abi.encodeCall(Docket.createIdea, ("t", filled(4001)));
            expected = Docket.BadLength.selector;
        } else if (kind == 2 || modelIdeas == 0) {
            data = abi.encodeCall(Docket.comment, (modelIdeas + 1, "b"));
            expected = Docket.UnknownIdea.selector;
        } else {
            data = abi.encodeCall(Docket.comment, (1 + seed % modelIdeas, filled(2001)));
            expected = Docket.BadLength.selector;
        }
        vm.recordLogs();
        vm.prank(caller);
        (bool ok, bytes memory reason) = address(docket).call(data);
        assert(!ok && keccak256(reason) == keccak256(abi.encodeWithSelector(expected)));
        assert(vm.getRecordedLogs().length == 0);
        _checkAllCounters();
    }

    function _checkAllCounters() private view {
        assert(docket.ideaCount() == modelIdeas);
        assert(docket.commentCount(0) == 0);
        for (uint256 i = 1; i <= modelIdeas; ++i) {
            assert(docket.commentCount(i) == modelComments[i]);
        }
        assert(docket.commentCount(modelIdeas + 1) == 0);
    }
}

contract DocketInvariantTest is TestBase {
    Docket private docket;
    DocketHandler private handler;

    function setUp() public {
        docket = new Docket();
        handler = new DocketHandler(docket);
    }

    function targetContracts() external view returns (address[] memory targets) {
        targets = new address[](1);
        targets[0] = address(handler);
    }

    function invariantCountersEqualReconstructedLogs() public view {
        uint256 count = handler.modelIdeas();
        assert(docket.ideaCount() == count);
        for (uint256 i; i <= count; ++i) {
            assert(docket.commentCount(i) == handler.modelComments(i));
        }
        assert(docket.commentCount(count + 1) == 0);
    }
}
