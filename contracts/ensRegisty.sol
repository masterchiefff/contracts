// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IENSRegistry {
    function resolver(bytes32 node) external view returns (address);
}

interface IPublicResolver {
    function addr(bytes32 node) external view returns (address);
}

interface IBaseRegistrar {
    function ownerOf(uint256 tokenId) external view returns (address);
}

contract DecentralizedMail {
    struct Message {
        address sender;
        address receiver;
        string content;
        uint256 timestamp;
        bool isDeleted;
    }

    Message[] public messages;

    address constant baseRegistrarAddress =
        0x03c4738Ee98aE44591e1A4A4F3CaB6641d95DD9a;
    address constant ENS_REGISTRY = 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e; // ENS Registry on Ethereum

    error InvalidLabel(string reason);

    /// @notice Converts a label to its ENS node hash for ".base.eth"
    /// @param label The label part of the name (e.g., "techwithmide" for "techwithmide.base.eth")
    /// @dev Validates the label before conversion to prevent mistakes
    // function computeNode(string calldata label) public pure returns (bytes32) {
    //     if (bytes(label).length == 0) revert InvalidLabel("Label cannot be empty");
    //     if (bytes(label).length > 63) revert InvalidLabel("Label too long");
    //     for (uint256 i = 0; i < bytes(label).length; i++) {
    //         bytes1 char = bytes(label)[i];
    //         if (!(char >= 0x61 && char <= 0x7A) && // a-z
    //             !(char >= 0x30 && char <= 0x39) && // 0-9
    //             !(char == 0x2D)) // hyphen (-)
    //         {
    //             revert InvalidLabel("Invalid character in label");
    //         }
    //     }
    //     return keccak256(abi.encodePacked(keccak256(abi.encodePacked("base.eth")), keccak256(bytes(label))));
    // }

    function computeNode(string calldata label) public pure returns (bytes32) {
        bytes memory labelBytes = bytes(label);
        uint256 length = labelBytes.length;

        // Validate label length
        if (length == 0) revert InvalidLabel("Label cannot be empty");
        if (length > 63) revert InvalidLabel("Label too long");

        // Validate characters in the label
        for (uint256 i = 0; i < length; i++) {
            bytes1 char = labelBytes[i];
            if (
                !(char >= 0x61 && char <= 0x7A) && // a-z
                !(char >= 0x30 && char <= 0x39) && // 0-9
                !(char == 0x2D) // hyphen (-)
            ) {
                revert InvalidLabel("Invalid character in label");
            }
        }

        // Compute and return the node hash
        return
            keccak256(
                abi.encodePacked(
                    keccak256(abi.encodePacked("base.eth")),
                    keccak256(labelBytes)
                )
            );
    }

    /// @notice Get the owner of a ".base.eth" name
    /// @param label The label part of the name (e.g., "techwithmide" for "techwithmide.base.eth")
    /// @return The address of the current owner, or address(0) if unregistered
    function getBasenameOwner(string calldata label)
        public
        view
        returns (address)
    {
        bytes32 node = computeNode(label);
        IENSRegistry registry = IENSRegistry(ENS_REGISTRY);
        address resolverAddress = registry.resolver(node);
        if (resolverAddress == address(0)) return address(0); // Name not registered

        IPublicResolver resolver = IPublicResolver(resolverAddress);
        return resolver.addr(node);
    }

    // Send a message to an ENS name
    function sendMessage(string calldata _receiverENS, string memory _content)
        public
    {
        address receiver = getBasenameOwner(_receiverENS);

        require(
            receiver != address(0),
            "Invalid ENS name or not owned by anyone"
        );

        // Ensure the sender is the owner of the ENS name
        require(
            receiver == msg.sender,
            "You can not send messages to your self"
        );

        // Push the message into the array
        messages.push(
            Message(msg.sender, receiver, _content, block.timestamp, false)
        );
    }

    function getMessages() public view returns (Message[] memory) {
        return messages;
    }

    function deleteMessage(uint256 messageId) public {
        require(
            messages[messageId].sender == msg.sender ||
                messages[messageId].receiver == msg.sender,
            "Not authorized"
        );
        messages[messageId].isDeleted = true;
    }
}
