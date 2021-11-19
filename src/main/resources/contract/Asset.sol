pragma solidity ^0.6.0;
pragma experimental ABIEncoderV2;

import "./Table.sol";

contract Asset {
    // event
    event RegisterEvent(int256 ret, string indexed account, uint256 indexed asset_value);
    event TransferEvent(int256 ret, string indexed from_account, string indexed to_account, uint256 indexed amount);
    Table tf;

    constructor() public {
        // 构造函数中创建t_asset表
        tf = Table(0x1001);
        // 资产管理表, key : account, field : asset_value
        // |  资产账户(主键)      |     资产金额       |
        // |-------------------- |-------------------|
        // |        account      |    asset_value    |
        // |---------------------|-------------------|
        //
        // 创建表
        tf.createTable("t_asset", "account", "asset_value");
    }

    /*
    描述 : 根据资产账户查询资产金额
    参数 ：
            account : 资产账户

    返回值：
            参数一： 成功返回0, 账户不存在返回-1
            参数二： 第一个参数为0时有效，资产金额
    */
    function select(string memory account) public view returns(int256, uint256) {
        // 打开表

        CompareTriple memory compareTriple1 = CompareTriple("account",account,Comparator.EQ);
        CompareTriple[] memory compareFields = new CompareTriple[](1);
        compareFields[0] = compareTriple1;
        Condition memory condition;
        condition.condFields = compareFields;
        // 查询
        Entry[] memory entries = tf.select("t_asset",condition);
        uint256 asset_value = 0;
        if (0 == uint256(entries.length)) {
            return (-1, asset_value);
        } else {
            asset_value = safeParseInt(entries[0].fields[0].value);
            return (0, uint256(asset_value));
        }
    }

    /*
    描述 : 资产注册
    参数 ：
            account : 资产账户
            amount  : 资产金额
    返回值：
            0  资产注册成功
            -1 资产账户已存在
            -2 其他错误
    */
    function register(string memory account, uint256 asset_value) public returns(int256){
        int256 ret_code = 0;
        int256 ret= 0;
        uint256 temp_asset_value = 0;
        // 查询账号是否存在
        (ret, temp_asset_value) = select(account);
        if(ret != 0) {
            string memory asset_value_str = uint2str(asset_value);
            KVField memory kv0 = KVField("account",account);
            KVField memory kv1 = KVField("asset_value",asset_value_str);
            KVField[] memory KVFields = new KVField[](2);
            KVFields[0] = kv0;
            KVFields[1] = kv1;
            Entry memory entry = Entry(KVFields);

            // 插入
            int256 count = tf.insert("t_asset",entry);
            if (count == 1) {
                // 成功
                ret_code = 0;
            } else {
                // 失败? 无权限或者其他错误
                ret_code = -2;
            }
        } else {
            // 账户已存在
            ret_code = -1;
        }

        emit RegisterEvent(ret_code, account, asset_value);

        return ret_code;
    }

    /*
    描述 : 资产转移
    参数 ：
            from_account : 转移资产账户
            to_account ： 接收资产账户
            amount ： 转移金额
    返回值：
            0  资产转移成功
            -1 转移资产账户不存在
            -2 接收资产账户不存在
            -3 金额不足
            -4 金额溢出
            -5 其他错误
    */
    function transfer(string memory from_account, string memory to_account, uint256 amount) public returns(int256) {
        // 查询转移资产账户信息
        int256 ret = 0;
        uint256 from_asset_value = 0;
        uint256 to_asset_value = 0;

        // 转移账户是否存在?
        (ret, from_asset_value) = select(from_account);
        if(ret != 0) {

            // 转移账户不存在
            emit TransferEvent(-1, from_account, to_account, amount);
            return -1;

        }

        // 接受账户是否存在?
        (ret, to_asset_value) = select(to_account);
        if(ret != 0) {
            // 接收资产的账户不存在
            emit TransferEvent(-2, from_account, to_account, amount);
            return -2;
        }

        if(from_asset_value < amount) {
            // 转移资产的账户金额不足
            emit TransferEvent(-3, from_account, to_account, amount);
            return -3;
        }

        if (to_asset_value + amount < to_asset_value) {
            // 接收账户金额溢出
            emit TransferEvent(-4, from_account, to_account, amount);
            return -4;
        }

        string memory f_new_value_str = uint2str(from_asset_value - amount);
        KVField memory kv1 = KVField("asset_value",f_new_value_str);
        KVField[] memory KVFields1 = new KVField[](1);
        KVFields1[0] = kv1;
        Entry memory entry1 = Entry(KVFields1);

        Condition memory condition1;
        condition1.condFields = new CompareTriple[](1);
        condition1.condFields[0] = CompareTriple("account",from_account,Comparator.EQ);

        // 更新转账账户
        int count = tf.update("t_asset",entry1, condition1);
        if(count != 1) {
            // 失败? 无权限或者其他错误?
            emit TransferEvent(-5, from_account, to_account, amount);
            return -5;
        }


        string memory to_new_value_str = uint2str(to_asset_value + amount);
        kv1 = KVField("asset_value",to_new_value_str);
        KVFields1 = new KVField[](1);
        KVFields1[0] = kv1;
        entry1 = Entry(KVFields1);

        condition1.condFields[0] =  CompareTriple("account",to_account,Comparator.EQ);

        // 更新接收账户
        tf.update("t_asset",entry1, condition1);

        emit TransferEvent(0, from_account, to_account, amount);

        return 0;
    }


    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len - 1;
        while (_i != 0) {
            bstr[k--] = byte(uint8(48 + _i % 10));
            _i /= 10;
        }
        return string(bstr);
    }

    function safeParseInt(string memory _a) internal pure returns (uint _parsedInt) {
        return safeParseInt(_a, 0);
    }

    function safeParseInt(string memory _a, uint _b) internal pure returns (uint _parsedInt) {
        bytes memory bresult = bytes(_a);
        uint mint = 0;
        bool decimals = false;
        for (uint i = 0; i < bresult.length; i++) {
            if ((uint(uint8(bresult[i])) >= 48) && (uint(uint8(bresult[i])) <= 57)) {
                if (decimals) {
                    if (_b == 0) break;
                    else _b--;
                }
                mint *= 10;
                mint += uint(uint8(bresult[i])) - 48;
            } else if (uint(uint8(bresult[i])) == 46) {
                require(!decimals, 'More than one decimal encountered in string!');
                decimals = true;
            } else {
                revert("Non-numeral character encountered in string!");
            }
        }
        if (_b > 0) {
            mint *= 10 ** _b;
        }
        return mint;
    }
}
