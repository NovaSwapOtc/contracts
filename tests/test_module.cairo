%lang starknet

from protostar.asserts import (
    assert_eq,
    assert_not_eq,
    assert_signed_lt,
    assert_signed_le,
    assert_signed_gt,
    assert_unsigned_lt,
    assert_unsigned_le,
    assert_unsigned_gt,
    assert_signed_ge,
    assert_unsigned_ge,
)

from starkware.cairo.common.bool import TRUE, FALSE


from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.uint256 import (
    Uint256, 
    uint256_le, 
    uint256_eq,
    uint256_add,
    uint256_sub,
    uint256_not
)


from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp,
)

from src.otc_module.interfaces.IOtcModule import IOtcModule
from src.common_mock.interfaces.IERC20 import IERC20
from src.common_mock.interfaces.IERC721 import IERC721

from src.utils.token.erc1155.interfaces.IERC1155 import IERC1155

from src.otc_module.otc_module import (
    ERC1155DataStorage,
    ERC721DataInput,
    ERC20DataInput
)

@external
func __setup__() {
    tempvar deployer_address = 123456789987654321;
    %{ 
        context.deployer_address = ids.deployer_address
        context.erc1155_address = deploy_contract("./src/common_mock/erc1155_contract.cairo").contract_address 
        context.erc20_address = deploy_contract("./src/common_mock/erc20_contract.cairo", 
            [0x6d6f636b, 0x6d6f636b, 18]
        ).contract_address 
        context.erc721_address = deploy_contract("./src/common_mock/erc721_contract.cairo",
            [0x6d6f636b, 0x6d6f636b]
        ).contract_address 
        context.otc_module = deploy_contract("./src/otc_module/otc_module.cairo", [context.deployer_address]).contract_address 
    %}
    return ();
}

@external 
func test_open_swap{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;
    
    //%{ stop_prank_callable = start_prank(123) %}
    
    local contract_address;

    local erc1155_address;
    local erc20_address;
    local erc721_address;

    local caller;
    //assert caller = 0;
    %{ 
        ids.erc1155_address = context.erc1155_address
        ids.erc20_address = context.erc20_address
        ids.erc721_address = context.erc721_address
        ids.caller = context.deployer_address
        ids.contract_address = context.otc_module
    %}


    let (counter) = IOtcModule.get_swap_counter(contract_address=contract_address);
    assert counter = 1;

    // PARAMS

    let erc1155_storage : ERC1155DataStorage = ERC1155DataStorage(
        asset_contract=erc1155_address,
        assets_ids_len=2,
        assets_amounts_len=2,
    );

    let (local erc1155_datas : ERC1155DataStorage*) = alloc();
    assert [erc1155_datas] = erc1155_storage;

    let (local erc1155_array_ids : Uint256*) = alloc();
    assert [erc1155_array_ids] = Uint256(25,0);
    assert [erc1155_array_ids + Uint256.SIZE] = Uint256(50,0);

    let (local erc1155_array_amounts : Uint256*) = alloc();
    assert [erc1155_array_amounts] = Uint256(2,0);
    assert [erc1155_array_amounts + Uint256.SIZE] = Uint256(10,0);


    let erc721_data : ERC721DataInput = ERC721DataInput(
        asset_contract=erc721_address,
        asset_id=7,
    );

    let (local erc721_array : ERC721DataInput*) = alloc();
    assert [erc721_array] = erc721_data;


    let erc20_data : ERC20DataInput = ERC20DataInput(
        asset_contract=erc20_address,
        amount=120,
    );

    let (local erc20_array : ERC20DataInput*) = alloc();
    assert [erc20_array] = erc20_data;

    // APPROVEs
    let (calling_address) = get_contract_address();

    IERC1155.setApprovalForAll(contract_address=erc1155_address, operator=contract_address, approved=1);
    let (res) = IERC20.approve(contract_address=erc20_address, spender=contract_address, amount=Uint256(120,0));
    assert res = 1;
    IERC721.setApprovalForAll(contract_address=erc721_address, operator=contract_address, approved=1);

    let (is_erc1155_approved) = IERC1155.isApprovedForAll(contract_address=erc1155_address, account=calling_address, operator=contract_address);
    assert is_erc1155_approved = 1;
    
    let (is_erc721_approved) = IERC721.isApprovedForAll(contract_address=erc1155_address, owner=calling_address, operator=contract_address);
    assert is_erc721_approved = 1;

    // OK 


    // MINT TOKENS TO THIS ADDRESS TO INITIATE A SWAP
    IERC20.mint(erc20_address, calling_address, Uint256(120,0));
    let (local null : felt*) = alloc();
    IERC1155.batchMint(erc1155_address, calling_address, 2, erc1155_array_ids, 2, erc1155_array_amounts, 0, null);
    IERC721.mint(erc721_address, calling_address, Uint256(7,0));

    // check if mint successful
    let (balance_nft : Uint256) = IERC721.balanceOf(erc721_address, calling_address);
    uint256_eq(balance_nft, Uint256(1,0));

    let (owner_nft) = IERC721.ownerOf(erc721_address, Uint256(7,0));
    assert owner_nft = calling_address;

    let (balance_token : Uint256) = IERC20.balanceOf(erc20_address, calling_address);

    uint256_eq(balance_token, Uint256(120,0));

    let (balance_erc1155_one : Uint256) = IERC1155.balanceOf(erc1155_address, calling_address, Uint256(25,0));
    uint256_eq(balance_erc1155_one, Uint256(2,0));

    let (balance_erc1155_two : Uint256) = IERC1155.balanceOf(erc1155_address, calling_address, Uint256(50,0));
    uint256_eq(balance_erc1155_one, Uint256(10,0));

    IOtcModule.open_swap(
        contract_address, 
        1,
        erc1155_datas,
        2,
        erc1155_array_ids,
        2,
        erc1155_array_amounts,
        1,
        erc721_array,
        1,
        erc20_array
    );

    let (new_counter) = IOtcModule.get_swap_counter(contract_address=contract_address);
    assert new_counter = 2;

    let (swap_status) = IOtcModule.get_swap_status(contract_address, 1);
    assert swap_status = 1;

    return ();
}


@external 
func test_bid_swap{syscall_ptr: felt*, range_check_ptr}() {
    alloc_locals;

    local contract_address;

    local erc1155_address;
    local erc20_address;
    local erc721_address;

    local caller;
    %{ 
        ids.erc1155_address = context.erc1155_address
        ids.erc20_address = context.erc20_address
        ids.erc721_address = context.erc721_address
        ids.caller = context.deployer_address
        ids.contract_address = context.otc_module
    %}


    let (counter) = IOtcModule.get_swap_counter(contract_address=contract_address);
    assert counter = 1;

    // PARAMS OWNER

    let erc1155_storage : ERC1155DataStorage = ERC1155DataStorage(
        asset_contract=erc1155_address,
        assets_ids_len=2,
        assets_amounts_len=2,
    );

    let (local erc1155_datas : ERC1155DataStorage*) = alloc();
    assert [erc1155_datas] = erc1155_storage;

    let (local erc1155_array_ids : Uint256*) = alloc();
    assert [erc1155_array_ids] = Uint256(25,0);
    assert [erc1155_array_ids + Uint256.SIZE] = Uint256(50,0);

    let (local erc1155_array_amounts : Uint256*) = alloc();
    assert [erc1155_array_amounts] = Uint256(2,0);
    assert [erc1155_array_amounts + Uint256.SIZE] = Uint256(10,0);


    let erc721_data : ERC721DataInput = ERC721DataInput(
        asset_contract=erc721_address,
        asset_id=7,
    );

    let (local erc721_array : ERC721DataInput*) = alloc();
    assert [erc721_array] = erc721_data;


    let erc20_data : ERC20DataInput = ERC20DataInput(
        asset_contract=erc20_address,
        amount=120,
    );

    let (local erc20_array : ERC20DataInput*) = alloc();
    assert [erc20_array] = erc20_data;

    // APPROVEs
    let (calling_address) = get_contract_address();

    IERC1155.setApprovalForAll(contract_address=erc1155_address, operator=contract_address, approved=1);
    let (res) = IERC20.approve(contract_address=erc20_address, spender=contract_address, amount=Uint256(120,0));
    assert res = 1;
    IERC721.setApprovalForAll(contract_address=erc721_address, operator=contract_address, approved=1);

    let (is_erc1155_approved) = IERC1155.isApprovedForAll(contract_address=erc1155_address, account=calling_address, operator=contract_address);
    assert is_erc1155_approved = 1;
    
    let (is_erc721_approved) = IERC721.isApprovedForAll(contract_address=erc1155_address, owner=calling_address, operator=contract_address);
    assert is_erc721_approved = 1;

    // OK 


    // MINT TOKENS TO THIS ADDRESS TO INITIATE A SWAP
    IERC20.mint(erc20_address, calling_address, Uint256(120,0));
    let (local null : felt*) = alloc();
    IERC1155.batchMint(erc1155_address, calling_address, 2, erc1155_array_ids, 2, erc1155_array_amounts, 0, null);
    IERC721.mint(erc721_address, calling_address, Uint256(7,0));

    // check if mint successful
    let (balance_nft : Uint256) = IERC721.balanceOf(erc721_address, calling_address);
    uint256_eq(balance_nft, Uint256(1,0));

    let (owner_nft) = IERC721.ownerOf(erc721_address, Uint256(7,0));
    assert owner_nft = calling_address;

    let (balance_token : Uint256) = IERC20.balanceOf(erc20_address, calling_address);

    uint256_eq(balance_token, Uint256(120,0));

    let (balance_erc1155_one : Uint256) = IERC1155.balanceOf(erc1155_address, calling_address, Uint256(25,0));
    uint256_eq(balance_erc1155_one, Uint256(2,0));

    let (balance_erc1155_two : Uint256) = IERC1155.balanceOf(erc1155_address, calling_address, Uint256(50,0));
    uint256_eq(balance_erc1155_one, Uint256(10,0));

    IOtcModule.open_swap(
        contract_address, 
        1,
        erc1155_datas,
        2,
        erc1155_array_ids,
        2,
        erc1155_array_amounts,
        1,
        erc721_array,
        1,
        erc20_array
    );

    let (new_counter) = IOtcModule.get_swap_counter(contract_address=contract_address);
    assert new_counter = 2;

    let (swap_status) = IOtcModule.get_swap_status(contract_address, 1);
    assert swap_status = 1;


    // BID
    %{ stop_prank_callable = start_prank(123) %}

    let (prank_caller) = get_caller_address();

    assert prank_caller = 123;

    %{ stop_prank_callable() %}

    // PARAMS BIDDER

    let erc1155_storage_b : ERC1155DataStorage = ERC1155DataStorage(
        asset_contract=erc1155_address,
        assets_ids_len=2,
        assets_amounts_len=2,
    );

    let (local erc1155_datas_b : ERC1155DataStorage*) = alloc();
    assert [erc1155_datas_b] = erc1155_storage_b;

    let (local erc1155_array_ids_b : Uint256*) = alloc();
    assert [erc1155_array_ids_b] = Uint256(75,0);
    assert [erc1155_array_ids_b + Uint256.SIZE] = Uint256(80,0);

    let (local erc1155_array_amounts_b : Uint256*) = alloc();
    assert [erc1155_array_amounts_b] = Uint256(4,0);
    assert [erc1155_array_amounts_b + Uint256.SIZE] = Uint256(15,0);


    let erc721_data_b : ERC721DataInput = ERC721DataInput(
        asset_contract=erc721_address,
        asset_id=90,
    );

    let (local erc721_array_b : ERC721DataInput*) = alloc();
    assert [erc721_array_b] = erc721_data_b;


    let erc20_data_b : ERC20DataInput = ERC20DataInput(
        asset_contract=erc20_address,
        amount=320,
    );

    let (local erc20_array_b : ERC20DataInput*) = alloc();
    assert [erc20_array_b] = erc20_data_b;


    // BID
    %{ stop_prank_callable = start_prank(123, ids.erc1155_address) %}
    IERC1155.batchMint(erc1155_address, prank_caller, 2, erc1155_array_ids_b, 2, erc1155_array_amounts_b, 0, null);


    let (balance_erc1155_one_b : Uint256) = IERC1155.balanceOf(erc1155_address, prank_caller, Uint256(75,0));
    uint256_eq(balance_erc1155_one_b, Uint256(4,0));

    let (balance_erc1155_two_b : Uint256) = IERC1155.balanceOf(erc1155_address, prank_caller, Uint256(80,0));
    uint256_eq(balance_erc1155_two_b, Uint256(15,0));
    // APPROVEs
    IERC1155.setApprovalForAll(contract_address=erc1155_address, operator=contract_address, approved=1);

    let (is_erc1155_approved_b) = IERC1155.isApprovedForAll(contract_address=erc1155_address, account=prank_caller, operator=contract_address);
    assert is_erc1155_approved_b = 1;

    %{ stop_prank_callable() %}
    
    %{ stop_prank_callable = start_prank(123, ids.erc20_address) %}

    IERC20.mint(erc20_address, prank_caller, Uint256(320,0));
    let (balance_token_b : Uint256) = IERC20.balanceOf(erc20_address, prank_caller);

    uint256_eq(balance_token_b, Uint256(320,0));

    let (res_b) = IERC20.approve(contract_address=erc20_address, spender=contract_address, amount=Uint256(320,0));
    assert res_b = 1;
    
    %{ stop_prank_callable() %}

    %{ stop_prank_callable = start_prank(123, ids.erc721_address) %}
    IERC721.mint(erc721_address, prank_caller, Uint256(90,0));

    // check if mint successful
    let (balance_nft_b : Uint256) = IERC721.balanceOf(erc721_address, prank_caller);
    uint256_eq(balance_nft_b, Uint256(1,0));

    let (owner_nft_b) = IERC721.ownerOf(erc721_address, Uint256(90,0));
    assert owner_nft_b = prank_caller;
    IERC721.setApprovalForAll(contract_address=erc721_address, operator=contract_address, approved=1);
    
    let (is_erc721_approved_b) = IERC721.isApprovedForAll(contract_address=erc1155_address, owner=prank_caller, operator=contract_address);
    assert is_erc721_approved_b = 1;

    %{ stop_prank_callable() %}

    // OK 

    %{ stop_prank_callable = start_prank(123, ids.contract_address) %}

    IOtcModule.bid_swap(
        contract_address,
        1,
        1,
        erc1155_datas_b,
        2,
        erc1155_array_ids_b,
        2,
        erc1155_array_amounts_b,
        1,
        erc721_array_b,
        1,
        erc20_array_b
    );
    let (am) = IOtcModule.get_amount_bids_per_swap(contract_address,1);
    assert am = 1;

    %{ stop_prank_callable() %}

    return ();

}

@external
func test_execute_swap{syscall_ptr: felt*, range_check_ptr}(){
    alloc_locals;

    local contract_address;

    local erc1155_address;
    local erc20_address;
    local erc721_address;

    local caller;
    %{ 
        ids.erc1155_address = context.erc1155_address
        ids.erc20_address = context.erc20_address
        ids.erc721_address = context.erc721_address
        ids.caller = context.deployer_address
        ids.contract_address = context.otc_module
    %}


    let (counter) = IOtcModule.get_swap_counter(contract_address=contract_address);
    assert counter = 1;

    // PARAMS OWNER

    let erc1155_storage : ERC1155DataStorage = ERC1155DataStorage(
        asset_contract=erc1155_address,
        assets_ids_len=2,
        assets_amounts_len=2,
    );

    let (local erc1155_datas : ERC1155DataStorage*) = alloc();
    assert [erc1155_datas] = erc1155_storage;

    let (local erc1155_array_ids : Uint256*) = alloc();
    assert [erc1155_array_ids] = Uint256(25,0);
    assert [erc1155_array_ids + Uint256.SIZE] = Uint256(50,0);

    let (local erc1155_array_amounts : Uint256*) = alloc();
    assert [erc1155_array_amounts] = Uint256(2,0);
    assert [erc1155_array_amounts + Uint256.SIZE] = Uint256(10,0);


    let erc721_data : ERC721DataInput = ERC721DataInput(
        asset_contract=erc721_address,
        asset_id=7,
    );

    let (local erc721_array : ERC721DataInput*) = alloc();
    assert [erc721_array] = erc721_data;


    let erc20_data : ERC20DataInput = ERC20DataInput(
        asset_contract=erc20_address,
        amount=120,
    );

    let (local erc20_array : ERC20DataInput*) = alloc();
    assert [erc20_array] = erc20_data;

    // APPROVEs
    let (calling_address) = get_contract_address();

    IERC1155.setApprovalForAll(contract_address=erc1155_address, operator=contract_address, approved=1);
    let (res) = IERC20.approve(contract_address=erc20_address, spender=contract_address, amount=Uint256(120,0));
    assert res = 1;
    IERC721.setApprovalForAll(contract_address=erc721_address, operator=contract_address, approved=1);

    let (is_erc1155_approved) = IERC1155.isApprovedForAll(contract_address=erc1155_address, account=calling_address, operator=contract_address);
    assert is_erc1155_approved = 1;
    
    let (is_erc721_approved) = IERC721.isApprovedForAll(contract_address=erc1155_address, owner=calling_address, operator=contract_address);
    assert is_erc721_approved = 1;

    // OK 


    // MINT TOKENS TO THIS ADDRESS TO INITIATE A SWAP
    IERC20.mint(erc20_address, calling_address, Uint256(120,0));
    let (local null : felt*) = alloc();
    IERC1155.batchMint(erc1155_address, calling_address, 2, erc1155_array_ids, 2, erc1155_array_amounts, 0, null);
    IERC721.mint(erc721_address, calling_address, Uint256(7,0));

    // check if mint successful
    let (balance_nft : Uint256) = IERC721.balanceOf(erc721_address, calling_address);
    uint256_eq(balance_nft, Uint256(1,0));

    let (owner_nft) = IERC721.ownerOf(erc721_address, Uint256(7,0));
    assert owner_nft = calling_address;

    let (balance_token : Uint256) = IERC20.balanceOf(erc20_address, calling_address);

    uint256_eq(balance_token, Uint256(120,0));

    let (balance_erc1155_one : Uint256) = IERC1155.balanceOf(erc1155_address, calling_address, Uint256(25,0));
    uint256_eq(balance_erc1155_one, Uint256(2,0));

    let (balance_erc1155_two : Uint256) = IERC1155.balanceOf(erc1155_address, calling_address, Uint256(50,0));
    uint256_eq(balance_erc1155_one, Uint256(10,0));

    IOtcModule.open_swap(
        contract_address, 
        1,
        erc1155_datas,
        2,
        erc1155_array_ids,
        2,
        erc1155_array_amounts,
        1,
        erc721_array,
        1,
        erc20_array
    );

    let (new_counter) = IOtcModule.get_swap_counter(contract_address=contract_address);
    assert new_counter = 2;

    let (swap_status) = IOtcModule.get_swap_status(contract_address, 1);
    assert swap_status = 1;


    // BID
    %{ stop_prank_callable = start_prank(123) %}

    let (prank_caller) = get_caller_address();

    assert prank_caller = 123;

    %{ stop_prank_callable() %}

    // PARAMS BIDDER

    let erc1155_storage_b : ERC1155DataStorage = ERC1155DataStorage(
        asset_contract=erc1155_address,
        assets_ids_len=2,
        assets_amounts_len=2,
    );

    let (local erc1155_datas_b : ERC1155DataStorage*) = alloc();
    assert [erc1155_datas_b] = erc1155_storage_b;

    let (local erc1155_array_ids_b : Uint256*) = alloc();
    assert [erc1155_array_ids_b] = Uint256(75,0);
    assert [erc1155_array_ids_b + Uint256.SIZE] = Uint256(80,0);

    let (local erc1155_array_amounts_b : Uint256*) = alloc();
    assert [erc1155_array_amounts_b] = Uint256(4,0);
    assert [erc1155_array_amounts_b + Uint256.SIZE] = Uint256(15,0);


    let erc721_data_b : ERC721DataInput = ERC721DataInput(
        asset_contract=erc721_address,
        asset_id=90,
    );

    let (local erc721_array_b : ERC721DataInput*) = alloc();
    assert [erc721_array_b] = erc721_data_b;


    let erc20_data_b : ERC20DataInput = ERC20DataInput(
        asset_contract=erc20_address,
        amount=320,
    );

    let (local erc20_array_b : ERC20DataInput*) = alloc();
    assert [erc20_array_b] = erc20_data_b;


    // BID
    %{ stop_prank_callable = start_prank(123, ids.erc1155_address) %}
    IERC1155.batchMint(erc1155_address, prank_caller, 2, erc1155_array_ids_b, 2, erc1155_array_amounts_b, 0, null);


    let (balance_erc1155_one_b : Uint256) = IERC1155.balanceOf(erc1155_address, prank_caller, Uint256(75,0));
    uint256_eq(balance_erc1155_one_b, Uint256(4,0));

    let (balance_erc1155_two_b : Uint256) = IERC1155.balanceOf(erc1155_address, prank_caller, Uint256(80,0));
    uint256_eq(balance_erc1155_two_b, Uint256(15,0));
    // APPROVEs
    IERC1155.setApprovalForAll(contract_address=erc1155_address, operator=contract_address, approved=1);

    let (is_erc1155_approved_b) = IERC1155.isApprovedForAll(contract_address=erc1155_address, account=prank_caller, operator=contract_address);
    assert is_erc1155_approved_b = 1;

    %{ stop_prank_callable() %}
    
    %{ stop_prank_callable = start_prank(123, ids.erc20_address) %}

    IERC20.mint(erc20_address, prank_caller, Uint256(320,0));
    let (balance_token_b : Uint256) = IERC20.balanceOf(erc20_address, prank_caller);

    uint256_eq(balance_token_b, Uint256(320,0));

    let (res_b) = IERC20.approve(contract_address=erc20_address, spender=contract_address, amount=Uint256(320,0));
    assert res_b = 1;
    
    %{ stop_prank_callable() %}

    %{ stop_prank_callable = start_prank(123, ids.erc721_address) %}
    IERC721.mint(erc721_address, prank_caller, Uint256(90,0));

    // check if mint successful
    let (balance_nft_b : Uint256) = IERC721.balanceOf(erc721_address, prank_caller);
    uint256_eq(balance_nft_b, Uint256(1,0));

    let (owner_nft_b) = IERC721.ownerOf(erc721_address, Uint256(90,0));
    assert owner_nft_b = prank_caller;
    IERC721.setApprovalForAll(contract_address=erc721_address, operator=contract_address, approved=1);
    
    let (is_erc721_approved_b) = IERC721.isApprovedForAll(contract_address=erc1155_address, owner=prank_caller, operator=contract_address);
    assert is_erc721_approved_b = 1;

    %{ stop_prank_callable() %}

    // OK 

    %{ stop_prank_callable = start_prank(123, ids.contract_address) %}

    IOtcModule.bid_swap(
        contract_address,
        1,
        1,
        erc1155_datas_b,
        2,
        erc1155_array_ids_b,
        2,
        erc1155_array_amounts_b,
        1,
        erc721_array_b,
        1,
        erc20_array_b
    );
    let (am) = IOtcModule.get_amount_bids_per_swap(contract_address,1);
    assert am = 1;


    %{ stop_prank_callable() %}


    IOtcModule.execute_swap(contract_address, 1, 0);

    let (new_swap_status) = IOtcModule.get_swap_status(contract_address, 1);
    assert new_swap_status = 2;


    //let (add : felt, id : Uint256) = IOtcModule.get_erc721_per_swap(contract_address, 1, 0);
    //assert add = erc721_address;
    //uint256_eq(id, Uint256(7,0));
    return ();
}