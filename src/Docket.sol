// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice A permissionless board whose text is stored only in transaction logs.
contract Docket {
    error BadLength();
    error UnknownIdea();

    event IdeaCreated(uint256 indexed ideaId, address indexed author, string title, string body);
    event CommentPosted(uint256 indexed ideaId, uint256 indexed commentId, address indexed author, string body);

    uint256 public ideaCount;
    mapping(uint256 ideaId => uint256 count) public commentCount;

    /// @notice Publish an idea with a 1-120 byte title and a 1-4000 byte body.
    function createIdea(string calldata title, string calldata body) external returns (uint256 ideaId) {
        if (bytes(title).length == 0 || bytes(title).length > 120) revert BadLength();
        if (bytes(body).length == 0 || bytes(body).length > 4000) revert BadLength();
        ideaId = ++ideaCount;
        emit IdeaCreated(ideaId, msg.sender, title, body);
    }

    /// @notice Publish a 1-2000 byte comment on an existing idea.
    function comment(uint256 ideaId, string calldata body) external returns (uint256 commentId) {
        if (ideaId == 0 || ideaId > ideaCount) revert UnknownIdea();
        if (bytes(body).length == 0 || bytes(body).length > 2000) revert BadLength();
        commentId = ++commentCount[ideaId];
        emit CommentPosted(ideaId, commentId, msg.sender, body);
    }
}
