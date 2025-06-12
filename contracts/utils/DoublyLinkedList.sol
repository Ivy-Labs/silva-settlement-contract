pragma solidity ^0.8;
pragma experimental ABIEncoderV2;

library Dataset {
    struct NodeData {
        //链表节点数据结构
        string someData;
    }

    function getInitNodeData() internal pure returns (NodeData memory) {
        return NodeData("");
    }
}

library DoublyLinkedList {
    struct Node {
        Dataset.NodeData data;
        uint256 current; //本节点的数组下标
        uint256 prev; //前置节点的数组下标
        uint256 next; //后置节点的数组下标
    }

    struct List {
        uint256 listLength;
        uint256 spacePointer; //备用链指针，指针如果为0，则需要使用push方法扩展节点的长度
        uint256 head; //指向头节点的数组下标，固定为0
        uint256 tail; //指向尾节点的数组下标
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

    //Node 成员方法
    //判断链表中指定元素的下个元素是否存在
    function hasNext(Node storage self) internal view returns (bool) {
        return self.next > 0;
    }

    //判断链表中指定元素的上个元素是否存在
    function hasPrevious(Node storage self) internal view returns (bool) {
        return self.prev > 0;
    }

    //List 成员方法
    function getListLength(List storage self) internal view returns (uint256) {
        return self.listLength;
    }

    function getInitNode() internal pure returns (Node memory) {
        return Node(Dataset.getInitNodeData(), 0, 0, 0);
    }

    function initList(List storage self) internal {
        require(0 == self.nodes.length, "no need to initialize");
        //填充数组下标为0的节点，该节点作为链表的头节点，且初始化时也是队尾节点
        self.nodes.push(getInitNode());
    }

    //在当前节点之前插入新节点
    function linkBefore(List storage self, uint256 nodePointer, Dataset.NodeData memory data) internal initialized(self) {
        //当前节点
        Node storage currentNode = self.nodes[nodePointer];
        //获得空闲节点的数组下标
        uint256 newNodePointer = popSpacePointer(self);
        //修改新节点的数据
        self.nodes[newNodePointer].data = data;
        self.nodes[newNodePointer].next = nodePointer; //新节点的后继节点即为当前节点
        self.nodes[newNodePointer].prev = currentNode.prev; //新节点的前继节点即为当前节点的原前继节点
        self.nodes[newNodePointer].current = newNodePointer; //记录新节点的数组下标

        //将原前继节点的后继节点改为新节点
        self.nodes[currentNode.prev].next = newNodePointer;

        //将当前节点的前继节点改为新节点
        currentNode.prev = newNodePointer;

        //链表长度加1
        self.listLength++;
    }

    //在链表尾部插入新节点
    function linkLast(List storage self, Dataset.NodeData memory data) internal initialized(self) {
        //获得空闲节点的数组下标
        uint256 newNodePointer = popSpacePointer(self);
        //修改新节点的数据
        self.nodes[newNodePointer].data = data;
        self.nodes[newNodePointer].prev = self.tail; //新节点的前继节点即为原队尾节点
        self.nodes[newNodePointer].current = newNodePointer; //记录新节点的数组下标
        //将原队尾节点的后继节点改为新节点
        self.nodes[self.tail].next = newNodePointer;
        //将队尾节点下标改为新节点下标
        self.tail = newNodePointer;
        //链表长度加1
        self.listLength++;
    }

    //获得空闲节点的数组下标
    function popSpacePointer(List storage self) private returns (uint256) {
        uint256 spacePointer = self.spacePointer; //找到空闲节点的下标
        if (spacePointer > 0) {
            self.spacePointer = self.nodes[spacePointer].next; //已经拿出一个备用空闲下标，将其的下一个备用空闲下标拿出来做备用
        } else {
            //sapcePointer=0表示当前没有空闲节点，需要扩展list的节点数组长度
            self.nodes.push(getInitNode());
            spacePointer = self.nodes.length - 1; //返回新节点的数组下标
        }
        return spacePointer;
    }

    //添加元素
    function insert(List storage self, uint256 index, Dataset.NodeData memory data) internal {
        uint256 listLength = getListLength(self);
        require(index >= 0 && index <= listLength, "invalid index."); //最多只能往链表的末尾加一个节点

        //如果是一个空的list则需要先初始化它
        if (index == listLength) {
            linkLast(self, data);
        } else {
            linkBefore(self, getNodePointer(self, index), data);
        }
    }

    //获取节点的指针（数组下标）
    function getNodePointer(List storage self, uint256 index) internal view validIndex(self, index) returns (uint256) {
        uint256 listLength = getListLength(self);

        if (index < (listLength >> 1)) {
            //链表前半部分，从头开始找
            Node storage node = self.nodes[self.head];
            for (uint256 i = 0; i < index; i++) node = self.nodes[node.next];
            return node.next;
        } else {
            //尾节点直接返回
            if (index == listLength - 1) {
                return self.tail;
            }
            //链表后半部分，从尾开始找
            Node storage node = self.nodes[self.tail];
            for (uint256 i = listLength - 1; i > index; i--) node = self.nodes[node.prev];
            return node.current;
        }
    }

    //删除指定节点
    function remove(List storage self, Node storage delNode) internal {
        uint256 prevNodePointer = delNode.prev;
        uint256 nextNodePointer = delNode.next;

        self.nodes[prevNodePointer].next = nextNodePointer;

        if (nextNodePointer == 0) {
            //删除的是尾节点,需要更新tail
            self.tail = prevNodePointer;
        } else {
            self.nodes[nextNodePointer].prev = prevNodePointer;
        }

        //将待删除节点移到备用节点的最前端，并且将备用节点链接到待删除节点之后
        delNode.next = self.spacePointer;
        self.spacePointer = delNode.current;

        self.listLength--; //list长度减1
    }

    //删除指定节点
    function remove(List storage self, uint256 index) internal {
        remove(self, getNode(self, index));
    }

    //更新指定数组位置的节点数据
    function set(List storage self, uint256 nodePointer, Dataset.NodeData memory data) internal {
        self.nodes[nodePointer].data = data;
    }

    //查询方法
    //查询链表是否为空
    function isEmpty(List storage self) internal view returns (bool) {
        //没有初始化或者头节点的next为0
        // return !self.initialized || !(self.nodes[self.head].hasNext());
        return !self.initialized;
    }

    //查询链表中第一个节点。如果链表为空，则报错
    function getFirst(List storage self) internal view returns (Node storage) {
        require(!isEmpty(self), "list is empty.");
        uint256 firstNodePointer = self.nodes[self.head].next;
        return self.nodes[firstNodePointer];
    }

    //查询链表中最后一个节点。如果链表为空，则报错
    function getLast(List storage self) internal view returns (Node storage) {
        require(!isEmpty(self), "list is empty.");
        return self.nodes[self.tail];
    }

    //遍历方法

    //获取链表中指定元素的下个元素
    function getNextNode(List storage self, Node storage current) internal view returns (Node storage) {
        require(hasNext(current), "next node not exist.");
        return self.nodes[current.next];
    }

    //获取链表中指定元素的上个元素
    function getPreviousNode(List storage self, Node storage current) internal view returns (Node storage) {
        require(hasPrevious(current), "previous node not exist.");
        return self.nodes[current.prev];
    }

    //----以下方法用处不大---------------------
    //获取链表指定下标的元素
    function getNode(List storage self, uint256 index) internal view returns (Node storage) {
        uint256 nodePointer = getNodePointer(self, index);
        return self.nodes[nodePointer];
    }

    //获取链表指定下标的元素数据
    function getNodeData(List storage self, uint256 index) internal view returns (Dataset.NodeData storage) {
        Node storage node = getNode(self, index);
        return node.data;
    }
}


