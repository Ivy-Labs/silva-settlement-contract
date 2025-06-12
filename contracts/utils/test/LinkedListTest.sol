pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

import "../DoublyLinkedList.sol";

contract LinkedListTest {
    using DoublyLinkedList for DoublyLinkedList.List;
    using DoublyLinkedList for DoublyLinkedList.Node;

    DoublyLinkedList.List doublyLinkedList;

    function insert(string memory data, uint256 index) public {
        Dataset.NodeData memory newNodeData = Dataset.NodeData(data);
        doublyLinkedList.insert(index, newNodeData);
    }

    function remove(uint256 index) public {
        doublyLinkedList.remove(index);
    }

    function set(string memory data, uint256 nodePointer) public {
        Dataset.NodeData memory newNodeData = Dataset.NodeData(data);
        doublyLinkedList.set(nodePointer, newNodeData);
    }

    //链表长度
    function getListLength() public view returns (uint256) {
        return doublyLinkedList.getListLength();
    }

    //链表节点数组的长度
    function getListNodesArrLength() public view returns (uint256) {
        return doublyLinkedList.nodes.length;
    }

    //获取链表节点组成的数组
    function getLinkedList() public view returns (DoublyLinkedList.Node[] memory) {
        uint256 listLength = getListLength();
        DoublyLinkedList.Node[] memory listNode = new DoublyLinkedList.Node[](listLength);
        for (uint256 i = 0; i < listLength; i++) {
            DoublyLinkedList.Node memory node = doublyLinkedList.getNode(i);
            listNode[i] = node;
        }
        return listNode;
    }

    //从头正向遍历，获取链表节点组成的数组
    function iterateFromHead() public view returns (DoublyLinkedList.Node[] memory) {
        uint256 listLength = getListLength();
        DoublyLinkedList.Node[] memory listNode = new DoublyLinkedList.Node[](listLength);
        DoublyLinkedList.Node storage node = doublyLinkedList.getFirst();
        listNode[0] = node;
        uint256 i = 1;
        while (node.hasNext()) {
            node = doublyLinkedList.getNextNode(node);
            listNode[i++] = node;
        }
        return listNode;
    }

    //从列表尾反向遍历，获取链表节点组成的数组
    function iterateFromTail() public view returns (DoublyLinkedList.Node[] memory) {
        uint256 listLength = getListLength();
        DoublyLinkedList.Node[] memory listNode = new DoublyLinkedList.Node[](listLength);
        DoublyLinkedList.Node storage node = doublyLinkedList.getLast();
        listNode[0] = node;
        uint256 i = 1;
        while (node.hasPrevious()) {
            node = doublyLinkedList.getPreviousNode(node);
            listNode[i++] = node;
        }
        return listNode;
    }

    //获取链表节点数据组成的数组
    function getDataList() public view returns (Dataset.NodeData[] memory) {
        uint256 listLength = getListLength();
        Dataset.NodeData[] memory listData = new Dataset.NodeData[](listLength);
        for (uint256 i = 0; i < listLength; i++) {
            Dataset.NodeData memory nodeData = doublyLinkedList.getNodeData(i);
            listData[i] = nodeData;
        }
        return listData;
    }

    //获取链表节点的数组下标
    function getPointerList() public view returns (uint256[] memory) {
        uint256 listLength = getListLength();
        uint256[] memory listPointers = new uint256[](listLength);
        for (uint256 i = 0; i < listLength; i++) {
            listPointers[i] = doublyLinkedList.getNodePointer(i);
        }
        return listPointers;
    }

    //获取数组内容
    function getNodeArray() public view returns (DoublyLinkedList.Node[] memory) {
        return doublyLinkedList.nodes;
    }

    //获取链表信息
    function getListInfo() public view returns (uint256, uint256, uint256, bool) {
        return (doublyLinkedList.spacePointer, doublyLinkedList.head, doublyLinkedList.tail, doublyLinkedList.initialized);
    }

    //获取空闲节点的数组下标
    function getSpaceLinkedList() public view returns (uint256[] memory) {
        uint256 listNodesArrLength = getListNodesArrLength();
        uint256[] memory spaceListPointers = new uint256[](listNodesArrLength);
        uint256 spacePointer = doublyLinkedList.spacePointer;
        uint256 i = 0;
        while (spacePointer > 0) {
            spaceListPointers[i] = spacePointer;
            spacePointer = doublyLinkedList.nodes[spacePointer].next;
            i++;
        }

        return spaceListPointers;
    }
}