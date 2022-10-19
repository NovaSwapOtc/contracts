
%lang starknet
%builtins pedersen range_check bitwise

from starkware.cairo.common.bitwise import bitwise_and
from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.starknet.common.syscalls import (
    get_caller_address,
    get_contract_address,
    get_block_timestamp,
)
from starkware.cairo.common.math import (
    assert_nn_le, 
    unsigned_div_rem, 
    assert_lt_felt, 
    assert_not_zero,
    assert_not_equal,
    split_felt
)
from starkware.cairo.common.uint256 import (
    Uint256, 
    uint256_le, 
    uint256_eq,
    uint256_add,
    uint256_sub
)

from starkware.cairo.common.bool import TRUE, FALSE

from openzeppelin.token.erc20.IERC20 import IERC20
from openzeppelin.token.erc721.IERC721 import IERC721
from src.utils.token.erc1155.interfaces.IERC1155 import IERC1155

from src.utils.token.erc1155.library import ERC1155
from openzeppelin.introspection.erc165.library import ERC165

from openzeppelin.upgrades.library import Proxy

from openzeppelin.access.ownable.library import Ownable

from openzeppelin.security.pausable.library import Pausable

from src.utils.constants import (
    ON_ERC1155_RECEIVED_SELECTOR,
    ON_ERC1155_BATCH_RECEIVED_SELECTOR,
)

//
// STRUCTS
//

namespace Erc1155SwapStatus {
    const Opened = 1;
    const Executed = 2;
    const Cancelled = 3;
}

struct Erc1155Swap {
    id : felt,
    owner : felt,
    asset_contract: felt,
    asset_ids_len : felt,
    asset_amounts_len : felt,
    status: felt,  // from Erc1155SwapStatus
    //expiration : felt,
}

// Struct which represents the ERC1155 that a user can give/ask 
struct ERC1155DataStorage{
    asset_contract : felt,
    assets_ids_len: felt,
    assets_amounts_len : felt,
}

// Struct which represents the ERC721 that a user can give/ask in function param

struct ERC721DataInput {
    asset_contract : felt,
    asset_id : felt,
}

// Struct which represents the ERC721 that a user can give/ask 
struct ERC721Data {
    asset_contract : felt,
    asset_id : Uint256,
}

// Struct which represents the ERC20 that a user can give/ask in function param
struct ERC20DataInput {
    asset_contract : felt,
    amount : felt,
}

// Struct which represents the ERC20 that a user can give/ask 
struct ERC20Data {
    asset_contract : felt,
    amount : Uint256,
}

struct Swap{
    id : felt,
    owner : felt,
    status: felt,
}

// Struct which represents the Bid of a user interested in a swap opened on the protocol
struct Bid {
    bid_id : felt,
    owner : felt,
    successful : felt,
}
// 
// EVENTS
//

@event
func SwapOpened(swap: Swap, executor : felt) {
}

@event
func SwapCancelled(swap : Swap) {
}

@event
func SwapExecuted(swap : Swap, executor : felt) {
}

//
// Storage
// 

///// SWAPS STORAGE
//////////////////

// Indexed list of all swaps
@storage_var
func _swaps(idx: felt) -> (swap : Erc1155Swap) {
}
@storage_var
func _swaps_v2(idx : felt) -> (swap: Swap) {
}


// Tracks all the token ids (ERC1155) per swap
@storage_var
func _assets_ids_per_swap(idx : felt, j : felt) -> (id : Uint256) {
}

// Tracks all the amount ids (ERC1155) per swap
@storage_var
func _amounts_ids_per_swap(idx : felt, j : felt) -> (amount : Uint256) {
}

// The current number of swaps
@storage_var
func _swaps_counter() -> (value: felt) {
}


///// BIDS STORAGE
//////////////////

// Tracks the number of bids per swap
@storage_var
func bids_counter_per_swap(swap_id : felt) -> (bid_counter: felt) {
}

// Mapping of bids per swap
// Each bid is just represented by its struct Bid with a unique id & a successful flag (if it has been accepted by owner of swap)
@storage_var
func bids_per_swap(swap_id : felt, idx : felt) -> (res: Bid) {
}

// The current number of ERC1155 "offered" by a bidder. It is classified by swap_id and by bid_id. 
@storage_var
func erc1155_assets_per_bid_amount(swap_id : felt, bid_id : felt) -> (amount: felt) {
}

// Tracks the ERC1155 assets "offered" by a bidder. It is classified by swap_id and by bid_id. 
// One bid_id can have multiple ERC1155 assets
@storage_var
func mapping_erc1155_assets_per_bid(swap_id : felt, bid_id : felt, idx : felt) -> (res: ERC1155DataStorage) {
}

// Tracks the ERC1155 tokens ids "offered" by a bidder. 
// It is classified by bid_id and by swap_id for each single ERC1155Data.
// idx : index of current ERC1155Data of the specific bid_id
// Remember : One bid_id can have multiple ERC1155 assets 
@storage_var
func mapping_erc1155_ids_per_bid(swap_id : felt, bid_id : felt, idx : felt, idx_token_id : felt) -> (id: Uint256) {
}

// Tracks the ERC1155 tokens amounts "offered" by a bidder. 
// It is classified by bid_id and by swap_id for each single ERC1155Data.
// idx : index of current ERC1155Data of the specific bid_id
// Remember : One bid_id can have multiple ERC1155 assets 
@storage_var
func mapping_erc1155_amounts_per_bid(swap_id : felt, bid_id : felt, idx : felt, idx_token_id : felt) -> (amount: Uint256) {
}

// The current number of ERC721 "offered" by a bidder. It is classified by swap_id and by bid_id. 
@storage_var
func erc721_assets_per_bid_amount(swap_id : felt, bid_id : felt) -> (amount: felt) {
}

// Tracks the ERC721 assets "offered" by a bidder. It is classified by swap_id and by bid_id. 
// One bid_id can have multiple ERC721 assets
@storage_var
func mapping_erc721_assets_per_bid(swap_id : felt, bid_id : felt, idx : felt) -> (res: ERC721Data) {
}

// The current number of ERC20 "offered" by a bidder. It is classified by swap_id and by bid_id. 
@storage_var
func erc20_assets_per_bid_amount(swap_id : felt, bid_id : felt) -> (amount: felt) {
}

// Tracks the ERC20 assets "offered" by a bidder. It is classified by swap_id and by bid_id. 
// One bid_id can have multiple ERC20 assets
@storage_var
func mapping_erc20_assets_per_bid(swap_id : felt, bid_id : felt, idx : felt) -> (res: ERC20Data) {
}



@storage_var
func mapping_erc1155_assets_per_swap(swap_id : felt, idx : felt) -> (res: ERC1155DataStorage) {
}

@storage_var
func mapping_erc1155_ids_per_swap(swap_id : felt, idx : felt, idx_token_id : felt) -> (id: Uint256) {
}

@storage_var
func mapping_erc1155_amounts_per_swap(swap_id : felt, idx : felt, idx_token_id : felt) -> (amount: Uint256) {
}



@storage_var
func erc1155_assets_per_swap_amount(swap_id : felt) -> (amount: felt) {
}

@storage_var
func erc20_assets_per_swap_amount(swap_id : felt) -> (amount: felt) {
}
@storage_var
func mapping_erc20_assets_per_swap(swap_id : felt, idx : felt) -> (res: ERC20Data) {
}

@storage_var
func erc721_assets_per_swap_amount(swap_id : felt) -> (amount: felt) {
}
@storage_var
func mapping_erc721_assets_per_swap(swap_id : felt, idx : felt) -> (res: ERC721Data) {
}



//##############
// CONSTRUCTOR #
//##############

@constructor
func constructor{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    proxy_admin : felt
) {
    //Proxy.initializer(proxy_admin);    
    Ownable.initializer(proxy_admin);
    _swaps_counter.write(1);
    return ();
}


@external
func open_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    erc1155_datas_len : felt,
    erc1155_datas : ERC1155DataStorage*,
    erc1155_array_ids_len : felt,
    erc1155_array_ids : Uint256*,
    erc1155_array_amounts_len : felt,
    erc1155_array_amounts : Uint256*,
    erc721_array_len : felt,
    erc721_array : ERC721DataInput*,
    erc20_array_len : felt,
    erc20_array : ERC20DataInput*,
    // _expiration : felt
) {
    alloc_locals;

    Pausable.assert_not_paused();

    let (caller) = get_caller_address();

    with_attr error_message("ERC1155_EXCHANGE: caller MUST BE different than 0") {
        assert_not_zero(caller);
    }
    with_attr error_message("ERC1155_EXCHANGE: erc1155_array_ids_len MUST BE equals to erc1155_array_amounts_len") {
        assert erc1155_array_ids_len = erc1155_array_amounts_len;
    }
    assert_sizes_correct(erc1155_datas_len,erc1155_datas,erc1155_array_ids_len);

    //with_attr error_message("ERC1155_EXCHANGE: _expiration MUST BE different than 0") {
      //  assert_not_zero(_expiration);
    //}
    // check if expiration is valid
    //with_attr error_message("ERC1155_EXCHANGE: _expiration MUST BE greater than 1 day") {
        //let (block_timestamp) = get_block_timestamp();
        // actual time + 1 day in seconds
        //let sum_future = block_timestamp + 86400;
        //assert_nn_le(block_timestamp, _expiration);
    //}

 
    
    // make sure caller owns the erc1155 assets
    assert_erc1155_owned(0, erc1155_datas_len, erc1155_datas, erc1155_array_ids_len, erc1155_array_ids, erc1155_array_amounts);

    // TODO : make sure caller owns the erc721, erc20 assets


    let (swaps_count) = _swaps_counter.read();

    local swap : Swap = Swap(swaps_count, caller, Erc1155SwapStatus.Opened);
    _swaps_v2.write(swaps_count, swap);

    // Store the amount of ERC1155 being "offered" for swap_id
    erc1155_assets_per_swap_amount.write(swaps_count, erc1155_datas_len);

    // Save ERC1155 data for this (swap_id)
    _write_storage_swap_erc1155_data(0, swaps_count, erc1155_datas_len, erc1155_datas);

    // Save ERC1155 ids for each single ERC1155Data for this (swap_id)
    _write_storage_swap_erc1155_ids(0, swaps_count, erc1155_datas_len, erc1155_array_ids); 

    // Save ERC1155 amounts for each single ERC1155Data for this (swap_id)
    _write_storage_swap_erc1155_amounts(0, swaps_count, erc1155_datas_len, erc1155_array_amounts);

    // Store the amount of ERC721 being "offered" for swap_id
    erc721_assets_per_swap_amount.write(swaps_count, erc721_array_len);
    // Save ERC721 data for this (swap_id)
    _write_storage_swap_erc721_data(0, swaps_count, erc721_array_len, erc721_array);

    // Store the amount of ERC20 being "offered" for swap_id
    erc20_assets_per_swap_amount.write(swaps_count, erc20_array_len);
    // Save ERC20 data for this (swap_id)
    _write_storage_swap_erc20_data(0, swaps_count, erc20_array_len, erc20_array);


    
    // increment
    _swaps_counter.write(swaps_count + 1);

    SwapOpened.emit(swap, caller);

    return ();
}

// Party that is interested in the swap denominated by swap_id
// As Cairo doesnt allow to have  a struct which contains a pointer
// we accept the erc1155_array as : 
// [token_id_1, token_amount_1, token_id_2, token_amount_2, 
// token_id_3, token_amount_4, token_id_4, token_amount_4, ...]  
// we accept the erc1155_datas array as struct ERC1155DataStorage*
// [DATA_1, DATA_2, DATA_3, DATA_4, ...] where each DATA_N = {asset_contract, assets_ids_len, assets_amounts_len}
// it is directly tied to the erc1155_array
// if DATA_1 = {asset_contract="0x07656534346", assets_ids_len=2, assets_amounts_len=2} (yes they MUST be equal ofc
// then {{ token_id_1, token_amount_1, token_id_2, token_amount_2 }} from erc1155_array 
// are related to the first DATA_1 struct, hence we exactly know who each pair (asset, amount) belongs to.
@external
func bid_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt,
    erc1155_datas_len : felt,
    erc1155_datas : ERC1155DataStorage*,
    erc1155_array_ids_len : felt,
    erc1155_array_ids : Uint256*,
    erc1155_array_amounts_len : felt,
    erc1155_array_amounts : Uint256*,
    erc721_array_len : felt,
    erc721_array : ERC721DataInput*,
    erc20_array_len : felt,
    erc20_array : ERC20DataInput*,
) {
    alloc_locals;
    let (caller) = get_caller_address();
    let (swap_count) = _swaps_counter.read();

    with_attr error_message("ERC1155_EXCHANGE: caller MUST BE different than 0") {
        assert_not_zero(caller);
    }

    let (swap : Swap) = _swaps_v2.read(swap_id);
    with_attr error_message("ERC1155_EXCHANGE: owner CAN NOT bid on its own swap") {
      assert_not_equal(caller, swap.owner);
    }

    with_attr error_message("ERC1155_EXCHANGE: swap id UNVALID") {
        assert_nn_le(swap_id, swap_count);
    }

    assert_sizes_correct(erc1155_datas_len,erc1155_datas,erc1155_array_ids_len);


    
    // make sure caller owns the erc1155 assets
    assert_erc1155_owned(0, erc1155_datas_len,erc1155_datas,erc1155_array_ids_len,erc1155_array_ids,erc1155_array_amounts);
    //
   
    let (bids_count) = bids_counter_per_swap.read(swap_id);


    local bid : Bid = Bid(bids_count, caller, FALSE);

    // Save bid for this swap_id
    bids_per_swap.write(swap_id, bids_count, bid); 

    // Store the amount of ERC1155 being "offered" inside this bid for swap_id
    erc1155_assets_per_bid_amount.write(swap_id, bids_count, erc1155_datas_len);

    // Save ERC1155 data for this (swap_id, bid_id)
    _write_storage_bid_erc1155_data(0, swap_id, bids_count, erc1155_datas_len, erc1155_datas);

    
    // Save ERC1155 ids for each single ERC1155Data for this (swap_id)
    _write_storage_bid_erc1155_ids(0, swap_id, bids_count, erc1155_datas_len, erc1155_array_ids); 

    // Save ERC1155 amounts for each single ERC1155Data for this (swap_id)
    _write_storage_bid_erc1155_amounts(0, swap_id, bids_count, erc1155_datas_len, erc1155_array_amounts);

    // Store the amount of ERC721 being "offered" inside this bid for swap_id
    erc721_assets_per_bid_amount.write(swap_id, bids_count, erc721_array_len);
    // Save ERC721 data for this (swap_id, bid_id)
    _write_storage_bid_erc721_data(0, swap_id, bids_count, erc721_array_len, erc721_array);

    // Store the amount of ERC20 being "offered" inside this bid for swap_id
    erc20_assets_per_bid_amount.write(swap_id, bids_count, erc20_array_len);
    // Save ERC20 data for this (swap_id, bid_id)
    _write_storage_bid_erc20_data(0, swap_id, bids_count, erc20_array_len, erc20_array);

    // Increment number of bids for this swap_id
    bids_counter_per_swap.write(swap_id, bids_count + 1);

    return ();
}



@external
func cancel_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt
) {
    alloc_locals;
    Pausable.assert_not_paused();
    let (swap : Swap) = _swaps_v2.read(swap_id);
    let (caller) = get_caller_address();

    with_attr error_message("ERC1155_EXCHANGE: Swap MUST BE OPENED") {
        assert swap.status = Erc1155SwapStatus.Opened;
    }

    with_attr error_message("ERC1155_EXCHANGE: Swap MUST BE cancelled by Owner") {
        assert caller = swap.owner;
    }
    // TODO : if expiration exists do a check if it has expired 
    local cancelled_swap : Swap = Swap(
        swap.id,
        swap.owner,
        Erc1155SwapStatus.Cancelled,
    );
    _swaps_v2.write(swap_id, cancelled_swap);
    SwapCancelled.emit(cancelled_swap);
    return (); 
}

//TODO
@external
func execute_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    
) {
    return (); 
}

// VIEWS

////////
//////// BIDS GETTERS
////////

// TODO : Get All Bids Of Swap swap_id
@view
func get_bids_of_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt
) -> (res : felt){
    alloc_locals;
    
    return (res=0);
}

// Get Amount Of Bids for Swap swap_id
@view
func get_amount_bids_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt
) -> (res : felt){
    alloc_locals;
    let (count) = bids_counter_per_swap.read(swap_id);
    return (res=count);
}

// Get Amount Of ERC1155 assets "offered" for a swap_id, inside a bid_id
@view
func get_erc1155_bids_per_swap_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt, bid_id : felt
)-> (res : felt){
    let (count) = erc1155_assets_per_bid_amount.read(swap_id, bid_id);
    return (res=count);
}

// Get ERC1155 data inside a bid_id, for a swap_id for specific index idx
// Indeed we might have several ERC1155 Data being "offered" for one bid id
// It returns the ERC1155 address and the amounts of ids being "offered"
@view
func get_erc1155_bids_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt, bid_id : felt, idx : felt
) -> (address: felt, amount : felt){
    alloc_locals;
    let (local data_storage : ERC1155DataStorage) = mapping_erc1155_assets_per_bid.read(swap_id, bid_id, idx);
    return (address=data_storage.asset_contract, amount=data_storage.assets_ids_len);
}

// It returns the ERC1155 token ids being "offered" inside a bid_id, for a swap_id for specific index idx
// Indeed we might have several ERC1155 Data being "offered" for one bid id
@view
func get_erc1155_ids_per_bid_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt, bid_id : felt, idx : felt
) -> (res_len: felt, res : Uint256*){
    alloc_locals;
    let (local data_storage : ERC1155DataStorage) = mapping_erc1155_assets_per_bid.read(swap_id, bid_id, idx);
    local size = data_storage.assets_ids_len;
    let (local array : Uint256*) = alloc();
    _get_erc1155_ids_per_bid_per_swap(start=0, to_fill=array, array_len=size, swap_id=swap_id, bid_id=bid_id, idx=idx);
    return (res_len=size, res=array);
}

// It returns the ERC1155 token amounts being "offered" inside a bid_id, for a swap_id for specific index idx
// Indeed we might have several ERC1155 Data being "offered" for one bid id
@view
func get_erc1155_amounts_per_bid_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt, bid_id : felt, idx : felt
) -> (res_len: felt, res : Uint256*){
    alloc_locals;
    let (local data_storage : ERC1155DataStorage) = mapping_erc1155_assets_per_bid.read(swap_id, bid_id, idx);
    local size = data_storage.assets_amounts_len;
    let (local array : Uint256*) = alloc();
    _get_erc1155_amounts_per_bid_per_swap(start=0, to_fill=array, array_len=size, swap_id=swap_id, bid_id=bid_id, idx=idx);
    return (res_len=size, res=array);
}

// Get Amount Of ERC20 assets "offered" for a swap_id, inside a bid_id
@view
func get_erc20_bids_per_swap_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt, bid_id : felt
)-> (res : felt){
    let (count) = erc20_assets_per_bid_amount.read(swap_id, bid_id);
    return (res=count);
}


// Get ERC20 data inside a bid_id, for a swap_id for specific index idx
// Indeed we might have several ERC20 Data being "offered" for one bid id
@view
func get_erc20_bids_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt, bid_id : felt, idx : felt
) -> (address : felt, amount : Uint256){
    alloc_locals;
    let (local data : ERC20Data) = mapping_erc20_assets_per_bid.read(swap_id, bid_id, idx);
    return (address=data.asset_contract, amount=data.amount);
}

// Get Amount Of ERC721 assets "offered" for a swap_id, inside a bid_id
@view
func get_erc721_bids_per_swap_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt, bid_id : felt
)-> (res : felt){
    let (count) = erc721_assets_per_bid_amount.read(swap_id, bid_id);
    return (res=count);
}

// Get ERC721 data inside a bid_id, for a swap_id for specific index idx
// Indeed we might have several ERC721 Data being "offered" for one bid id
@view
func get_erc721_bids_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt, bid_id : felt, idx : felt
) -> (address : felt, id : Uint256){
    alloc_locals;
    let (local data : ERC721Data) = mapping_erc721_assets_per_bid.read(swap_id, bid_id, idx);
    return (address=data.asset_contract, id=data.asset_id);
}

@view
func get_bidders_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt
) -> (res_len : felt, res : felt*){
    alloc_locals;
    let (local count) = bids_counter_per_swap.read(swap_id);
    let (local bidders : felt*) = alloc();
    _get_bidders(start=0, swap_id=swap_id, bidders=bidders, end=count);
    return (res_len=count, res=bidders);
}
@view
func get_bids_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt
) -> (res_len : felt, res : felt*){
    alloc_locals;
    let (local count) = bids_counter_per_swap.read(swap_id);
    let (local bids : felt*) = alloc();
    _get_bids(start=0, swap_id=swap_id, bids=bids, end=count);
    return (res_len=count, res=bids);
}


////////
//////// SWAP GETTERS
////////

// Get Activated Swap represented by idx
@view
func get_active_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    idx : felt
) -> (res : felt){
    alloc_locals;
    let (_, local swap_ids : felt*) = _get_active_swaps();
    let value = swap_ids[idx];
    return (res=value);
}

@view
func get_active_swaps_len{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (res : felt){
    alloc_locals;
    let (local swaps_ids_len : felt, _) = _get_active_swaps();
    return (res=swaps_ids_len);
}

// Get Cancelled Swap represented by idx
@view
func get_cancelled_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    idx : felt
) -> (res : felt){
    alloc_locals;
    let (_, local swap_ids : felt*) = _get_cancelled_swaps();
    let value = swap_ids[idx];
    return (res=value);
}

// Get Amount Of Cancelled Swaps
@view
func get_cancelled_swaps_len{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (res : felt){
    alloc_locals;
    let (local swaps_ids_len : felt, _) = _get_cancelled_swaps();
    return (res=swaps_ids_len);
}

// Get Executed Swap represented by idx
@view
func get_executed_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    idx : felt
) -> (res : felt){
    alloc_locals;
    let (_, local swap_ids : felt*) = _get_executed_swaps();
    let value = swap_ids[idx];
    return (res=value);
}

// Get Amount Of Executed Swaps
@view
func get_executed_swaps_len{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (res : felt){
    alloc_locals;
    let (local swaps_ids_len : felt, _) = _get_executed_swaps();
    return (res=swaps_ids_len);
}


// Get Actual Time
@view
func get_timestamp{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (res: felt){
    let (block_timestamp) = get_block_timestamp();
    return (res=block_timestamp);
}   

// Get Swap by Id
@view
func get_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    idx: felt
) -> (
    swap: Swap
) {
   return _swaps_v2.read(idx);
}

// Get Swap Owner of swap idx
@view
func get_swap_owner{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    idx: felt
) -> (
    res: felt
) {
    let (swap : Swap) = _swaps_v2.read(idx);
    return (res=swap.owner);
}

// Get Swap Id of swap idx
@view
func get_swap_id{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    idx: felt
) -> (
    res: felt
) {
    let (swap : Swap) = _swaps_v2.read(idx);
    return (res=swap.id);
}

// Get Amount Of Swaps
@view
func get_swap_counter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (
    value: felt
) {
    return  _swaps_counter.read();
}

// Get Asset Status of Swap idx
@view
func get_swap_status{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    idx: felt
) -> (status: felt) {
    let (swap : Swap) = _swaps_v2.read(idx);
    return (status=swap.status);
}

@view
func get_erc1155_per_swap_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt
)-> (res : felt){
    let (count) = erc1155_assets_per_swap_amount.read(swap_id);
    return (res=count);
}

@view
func get_erc1155_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt, idx : felt
) -> (address: felt, amount : felt){
    alloc_locals;
    let (local data_storage : ERC1155DataStorage) = mapping_erc1155_assets_per_swap.read(swap_id, idx);
    return (address=data_storage.asset_contract, amount=data_storage.assets_ids_len);
}

@view
func get_erc1155_ids_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt, idx : felt
) -> (res_len: felt, res : Uint256*){
    alloc_locals;
    let (local data_storage : ERC1155DataStorage) = mapping_erc1155_assets_per_swap.read(swap_id, idx);
    local size = data_storage.assets_ids_len;
    let (local array : Uint256*) = alloc();
    _get_erc1155_ids_per_swap(start=0, to_fill=array, array_len=size, swap_id=swap_id, idx=idx);
    return (res_len=size, res=array);
}
@view
func get_erc1155_amounts_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt, idx : felt
) -> (res_len: felt, res : Uint256*){
    alloc_locals;
    let (local data_storage : ERC1155DataStorage) = mapping_erc1155_assets_per_swap.read(swap_id, idx);
    local size = data_storage.assets_amounts_len;
    let (local array : Uint256*) = alloc();
    _get_erc1155_amounts_per_swap(start=0, to_fill=array, array_len=size, swap_id=swap_id, idx=idx);
    return (res_len=size, res=array);
}

@view
func get_erc20_per_swap_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt
)-> (res : felt){
    let (count) = erc20_assets_per_swap_amount.read(swap_id);
    return (res=count);
}


@view
func get_erc20_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt, idx : felt
) -> (address : felt, amount : Uint256){
    alloc_locals;
    let (local data : ERC20Data) = mapping_erc20_assets_per_swap.read(swap_id, idx);
    return (address=data.asset_contract, amount=data.amount);
}

@view
func get_erc721_per_swap_amount{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt
)-> (res : felt){
    let (count) = erc721_assets_per_swap_amount.read(swap_id);
    return (res=count);
}

@view
func get_erc721_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    swap_id : felt, idx : felt
) -> (address : felt, id : Uint256){
    alloc_locals;
    let (local data : ERC721Data) = mapping_erc721_assets_per_swap.read(swap_id, idx);
    return (address=data.asset_contract, id=data.asset_id);
}

//
// SETTERS 
//

@external
func pause{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Ownable.assert_only_owner();
    Pausable._pause();
    return ();
}
@external
func unpause{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}() {
    Ownable.assert_only_owner();
    Pausable._unpause();
    return ();
}


// INTERNALS


func _assert_data_sizes{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, erc1155_datas_len : felt, erc1155_datas : ERC1155DataStorage*
) {
    if (start==erc1155_datas_len) {
        return ();
    }
    let data_storage : ERC1155DataStorage = [erc1155_datas];
 
    let token_amounts_len = data_storage.assets_amounts_len;
    let token_ids_len = data_storage.assets_ids_len;
    with_attr error_message("ERC1155_EXCHANGE: token_amounts_len MUST BE equals to token_ids_len") {
        assert token_amounts_len = token_ids_len;
    }
    return _assert_data_sizes(start=start+1, erc1155_datas_len=erc1155_datas_len, erc1155_datas=erc1155_datas+ERC1155DataStorage.SIZE);
}

func _get_added_size{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, erc1155_datas_len : felt, erc1155_datas : ERC1155DataStorage*, sum : felt
)-> (res : felt){
    if (start==erc1155_datas_len) {
        return (res=sum);
    }
    let data_storage : ERC1155DataStorage = [erc1155_datas];
    let part_sum = 2 * data_storage.assets_amounts_len;
    return _get_added_size(
        start=start+1, erc1155_datas_len=erc1155_datas_len,erc1155_datas=erc1155_datas+ERC1155DataStorage.SIZE, sum=sum+part_sum
    );
}

func assert_sizes_correct{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    erc1155_datas_len : felt, erc1155_datas : ERC1155DataStorage*, erc1155_array_ids_len : felt
) {
    // Check if token_amount == ids_amount for each data inside erc1155_datas
    _assert_data_sizes(start=0,erc1155_datas_len=erc1155_datas_len, erc1155_datas=erc1155_datas);

    let (added_size) = _get_added_size(0, erc1155_datas_len, erc1155_datas, 0);
    with_attr error_message("ERC1155_EXCHANGE: erc1155_array MUST BE equals to storage data sizes summed") {
        assert added_size = 2 * erc1155_array_ids_len;
    }
    return ();
}

func assert_erc1155_owned{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, erc1155_datas_len : felt, erc1155_datas : ERC1155DataStorage*, erc1155_array_len_ids : felt, erc1155_array_ids : Uint256*, erc1155_array_amounts : Uint256*
){
    if (start==erc1155_datas_len) {
        return ();
    }
    let data_storage : ERC1155DataStorage = [erc1155_datas];

    let address_erc1155 = data_storage.asset_contract;
    let token_amounts_len = data_storage.assets_amounts_len;
    let token_ids_len = data_storage.assets_ids_len;
    _assert_erc1155_owned(0, address_erc1155,token_amounts_len, erc1155_array_ids, erc1155_array_amounts);

    return assert_erc1155_owned(start=start+1, erc1155_datas_len=erc1155_datas_len, erc1155_datas=erc1155_datas + ERC1155DataStorage.SIZE, erc1155_array_len_ids=erc1155_array_len_ids, erc1155_array_ids=erc1155_array_ids+ token_amounts_len * Uint256.SIZE, erc1155_array_amounts=erc1155_array_amounts+ token_amounts_len * Uint256.SIZE);
}

func _assert_erc1155_owned{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, address_erc1155 : felt , token_amounts_len : felt, erc1155_array_ids : Uint256*, erc1155_array_amounts : Uint256*
){
    if (start==token_amounts_len) {
        return ();
    }
    let (caller) = get_caller_address();
    // check if user owns token_amount of token_id of ERC1155 contract address
    let id : Uint256 = [erc1155_array_ids];
    let amount : Uint256 = [erc1155_array_amounts];

    let (balance : Uint256) = IERC1155.balanceOf(contract_address=address_erc1155, owner=caller, token_id=id);
    with_attr error_message("ERC1155_EXCHANGE : Error Inside Asserting Min Amounts Are Available") {
        uint256_le(amount, balance);
    }
    return _assert_erc1155_owned(start=start+1, address_erc1155=address_erc1155 , token_amounts_len=token_amounts_len, erc1155_array_ids=erc1155_array_ids+Uint256.SIZE, erc1155_array_amounts=erc1155_array_amounts+Uint256.SIZE);
}




func _write_storage_swap_erc1155_ids{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, swap_id : felt, erc1155_datas_len :felt, ids_array : Uint256*
){
    alloc_locals;
    if(start==erc1155_datas_len){
        return ();
    }
    // get size of ids array for index start of ERC1155DataStorage
    let (local data_storage: ERC1155DataStorage) = mapping_erc1155_assets_per_swap.read(swap_id, start);
    let assets_ids_len = data_storage.assets_ids_len;

    _write_storage_swap_erc1155_ids_inter(start, 0, swap_id, assets_ids_len, ids_array);
    return _write_storage_swap_erc1155_ids(start=start+1, swap_id=swap_id, erc1155_datas_len=erc1155_datas_len, ids_array=ids_array+ assets_ids_len * Uint256.SIZE);
}


func _write_storage_swap_erc1155_ids_inter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    data_idx : felt, start : felt, swap_id : felt, array_ids_len : felt, ids_array : Uint256*
){
    alloc_locals;
    if(start==array_ids_len){
        return ();
    }
    let id : Uint256 = [ids_array];
    mapping_erc1155_ids_per_swap.write(swap_id, data_idx, start, id);
    return _write_storage_swap_erc1155_ids_inter(data_idx=data_idx, start=start+1, swap_id=swap_id, array_ids_len=array_ids_len, ids_array=ids_array+ Uint256.SIZE);
}

func _write_storage_swap_erc1155_amounts{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, swap_id : felt, erc1155_datas_len :felt, amounts_array : Uint256*
){
    alloc_locals;
    if(start==erc1155_datas_len){
        return ();
    }
    // get size of ids array for index start of ERC1155DataStorage
    let (local data_storage: ERC1155DataStorage) = mapping_erc1155_assets_per_swap.read(swap_id, start);
    let assets_amounts_len = data_storage.assets_amounts_len;

    _write_storage_swap_erc1155_amounts_inter(start, 0, swap_id, assets_amounts_len, amounts_array);
    return _write_storage_swap_erc1155_amounts(start=start+1, swap_id=swap_id, erc1155_datas_len=erc1155_datas_len, amounts_array=amounts_array + assets_amounts_len * Uint256.SIZE);
}


func _write_storage_swap_erc1155_amounts_inter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    data_idx : felt, start : felt, swap_id : felt, array_ids_len : felt, amounts_array : Uint256*
){
    alloc_locals;
    if(start==array_ids_len){
        return ();
    }
    let amount : Uint256 = [amounts_array];
    mapping_erc1155_amounts_per_swap.write(swap_id, data_idx, start, amount);
    return _write_storage_swap_erc1155_amounts_inter(data_idx=data_idx, start=start+1, swap_id=swap_id, array_ids_len=array_ids_len, amounts_array= amounts_array+ Uint256.SIZE);
}



func _write_storage_swap_erc721_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, swap_id : felt, erc721_array_len :felt, erc721_array : ERC721DataInput*
){
    alloc_locals;
    if(start==erc721_array_len){
        return ();
    }
    let data : ERC721DataInput = [erc721_array];
    let (local new_id : Uint256) = _felt_to_uint(data.asset_id);
    let new_data : ERC721Data = ERC721Data(data.asset_contract,new_id);
    mapping_erc721_assets_per_swap.write(swap_id, start, new_data);

    return _write_storage_swap_erc721_data(start=start+1, swap_id=swap_id, erc721_array_len=erc721_array_len, erc721_array=erc721_array+ ERC721DataInput.SIZE);
}

func _write_storage_swap_erc20_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, swap_id : felt, erc20_array_len :felt, erc20_array : ERC20DataInput*
){
    alloc_locals;
    if(start==erc20_array_len){
        return ();
    }
    let data : ERC20DataInput = [erc20_array];
    let (local new_amount : Uint256) = _felt_to_uint(data.amount);
    let new_data : ERC20Data = ERC20Data(data.asset_contract,new_amount);
    mapping_erc20_assets_per_swap.write(swap_id, start, new_data);

    return _write_storage_swap_erc20_data(start=start+1, swap_id=swap_id, erc20_array_len=erc20_array_len, erc20_array=erc20_array+ ERC20DataInput.SIZE);
}


func _write_assets_inside_storage{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, start : felt}(
    swap_count : felt, _token_ids_len : felt, _token_ids : Uint256*
) {
    alloc_locals;
    if (_token_ids_len == 0) {
        return ();
    }
    let id = [_token_ids];
    _assets_ids_per_swap.write(swap_count, start, id);
    local new_start = start + 1;
    return _write_assets_inside_storage{
        syscall_ptr=syscall_ptr, pedersen_ptr=pedersen_ptr, range_check_ptr=range_check_ptr, start=new_start
    }(swap_count=swap_count, _token_ids_len=_token_ids_len - 1, _token_ids=_token_ids + Uint256.SIZE);
}
func _write_amounts_inside_storage{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, start : felt}(
    swap_count : felt, _token_amounts_len : felt, _token_amounts : Uint256*
) {
    alloc_locals;
    if (_token_amounts_len == 0) {
        return ();
    }
    let amount = [_token_amounts];
    _amounts_ids_per_swap.write(swap_count, start, amount);
    local new_start = start + 1;
    return _write_amounts_inside_storage{
        syscall_ptr=syscall_ptr, pedersen_ptr=pedersen_ptr, range_check_ptr=range_check_ptr, start=new_start
    }(swap_count=swap_count, _token_amounts_len=_token_amounts_len - 1, _token_amounts=_token_amounts + Uint256.SIZE);
}


// TODO : optimization 
func _write_storage_swap_erc1155_opt{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, swap_id : felt, bid_id : felt, erc1155_datas_len :felt, ids_array : Uint256*, amounts_array : Uint256*
){
    alloc_locals;
    if(start==erc1155_datas_len){
        return ();
    }
    // get size of ids array for index start of ERC1155DataStorage
    let (local data_storage: ERC1155DataStorage) = mapping_erc1155_assets_per_bid.read(swap_id, bid_id, start);
    let assets_ids_len = data_storage.assets_ids_len;

    _write_storage_swap_erc1155_opt_inter(start, 0, swap_id, bid_id, assets_ids_len, ids_array, amounts_array);
    return _write_storage_swap_erc1155_opt(start=start+1, swap_id=swap_id, bid_id=bid_id, erc1155_datas_len=erc1155_datas_len, ids_array=ids_array+ assets_ids_len * Uint256.SIZE, amounts_array=amounts_array+assets_ids_len* Uint256.SIZE);
}

func _write_storage_swap_erc1155_opt_inter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    data_idx : felt, start : felt, swap_id : felt, bid_id : felt, array_ids_len : felt, ids_array : Uint256*, amounts_array : Uint256*
){
    alloc_locals;
    if(start==array_ids_len){
        return ();
    }  
    let id : Uint256 = [ids_array];
    let amount : Uint256 = [amounts_array];
    mapping_erc1155_ids_per_bid.write(swap_id, bid_id, data_idx, start, id);
    mapping_erc1155_amounts_per_bid.write(swap_id, bid_id, data_idx, start, amount);
    return _write_storage_swap_erc1155_opt_inter(data_idx=data_idx, start=start+1, swap_id=swap_id, bid_id=bid_id, array_ids_len=array_ids_len, ids_array=ids_array+ Uint256.SIZE, amounts_array=amounts_array + Uint256.SIZE);
}



func _write_storage_bid_erc1155_ids{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, swap_id : felt, bid_id : felt, erc1155_datas_len :felt, ids_array : Uint256*
){
    alloc_locals;
    if(start==erc1155_datas_len){
        return ();
    }
    // get size of ids array for index start of ERC1155DataStorage
    let (local data_storage: ERC1155DataStorage) = mapping_erc1155_assets_per_bid.read(swap_id, bid_id, start);
    let assets_ids_len = data_storage.assets_ids_len;

    _write_storage_bid_erc1155_ids_inter(start, 0, swap_id, bid_id, assets_ids_len, ids_array);
    return _write_storage_bid_erc1155_ids(start=start+1, swap_id=swap_id, bid_id=bid_id, erc1155_datas_len=erc1155_datas_len, ids_array=ids_array+ assets_ids_len * Uint256.SIZE);
}



func _write_storage_bid_erc1155_ids_inter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    data_idx : felt, start : felt, swap_id : felt, bid_id : felt, array_ids_len : felt, ids_array : Uint256*
){
    alloc_locals;
    if(start==array_ids_len){
        return ();
    }  
    let id : Uint256 = [ids_array];
    //let amount : Uint256 = [amounts_array];
    mapping_erc1155_ids_per_bid.write(swap_id, bid_id, data_idx, start, id);
    //mapping_erc1155_amounts_per_bid.write(swap_id, bid_id, data_idx, start, amount);
    return _write_storage_bid_erc1155_ids_inter(data_idx=data_idx, start=start+1, swap_id=swap_id, bid_id=bid_id, array_ids_len=array_ids_len, ids_array=ids_array+ Uint256.SIZE);
}


func _write_storage_bid_erc1155_amounts{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, swap_id : felt, bid_id : felt, erc1155_datas_len :felt, amounts_array : Uint256*
){
    alloc_locals;
    if(start==erc1155_datas_len){
        return ();
    }
    // get size of ids array for index start of ERC1155DataStorage
    let (local data_storage: ERC1155DataStorage) = mapping_erc1155_assets_per_bid.read(swap_id, bid_id, start);
    let assets_ids_len = data_storage.assets_ids_len;

    _write_storage_bid_erc1155_amounts_inter(start, 0, swap_id, bid_id, assets_ids_len, amounts_array);
    return _write_storage_bid_erc1155_amounts(start=start+1, swap_id=swap_id, bid_id=bid_id, erc1155_datas_len=erc1155_datas_len, amounts_array=amounts_array+ assets_ids_len * Uint256.SIZE);
}



func _write_storage_bid_erc1155_amounts_inter{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    data_idx : felt, start : felt, swap_id : felt, bid_id : felt, array_ids_len : felt, amounts_array : Uint256*
){
    alloc_locals;
    if(start==array_ids_len){
        return ();
    }  
    let amount : Uint256 = [amounts_array];
    mapping_erc1155_amounts_per_bid.write(swap_id, bid_id, data_idx, start, amount);
    return _write_storage_bid_erc1155_amounts_inter(data_idx=data_idx, start=start+1, swap_id=swap_id, bid_id=bid_id, array_ids_len=array_ids_len, amounts_array=amounts_array+ Uint256.SIZE);
}



func _write_storage_bid_erc1155_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, swap_id : felt, bid_id : felt,  erc1155_datas_len : felt, erc1155_datas: ERC1155DataStorage*
){
    alloc_locals;
    if(start==erc1155_datas_len){
        return ();
    }
    let data : ERC1155DataStorage = [erc1155_datas];

    mapping_erc1155_assets_per_bid.write(swap_id, bid_id, start, data);

    return _write_storage_bid_erc1155_data(start=start+1, swap_id=swap_id, bid_id=bid_id, erc1155_datas_len=erc1155_datas_len, erc1155_datas=erc1155_datas+ ERC1155DataStorage.SIZE);
}

func _write_storage_swap_erc1155_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, swap_id : felt,  erc1155_datas_len : felt, erc1155_datas: ERC1155DataStorage*
){
    alloc_locals;
    if(start==erc1155_datas_len){
        return ();
    }
    let data : ERC1155DataStorage = [erc1155_datas];

    mapping_erc1155_assets_per_swap.write(swap_id, start, data);

    return _write_storage_swap_erc1155_data(start=start+1, swap_id=swap_id, erc1155_datas_len=erc1155_datas_len, erc1155_datas=erc1155_datas+ ERC1155DataStorage.SIZE);
}


func _write_storage_bid_erc721_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, swap_id : felt, bid_id : felt, erc721_array_len :felt, erc721_array : ERC721DataInput*
){
    alloc_locals;
    if(start==erc721_array_len){
        return ();
    }
    let data : ERC721DataInput = [erc721_array];
    let (local new_id : Uint256) = _felt_to_uint(data.asset_id);
    let new_data : ERC721Data = ERC721Data(data.asset_contract,new_id);
    mapping_erc721_assets_per_bid.write(swap_id, bid_id, start, new_data);

    return _write_storage_bid_erc721_data(start=start+1, swap_id=swap_id, bid_id=bid_id, erc721_array_len=erc721_array_len, erc721_array=erc721_array+ ERC721DataInput.SIZE);
}

func _write_storage_bid_erc20_data{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, swap_id : felt, bid_id : felt, erc20_array_len :felt, erc20_array : ERC20DataInput*
){
    alloc_locals;
    if(start==erc20_array_len){
        return ();
    }
    let data : ERC20DataInput = [erc20_array];
    let (local new_amount : Uint256) = _felt_to_uint(data.amount);
    let new_data : ERC20Data = ERC20Data(data.asset_contract,new_amount);
    mapping_erc20_assets_per_bid.write(swap_id, bid_id, start, new_data);

    return _write_storage_bid_erc20_data(start=start+1, swap_id=swap_id, bid_id=bid_id, erc20_array_len=erc20_array_len, erc20_array=erc20_array+ ERC20DataInput.SIZE);
}

func _get_active_swaps{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (swaps_ids_len : felt, swaps_ids :felt*){
    alloc_locals;
    let (local res : felt*) = alloc();
    local res_len = 0;
    _get_active_swaps_internal{
        syscall_ptr=syscall_ptr, pedersen_ptr=pedersen_ptr, range_check_ptr=range_check_ptr, strt=res_len
    }(start_tab=res);
    return (swaps_ids_len=res_len, swaps_ids=res);
}

func _get_active_swaps_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, strt : felt}(
    start_tab : felt*
) {
    alloc_locals;
    let (swap_count) = _swaps_counter.read();
    return _fill_active_swaps{
        syscall_ptr=syscall_ptr, pedersen_ptr=pedersen_ptr, range_check_ptr=range_check_ptr, strt=strt
    }(start=1, start_tab=start_tab, end=swap_count);
}

@view
func _get_cancelled_swaps{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (swaps_ids_len : felt, swaps_ids :felt*){
    alloc_locals;
    let (local res : felt*) = alloc();
    local res_len = 0;
    _get_cancelled_swaps_internal{
        syscall_ptr=syscall_ptr, pedersen_ptr=pedersen_ptr, range_check_ptr=range_check_ptr, strt=res_len
    }(start_tab=res);
    return (swaps_ids_len=res_len, swaps_ids=res);
}

func _get_cancelled_swaps_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, strt : felt}(
    start_tab : felt*
) {
    alloc_locals;
    let (swap_count) = _swaps_counter.read();
    return _fill_cancelled_swaps{
        syscall_ptr=syscall_ptr, pedersen_ptr=pedersen_ptr, range_check_ptr=range_check_ptr, strt=strt
    }(start=1, start_tab=start_tab, end=swap_count);
}


func _get_executed_swaps{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
) -> (swaps_ids_len : felt, swaps_ids :felt*){
    alloc_locals;
    let (local res : felt*) = alloc();
    local res_len = 0;
    _get_executed_swaps_internal{
        syscall_ptr=syscall_ptr, pedersen_ptr=pedersen_ptr, range_check_ptr=range_check_ptr, strt=res_len
    }(start_tab=res);
    return (swaps_ids_len=res_len, swaps_ids=res);
}

func _get_executed_swaps_internal{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, strt : felt}(
   start_tab : felt*
) {
    alloc_locals;
    let (swap_count) = _swaps_counter.read();
    return _fill_executed_swaps{
        syscall_ptr=syscall_ptr, pedersen_ptr=pedersen_ptr, range_check_ptr=range_check_ptr, strt=strt
    }(start=1, start_tab=start_tab, end=swap_count);
}

func _fill_executed_swaps{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, strt : felt}(
    start : felt, start_tab : felt*, end : felt
){
    alloc_locals;
    if (start==end){
        return ();
    }
    let (swap : Swap) = _swaps_v2.read(start);
    let status = swap.status;
    let id = swap.id;
    if (status == Erc1155SwapStatus.Executed) {
        assert [start_tab] = id;
        local new_len = strt + 1;
        return _fill_executed_swaps{
            syscall_ptr=syscall_ptr, pedersen_ptr=pedersen_ptr, range_check_ptr=range_check_ptr, strt=new_len
        }(start=start+1, start_tab = start_tab + 1, end=end);
    }
    local new_len = strt;
    return _fill_executed_swaps{
        syscall_ptr=syscall_ptr, pedersen_ptr=pedersen_ptr, range_check_ptr=range_check_ptr, strt=new_len
    }(start=start+1, start_tab = start_tab, end=end);
}

func _fill_cancelled_swaps{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, strt : felt}(
    start : felt, start_tab : felt*, end : felt
){
    alloc_locals;
    if (start==end){
        return ();
    }
    let (swap : Swap) = _swaps_v2.read(start);
    let status = swap.status;
    let id = swap.id;
    if (status == Erc1155SwapStatus.Cancelled) {
        assert [start_tab] = id;
        local new_len = strt + 1; 
        return _fill_cancelled_swaps{
            syscall_ptr=syscall_ptr, pedersen_ptr=pedersen_ptr, range_check_ptr=range_check_ptr, strt=new_len
        }(start=start+1, start_tab = start_tab + 1, end=end);
    }
    local new_len = strt;
    return _fill_cancelled_swaps{
        syscall_ptr=syscall_ptr, pedersen_ptr=pedersen_ptr, range_check_ptr=range_check_ptr, strt=new_len
    }(start=start+1, start_tab = start_tab, end=end);
}

func _fill_active_swaps{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, strt : felt}(
    start : felt, start_tab : felt*, end : felt
){
    alloc_locals;
    if (start==end){
        return ();
    }
    let (swap : Swap) = _swaps_v2.read(start);
    let status = swap.status;
    let id = swap.id;
    if (status == Erc1155SwapStatus.Opened) {
        assert [start_tab] = id;
        local new_len = strt + 1;
        return _fill_active_swaps{
            syscall_ptr=syscall_ptr, pedersen_ptr=pedersen_ptr, range_check_ptr=range_check_ptr, strt=new_len
        }(start=start+1, start_tab = start_tab + 1, end=end);
    }
    local new_len = strt;
    return _fill_active_swaps{
        syscall_ptr=syscall_ptr, pedersen_ptr=pedersen_ptr, range_check_ptr=range_check_ptr, strt=new_len
    }(start=start+1, start_tab = start_tab, end=end);
}

func _get_assets_ids_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    res_ : felt*, start : felt, token_ids_len : felt, swap_id : felt
) {
    if (token_ids_len==0){
        return ();
    }

    let (id : Uint256) = _assets_ids_per_swap.read(swap_id,start);
    // TODO ; is it safe to take the low part ? what if we have a number which is on both ends ?
    assert [res_] = id.low;
    return _get_assets_ids_per_swap(
        res_=res_+1, start=start+1, token_ids_len=token_ids_len-1, swap_id=swap_id
    );
}

func _get_amounts_ids_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    res_ : felt*, start : felt, amount_ids_len : felt, swap_id : felt
) {
    if (amount_ids_len==0){
        return ();
    }

    let (id : Uint256) = _amounts_ids_per_swap.read(swap_id,start);
    // TODO ; is it safe to take the low part ? what if we have a number which is on both ends ?
    assert [res_] = id.low;
    return _get_amounts_ids_per_swap(
        res_=res_+1, start=start+1, amount_ids_len=amount_ids_len-1, swap_id=swap_id
    );
}

func _get_erc1155_ids_per_bid_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, to_fill : Uint256*, array_len : felt, swap_id : felt, bid_id : felt, idx : felt
){
    alloc_locals;
    if(start==array_len){
        return ();
    }
    let (local id : Uint256) = mapping_erc1155_ids_per_bid.read(swap_id=swap_id, bid_id=bid_id, idx=idx, idx_token_id=start);
    assert [to_fill] = id;
    return _get_erc1155_ids_per_bid_per_swap(start=start+1, to_fill=to_fill+Uint256.SIZE, array_len=array_len, swap_id=swap_id, bid_id=bid_id, idx=idx);
}

func _get_erc1155_amounts_per_bid_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, to_fill : Uint256*, array_len : felt, swap_id : felt, bid_id : felt, idx : felt
){
    alloc_locals;
    if(start==array_len){
        return ();
    }
    let (local amount : Uint256) = mapping_erc1155_amounts_per_bid.read(swap_id=swap_id, bid_id=bid_id, idx=idx, idx_token_id=start);
    assert [to_fill] = amount;
    return _get_erc1155_amounts_per_bid_per_swap(start=start+1, to_fill=to_fill+Uint256.SIZE, array_len=array_len, swap_id=swap_id, bid_id=bid_id, idx=idx);
}

// SWAP VERSION

func _get_erc1155_ids_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, to_fill : Uint256*, array_len : felt, swap_id : felt, idx : felt
){
    alloc_locals;
    if(start==array_len){
        return ();
    }
    let (local id : Uint256) = mapping_erc1155_ids_per_swap.read(swap_id=swap_id, idx=idx, idx_token_id=start);
    assert [to_fill] = id;
    return _get_erc1155_ids_per_swap(start=start+1, to_fill=to_fill+Uint256.SIZE, array_len=array_len, swap_id=swap_id, idx=idx);
}

func _get_erc1155_amounts_per_swap{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, to_fill : Uint256*, array_len : felt, swap_id : felt, idx : felt
){
    alloc_locals;
    if(start==array_len){
        return ();
    }
    let (local amount : Uint256) = mapping_erc1155_amounts_per_swap.read(swap_id=swap_id, idx=idx, idx_token_id=start);
    assert [to_fill] = amount;
    return _get_erc1155_amounts_per_swap(start=start+1, to_fill=to_fill+Uint256.SIZE, array_len=array_len, swap_id=swap_id, idx=idx);
}

////

func _get_bids{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, swap_id : felt, bids : felt*, end : felt
) {
    alloc_locals;
    if(start==end){
        return ();
    }
    let (local bid : Bid) = bids_per_swap.read(swap_id, start);
    assert [bids] = bid.bid_id;
    return _get_bids(start=start+1, swap_id=swap_id, bids=bids+1, end=end);
}

func _get_bidders{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr}(
    start : felt, swap_id : felt, bidders : felt*, end : felt
) {
    alloc_locals;
    if(start==end){
        return ();
    }
    let (local bid : Bid) = bids_per_swap.read(swap_id, start);
    assert [bidders] = bid.owner;
    return _get_bidders(start=start+1, swap_id=swap_id, bidders=bidders+1, end=end);
}


func _convert_to_uint_array{syscall_ptr: felt*, pedersen_ptr: HashBuiltin*, range_check_ptr, start : felt}(
    to_fill : Uint256*, array_len : felt, array : felt*
){
    if(start==array_len) {
        return ();
    }
    let uint_val = [array];
    let value : Uint256 = _felt_to_uint(uint_val);
    assert [to_fill] = value;
    return _convert_to_uint_array(to_fill=to_fill+ Uint256.SIZE, array_len=array_len+1, array= array + 1);
}

// HELPERS
func _felt_to_uint{
    syscall_ptr: felt*,
    pedersen_ptr: HashBuiltin*,
    range_check_ptr
} (value: felt) -> (value: Uint256) {
    let (high, low) = split_felt(value);
    tempvar res: Uint256;
    res.high = high;
    res.low = low;
    return (value=res);
}