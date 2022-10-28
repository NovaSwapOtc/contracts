%lang starknet

from starkware.cairo.common.uint256 import Uint256
from src.otc_module.otc_module import (
    ERC1155DataStorage,
    ERC721DataInput,
    ERC20DataInput
)
@contract_interface
namespace IOtcModule {
    func get_swap_counter() -> (value : felt) {
    }

    func get_swap_status(idx: felt) -> (value : felt) {
    }

    func open_swap(
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
    ){
    }

    func bid_swap(  
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
    ){
    }

    func get_amount_bids_per_swap(
        swap_id : felt
    ) -> (res : felt){
    }

    func execute_swap(
        swap_id : felt, bid_id : felt
    ){
    }

    func get_erc721_per_swap(
        swap_id : felt, idx : felt
    ) -> (address : felt, id : Uint256){
    }
    
}