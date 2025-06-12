// SPDX-License-Identifier: MIT
pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

library Dataset {
    struct NodeData {
        //链表节点数据结构
        uint256 epoch;
    }

    function getInitNodeData() internal pure returns (NodeData memory) {
        return NodeData(uint256(0));
    }
}

library EpochLinkedList {
    struct Node {
        Dataset.NodeData data;
        uint256 current;
        uint256 prev;
        uint256 next;
    }

    struct List {
        uint256 listLength;
        uint256 spacePointer;
        uint256 head;
        uint256 tail;
        bool initialized;
        Node[] nodes;
    }

    modifier validIndex(List storage self, uint256 index) {
        uint256 listLength = getListLength(self);
        require(index >= 0 && index < listLength, "Index out of bound.");
        _;
    }

    modifier initialized(List storage self) {
        if (!self.initialized) {
            initList(self);
            self.initialized = true;
        }
        _;
    }

    function hasNext(Node storage self) internal view returns (bool) {
        return self.next > 0;
    }

    function hasPrevious(Node storage self) internal view returns (bool) {
        return self.prev > 0;
    }

    function getListLength(List storage self) internal view returns (uint256) {
        return self.listLength;
    }

    function getInitNode() internal pure returns (Node memory) {
        return Node(Dataset.getInitNodeData(), 0, 0, 0);
    }

    function initList(List storage self) internal {
        require(0 == self.nodes.length, "no need to initialize");
        self.nodes.push(getInitNode());
    }

    function linkBefore(List storage self, uint256 nodePointer, Dataset.NodeData memory data) internal initialized(self) {
        Node storage currentNode = self.nodes[nodePointer];
        uint256 newNodePointer = popSpacePointer(self);
        self.nodes[newNodePointer].data = data;
        self.nodes[newNodePointer].next = nodePointer;
        self.nodes[newNodePointer].prev = currentNode.prev;
        self.nodes[newNodePointer].current = newNodePointer;

        self.nodes[currentNode.prev].next = newNodePointer;

        currentNode.prev = newNodePointer;

        self.listLength++;
    }


    function linkLast(List storage self, Dataset.NodeData memory data) internal initialized(self) {
        uint256 newNodePointer = popSpacePointer(self);
        self.nodes[newNodePointer].data = data;
        self.nodes[newNodePointer].prev = self.tail;
        self.nodes[newNodePointer].current = newNodePointer;
        self.nodes[self.tail].next = newNodePointer;
        self.tail = newNodePointer;
        self.listLength++;
    }

    function popSpacePointer(List storage self) private returns (uint256) {
        uint256 spacePointer = self.spacePointer;
        if (spacePointer > 0) {
            self.spacePointer = self.nodes[spacePointer].next;
        } else {
            self.nodes.push(getInitNode());
            spacePointer = self.nodes.length - 1;
        }
        return spacePointer;
    }

    function insert(List storage self, uint256 index, Dataset.NodeData memory data) internal {
        uint256 listLength = getListLength(self);
        require(index >= 0 && index <= listLength, "invalid index.");

        if (index == listLength) {
            linkLast(self, data);
        } else {
            linkBefore(self, getNodePointer(self, index), data);
        }
    }

    function getNodePointer(List storage self, uint256 index) internal view validIndex(self, index) returns (uint256) {
        uint256 listLength = getListLength(self);

        if (index < (listLength >> 1)) {
            Node storage node = self.nodes[self.head];
            for (uint256 i = 0; i < index; i++) node = self.nodes[node.next];
            return node.next;
        } else {
            if (index == listLength - 1) {
                return self.tail;
            }
            Node storage node = self.nodes[self.tail];
            for (uint256 i = listLength - 1; i > index; i--) node = self.nodes[node.prev];
            return node.current;
        }
    }

    function remove(List storage self, Node storage delNode) internal {
        uint256 prevNodePointer = delNode.prev;
        uint256 nextNodePointer = delNode.next;

        self.nodes[prevNodePointer].next = nextNodePointer;

        if (nextNodePointer == 0) {
            self.tail = prevNodePointer;
        } else {
            self.nodes[nextNodePointer].prev = prevNodePointer;
        }
        delNode.next = self.spacePointer;
        self.spacePointer = delNode.current;

        self.listLength--;
    }

    function remove(List storage self, uint256 index) internal {
        remove(self, getNode(self, index));
    }

    function set(List storage self, uint256 nodePointer, Dataset.NodeData memory data) internal {
        self.nodes[nodePointer].data = data;
    }

    function isEmpty(List storage self) internal view returns (bool) {
        // return !self.initialized || !(self.nodes[self.head].hasNext());
        return !self.initialized;
    }

    function getFirst(List storage self) internal view returns (Node storage) {
        require(!isEmpty(self), "list is empty.");
        uint256 firstNodePointer = self.nodes[self.head].next;
        return self.nodes[firstNodePointer];
    }

    function getLast(List storage self) internal view returns (Node storage) {
        require(!isEmpty(self), "list is empty.");
        return self.nodes[self.tail];
    }

    function getNextNode(List storage self, Node storage current) internal view returns (Node storage) {
        require(hasNext(current), "next node not exist.");
        return self.nodes[current.next];
    }

    function getPreviousNode(List storage self, Node storage current) internal view returns (Node storage) {
        require(hasPrevious(current), "previous node not exist.");
        return self.nodes[current.prev];
    }

    function getNode(List storage self, uint256 index) internal view returns (Node storage) {
        uint256 nodePointer = getNodePointer(self, index);
        return self.nodes[nodePointer];
    }

    function getNodeData(List storage self, uint256 index) internal view returns (Dataset.NodeData storage) {
        Node storage node = getNode(self, index);
        return node.data;
    }
}


